# Repository instructions

Follow [CONTRIBUTING.md](./CONTRIBUTING.md) for issues, pull requests,
local gates, and worktree commands. Use [REVIEWING.md](./REVIEWING.md)
for reviews, [README.md](./README.md) for the repository and setup, and
[REPOSITORY.md](./REPOSITORY.md) before changing workflows or settings.
For vulnerability reporting, see
[btclib-org/.github's SECURITY.md][security].

[security]: https://github.com/btclib-org/.github/blob/main/SECURITY.md

Keep the primary checkout clean and on `main`; use a separate worktree
for each task, following the setup and cleanup commands in
`CONTRIBUTING.md`.

Choose the least capable model that can reliably complete the task: use
a fast model for straightforward execution, a reasoning-focused model
for multi-step work, and the most capable available model for difficult
or ambiguous problems. Increase capability if progress stalls.

This repository holds the maintainers' process: `process/btclib-common.md`
contains shared rules, `skills/btclib-iss/SKILL.md` and
`skills/btclib-pr/SKILL.md` guide issue and pull-request work, and
`agents/` defines the writer and reviewer roles.
