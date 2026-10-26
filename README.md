# claude-process

<!-- One badge per property of the tree, in the order section 2 of
btclib-org/.github's README.md fixes. Nothing here is a Python package
and there is no `release.yml`, so the first group is empty; the second
holds the gates, pre-commit.ci and then `lint`, and then the sentinels,
which section 10's record gives this tree as `links` alone. Every
workflow badge carries `?branch=main`, and its link the same filter. -->
[![pre-commit.ci status](https://results.pre-commit.ci/badge/github/btclib-org/claude-process/main.svg)](https://results.pre-commit.ci/latest/github/btclib-org/claude-process/main)
[![lint](https://github.com/btclib-org/claude-process/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/btclib-org/claude-process/actions/workflows/lint.yml?query=branch%3Amain)
[![links](https://github.com/btclib-org/claude-process/actions/workflows/links.yml/badge.svg?branch=main)](https://github.com/btclib-org/claude-process/actions/workflows/links.yml?query=branch%3Amain)

The process the btclib-org maintainers follow with
[Claude Code](https://claude.com/claude-code):

- `commands/btclib-iss.md` — the `/btclib-iss` command, from an issue to
  an open pull request, followed as its author;
- `commands/btclib-pr.md` — the `/btclib-pr` command, from an open pull
  request to the decision to approve, and to `main`;
- `commands/btclib-table.md` — the `/btclib-table` command, one table of
  every repository of the organization, which only reads;
- `process/btclib-common.md` — what `/btclib-iss` and `/btclib-pr`
  share, read whole by each;
- `agents/writer.md` — the agent that writes a change in its own
  worktree;
- `agents/reviewer.md` — the agent that reviews it at fresh context;
- `scripts/gate-lock.sh` — the gate lock every worker of every session
  takes before its heavy gates;
- `scripts/test-gate-lock.sh` — `sh scripts/test-gate-lock.sh` shows
  sessions taking that lock's slots, and waiting while every slot is
  held.

`process/btclib-common.md`'s opening says how these files divide the
process.

## Prerequisites

- Claude Code.
- `gh`, logged in (`gh auth login`).
- `uv`.
- git signing your commits: `commit.gpgsign = true` and a key registered
  on GitHub. The process signs every commit it writes
  (`process/btclib-common.md`'s *Signed and signed off*).

## Setup

Clone the repository and link its files into `~/.claude/`. The clone
can sit at any absolute path, set once here; `~/Git/claude-process` is
only an example:

```shell
CLAUDE_PROCESS=~/Git/claude-process
```

```shell
git clone https://github.com/btclib-org/claude-process "${CLAUDE_PROCESS:?}"
```

```shell
mkdir -p ~/.claude/commands ~/.claude/agents ~/.claude/scripts ~/.claude/process
```

```shell
ln -s "${CLAUDE_PROCESS:?}/commands/btclib-iss.md" ~/.claude/commands/btclib-iss.md
```

```shell
ln -s "${CLAUDE_PROCESS:?}/commands/btclib-pr.md" ~/.claude/commands/btclib-pr.md
```

```shell
ln -s "${CLAUDE_PROCESS:?}/commands/btclib-table.md" ~/.claude/commands/btclib-table.md
```

```shell
ln -s "${CLAUDE_PROCESS:?}/process/btclib-common.md" ~/.claude/process/btclib-common.md
```

```shell
ln -s "${CLAUDE_PROCESS:?}/agents/writer.md" ~/.claude/agents/writer.md
```

```shell
ln -s "${CLAUDE_PROCESS:?}/agents/reviewer.md" ~/.claude/agents/reviewer.md
```

```shell
ln -s "${CLAUDE_PROCESS:?}/scripts/gate-lock.sh" ~/.claude/scripts/gate-lock.sh
```

Each link holds the clone's path as it was when the link was made: a
clone moved later leaves the links pointing at nothing; remove them and
make them again from the new path.

`ln -s` refuses to overwrite an existing file: move any file of the same
name you already have out of the way first.

Check it in a new session: `/btclib-iss`, `/btclib-pr` and
`/btclib-table` are listed among the commands, and `/agents` lists
`writer` and `reviewer`.

## Use

```text
/btclib-iss <issue URLs or numbers>
```

takes issues to open pull requests, locally reviewed, and follows them
as their author.

```text
/btclib-pr [pull request URLs or numbers]
```

answers what the reviewers raised, gets CI green, and takes them to the
decision to approve and to `main`. With no argument it sweeps the
organization's open pull requests and proposes which to work.

```text
/btclib-table
```

shows one table of every repository of the organization that is not
archived: open issues, open pull requests, CI and README badge status,
the last release, and whether a new one is due. It only reads.

`/btclib-iss` and `/btclib-pr` work in every repository of
`btclib-org`; the shared *Where you work* says how the repository is
named. `/btclib-pr`'s *The decision* and *Landing* say when a session
approves and when it lands, `--land` included.

## Updating

Set the clone's path as in *Setup*, then pull:

```shell
CLAUDE_PROCESS=~/Git/claude-process
```

```shell
git -C "${CLAUDE_PROCESS:?}" pull --ff-only
```

A command added since the machine was set up has no link yet: make it
as *Setup* says.

A machine set up before the commands were split has a link
`~/.claude/commands/btclib-org.md` that points at nothing. Remove it,
then make the directory and the links of *Setup* it lacks:

```shell
rm ~/.claude/commands/btclib-org.md
```

```shell
mkdir -p ~/.claude/process
```

The links then point at the new text. Do not edit the clone the links
point at: change the process through a pull request from a worktree,
reviewed by another person, like any other btclib-org repository.
[CONTRIBUTING.md](./CONTRIBUTING.md) says how.

## Contributing

Development is LLM-based: humans are welcome, as long as they are
comfortable with agentic development ;-). A contribution must have been
read and understood by the person who submits it.
[`CONTRIBUTING.md`](./CONTRIBUTING.md#working-with-an-llm) has the rules.
