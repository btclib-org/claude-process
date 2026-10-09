# shellcheck shell=sh
# The gate lock, shared by every worker of a session. POSIX sh, sourced in
# the same shell call that runs the gates, so that `$$` is the holder:
#
#   . ~/.claude/scripts/gate-lock.sh
#   gate_take <scratchpad> <worktree> && { <gates>; gate_release <scratchpad>; }
#
# Without a directory, both print their usage and return 1. To check, from
# the repository root in a fresh sh:
#
#   . scripts/gate-lock.sh
#   gate_take; echo $?
#   gate_release; echo $?
#   d=$(mktemp -d); gate_take "$d" && gate_release "$d"; rm -r "$d"
#
# Waiters queue in arrival order. gate_take writes a ticket into
# <scratchpad>/gate.queue, named by its arrival time and PID, and waits
# until its ticket is the oldest one whose process is alive. Then it waits
# for the load to fall under GATE_LOCK_LOAD and takes the lock. Neither
# wait has a bound: a holder that never finishes keeps every waiter
# waiting, and `cat <scratchpad>/gate.lock/owner` names it.
#
# A ticket holds its PID, that process's start time, read in UTC, and the
# worktree. A ticket whose process is gone, or whose PID now belongs to a
# process started at another time, is dead, and any waiter removes it.
#
# gate_take writes the holder's PID into the lock, so that only the holder
# releases it. A lock whose holder's process is gone is stale, and
# gate_take removes it.
#
# Reclaiming renames the owner file, which only one waiter wins (mv is
# atomic; the others find no file). The winner reads the PID in what it
# moved: only if that is the dead PID it judged stale does it remove the
# lock. Otherwise its read was out of date and it moved a live holder's
# file, which it puts back at once. While the lock has no owner file nobody
# reclaims it, and gate_release reads again for up to 5 seconds. A waiter
# killed while it holds the owner file renamed to stale.<pid> leaves a lock
# with no owner, which the human removes.

GATE_LOCK_LOAD=${GATE_LOCK_LOAD:-20}
GATE_LOCK_POLL=${GATE_LOCK_POLL:-5}

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

gate_take() {
  [ -d "$1" ] || {
    echo "usage: gate_take <scratchpad> [<worktree>]; no directory '$1'"
    return 1
  }
  _gl_lock="$1/gate.lock"
  _gl_queue="$1/gate.queue"
  mkdir -p "$_gl_queue"
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
      printf '%s\n%s\n%s\n' "$$" "$_gl_start" "${2:-}" > "$_gl_queue/.$$" &&
        mv "$_gl_queue/.$$" "$_gl_ticket"
    }
    _gl_head=""
    for _gl_t in "$_gl_queue"/*; do
      [ -f "$_gl_t" ] || continue
      if _gl_alive "$_gl_t"; then _gl_head=$_gl_t; break; fi
      rm -f "$_gl_t"
    done
    [ "$_gl_head" = "$_gl_ticket" ] || { sleep "$GATE_LOCK_POLL"; continue; }
    _gl_l=$(_gl_load)
    [ "${_gl_l%.*}" -lt "$GATE_LOCK_LOAD" ] || { sleep "$GATE_LOCK_POLL"; continue; }
    if mkdir "$_gl_lock" 2>/dev/null; then
      echo "$$ $(date +%s) ${2:-}" > "$_gl_lock/owner"
      rm -f "$_gl_ticket"
      echo "gate.lock taken by $$ at load $_gl_l"
      return 0
    fi
    _gl_pid=""
    [ -r "$_gl_lock/owner" ] && read -r _gl_pid _ < "$_gl_lock/owner"
    if [ -n "$_gl_pid" ] && ! ps -p "$_gl_pid" >/dev/null 2>&1 &&
      mv "$_gl_lock/owner" "$_gl_lock/stale.$$" 2>/dev/null; then
      _gl_now=""
      read -r _gl_now _ < "$_gl_lock/stale.$$"
      if [ "$_gl_now" = "$_gl_pid" ]; then
        echo "gate.lock of pid $_gl_pid is stale, its process gone: removed"
        rm -f "$_gl_lock/stale.$$"
        rmdir "$_gl_lock" 2>/dev/null
      else
        mv "$_gl_lock/stale.$$" "$_gl_lock/owner"
      fi
      continue
    fi
    sleep "$GATE_LOCK_POLL"
  done
}

gate_release() {
  [ -d "$1" ] || {
    echo "usage: gate_release <scratchpad>; no directory '$1'"
    return 1
  }
  _gl_lock="$1/gate.lock"
  _gl_i=0
  while [ "$_gl_i" -lt 5 ]; do
    _gl_pid=""
    [ -r "$_gl_lock/owner" ] && read -r _gl_pid _ < "$_gl_lock/owner"
    if [ "$_gl_pid" = "$$" ]; then
      rm -f "$_gl_lock/owner"
      rmdir "$_gl_lock" 2>/dev/null &&
        { echo "gate.lock released by $$"; return 0; }
    elif [ -n "$_gl_pid" ]; then
      break
    fi
    _gl_i=$((_gl_i + 1)); sleep 1
  done
  echo "gate.lock is not ours (holder ${_gl_pid:-unknown}, we are $$): left alone"
  return 1
}
