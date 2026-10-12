#!/bin/sh
# Two sessions, each with a scratchpad of its own, ask for the gate lock,
# the second while the first holds it. The lock holds if the second takes
# it only after the first releases:
#
#   sh scripts/test-gate-lock.sh [<gate-lock.sh>]
#
# Each session is a `sh` of its own, since the holder is its PID, and
# calls `gate_take <scratchpad> <worktree>`. gate-lock.sh ignores the
# scratchpad; a script that keeps one lock per scratchpad fails the test.
# Each session writes "<name> done" once gate_release succeeds. The test
# polls for A's take, and then for both "done" lines, once a second up to
# 30 times each. Past either, it kills the sessions it started and their
# children, and exits 1. Otherwise it exits 0 when the takes serialize, and
# 1 when they do not.

script=${1:-$(dirname "$0")/gate-lock.sh}
tmp=$(mktemp -d) || exit 1
trap 'rm -r "$tmp"' EXIT
GATE_LOCK_DIR=$tmp/lock GATE_LOCK_POLL=1 GATE_LOCK_LOAD=100000
export GATE_LOCK_DIR GATE_LOCK_POLL GATE_LOCK_LOAD
mkdir "$tmp/scratchpad-A" "$tmp/scratchpad-B"
: > "$tmp/events"

session() { # <name> <scratchpad> <seconds held>
  exec sh -c '
    . "$1"
    gate_take "$3" "wt-$2" >/dev/null || exit 1
    echo "$(date +%s) $2 taken" >> "$4"
    sleep "$5"
    echo "$(date +%s) $2 released" >> "$4"
    gate_release "$3" >/dev/null || exit 1
    echo "$(date +%s) $2 done" >> "$4"
  ' sh "$script" "$1" "$2" "$tmp/events" "$3"
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
[ "$order" = "A taken,A released,B taken,B released," ] || {
  echo "FAIL: the takes did not serialize"
  exit 1
}
echo "ok: B took only after A released"
