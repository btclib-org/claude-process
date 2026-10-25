#!/usr/bin/env python3
"""Hook: approve `git -C <path> <subcommand>` for a fixed set.

It replaces the `Bash(git -C * <subcommand> *)` allow rules. Their `*`
before the subcommand also matched options such as `-c core.pager=<cmd>`.
Anything it does not approve falls through to the usual permission flow.

It answers the event that ran it: `PreToolUse` in Claude Code, and
`PermissionRequest` in Codex, which refuses a `PreToolUse` allow.
"""

import json
import shlex
import sys

READ = {
    "blame",
    "cat-file",
    "describe",
    "diff",
    "for-each-ref",
    "grep",
    "log",
    "ls-files",
    "ls-remote",
    "ls-tree",
    "merge-base",
    "merge-tree",
    "rev-list",
    "rev-parse",
    "show",
    "status",
}
# Options that run a command or write a file: long ones, then the letters
# of short ones.
UNSAFE = (
    (
        "--output",
        "--open-files-in-pager",
        "--upload-pack",
        "--receive-pack",
        "--exec",
        "--ext-diff",
        "--textconv",
    ),
    "O",
)
BRANCH_WRITE = (
    (
        "--delete",
        "--move",
        "--copy",
        "--force",
        "--set-upstream-to",
        "--unset-upstream",
        "--edit-description",
        "--track",
    ),
    "dDmMcCfut",
)
# The options that list branches even when a name follows.
BRANCH_FILTER = {
    "--list",
    "-l",
    "--contains",
    "--no-contains",
    "--merged",
    "--no-merged",
    "--points-at",
}


def hits(arg: str, options: tuple[tuple[str, ...], str]) -> bool:
    """Whether `arg` may be one of `options`.

    git takes any unique prefix of a long option for the option, so a
    long `arg` hits every option it is a prefix of. A short `arg` may
    bundle letters, so it hits where it holds any of them.
    """
    long, short = options
    if arg.startswith("--"):
        name = arg.split("=")[0]
        return name != "--" and any(o.startswith(name) for o in long)
    return arg.startswith("-") and any(c in short for c in arg[1:])


def expands(cmd: str) -> bool:
    """Whether the shell would expand a brace or a glob in `cmd`.

    shlex.split expands neither, so the words it returns would not be
    the words git gets. Inside quotes both are literal.
    """
    quote = ""
    for c in cmd:
        if quote:
            quote = "" if c == quote else quote
        elif c in "'\"":
            quote = c
        elif c in "{}*?[":
            return True
    return False


def allowed(cmd: str) -> bool:
    if not cmd.startswith("git -C ") or any(c in cmd for c in ";&|`$<>()\n\\"):
        return False
    if expands(cmd):
        return False
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        return False
    if len(tokens) < 4 or tokens[2].startswith("-"):
        return False
    rest = tokens[3:]
    if rest[:2] == ["-c", "merge.union.driver=false"]:
        rest = rest[2:]
        if rest[:1] != ["merge-tree"]:
            return False
    sub, args = rest[0], rest[1:]
    if any(hits(a, UNSAFE) for a in args):
        return False
    if sub in READ:
        return True
    if sub == "branch":
        if any(hits(a, BRANCH_WRITE) for a in args):
            return False
        positional = [a for a in args if not a.startswith("-")]
        return not positional or any(a.split("=")[0] in BRANCH_FILTER for a in args)
    if sub == "worktree":
        return args[:1] == ["list"]
    if sub == "fetch":
        return True
    if sub == "pull":
        return args == ["--ff-only"]
    if sub == "rebase":
        return args in (["--abort"], ["--continue"], ["--skip"])
    if sub == "push":
        return (
            args[:1] != []
            and args[0].startswith("--force-with-lease")
            or args[:2] == ["origin", "--delete"]
        )
    return False


def main() -> None:
    event = json.load(sys.stdin)
    if event.get("tool_name") != "Bash":
        return
    if not allowed(event.get("tool_input", {}).get("command", "")):
        return
    name = event.get("hook_event_name")
    if name == "PreToolUse":
        json.dump(
            {
                "hookSpecificOutput": {
                    "hookEventName": name,
                    "permissionDecision": "allow",
                    "permissionDecisionReason": "git -C allowlist (git-c-allow.py)",
                }
            },
            sys.stdout,
        )
    elif name == "PermissionRequest":
        json.dump(
            {
                "hookSpecificOutput": {
                    "hookEventName": name,
                    "decision": {"behavior": "allow"},
                }
            },
            sys.stdout,
        )


if __name__ == "__main__":
    main()
