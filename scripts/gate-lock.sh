# shellcheck shell=sh
# The gate lock, by default one per user, shared by every worker of every
# session that user runs. It has GATE_LOCK_SLOTS slots, 3 by default, so
# that many workers gate at once. POSIX sh, sourced in the same shell call
# that runs the gates, so that `$$` is the holder. Sourcing sets
# GATE_LOCK_WORKERS, the cores divided by the slots, for the `-n` of a
# suite run in a slot:
#
#   . ~/.claude/scripts/gate-lock.sh
#   gate_take [<worktree>] && { gate_wait; <a gate>; gate_wait; <a gate>; gate_release; }
#
# A load generator takes every slot with gate_take_all and releases them with
# gate_release_all. One runs at a time.
#
# The slots and the queue sit in $GATE_LOCK_DIR, by default
# /tmp/claude-<uid>/gate. The first slot is the directory gate.lock, the
# others gate.lock.2, gate.lock.3 and so on. A script that knows one lock
# only takes gate.lock, so its holder fills the first slot.
# `gate_take <scratchpad> <worktree>` and `gate_release <scratchpad>` take
# and release a slot as the one-argument forms do: the scratchpad is
# ignored.
#
# Waiters queue in arrival order. gate_take writes a ticket into
# $GATE_LOCK_DIR/gate.queue, named by its arrival time and PID, and waits
# until its ticket is the oldest one whose process is alive. Then it waits,
# as gate_wait does, and takes the first free slot. While a slot is held,
# it takes none within GATE_LOCK_STAGGER seconds of the last take recorded
# in gate.last, so that the idle reading shows the gate just started. A
# slot is held while its owner file names a live process, so that a stale
# slot does not hold the next take back. gate.last sits in
# $GATE_LOCK_DIR and is written aside and renamed. gate_wait waits
# until GATE_LOCK_IDLE percent or more of the CPU was idle over the last
# GATE_LOCK_POLL seconds, the 1-minute load is under GATE_LOCK_LOAD, GATE_LOCK_DISK GB or
# more of disk is free where $GATE_LOCK_DIR sits (/tmp when it is unset),
# and memory is admissible: pressure level 1, or level 2 with GATE_LOCK_FREE
# percent of memory or more free, never level 4. Where a read fails, as
# off macOS, it does not wait on that read. It prints the idle percentage,
# the load, the level, the percentage free and the disk free. The idle
# percentage is the gate; the load, which on macOS counts threads that use
# no CPU, is only a ceiling that catches a runaway. These waits have no
# bound, nor has the wait for gate.generator: holders that never finish keep
# every waiter waiting. btclib-common.md's "The gates" (the gate lock) gives the command
# that names them.
#
# To check, from the repository root in a fresh sh, with a directory of
# your own so as not to wait on a real gate:
#
#   . scripts/gate-lock.sh
#   GATE_LOCK_DIR=$(mktemp -d); export GATE_LOCK_DIR
#   gate_take; echo $?
#   gate_release; echo $?
#   rm -r "$GATE_LOCK_DIR"
#
# A ticket holds its PID, that process's start time, read in UTC, and the
# worktree. A ticket whose process is gone, or whose PID now belongs to a
# process started at another time, is dead, and any waiter removes it.
#
# gate_take writes the holder's PID into the slot's owner file, so that
# only the holder releases it. A slot whose holder's process is gone is
# stale, and gate_take removes it.
#
# Reclaiming renames the owner file, which only one waiter wins (mv is
# atomic; the others find no file). The winner reads the PID in what it
# moved: only if that is the dead PID it judged stale does it remove the
# slot. Otherwise its read was out of date and it moved a live holder's
# file, which it puts back at once. While a slot has no owner file nobody
# reclaims it, and gate_release reads again for up to 5 seconds. A waiter
# killed while it holds the owner file renamed to stale.<pid> leaves a slot
# with no owner, which the human removes.

# The number of cores
_gl_ncpu() {
  sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null ||
    nproc 2>/dev/null || echo 1
}

# The load ceiling and the workers follow the cores, so that they hold on any machine
_gl_cpus=$(_gl_ncpu)
GATE_LOCK_SLOTS=${GATE_LOCK_SLOTS:-3}
[ "$GATE_LOCK_SLOTS" -ge 1 ] 2>/dev/null || GATE_LOCK_SLOTS=1
GATE_LOCK_LOAD=${GATE_LOCK_LOAD:-$((_gl_cpus * 3))}
GATE_LOCK_IDLE=${GATE_LOCK_IDLE:-30}
GATE_LOCK_WORKERS=${GATE_LOCK_WORKERS:-$((_gl_cpus / GATE_LOCK_SLOTS))}
[ "$GATE_LOCK_WORKERS" -ge 1 ] || GATE_LOCK_WORKERS=1
GATE_LOCK_FREE=${GATE_LOCK_FREE:-30}
GATE_LOCK_DISK=${GATE_LOCK_DISK:-20}
GATE_LOCK_STAGGER=${GATE_LOCK_STAGGER:-60}
GATE_LOCK_POLL=${GATE_LOCK_POLL:-5}

_gl_dir() {
  _gl_d=${GATE_LOCK_DIR:-/tmp/claude-$(id -u)/gate}
  [ -d "$_gl_d" ] || (umask 077 && mkdir -p "$_gl_d") || {
    echo "gate lock: cannot create '$_gl_d'"
    return 1
  }
}

# The directory of slot $1: gate.lock for the first, gate.lock.<n> after it
_gl_slot() {
  if [ "$1" -eq 1 ]; then _gl_s="$_gl_d/gate.lock"
  else _gl_s="$_gl_d/gate.lock.$1"; fi
}

_gl_started() {
  # ps pads the time with spaces, which `read` strips: squeeze them so that
  # the ticket and a fresh read compare equal
  LC_ALL=C TZ=UTC0 ps -o lstart= -p "$1" 2>/dev/null |
    tr -s ' ' | sed 's/^ //; s/ $//'
}

_gl_alive() {
  # $1 is a ticket: "<pid>" on its first line, its start time on the second
  _gl_tpid="" _gl_tstart=""
  { { read -r _gl_tpid; read -r _gl_tstart; } < "$1"; } 2>/dev/null || return 1
  [ -n "$_gl_tpid" ] && [ -n "$_gl_tstart" ] &&
    [ "$(_gl_started "$_gl_tpid")" = "$_gl_tstart" ]
}

_gl_load() {
  if [ -r /proc/loadavg ]; then cut -d' ' -f1 /proc/loadavg
  else LC_ALL=C sysctl -n vm.loadavg | cut -d' ' -f2; fi
}

# The percentage of CPU idle over the next GATE_LOCK_POLL seconds, as an
# integer. The read is the wait of a poll, so that a poll costs the same
# time whether or not the read works. Linux reads /proc/stat twice; macOS
# reads the second line of `iostat -c 2`, the first being the average since
# boot. Where it fails it prints nothing.
_gl_idle() {
  if [ -r /proc/stat ]; then
    { head -n 1 /proc/stat; sleep "$GATE_LOCK_POLL"; head -n 1 /proc/stat; } |
      awk '{ t = 0; for (i = 2; i <= NF; i++) t += $i
             if (NR == 1) { t0 = t; i0 = $5 }
             else if (t > t0) print int(($5 - i0) * 100 / (t - t0)) }'
  else
    _gl_o=$(LC_ALL=C iostat -c 2 -w "$GATE_LOCK_POLL" 2>/dev/null |
      awk 'END { if ($(NF-3) ~ /^[0-9]+$/) print $(NF-3) }')
    if [ -n "$_gl_o" ]; then echo "$_gl_o"; else sleep "$GATE_LOCK_POLL"; fi
  fi
}

_gl_level() { sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null; }
_gl_free() { sysctl -n kern.memorystatus_level 2>/dev/null; }

# GB available, in units of 1024^3 bytes as `df -g` counts them
_gl_disk() {
  LC_ALL=C df -Pk "${GATE_LOCK_DIR:-/tmp}" 2>/dev/null |
    awk 'NR == 2 { print int($4 / 1048576) }'
}

# Reads idle, load, level, free and disk into _gl_u, _gl_l, _gl_p, _gl_f and
# _gl_g; succeeds when all five admit a gate. An empty read admits.
_gl_admit() {
  _gl_u=$(_gl_idle 2>/dev/null) _gl_l=$(_gl_load 2>/dev/null)
  _gl_p=$(_gl_level) _gl_f=$(_gl_free) _gl_g=$(_gl_disk)
  [ -z "$_gl_u" ] || [ "$_gl_u" -ge "$GATE_LOCK_IDLE" ] || return 1
  [ -z "${_gl_l%.*}" ] || [ "${_gl_l%.*}" -lt "$GATE_LOCK_LOAD" ] || return 1
  [ -z "$_gl_g" ] || [ "$_gl_g" -ge "$GATE_LOCK_DISK" ] || return 1
  [ -z "$_gl_p" ] || [ "$_gl_p" -le 1 ] && return 0
  [ "$_gl_p" -eq 2 ] && { [ -z "$_gl_f" ] || [ "$_gl_f" -ge "$GATE_LOCK_FREE" ]; }
}

_gl_status() {
  echo "${_gl_u:-?}% CPU idle, load ${_gl_l:-?}, memory pressure level ${_gl_p:-?}, ${_gl_f:-?}% free, ${_gl_g:-?} GB disk free"
}

# Succeeds when GATE_LOCK_STAGGER seconds or more have passed since the last
# take, or when the time of the last take is unreadable or in the future
_gl_spaced() {
  _gl_last=""
  [ -r "$_gl_d/gate.last" ] && read -r _gl_last < "$_gl_d/gate.last"
  case $_gl_last in
    "" | *[!0-9]* | 0?* | ???????????*) return 0 ;;
  esac
  _gl_gap=$(($(date +%s) - _gl_last))
  [ "$_gl_gap" -lt 0 ] || [ "$_gl_gap" -ge "$GATE_LOCK_STAGGER" ]
}

# Succeeds when the owner file of a slot names a live process
_gl_held() {
  _gl_hn=1
  # counted rather than globbed: zsh stops at a glob with no match
  while [ "$_gl_hn" -le "$GATE_LOCK_SLOTS" ]; do
    _gl_slot "$_gl_hn"
    _gl_hn=$((_gl_hn + 1))
    _gl_hpid=""
    [ -r "$_gl_s/owner" ] && read -r _gl_hpid _ < "$_gl_s/owner"
    [ -n "$_gl_hpid" ] && ps -p "$_gl_hpid" >/dev/null 2>&1 && return 0
  done
  return 1
}

# Records now as the time of the last take. It is written before the ticket
# is removed, so that the next head reads it. The rename keeps a reader from
# a half written file.
_gl_stamp() {
  date +%s > "$_gl_d/.last.$$" && mv "$_gl_d/.last.$$" "$_gl_d/gate.last"
}

gate_wait() {
  until _gl_admit; do :; done
  echo "gate_wait: $(_gl_status)"
}

# Removes slot $_gl_s if its holder's process is gone; succeeds if it did
_gl_reclaim() {
  _gl_pid=""
  [ -r "$_gl_s/owner" ] && read -r _gl_pid _ < "$_gl_s/owner"
  [ -n "$_gl_pid" ] || return 1
  ! ps -p "$_gl_pid" >/dev/null 2>&1 || return 1
  mv "$_gl_s/owner" "$_gl_s/stale.$$" 2>/dev/null || return 1
  _gl_now=""
  read -r _gl_now _ < "$_gl_s/stale.$$"
  if [ "$_gl_now" = "$_gl_pid" ]; then
    echo "${_gl_s##*/} of pid $_gl_pid is stale, its process gone: removed"
    rm -f "$_gl_s/stale.$$"
    rmdir "$_gl_s" 2>/dev/null
    return 0
  fi
  mv "$_gl_s/stale.$$" "$_gl_s/owner"
  return 1
}

gate_take() {
  _gl_dir || return 1
  _gl_wt=${2:-${1:-}}
  _gl_queue="$_gl_d/gate.queue"
  _gl_start=$(_gl_started $$)
  [ -n "$_gl_start" ] || {
    echo "gate_take: ps -o lstart= prints nothing for pid $$"
    return 1
  }
  _gl_ticket="$_gl_queue/$(date +%s).$(printf '%010d' $$)"
  while :; do
    # written aside and renamed, so that no waiter reads it half written,
    # and written again if a waiter removed it, so that it keeps its place
    [ -f "$_gl_ticket" ] || {
      mkdir -p "$_gl_queue" &&
      printf '%s\n%s\n%s\n' "$$" "$_gl_start" "$_gl_wt" > "$_gl_queue/.$$" &&
        mv "$_gl_queue/.$$" "$_gl_ticket" &&
        # long enough for a ticket written at the same moment to be seen
        # by the first scan, so that two new waiters do not both find
        # themselves at the head
        sleep 1
    }
    _gl_head=""
    # listed rather than globbed: zsh stops at a glob with no match. The
    # names are digits and a dot, so each line is one whole name.
    while read -r _gl_t; do
      _gl_t="$_gl_queue/$_gl_t"
      [ -f "$_gl_t" ] || continue
      if _gl_alive "$_gl_t"; then _gl_head=$_gl_t; break; fi
      rm -f "$_gl_t"
    done <<EOF
$(ls "$_gl_queue" 2>/dev/null)
EOF
    [ "$_gl_head" = "$_gl_ticket" ] || { sleep "$GATE_LOCK_POLL"; continue; }
    ! _gl_held || _gl_spaced || { sleep "$GATE_LOCK_POLL"; continue; }
    _gl_admit || continue
    _gl_i=1
    while [ "$_gl_i" -le "$GATE_LOCK_SLOTS" ]; do
      _gl_slot "$_gl_i"
      if mkdir "$_gl_s" 2>/dev/null; then
        echo "$$ $(date +%s) $_gl_wt" > "$_gl_s/owner"
        _gl_stamp
        rm -f "$_gl_ticket"
        echo "${_gl_s##*/} taken by $$ at $(_gl_status)"
        return 0
      fi
      _gl_reclaim
      _gl_i=$((_gl_i + 1))
    done
    # no sleep here: the admit above waited a poll
  done
}

gate_release() {
  _gl_dir || return 1
  _gl_i=0
  while [ "$_gl_i" -lt 5 ]; do
    # a slot with no owner file may be ours, its file renamed by a waiter
    # that is about to put it back
    _gl_unowned="" _gl_n=1
    # counted rather than globbed: zsh stops at a glob with no match
    while [ "$_gl_n" -le "$GATE_LOCK_SLOTS" ]; do
      _gl_slot "$_gl_n"
      _gl_n=$((_gl_n + 1))
      [ -d "$_gl_s" ] || continue
      _gl_pid=""
      [ -r "$_gl_s/owner" ] && read -r _gl_pid _ < "$_gl_s/owner"
      if [ "$_gl_pid" = "$$" ]; then
        rm -f "$_gl_s/owner"
        rmdir "$_gl_s" 2>/dev/null &&
          { echo "${_gl_s##*/} released by $$"; return 0; }
      elif [ -z "$_gl_pid" ]; then
        _gl_unowned=1
      fi
    done
    [ -n "$_gl_unowned" ] || break
    _gl_i=$((_gl_i + 1)); sleep 1
  done
  echo "no gate slot is held by $$: left alone"
  return 1
}

# A load generator takes every slot. Two generators that each took slots one
# by one would split them and wait on each other for ever, so the generator
# first takes gate.generator, a directory holding an owner file as a slot
# does, and removed as a stale slot is. Then it takes every slot. While it
# waits for the rest it holds the slots it has. btclib-common.md's "The gates"
# says what that costs.
gate_take_all() {
  _gl_dir || return 1
  _gl_gwt=${2:-${1:-}}
  while :; do
    _gl_s="$_gl_d/gate.generator"
    if mkdir "$_gl_s" 2>/dev/null; then
      echo "$$ $(date +%s) $_gl_gwt" > "$_gl_s/owner"
      break
    fi
    _gl_reclaim || sleep "$GATE_LOCK_POLL"
  done
  _gl_gi=0
  while [ "$_gl_gi" -lt "$GATE_LOCK_SLOTS" ]; do
    gate_take "$_gl_gwt" || { gate_release_all >/dev/null; return 1; }
    _gl_gi=$((_gl_gi + 1))
  done
}

# Releases every slot this shell holds, then gate.generator; fails if it
# released nothing
gate_release_all() {
  _gl_dir || return 1
  _gl_gi=0 _gl_gn=0
  while [ "$_gl_gi" -lt "$GATE_LOCK_SLOTS" ]; do
    gate_release || break
    _gl_gn=$((_gl_gn + 1))
    _gl_gi=$((_gl_gi + 1))
  done
  _gl_s="$_gl_d/gate.generator"
  _gl_pid=""
  [ -r "$_gl_s/owner" ] && read -r _gl_pid _ < "$_gl_s/owner"
  if [ "$_gl_pid" = "$$" ]; then
    rm -f "$_gl_s/owner"
    rmdir "$_gl_s" 2>/dev/null &&
      { echo "gate.generator released by $$"; _gl_gn=$((_gl_gn + 1)); }
  fi
  [ "$_gl_gn" -gt 0 ]
}
