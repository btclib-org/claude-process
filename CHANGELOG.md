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

### A `Signed-off-by:` trailer on every commit of a pull request

- **`lint.yml` carries `btclib-org/.github`'s `Sign-off` job, which refuses a
  commit not signed off by its author** (issue btclib-org/.github#1467):
  `CONTRIBUTING.md`'s shared half says how to sign off.

### The primary-checkout section uses one form for the checkout

- **The section writes the checkout as `"${checkout:?}"` throughout, says
  what `<scratchpad>` is and names the pull** (issue
  btclib-org/.github#1500).

### `CONTRIBUTING.md` says what stands in for the ack while the bot review is off

- **The shared half says a local review of a named sha stands in for the
  ack while `claude-review.yml` is off** (issue
  btclib-org/.github#1527).

### Sessions leave `good first issue` to outside contributors

- **No session takes an issue labelled `good first issue`, and small
  self-contained collateral that nothing waits on is filed with that
  label** (closes #23).

### `REPOSITORY.md` reads back the web sign-off setting

- **`REPOSITORY.md` reads `web_commit_signoff_required` back** (issue
  btclib-org/.github#1540): section 11 of the standard states the
  organization setting.

### The `Sign-off` check is required

- **A pull request whose commits lack the `Signed-off-by:` trailer cannot
  merge** (issue btclib-org/.github#1550): `Sign-off` is a required check.

### The process asks for the `Signed-off-by:` trailer

- **Every commit is signed off by its author**, checked by the writer and
  by the reviewer (issue btclib-org/.github#1550): `main` requires the
  `Sign-off` check.

### Every role leaves `good first issue` alone unless the human authorizes it

- **No session takes, closes, relabels or edits an issue labelled `good
  first issue`, and no branch closes or bundles one, unless the human
  expressly authorizes it.**

### `CONTRIBUTING.md` says the maintainer lands through the bypass

- **The shared half says the ack of record is a bot's, so the maintainer
  lands their own pull requests through the bypass** (issue
  btclib-org/.github#452).

### A landing in this repository brings its primary checkout forward

- **The orchestrator fast-forwards the primary checkout after a landing
  here and reads the landed text back through the symlinks in `~/.claude`**,
  which point into it.

### A finding only in the commit message is fixed in the squash

- **`--body-file` and `--subject` land the cleared head under a corrected
  message, with no new round**, keeping every `Signed-off-by:` and
  `Co-authored-by:` line.

### The README names the clone's path once

*Setup* and *Updating* name the clone's path in `CLAUDE_PROCESS`, say
that any absolute path works, and say that a clone moved later is
linked again (closes #21).

### The bypass is for emergencies, and no stacked base is fast-forwarded

`CONTRIBUTING.md` and `REVIEWING.md` say every pull request, the maintainer's
included, lands with an approving review from somebody other than its author;
the bypass is for emergencies (issue btclib-org/.github#1362).

### Earlier entries on how a pull request lands

Entries above that have the maintainer landing without another person's
approval describe the rule before issue btclib-org/.github#1362 (issue
btclib-org/.github#1569).

### REPOSITORY.md reads the review switch as the organization's

It states only what is this repository's own, that its variable store
holds no `CLAUDE_REVIEW_ENABLED`; the switch is the organization's
(closes #29).

### A hold takes the label for what it waits on

*Several issues, several pull requests* labels a question put to the
maintainer `decision`, a wait on an event or a person `blocked`, and a
pause the human decided `on-hold` (issue btclib-org/.github#1584).

### Union files are rebuilt by btclib-org/.github's script

*Union files after a rebase* runs `rebuild_union_files.py` after every
rebase or merge, whether the tree's `.gitattributes` keeps `merge=union`
or not (issue btclib-org/.github#1582).

### The forms set a type, and the history files lose `merge=union`

The issue forms set `type:` and no kind label (issue
btclib-org/.github#1584). `.gitattributes` is gone, so a rebase stops
on a conflict in `CHANGELOG.md` (issue btclib-org/.github#1582).

### Exit `2` of the union script does not always mean a refused file

*Union files after a rebase* splits `2` by whether the message names a
file: rebuild by hand only then (closes #37).
