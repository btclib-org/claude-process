#!/bin/sh
# Sessions ask for the gate lock's slots while others hold them:
#
#   sh scripts/test-gate-lock.sh [<gate-lock.sh>]
#
# Each session is a `sh` of its own, since the holder is its PID. Load,
# memory and disk are stubbed, so that the test does not depend on the
# machine: a session redefines _gl_load, _gl_level, _gl_free and _gl_disk
# after sourcing. Every wait for an event polls once a second, up to 30
# times. Past that, the test kills the sessions it started and their
# children, prints the events, and exits 1. The cases, in order:
#
# - One slot. Two sessions, each with a scratchpad of its own, call
#   `gate_take <scratchpad> <worktree>`, the second while the first holds
#   the slot for 3 seconds. gate-lock.sh ignores the scratchpad. The events
#   must read A asks, A taken, B asks, A released, B taken, B released, in
#   that order. A script that keeps one lock per scratchpad fails, unless
#   its gate_take for B is slow enough to return after A's hold: no order
#   of events tells that apart from a lock.
# - Three slots. Four sessions ask at once. Three take a slot, and the
#   fourth still has none 3 seconds later. One holder releases, and the
#   fourth takes the freed slot.
# - A holder killed with SIGKILL leaves its slot behind. A new session
#   finds the slot stale, removes it and takes it.
# - A gate.lock held by a live process that is not a session, as a script
#   that knows one lock only leaves it, fills one slot: of three sessions,
#   two take a slot and the third waits. Once that process is killed, the
#   third finds gate.lock stale and takes it.
# - A session takes a slot at a low load, finds the load high when it
#   calls gate_wait, and must return from it only after the test lowers
#   the load.
# - Spacing. With GATE_LOCK_STAGGER at 4 seconds, two sessions ask at once
#   with a slot free for each. The stamps in gate.last that the two takes
#   write are 4 seconds or more apart.
# - Zsh. A zsh session takes the first slot with no other slot present, and
#   releases it. Skipped where there is no zsh.
# - Load generators. Under each of sh, bash, zsh and dash, two sessions ask
#   at once for every slot with gate_take_all. Both finish, and their holds
#   do not overlap.
# - gate_release_all called by a shell that holds nothing fails, and leaves
#   the gate.generator and the slots of another shell as they were.
# - A generator killed with SIGKILL while it holds every slot. The next
#   generator reclaims gate.generator and the slots, and finishes.
# - Defaults. Sourced with no GATE_LOCK_LOAD, GATE_LOCK_SLOTS or
#   GATE_LOCK_WORKERS and a core count stubbed, the script sets the load to
#   1.5 times the cores, and the workers to the cores divided by the slots,
#   at least 1.
# - _gl_admit is called with each load, disk, level and free percentage
#   in the tables below.

# The stubs are called by the sourced script, and the script is a variable.
# The stubs are text a session evals, and they read $load.
# shellcheck disable=SC1090,SC2329,SC2016,SC2034
script=${1:-$(dirname "$0")/gate-lock.sh}
tmp=$(mktemp -d) || exit 1
trap 'rm -r "$tmp"' EXIT
GATE_LOCK_DIR=$tmp/lock GATE_LOCK_POLL=1 GATE_LOCK_SLOTS=1
GATE_LOCK_LOAD=15 GATE_LOCK_FREE=30 GATE_LOCK_DISK=20 GATE_LOCK_STAGGER=0
export GATE_LOCK_DIR GATE_LOCK_POLL GATE_LOCK_SLOTS GATE_LOCK_STAGGER
export GATE_LOCK_LOAD GATE_LOCK_FREE GATE_LOCK_DISK
echo 5 > "$tmp/load"
mkdir "$tmp/scratchpad-A" "$tmp/scratchpad-B"
: > "$tmp/events"

# The stubs every session defines after sourcing the script
stubs='
  _gl_load() { cat "$load"; }
  _gl_level() { echo 1; }
  _gl_free() { echo 50; }
  _gl_disk() { echo 100; }
'

session() { # <name> <scratchpad> <seconds held>
  exec sh -c '
    . "$1"
    load=$6
    eval "$7"
    echo "$(date +%s) $2 asks" >> "$4"
    gate_take "$3" "wt-$2" >/dev/null || exit 1
    echo "$(date +%s) $2 taken" >> "$4"
    sleep "$5"
    echo "$(date +%s) $2 released" >> "$4"
    gate_release "$3" >/dev/null || exit 1
    echo "$(date +%s) $2 done" >> "$4"
  ' sh "$script" "$1" "$2" "$tmp/events" "$3" "$tmp/load" "$stubs"
}

# <name>: writes its PID to $tmp/pid-<name> and what gate_take prints to
# $tmp/out-<name>, and holds its slot until the file $tmp/go-<name> exists
holder() {
  exec sh -c '
    . "$1"
    load=$4/load
    eval "$5"
    echo $$ > "$4/pid-$2"
    echo "$(date +%s) $2 asks" >> "$3"
    gate_take "wt-$2" > "$4/out-$2" || exit 1
    cp "$GATE_LOCK_DIR/gate.last" "$4/last-$2" 2>/dev/null
    echo "$(date +%s) $2 taken" >> "$3"
    until [ -f "$4/go-$2" ]; do sleep 1; done
    gate_release >/dev/null || exit 1
    echo "$(date +%s) $2 done" >> "$3"
  ' sh "$script" "$1" "$tmp/events" "$tmp" "$stubs"
}

pids=""
fail() { # <reason>: stop the sessions started and their children
  # one PID a line, since zsh does not split an unquoted $pids
  printf '%s\n' "$pids" | tr ' ' '\n' | while read -r pid; do
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

# <name>: whether that session holds a slot it took
holds() { grep -q " $1 taken$" "$tmp/events" && ! grep -q " $1 done$" "$tmp/events"; }

session A "$tmp/scratchpad-A" 3 &
pids=$!
await 'A taken' 1 "A never took the slot"
session B "$tmp/scratchpad-B" 0 &
pids="$pids $!"
await ' done$' 2 "a session never finished"
wait

cat "$tmp/events"
order=$(grep -v ' done$' "$tmp/events" | cut -d' ' -f2- | tr '\n' ',')
[ "$order" = "A asks,A taken,B asks,A released,B taken,B released," ] || {
  echo "FAIL: the events are not in the order of one slot"
  exit 1
}
echo "ok: with one slot, B asked while A held it, and took it only after A released"

# Three slots, four sessions.
GATE_LOCK_SLOTS=3
: > "$tmp/events"
pids=""
for n in C D E F; do
  holder "$n" &
  pids="$pids $!"
done
await ' taken$' 3 "three sessions never held a slot each"
sleep 3
[ "$(grep -c ' taken$' "$tmp/events")" -eq 3 ] ||
  fail "a fourth session took a slot while three held one"
waiter=""
for n in C D E F; do holds "$n" || waiter=$n; done
first=$(grep ' taken$' "$tmp/events" | head -n 1 | cut -d' ' -f2)
touch "$tmp/go-$first"
await ' taken$' 4 "$waiter never took the slot $first released"
cat "$tmp/events"
echo "ok: three sessions held a slot each, and $waiter took one only after $first released"

# A killed holder.
victim=""
for n in C D E F; do [ "$n" = "$first" ] || ! holds "$n" || victim=$n; done
kill -KILL "$(cat "$tmp/pid-$victim")"
holder G &
pids="$pids $!"
await 'G taken' 1 "G never took the slot of the killed $victim"
grep -q 'stale' "$tmp/out-G" || fail "G took a slot without reclaiming $victim's"
cat "$tmp/out-G"
echo "ok: G took the slot of $victim, killed while it held it"
for n in C D E F G; do touch "$tmp/go-$n"; done
wait

# A gate.lock left by a process that is not a session.
: > "$tmp/events"
sleep 300 &
legacy=$!
pids="$legacy"
mkdir "$GATE_LOCK_DIR/gate.lock"
echo "$legacy $(date +%s) wt-legacy" > "$GATE_LOCK_DIR/gate.lock/owner"
for n in H I J; do
  holder "$n" &
  pids="$pids $!"
done
await ' taken$' 2 "two sessions never held a slot each beside gate.lock"
sleep 3
[ "$(grep -c ' taken$' "$tmp/events")" -eq 2 ] ||
  fail "a third session took a slot while gate.lock and two slots were held"
kill "$legacy"
await ' taken$' 3 "the third session never took gate.lock once its holder was gone"
cat "$tmp/events"
cat "$tmp"/out-[HIJ]
grep -q 'gate.lock of pid' "$tmp"/out-[HIJ] ||
  fail "no session reclaimed gate.lock"
echo "ok: a live gate.lock filled a slot, and was reclaimed once its holder was gone"
for n in H I J; do touch "$tmp/go-$n"; done
wait

# Spacing: two sessions ask at once, and the second waits for the stagger.
GATE_LOCK_STAGGER=4
rm -f "$GATE_LOCK_DIR/gate.last"
: > "$tmp/events"
pids=""
for n in K L; do
  holder "$n" &
  pids="$pids $!"
done
await ' taken$' 1 "no session took a slot"
sleep 1
[ "$(grep -c ' taken$' "$tmp/events")" -eq 1 ] ||
  fail "a second session took a slot within the stagger of the first"
await ' taken$' 2 "the second session never took a slot"
# the times the takes were stamped, which gate_take returns after
t1=$(cat "$tmp/last-K")
t2=$(cat "$tmp/last-L")
[ "$t1" -le "$t2" ] || { t=$t1; t1=$t2; t2=$t; }
[ $((t2 - t1)) -ge "$GATE_LOCK_STAGGER" ] ||
  fail "the takes were $((t2 - t1)) seconds apart, under the stagger of $GATE_LOCK_STAGGER"
echo "ok: the second take came $((t2 - t1)) seconds after the first, the stagger being $GATE_LOCK_STAGGER"
for n in K L; do touch "$tmp/go-$n"; done
wait
GATE_LOCK_STAGGER=0

# Under zsh, which stops at a glob with no match, a session takes the first
# slot, with no gate.lock.2 or gate.lock.3 beside it, and releases it.
if command -v zsh > /dev/null; then
  rm -rf "${GATE_LOCK_DIR:?}"
  zsh -c '
    . "$1"
    load=$3
    eval "$4"
    gate_take wt-Z > /dev/null || exit 1
    gate_release
  ' zsh "$script" "$tmp" "$tmp/load" "$stubs" > "$tmp/out-Z" 2>&1 ||
    { cat "$tmp/out-Z"; fail "a zsh session did not release its slot"; }
  grep -q 'gate.lock released by' "$tmp/out-Z" || { cat "$tmp/out-Z"; fail "zsh printed no release"; }
  [ ! -e "$GATE_LOCK_DIR/gate.lock" ] || fail "gate.lock is still there after a zsh release"
  cat "$tmp/out-Z"
  echo "ok: under zsh, a session released gate.lock with no other slot present"
else
  echo "skipped: no zsh to run the release case under"
fi

# Load generators. Two generators ask at once for every slot, each in a shell
# of the kind named. Both finish, one after the other: a generator holds
# every slot, as its own owner file says, so the two do not split them and
# wait for ever.
generator() { # <shell> <name>
  exec "$1" -c '
    . "$1"
    load=$4/load
    eval "$5"
    echo "$(date +%s) $2 asks" >> "$3"
    gate_take_all "wt-$2" > /dev/null || exit 1
    # every slot has this shell as its owner
    for slot in gate.lock gate.lock.2 gate.lock.3; do
      owner=""
      read -r owner _ 2>/dev/null < "$GATE_LOCK_DIR/$slot/owner"
      [ "$owner" = "$$" ] || { echo "$2 does not hold $slot" >> "$3"; exit 1; }
    done
    echo "$(date +%s) $2 taken" >> "$3"
    sleep 2
    echo "$(date +%s) $2 released" >> "$3"
    gate_release_all > /dev/null || exit 1
    echo "$(date +%s) $2 done" >> "$3"
  ' "$1" "$script" "$2" "$tmp/events" "$tmp" "$stubs"
}
GATE_LOCK_SLOTS=3
for shell in sh bash zsh dash; do
  command -v "$shell" > /dev/null || { echo "skipped: no $shell for the generators"; continue; }
  rm -rf "${GATE_LOCK_DIR:?}"
  : > "$tmp/events"
  pids=""
  for n in P Q; do
    generator "$shell" "$n" &
    pids="$pids $!"
  done
  await ' done$' 2 "under $shell, the two generators did not both finish"
  wait
  order=$(grep -v -e ' asks$' -e ' done$' "$tmp/events" | cut -d' ' -f2- | tr '\n' ',')
  case $order in
    "P taken,P released,Q taken,Q released," | "Q taken,Q released,P taken,P released,") ;;
    *) cat "$tmp/events"; fail "under $shell, the generators overlapped: $order" ;;
  esac
  [ ! -e "$GATE_LOCK_DIR/gate.generator" ] && [ ! -e "$GATE_LOCK_DIR/gate.lock" ] &&
    [ ! -e "$GATE_LOCK_DIR/gate.lock.2" ] && [ ! -e "$GATE_LOCK_DIR/gate.lock.3" ] ||
    fail "under $shell, a slot or gate.generator is left after the release"
  "$shell" -c '. "$1"; gate_release_all > /dev/null' "$shell" "$script" &&
    fail "under $shell, gate_release_all released nothing and succeeded"
  echo "ok: under $shell, two generators took every slot one after the other"
done

# gate_release_all releases only what its own shell holds: called by another
# shell while a generator holds gate.generator and the slots, it fails and
# leaves all of them, and the owner file, as they were.
rm -rf "${GATE_LOCK_DIR:?}"
sh -c '
  . "$1"
  load=$3
  eval "$4"
  gate_take_all wt-H > /dev/null || exit 1
  : > "$2/held-H"
  exec sleep 300
' sh "$script" "$tmp" "$tmp/load" "$stubs" &
pids=$!
i=0
until [ -f "$tmp/held-H" ]; do
  i=$((i + 1))
  [ "$i" -le 30 ] || fail "the generator H never held every slot"
  sleep 1
done
before=$(cat "$GATE_LOCK_DIR/gate.generator/owner")
sh -c '. "$1"; gate_release_all' sh "$script" > /dev/null 2>&1 &&
  fail "gate_release_all succeeded in a shell that held nothing"
[ "$(cat "$GATE_LOCK_DIR/gate.generator/owner" 2>/dev/null)" = "$before" ] ||
  fail "another shell's gate_release_all changed gate.generator"
[ -d "$GATE_LOCK_DIR/gate.lock" ] || fail "another shell's gate_release_all released gate.lock"
kill "$pids"
wait "$pids" 2>/dev/null
echo "ok: gate_release_all left the gate.generator of another shell alone"

# A generator killed with SIGKILL while it holds gate.generator and every slot
# leaves them behind. The next generator finds all of them stale, removes
# them and finishes.
rm -rf "${GATE_LOCK_DIR:?}"
: > "$tmp/events"
sh -c '
  . "$1"
  load=$3
  eval "$4"
  gate_take_all wt-X > /dev/null || exit 1
  : > "$2/held-X"
  exec sleep 300
' sh "$script" "$tmp" "$tmp/load" "$stubs" &
pids=$!
i=0
until [ -f "$tmp/held-X" ]; do
  i=$((i + 1))
  [ "$i" -le 30 ] || fail "the generator X never held every slot"
  sleep 1
done
kill -KILL "$pids"
wait "$pids" 2>/dev/null
sh -c '
  . "$1"
  load=$3
  eval "$4"
  gate_take_all wt-R || exit 1
  gate_release_all
' sh "$script" "$tmp" "$tmp/load" "$stubs" > "$tmp/out-R" 2>&1 &
pids=$!
await_pid() { # <pid> <reason>: wait up to 30 seconds for the process to end
  i=0
  while kill -0 "$1" 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -le 30 ] || fail "$2"
    sleep 1
  done
}
await_pid "$pids" "a generator never took the leftovers of the killed one"
wait "$pids" || fail "the generator R failed"
cat "$tmp/out-R"
grep -q 'gate.generator of pid .* is stale' "$tmp/out-R" ||
  fail "the generator did not reclaim the stale gate.generator"
[ ! -e "$GATE_LOCK_DIR/gate.generator" ] && [ ! -e "$GATE_LOCK_DIR/gate.lock" ] &&
  [ ! -e "$GATE_LOCK_DIR/gate.lock.2" ] && [ ! -e "$GATE_LOCK_DIR/gate.lock.3" ] ||
  fail "gate.generator or a slot is left after the release"
echo "ok: a generator reclaimed the gate.generator and the slots of one killed while it held them"
GATE_LOCK_SLOTS=1

# Defaults: the core count is stubbed, once by sysctl and once by getconf.
# The values are printed by a subshell that has none of the settings.
defaults() { # <ncpu> <sysctl or getconf>
  (
    unset GATE_LOCK_LOAD GATE_LOCK_SLOTS GATE_LOCK_WORKERS
    n=$1
    if [ "$2" = sysctl ]; then sysctl() { echo "$n"; }
    else
      sysctl() { return 1; }
      getconf() { echo "$n"; }
    fi
    . "$script"
    echo "$GATE_LOCK_LOAD $GATE_LOCK_SLOTS $GATE_LOCK_WORKERS"
  )
}
bad=0
while read -r ncpu via want; do
  got=$(defaults "$ncpu" "$via")
  [ "$got" = "$want" ] || { echo "FAIL: $ncpu cores by $via: '$got', want '$want'"; bad=1; }
done <<'CASES'
10 sysctl 15 3 3
10 getconf 15 3 3
8 sysctl 12 3 2
2 getconf 3 3 1
CASES
[ "$bad" -eq 0 ] || exit 1
echo "ok: load is 1.5 times the cores, workers the cores divided by the slots, at least 1"

# A gate that finds the load high after the slot is taken waits for it.
: > "$tmp/events"
(
  . "$script"
  load=$tmp/load
  eval "$stubs"
  gate_take "$tmp/scratchpad-A" wt-W > /dev/null || exit 1
  echo 200 > "$tmp/load"
  echo "$(date +%s) W waits" >> "$tmp/events"
  gate_wait > /dev/null
  echo "$(date +%s) W returned" >> "$tmp/events"
  gate_release "$tmp/scratchpad-A" > /dev/null
) &
pids=$!
await 'W waits' 1 "W never reached gate_wait"
sleep 3
grep -q 'W returned' "$tmp/events" && fail "gate_wait returned at a load over GATE_LOCK_LOAD"
echo 5 > "$tmp/load"
await 'W returned' 1 "gate_wait did not return once the load fell"
wait
echo "ok: gate_wait waited for the load after the slot was taken"

# Load and disk: load, GB free, expected admission ("-" is a failed read).
(
  . "$script"
  _gl_level() { echo 1; }
  _gl_free() { echo 50; }
  bad=0
  while read -r l g want; do
    _gl_load() { [ "$l" = - ] || echo "$l"; }
    _gl_disk() { [ "$g" = - ] || echo "$g"; }
    _gl_admit && got=admit || got="wait"
    [ "$got" = "$want" ] || { echo "FAIL: load $l disk $g: $got, want $want"; bad=1; }
  done <<'CASES'
14.99 100 admit
15.00 100 wait
5.00 20 admit
5.00 19 wait
5.00 - admit
- 100 admit
CASES
  exit "$bad"
) || exit 1
echo "ok: a gate is admitted under load 15, and with 20 GB of disk free"

# Memory: level, free percentage, expected admission ("-" is a failed read).
(
  . "$script"
  _gl_load() { echo 5; }
  _gl_disk() { echo 100; }
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
