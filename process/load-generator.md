# A load generator

A load generator is anything run to raise the load for a timing
measurement, such as `yes`. It takes every slot of the gate lock, since
other gates spoil the measurement: `gate_take_all <worktree>` instead of
`gate_take`, and `gate_release_all` instead of `gate_release`. One
generator runs at a time, as the comment above `gate_take_all` in
`$PROCESS/scripts/gate-lock.sh` says.

While `gate_take_all` waits for the rest of the slots, it holds those it
has. That wait is at least (`GATE_LOCK_SLOTS` − 1) × `GATE_LOCK_STAGGER`
seconds, 30 seconds by default. Each take queues with a fresh ticket, so
gates that queue meanwhile take the next free slots before it, and it may
hold the slots it has for longer.

The session that runs it starts at most one single-threaded process per
free core: the cores times the idle fraction on the last line
`gate_take_all` printed, rounded down, minus the workers of the measured
run. The measured run goes in the same
shell call, inside that hold, with no `gate_take` of its own. The
session records the PIDs, kills them within 15 minutes of the start of
the measured run, as the example's watchdog does, and checks with `ps`
that they are gone before `gate_release_all`:

```shell
. "${PROCESS:?}/scripts/gate-lock.sh"
out=<scratchpad>/gen.out pids=<scratchpad>/gen.pids workers=<n>
gate_take_all <worktree> > "$out" 2>&1 && {
  idle=$(tail -n 1 "$out" | sed 's/.* at \([0-9]*\)% CPU idle.*/\1/')
  case $idle in ''|*[!0-9]*) idle=0 ;; esac
  free=$(( $(sysctl -n hw.ncpu) * idle / 100 - workers ))
  : > "$pids"
  trap 'while read -r pid; do kill "$pid" 2>/dev/null; done < "$pids"' EXIT
  trap 'exit 1' HUP INT TERM
  while [ "$free" -gt 0 ]; do
    yes > /dev/null & echo $! >> "$pids"
    free=$(( free - 1 ))
  done
  # the measured run goes in the background so that a signal reaches
  # the trap, and the watchdog kills it after 15 minutes (900 seconds)
  <the measured run> & run=$!; echo "$run" >> "$pids"
  ( sleep 900 & echo $! >> "$pids"; wait $!; kill "$run" ) 2>/dev/null &
  echo $! >> "$pids"
  wait "$run"
  while read -r pid; do kill "$pid" 2>/dev/null; done < "$pids"
  sleep 1
  while read -r pid; do ! ps -p "$pid" > /dev/null || exit 1; done < "$pids"
  trap - EXIT HUP INT TERM
  gate_release_all
}
```

The trap kills the processes when the shell exits or receives SIGHUP,
SIGINT or SIGTERM. A SIGKILL of the shell leaves the processes, and the
PID file is there to kill them by hand.
