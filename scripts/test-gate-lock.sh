#!/bin/sh
# Two sessions, each with a scratchpad of its own, ask for the gate lock,
# the second while the first holds it. The lock holds if the second takes
# it only after the first releases:
#
#   sh scripts/test-gate-lock.sh [<gate-lock.sh>]
#
# Each session is a `sh` of its own, since the holder is its PID, and
# calls `gate_take <scratchpad> <worktree>`. gate-lock.sh ignores the
# scratchpad. A script that keeps one lock per scratchpad fails the test,
# unless its gate_take for B is slow enough to return after A's 3-second
# hold: no order of events tells that apart from a lock.
# Each session writes "<name> asks" before gate_take, "<name> taken" and
# "<name> released" around its hold, and "<name> done" once gate_release
# succeeds. The test polls for A's take, and then for both "done" lines,
# once a second up to 30 times each. Past either, it kills the sessions it
# started and their children, and exits 1. Otherwise it exits 0 when the
# other lines read A asks, A taken, B asks, A released, B taken, B
# released, in that order, and 1 when they do not.
#
# Load and memory are stubbed, so that the test does not depend on the
# machine: a session redefines _gl_load, _gl_level and _gl_free after
# sourcing, the load from the file $tmp/load. A third session takes the
# lock at a low load, finds the load high when it calls gate_wait, and must
# return from it only after the test lowers the load. The memory cases call
# _gl_admit with each level and free percentage.

# The stubs are called by the sourced script, and the script is a variable.
# shellcheck disable=SC1090,SC2329
script=${1:-$(dirname "$0")/gate-lock.sh}
tmp=$(mktemp -d) || exit 1
trap 'rm -r "$tmp"' EXIT
GATE_LOCK_DIR=$tmp/lock GATE_LOCK_POLL=1 GATE_LOCK_LOAD=20 GATE_LOCK_FREE=30
export GATE_LOCK_DIR GATE_LOCK_POLL GATE_LOCK_LOAD GATE_LOCK_FREE
echo 5 > "$tmp/load"
mkdir "$tmp/scratchpad-A" "$tmp/scratchpad-B"
: > "$tmp/events"

session() { # <name> <scratchpad> <seconds held>
  exec sh -c '
    . "$1"
    load=$6
    _gl_load() { cat "$load"; }
    _gl_level() { echo 1; }
    _gl_free() { echo 50; }
    echo "$(date +%s) $2 asks" >> "$4"
    gate_take "$3" "wt-$2" >/dev/null || exit 1
    echo "$(date +%s) $2 taken" >> "$4"
    sleep "$5"
    echo "$(date +%s) $2 released" >> "$4"
    gate_release "$3" >/dev/null || exit 1
    echo "$(date +%s) $2 done" >> "$4"
  ' sh "$script" "$1" "$2" "$tmp/events" "$3" "$tmp/load"
}

fail() { # <reason>: stop the sessions started and their children
  for pid in "$pid_a" "$pid_b"; do
    [ -n "$pid" ] || continue
    # stopped first, so that it starts no child between the two kills
    kill -STOP "$pid" 2>/dev/null
    pkill -P "$pid" 2>/dev/null
    kill "$pid" 2>/dev/null
    kill -CONT "$pid" 2>/dev/null
  done
  wait
  cat "$tmp/events"
  echo "FAIL: $1"
  exit 1
}

# <pattern> <count> <reason>: wait up to 30 seconds for <count> events
await() {
  i=0
  until [ "$(grep -c "$1" "$tmp/events")" -ge "$2" ]; do
    i=$((i + 1))
    [ "$i" -le 30 ] || fail "$3"
    sleep 1
  done
}

pid_a="" pid_b=""
session A "$tmp/scratchpad-A" 3 &
pid_a=$!
await 'A taken' 1 "A never took the lock"
session B "$tmp/scratchpad-B" 0 &
pid_b=$!
await ' done$' 2 "a session never finished"
wait

cat "$tmp/events"
order=$(grep -v ' done$' "$tmp/events" | cut -d' ' -f2- | tr '\n' ',')
[ "$order" = "A asks,A taken,B asks,A released,B taken,B released," ] || {
  echo "FAIL: the events are not in the order of one lock"
  exit 1
}
echo "ok: B asked while A held the lock, and took it only after A released"

# A gate that finds the load high after the lock is taken waits for it.
: > "$tmp/events"
(
  . "$script"
  _gl_load() { cat "$tmp/load"; }
  _gl_level() { echo 1; }
  _gl_free() { echo 50; }
  gate_take "$tmp/scratchpad-A" wt-W > /dev/null || exit 1
  echo 200 > "$tmp/load"
  echo "$(date +%s) W waits" >> "$tmp/events"
  gate_wait > /dev/null
  echo "$(date +%s) W returned" >> "$tmp/events"
  gate_release "$tmp/scratchpad-A" > /dev/null
) &
pid_a=$! pid_b=""
await 'W waits' 1 "W never reached gate_wait"
sleep 3
grep -q 'W returned' "$tmp/events" && fail "gate_wait returned at a load over GATE_LOCK_LOAD"
echo 5 > "$tmp/load"
await 'W returned' 1 "gate_wait did not return once the load fell"
wait
echo "ok: gate_wait waited for the load after the lock was taken"

# Memory: level, free percentage, expected admission ("-" is a failed read).
(
  . "$script"
  _gl_load() { echo 5; }
  bad=0
  while read -r level free want; do
    _gl_level() { [ "$level" = - ] || echo "$level"; }
    _gl_free() { [ "$free" = - ] || echo "$free"; }
    _gl_admit && got=admit || got="wait"
    [ "$got" = "$want" ] || { echo "FAIL: level $level free $free: $got, want $want"; bad=1; }
  done <<'CASES'
1 5 admit
2 57 admit
2 30 admit
2 29 wait
4 90 wait
2 - admit
- 5 admit
- - admit
CASES
  exit "$bad"
) || exit 1
echo "ok: memory is admissible at level 1, or at level 2 with 30% free, never at level 4"
