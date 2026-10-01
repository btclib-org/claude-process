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

- `commands/btclib-org.md` — the `/btclib-org` command, from an issue or
  a pull request to `main`;
- `agents/writer.md` — the agent that writes a change in its own
  worktree;
- `agents/reviewer.md` — the agent that reviews it at fresh context.

The command is the single source of the process. The agents are
generic: they read the sections of it that their brief names.

## Prerequisites

- Claude Code.
- `gh`, logged in (`gh auth login`).
- `uv`.
- git signing your commits: `commit.gpgsign = true` and a key registered
  on GitHub. Every btclib-org repository requires signed commits on
  `main`.

## Setup

Clone the repository and link its process files into `~/.claude/`:

```shell
git clone https://github.com/btclib-org/claude-process ~/Git/claude-process
mkdir -p ~/.claude/commands ~/.claude/agents
ln -s ~/Git/claude-process/commands/btclib-org.md ~/.claude/commands/btclib-org.md
ln -s ~/Git/claude-process/agents/writer.md ~/.claude/agents/writer.md
ln -s ~/Git/claude-process/agents/reviewer.md ~/.claude/agents/reviewer.md
```

`ln -s` refuses to overwrite an existing file: move any `writer.md` or
`reviewer.md` you already have out of the way first.

Check it in a new session: `/btclib-org` is listed among the commands,
and `/agents` lists `writer` and `reviewer`.

## Use

```text
/btclib-org <issue or pull request number>
```

The session asks which repository the work is for. Only the
repository's maintainer is asked about a faster landing; everyone else
lands a pull request with an approving review from another person and
green CI, through auto-merge.

## Updating

```shell
git -C ~/Git/claude-process pull --ff-only
```

The links then point at the new text. Do not edit the clone the links
point at: change the process through a pull request from a worktree,
reviewed by another person, like any other btclib-org repository.
[CONTRIBUTING.md](./CONTRIBUTING.md) says how.
