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
# Options that run a command or write a file.
UNSAFE = (
    "--output",
    "--open-files-in-pager",
    "-O",
    "--upload-pack",
    "--receive-pack",
    "--exec",
    "--ext-diff",
    "--textconv",
)
BRANCH_WRITE = {
    "-d",
    "-D",
    "--delete",
    "-m",
    "-M",
    "--move",
    "-c",
    "-C",
    "--copy",
    "-f",
    "--force",
    "-u",
    "--set-upstream-to",
    "--unset-upstream",
    "--edit-description",
    "-t",
    "--track",
}
BRANCH_FILTER = {
    "--list",
    "-l",
    "--contains",
    "--no-contains",
    "--merged",
    "--no-merged",
    "--points-at",
    "--format",
    "--sort",
}


def allowed(cmd: str) -> bool:
    if not cmd.startswith("git -C ") or any(c in cmd for c in ";&|`$<>()\n\\"):
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
    if any(a.startswith(UNSAFE) for a in args):
        return False
    if sub in READ:
        return True
    if sub == "branch":
        if any(a.split("=")[0] in BRANCH_WRITE for a in args):
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
