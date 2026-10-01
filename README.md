# claude-process

The process the btclib-org maintainers follow with
[Claude Code](https://claude.com/claude-code):

- `commands/btclib-org.md` — the `/btclib-org` command, from an issue or
  a pull request to `main`;
- `agents/writer.md` — the agent that writes a change in its own
  worktree;
- `agents/reviewer.md` — the agent that reviews it at fresh context.

The command is the single source of the process. The two agents are
generic: they read the sections of it that their brief names.

## Prerequisites

- Claude Code.
- `gh`, logged in (`gh auth login`).
- `uv`.
- git signing your commits: `commit.gpgsign = true` and a key registered
  on GitHub. Every btclib-org repository requires signed commits on
  `main`.

## Setup

Clone the repository and link the three files into `~/.claude/`:

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
