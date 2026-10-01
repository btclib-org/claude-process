# Changelog

Every change a user of this repository would notice. Nothing here is
released — a clone is what ships — so every entry stays under
`## Unreleased`.

## Unreleased

### The tree carries what the organization standard asks of tier 3

The review workflow, the lint gate, the root files and the record of the
settings kept outside the tree (issue #2).

### Branch protection on `main` is recorded as set

`Lint` and `Dependency review` are required checks on `main`, with
`strict` on, and the files that describe it say so (closes #2).

### The gate lock records its holder

`scripts/gate-lock.sh` takes the gate lock with the holder's PID in it,
releases only a lock holding that PID, and removes a lock whose holder
is gone. *The gates* uses it alone (closes #5).

### A speedy landing is followed by a read of `main`'s CI

*Landing*'s speedy bullet has the orchestrator read `main`'s CI after
each speedy landing and put an agent on a red at once, the landings that
follow not pausing (closes #9).

### The union steps cover `RELEASE_NOTES.md` as well

*Union files after a rebase* saves, reconstructs and compares every
union file the branch touches, `RELEASE_NOTES.md` included, which
`check-changelog` does not read (closes #3).

### Two waiters no longer take one stale gate lock

`gate_take` reclaims a dead holder's lock by renaming its owner file,
which only one waiter wins, and checks the PID in what it moved (closes #10).

### REPOSITORY.md says this tree does not run codeql

*What is not configured* says section 10 does not name this tree for
`codeql`, and shows the languages default setup would scan (closes #15).

### A push follows a gate run that exited 0

*Committing and rebasing* pushes a commit or an amend only after a gate
run on it exited 0; the first push of new work needs none (closes #12).

### A rehearsal's input is compared with the real file

*How you establish a fact* has a rehearsal's input compared with the
real file it models, same shape, before its outcome is reported
(closes #13).
