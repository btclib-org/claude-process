# shellcheck shell=sh
# The gate lock, shared by every worker of a session. POSIX sh, sourced in
# the same shell call that runs the gates, so that `$$` is the holder:
#
#   . ~/.claude/scripts/gate-lock.sh
#   gate_take <scratchpad> <worktree> && { <gates>; gate_release <scratchpad>; }
#
# gate_take waits for the load (at most ~20 minutes, then runs anyway),
# then for the lock (at most ~30 minutes). It writes the holder's PID into
# the lock, so that only the holder releases it. A lock whose holder's
# process is gone is stale, and gate_take removes it.

gate_take() {
  [ -d "$1" ] || { echo "gate_take: no directory $1"; return 1; }
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
    if [ -n "$_gl_pid" ] && ! ps -p "$_gl_pid" >/dev/null 2>&1; then
      echo "gate.lock of pid $_gl_pid is stale, its process gone: removed"
      rm -f "$_gl_lock/owner"
      rmdir "$_gl_lock" 2>/dev/null
      continue
    fi
    _gl_i=$((_gl_i + 1)); sleep 30
  done
  echo "gate.lock still held after ~30 min: $(cat "$_gl_lock/owner" 2>/dev/null)"
  return 1
}

gate_release() {
  _gl_lock="$1/gate.lock"
  _gl_pid=""
  [ -r "$_gl_lock/owner" ] && read -r _gl_pid _ < "$_gl_lock/owner"
  if [ "$_gl_pid" = "$$" ]; then
    rm -f "$_gl_lock/owner"
    rmdir "$_gl_lock"
    echo "gate.lock released by $$"
  else
    echo "gate.lock is not ours (holder ${_gl_pid:-unknown}, we are $$): left alone"
    return 1
  fi
}
