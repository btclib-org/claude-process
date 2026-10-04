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
#   d=$(mktemp -d); gate_take "$d" && gate_release "$d"; rmdir "$d"
#
# gate_take waits for the load (at most ~20 minutes, then runs anyway),
# then for the lock (at most ~30 minutes). It writes the holder's PID into
# the lock, so that only the holder releases it. A lock whose holder's
# process is gone is stale, and gate_take removes it.
#
# Reclaiming renames the owner file, which only one waiter wins (mv is
# atomic; the others find no file). The winner reads the PID in what it
# moved: only if that is the dead PID it judged stale does it remove the
# lock. Otherwise its read was out of date and it moved a live holder's
# file, which it puts back at once. While the lock has no owner file nobody
# reclaims it, and gate_release reads again for up to 5 seconds. A waiter
# killed while it holds the owner file renamed to stale.<pid> leaves a lock
# with no owner, which the human removes.

gate_take() {
  [ -d "$1" ] || {
    echo "usage: gate_take <scratchpad> [<worktree>]; no directory '$1'"
    return 1
  }
  _gl_lock="$1/gate.lock"
  _gl_n=$(getconf _NPROCESSORS_ONLN)
  _gl_i=0
  while [ "$_gl_i" -lt 40 ]; do
    if [ -r /proc/loadavg ]; then _gl_l=$(cut -d' ' -f1 /proc/loadavg)
    else _gl_l=$(LC_ALL=C sysctl -n vm.loadavg | cut -d' ' -f2); fi
    [ "${_gl_l%.*}" -lt $((2 * _gl_n)) ] && break
    _gl_i=$((_gl_i + 1)); sleep 30
  done
  _gl_i=0
  while [ "$_gl_i" -lt 60 ]; do
    if mkdir "$_gl_lock" 2>/dev/null; then
      echo "$$ $(date +%s) ${2:-}" > "$_gl_lock/owner"
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
    _gl_i=$((_gl_i + 1)); sleep 30
  done
  echo "gate.lock still held after ~30 min: $(cat "$_gl_lock/owner" 2>/dev/null)"
  return 1
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
