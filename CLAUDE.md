# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

This repository is the text of the process the btclib-org maintainers
follow with Claude Code, and nothing else. `README.md` says what the
tree holds and how to set a machine up to use it; `CONTRIBUTING.md` is
how to work here, the commands and the gates being its last section;
`REPOSITORY.md` is the settings that live outside the tree — read it
before changing a workflow, a branch rule or a setting. `REVIEWING.md` is
the standard a review is written against, and `.claude/commands/review.md`
is that file as a command.

The organization's standard is
[btclib-org/.github](https://github.com/btclib-org/.github)'s
`README.md`, and this repository is tier 3 of it: sections 9, 11 and 14,
and the rows of the root-files table marked for that tier.

## Architecture

`commands/btclib-org.md` is the process and the single source of it.
`agents/writer.md` and `agents/reviewer.md` are generic: the brief a
session gives them names the sections of the command they read, so a rule
is changed in the command and not in an agent. `.claude/commands/review.md`
is a different file with a similar name: it is the `/review` command of
*this* repository's own pull requests, not part of the process shipped.

## The primary checkout is the maintainer's

Never work in it: no edit, no `git add`, no commit, no branch switch, no
rebase, no `git stash` — the hooks fix files in place. The one write
allowed there brings it forward, and only while it is on `main` and
`git status --porcelain` prints nothing; where it is not, stop:

```shell
checkout=<checkout>
```

```shell
git -C "${checkout:?}" pull --ff-only
```

Read it only after that, once `git -C <checkout> rev-parse HEAD
origin/main` prints one sha twice. A measurement that has to hold at a
named revision reads `git -C <checkout> show <sha>:<path>` instead.

Every session works in a worktree of its own, from its first edit, named
`wt-<tracker>-<issue>-<repo>-<role>` — `wt-github-255-btclib-writer` for
issue 255 of `btclib-org/.github`'s tracker, worked in `btclib` by a
writer. The environment is created there, with the command `CONTRIBUTING.md`
names under *The environment and the gates*. Every path is written out in
full:

```shell
git worktree add \
  <scratchpad>/wt-<tracker>-<issue>-<repo>-<role> origin/main -b <branch>
```

Removing it is part of finishing:

```shell
git worktree remove --force <scratchpad>/wt-<tracker>-<issue>-<repo>-<role>
```

`refs/stash` and the local `main` are shared by every worktree: never
`git stash`, and move `main` only by the fast-forward above.

## Non-obvious facts that will otherwise waste a session

- **The primary checkout is what every session reads.** On a machine set
  up as `README.md` says, `~/.claude/commands/btclib-org.md`,
  `~/.claude/agents/writer.md`, `~/.claude/agents/reviewer.md` and
  `~/.claude/scripts/gate-lock.sh` are symlinks into it, so a file
  edited or a branch switched to there changes the text the next
  session reads. That is why the section above holds here as it does,
  and why the fast-forward alone moves that checkout. The links answer:

  ```shell
  ls -l ~/.claude/commands/btclib-org.md ~/.claude/agents ~/.claude/scripts
  ```
