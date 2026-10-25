#!/usr/bin/env python3
"""Feed commands to git-c-allow.py and check which it approves.

    python3 scripts/test-git-c-allow.py

Each command goes in as a `PreToolUse` and as a `PermissionRequest`
event. The script prints each command whose answer is wrong, and exits 1
where there is one.
"""

import json
import subprocess
import sys
from pathlib import Path

HOOK = Path(__file__).with_name("git-c-allow.py")

APPROVED = [
    "git -C /r status --porcelain",
    "git -C /r log --oneline -5",
    "git -C /r diff --stat origin/main",
    "git -C /r diff --no-ext-diff --no-textconv",
    "git -C /r show --output-indicator-new=x HEAD",
    "git -C /r ls-remote origin",
    "git -C /r fetch origin",
    "git -C /r pull --ff-only",
    "git -C /r push --force-with-lease=refs/heads/b:abc origin HEAD:refs/heads/b",
    "git -C /r push origin --delete b",
    "git -C /r branch",
    "git -C /r branch -vv",
    "git -C /r branch --list 'iss-*'",
    "git -C /r rev-parse 'HEAD@{1}'",
    'git -C /r log --oneline -- "*.py"',
    "git -C /r branch --contains HEAD",
    "git -C /r branch --points-at HEAD b",
    "git -C /r branch --sort=-committerdate",
    "git -C /r branch --list --sort=refname 'iss-*'",
    "git -C /r branch --sort=refname --list 'iss-*'",
    "git -C /r branch --list --format %s 'iss-*'",
]

REFUSED = [
    "git -C /r diff --output=/tmp/x",
    "git -C /r log --outp=/tmp/x",
    "git -C /r diff --ext-diff",
    "git -C /r diff --ext",
    "git -C /r cat-file --textc HEAD:f",
    "git -C /r grep -O'touch x' y",
    "git -C /r grep -nO'touch x' y",
    "git -C /r grep --op='touch x' y",
    "git -C /r ls-remote --upload-pack='touch x' .",
    "git -C /r ls-remote --upl='touch x' .",
    "git -C /r ls-remote --upl 'touch x' .",
    "git -C /r fetch --upl='touch x' .",
    "git -C /r fetch --u='touch x' .",
    "git -C /r push --force-with-lease --rece='touch x' . HEAD:refs/heads/y",
    "git -C /r push --force-with-lease --exe='touch x' . HEAD:refs/heads/y",
    "git -C /r branch -D b",
    "git -C /r branch -vD b",
    "git -C /r branch --del b",
    "git -C /r branch --unset-u",
    "git -C /r branch --set-u=origin/main",
    "git -C /r branch -umain",
    "git -C /r branch --edit-d",
    "git -C /r branch newbranch",
    "git -C /r branch --sort=refname newbranch",
    "git -C /r branch --format=%s newbranch",
    "git -C /r branch --format --list newbranch",
    "git -C /r branch --sort --list newbranch",
    "git -C /r branch --form -l newbranch",
    "git -C /r -c core.pager=x log",
    "git -C /r worktree add /x",
    "git -C /r rebase origin/main",
    "git -C /r ls-remote {--upload-pack='touch x',.}",
    "git -C /r fetch {--upload-pack='touch x',.}",
    "git -C /r diff --out{put=x,} HEAD HEAD",
    "git -C /r grep -{O..O}x y",
    "git -C /r diff --outp* HEAD HEAD",
    "git -C /r grep -?x y",
    "git -C /r log [-]-output=x",
    "git -C /r rev-parse @{u}",
]


def approves(command: str, event: str) -> bool:
    payload = {
        "tool_name": "Bash",
        "hook_event_name": event,
        "tool_input": {"command": command},
    }
    out = subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return out != ""


def main() -> None:
    wrong = [
        f"{event}: {'refused' if expected else 'approved'}: {command}"
        for expected, commands in ((True, APPROVED), (False, REFUSED))
        for command in commands
        for event in ("PreToolUse", "PermissionRequest")
        if approves(command, event) != expected
    ]
    if wrong:
        print("\n".join(wrong))
    sys.exit(1 if wrong else 0)


if __name__ == "__main__":
    main()
