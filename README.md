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

The process the btclib-org maintainers follow with a coding agent,
[Claude Code](https://claude.com/claude-code) or
[Codex](https://developers.openai.com/codex):

- `skills/btclib-iss/SKILL.md` — the `/btclib-iss` skill, from an issue
  to an open pull request, followed as its author;
- `skills/btclib-pr/SKILL.md` — the `/btclib-pr` skill, from an open
  pull request to the decision to approve, and to `main`;
- `skills/btclib-pr/review-quota.md` — what `/btclib-pr` does while the
  review bot's quota is exhausted, read only then;
- `skills/btclib-table/SKILL.md` — the `/btclib-table` skill, one table
  of every repository of the organization, which only reads;
- `skills/btclib-table/measure.sh` — the script `/btclib-table` runs to
  read that table;
- `process/btclib-common.md` — what `/btclib-iss` and `/btclib-pr`
  share, read whole by each;
- `process/night-mode.md` — what the orchestrator follows while night
  mode is on, read when it is turned on;
- `process/load-generator.md` — how a timing measurement takes every
  slot of the gate lock, read before running one;
- `agents/writer.md` — the agent that writes a change in its own
  worktree;
- `agents/reviewer.md` — the agent that reviews it at fresh context;
- `agents/*.toml` — the same two agents for Codex, which
  `scripts/agents-toml.py` writes from the `.md` files;
- `hooks.json` and `scripts/git-c-allow.py` — the hook that approves a
  fixed set of `git -C` commands;
- `scripts/gate-lock.sh` — the gate lock every worker of every session
  takes before its heavy gates;
- `scripts/test-gate-lock.sh` — `sh scripts/test-gate-lock.sh` shows
  sessions taking that lock's slots, and waiting while every slot is
  held;
- `scripts/test-git-c-allow.py` — the commands `git-c-allow.py` must
  approve and must refuse, run by the `test-git-c-allow` hook.

`process/btclib-common.md`'s opening says how these files divide the
process, and its *Clients* says what differs between the two agents.

## Prerequisites

- Claude Code, Codex, or both.
- `gh`, logged in (`gh auth login`).
- `uv`.
- `python3` on the `PATH`, which runs `scripts/git-c-allow.py`.
- git signing your commits: `commit.gpgsign = true` and a key registered
  on GitHub. The process signs every commit it writes
  (`process/btclib-common.md`'s *Signed and signed off*).

## Setup

Clone the repository, and export its path as `PROCESS`, in this shell
and where every later shell reads it, `~/.zshenv` for zsh: each command
either agent runs is a new shell, and the process finds its files
through `$PROCESS`. The clone can sit at any absolute path without `"`,
`$`, `` ` ``, `\`, `|` or `&`, which the hook below cannot carry;
`~/Git/claude-process` is only an example:

```shell
export PROCESS=~/Git/claude-process
```

```shell
printf 'export PROCESS=%q\n' "${PROCESS:?}" >> ~/.zshenv
```

```shell
git clone https://github.com/btclib-org/claude-process "${PROCESS:?}"
```

Then link its files where your agent reads them. Each link holds the
clone's path as it was when the link was made: a clone moved later
leaves the links pointing at nothing; remove them and make them again
from the new path. `ln -s` refuses to overwrite an existing file: move
any file of the same name you already have out of the way first.

### Claude Code

Claude Code reads its files from `$CLAUDE_CONFIG_DIR` where that is set,
and from `~/.claude` otherwise. Run these once for each configuration
directory your sessions use, with `CLAUDE_CONFIG_DIR` set to it:

```shell
mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills" \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents"
```

```shell
ln -s "${PROCESS:?}/skills/btclib-iss" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/btclib-iss"
```

```shell
ln -s "${PROCESS:?}/skills/btclib-pr" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/btclib-pr"
```

```shell
ln -s "${PROCESS:?}/skills/btclib-table" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/btclib-table"
```

```shell
ln -s "${PROCESS:?}/agents/writer.md" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents/writer.md"
```

```shell
ln -s "${PROCESS:?}/agents/reviewer.md" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents/reviewer.md"
```

Add the hook under `hooks` in that directory's `settings.json`, with the
clone's path written out for `$PROCESS`, since a hook's shell need not
have it. Claude Code runs it before every Bash call:

```json
"PreToolUse": [
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "command": "\"$PROCESS/scripts/git-c-allow.py\"",
        "timeout": 5
      }
    ]
  }
]
```

Check it in a new session: `echo "$PROCESS"` prints the clone's path,
`/btclib-iss`, `/btclib-pr` and `/btclib-table` are listed among the
skills, `/agents` lists `writer` and `reviewer`, and `/hooks` lists the
`PreToolUse` hook.

### Codex

```shell
mkdir -p ~/.agents/skills ~/.codex/agents
```

```shell
ln -s "${PROCESS:?}/skills/btclib-iss" ~/.agents/skills/btclib-iss
```

```shell
ln -s "${PROCESS:?}/skills/btclib-pr" ~/.agents/skills/btclib-pr
```

```shell
ln -s "${PROCESS:?}/skills/btclib-table" ~/.agents/skills/btclib-table
```

```shell
ln -s "${PROCESS:?}/agents/writer.toml" ~/.codex/agents/writer.toml
```

```shell
ln -s "${PROCESS:?}/agents/reviewer.toml" ~/.codex/agents/reviewer.toml
```

Codex reads its hooks from `~/.codex/hooks.json`. Write it from
`hooks.json`, with the clone's path for `$PROCESS`. Where the file
exists already, add the `PermissionRequest` entry to it by hand instead.
Codex runs the hook when a command needs approval, and refuses the
`PreToolUse` answer Claude Code uses:

```shell
sed 's|\$PROCESS|'"${PROCESS:?}"'|' "${PROCESS:?}/hooks.json" > ~/.codex/hooks.json
```

Codex reads `~/.codex/AGENTS.md` in every session. Point it at the
process, so that a session started without a skill still finds it:

```shell
printf 'Work in a btclib-org repository follows %s, read whole first.\n' \
  "${PROCESS:?}/process/btclib-common.md" >> ~/.codex/AGENTS.md
```

Check it in a new session: `echo "$PROCESS"` prints the clone's path,
`/skills` lists `btclib-iss`, `btclib-pr` and `btclib-table`, Codex
names `writer` and `reviewer` when asked which custom agents it can
spawn, and `/hooks` lists the `PermissionRequest` hook. Codex runs a
hook only once you have trusted it there.

### A machine set up before the skills

A machine set up before the commands became skills has links into the
clone that the process no longer reads. Remove the ones it has, then
make the links above. Like the links, run these once for each
configuration directory your sessions use, with `CLAUDE_CONFIG_DIR` set
to it:

```shell
rm "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/btclib-iss.md" \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/btclib-pr.md" \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/btclib-table.md"
```

```shell
rm "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/process/btclib-common.md" \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/scripts/gate-lock.sh"
```

A machine set up before the commands were split also has
`commands/btclib-org.md` there:

```shell
rm "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/btclib-org.md"
```

A hook in a `settings.json` that runs a copy of `git-c-allow.py`
outside the clone is pointed at the clone's, as above.

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
organization's open pull requests: by day it proposes which to work, at
night it works every one that is not a draft.

```text
/btclib-table
```

shows one table of every repository of the organization that is not
archived: open issues, open pull requests, CI and README badge status,
the last release, and whether a new one is due. It only reads.

In Codex each starts with `$` instead of `/`: `$btclib-iss`.

`/btclib-iss` and `/btclib-pr` work in every repository of
`btclib-org`; the shared *Where you work* says how the repository is
named. `/btclib-pr`'s *The decision* and *Landing* say when a session
approves and when it lands, `--land` included.

## Updating

Pull, with `PROCESS` exported as in *Setup*:

```shell
git -C "${PROCESS:?}" pull --ff-only
```

A skill or agent added since the machine was set up has no link yet:
make it as *Setup* says. *A machine set up before the skills* says what
an older machine removes. A change to `hooks.json` reaches Codex only once
`~/.codex/hooks.json` is updated from it as *Setup* says, and trusted
again in `/hooks`.

The links then point at the new text. Do not edit the clone the links
point at: change the process through a pull request from a worktree,
reviewed by another person, like any other btclib-org repository.
[CONTRIBUTING.md](./CONTRIBUTING.md) says how.

## Contributing

Development is LLM-based: humans are welcome, as long as they are
comfortable with agentic development ;-). A contribution must have been
read and understood by the person who submits it.
[`CONTRIBUTING.md`](./CONTRIBUTING.md#working-with-an-llm) has the rules.
