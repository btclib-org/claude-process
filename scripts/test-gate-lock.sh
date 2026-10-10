#!/bin/sh
# Two sessions, each with a scratchpad of its own, take the gate lock at
# once. The lock holds if the second takes only after the first releases:
#
#   sh scripts/test-gate-lock.sh [<gate-lock.sh>]
#
# Each session is a `sh` of its own, since the holder is its PID, and
# calls `gate_take <scratchpad> <worktree>`, a form a previous version of
# the script also accepts. Exits 0 when the takes serialize.

script=${1:-$(dirname "$0")/gate-lock.sh}
tmp=$(mktemp -d) || exit 1
trap 'rm -r "$tmp"' EXIT
GATE_LOCK_DIR=$tmp/lock GATE_LOCK_POLL=1 GATE_LOCK_LOAD=100000
export GATE_LOCK_DIR GATE_LOCK_POLL GATE_LOCK_LOAD
mkdir "$tmp/scratchpad-A" "$tmp/scratchpad-B"

session() { # <name> <scratchpad> <seconds held>
  sh -c '
    . "$1"
    gate_take "$3" "wt-$2" >/dev/null || exit 1
    echo "$(date +%s) $2 taken" >> "$4"
    sleep "$5"
    echo "$(date +%s) $2 released" >> "$4"
    gate_release "$3" >/dev/null
  ' sh "$script" "$1" "$2" "$tmp/events" "$3"
}

session A "$tmp/scratchpad-A" 3 &
sleep 1
session B "$tmp/scratchpad-B" 0 &
wait

cat "$tmp/events"
order=$(cut -d' ' -f2- "$tmp/events" | tr '\n' ',')
[ "$order" = "A taken,A released,B taken,B released," ] || {
  echo "FAIL: the takes did not serialize"
  exit 1
}
echo "ok: B took only after A released"
