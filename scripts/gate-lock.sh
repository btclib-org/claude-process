# shellcheck shell=sh
# The gate lock, by default one per user, shared by every worker of every
# session that user runs. It has GATE_LOCK_SLOTS slots, 3 by default, so
# that many workers gate at once. POSIX sh, sourced in the same shell call
# that runs the gates, so that `$$` is the holder:
#
#   . ~/.claude/scripts/gate-lock.sh
#   gate_take [<worktree>] && { gate_wait; <a gate>; gate_wait; <a gate>; gate_release; }
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
# as gate_wait does, and takes the first free slot. gate_wait waits until
# the 1-minute load is under GATE_LOCK_LOAD, GATE_LOCK_DISK GB or more of
# disk is free where $GATE_LOCK_DIR sits (/tmp when it is unset), and
# memory is admissible: pressure level 1, or level 2 with GATE_LOCK_FREE
# percent of memory or more free, never level 4. Where a read fails, as
# off macOS, it does not wait on that read. It prints the load, the level,
# the percentage free and the disk free. Neither wait has a bound: holders
# that never finish keep every waiter waiting, and this names them:
#
#   cat "${GATE_LOCK_DIR:-/tmp/claude-$(id -u)/gate}"/gate.lock*/owner
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

GATE_LOCK_SLOTS=${GATE_LOCK_SLOTS:-3}
GATE_LOCK_LOAD=${GATE_LOCK_LOAD:-15}
GATE_LOCK_FREE=${GATE_LOCK_FREE:-30}
GATE_LOCK_DISK=${GATE_LOCK_DISK:-20}
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

_gl_level() { sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null; }
_gl_free() { sysctl -n kern.memorystatus_level 2>/dev/null; }

# GB available, in units of 1024^3 bytes as `df -g` counts them
_gl_disk() {
  LC_ALL=C df -Pk "${GATE_LOCK_DIR:-/tmp}" 2>/dev/null |
    awk 'NR == 2 { print int($4 / 1048576) }'
}

# Reads load, level, free and disk into _gl_l, _gl_p, _gl_f and _gl_g;
# succeeds when all four admit a gate. An empty read admits.
_gl_admit() {
  _gl_l=$(_gl_load 2>/dev/null) _gl_p=$(_gl_level) _gl_f=$(_gl_free)
  _gl_g=$(_gl_disk)
  [ -z "${_gl_l%.*}" ] || [ "${_gl_l%.*}" -lt "$GATE_LOCK_LOAD" ] || return 1
  [ -z "$_gl_g" ] || [ "$_gl_g" -ge "$GATE_LOCK_DISK" ] || return 1
  [ -z "$_gl_p" ] || [ "$_gl_p" -le 1 ] && return 0
  [ "$_gl_p" -eq 2 ] && { [ -z "$_gl_f" ] || [ "$_gl_f" -ge "$GATE_LOCK_FREE" ]; }
}

_gl_status() {
  echo "load ${_gl_l:-?}, memory pressure level ${_gl_p:-?}, ${_gl_f:-?}% free, ${_gl_g:-?} GB disk free"
}

gate_wait() {
  until _gl_admit; do sleep "$GATE_LOCK_POLL"; done
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
        mv "$_gl_queue/.$$" "$_gl_ticket"
    }
    _gl_head=""
    for _gl_t in "$_gl_queue"/*; do
      [ -f "$_gl_t" ] || continue
      if _gl_alive "$_gl_t"; then _gl_head=$_gl_t; break; fi
      rm -f "$_gl_t"
    done
    [ "$_gl_head" = "$_gl_ticket" ] || { sleep "$GATE_LOCK_POLL"; continue; }
    _gl_admit || { sleep "$GATE_LOCK_POLL"; continue; }
    _gl_i=1 _gl_freed=""
    while [ "$_gl_i" -le "$GATE_LOCK_SLOTS" ]; do
      _gl_slot "$_gl_i"
      if mkdir "$_gl_s" 2>/dev/null; then
        echo "$$ $(date +%s) $_gl_wt" > "$_gl_s/owner"
        rm -f "$_gl_ticket"
        echo "${_gl_s##*/} taken by $$ at $(_gl_status)"
        return 0
      fi
      _gl_reclaim && _gl_freed=1
      _gl_i=$((_gl_i + 1))
    done
    [ -n "$_gl_freed" ] || sleep "$GATE_LOCK_POLL"
  done
}

gate_release() {
  _gl_dir || return 1
  _gl_i=0
  while [ "$_gl_i" -lt 5 ]; do
    # a slot with no owner file may be ours, its file renamed by a waiter
    # that is about to put it back
    _gl_unowned=""
    for _gl_s in "$_gl_d"/gate.lock "$_gl_d"/gate.lock.*; do
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
