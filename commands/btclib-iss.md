---
description: btclib-iss — from an issue to an open pull request, measuring rather than asserting, with a local review before GitHub
argument-hint: [--night] <issue numbers or URLs>
---

# From an issue to a pull request

Take on the issues named in $ARGUMENTS, in a repository of `btclib-org`,
and take each to an open pull request: written, gated, cleared by a
local review, and with its reviewers requested. That is where this
command ends. Answering the reviews, CI, the approval and the landing
are `/btclib-pr`'s.

**First read `~/.claude/process/btclib-common.md`, whole.** It binds
this command, names the roles, and holds every rule the two commands
share. This file holds only what is this command's own.

GitHub numbers issues and pull requests together, so `gh pr view <n>`
says which a number is. A pull request among the arguments is
`/btclib-pr`'s: skip it and tell the human.

**Which sections are yours**, beyond the shared file's map:

- **The writer**: *What the issue still asks*.
- **The reviewer**: nothing more.
- **The orchestrator**: all of this file.

## Several issues, several pull requests

- **Never as a batch; never hold one that is ready.** Open each pull
  request as soon as it is cleared.
- **Bundle by file or by decision.** Related issues — same file or same
  decision — make one pull request; otherwise one pull request per
  issue. Before assigning a worker, look for open issues sharing a file
  or a decision with the one at hand (`gh issue view` each) and take them
  together.
- **A port asks for convergence.** Hash the copies first; ask each tree
  to take the source byte for byte rather than apply the delta you
  measured, which can come up short.
- **Where a pull request is already open for an issue**, this command
  opens no competing branch: that pull request is `/btclib-pr`'s.

## What the issue still asks

The writer does this for its issue; the orchestrator does it before
briefing anybody, after the shared *Before starting*.

**Re-derive the issue's *Done when* and its central measurement against
`origin/main`**, and say which parts are already answered. An issue
answered entirely is closed with the measurement. Within one repository
this finds landed commits citing still-open issues:

```shell
open=$(gh issue list --repo <owner>/<repo> --state open --limit 200 \
  --json number -q '.[].number')
git -C <wt> log --format='%h|%s' -80 origin/main |
while IFS='|' read -r sha subj; do
  echo "$subj" | grep -oE '#[0-9]+' | tr -d '#' | while read -r n; do
    echo "$open" | grep -qx "$n" && echo "$sha ISS $n  $subj"
  done
done
```

## Opening the pull request

The orchestrator's. **Before opening, and the last item once it is
open:**

- [ ] the local reviewer's `CLEARED` names the branch's content
- [ ] rebased onto `origin/main`; where it moved, gates re-run (the
      shared *A rebase and the clearance*)
- [ ] the subject that lands carries the right citation (the shared
      *Citations and closing keywords*)
- [ ] the body carries one closing keyword per line, and the sweep finds
      no other
- [ ] a reserved decision, if any, is the body's first paragraph
- [ ] `closingIssuesReferences` counts what you meant to close

- **Open only after the local review has cleared it.**
- **A change to `claude-review.yml` is its own pull request.** The
  action refuses to run where its workflow differs from the default
  branch's.
- **Rebase onto `origin/main`** and run the gates again.
- **Title and body.** The title carries the citation; the body carries
  the keyword, one per line, and states the reserved decision first
  where there is one. It also says which gates ran on the head, with
  their exit codes, and which rebase case the clearance is in.
- **Count what GitHub will close**:
  `gh pr view <n> --json closingIssuesReferences --jq
  '.closingIssuesReferences | length'`. The field lags creation by
  seconds to minutes; ask again.
- **Request the review** of every owner but the author, as
  `btclib-org/.github`'s `GOVERNANCE.md` names them: every pull request
  lands approved by somebody other than its author.

  ```shell
  gh pr edit <n> --repo <owner>/<repo> --add-reviewer <login>,<login>
  ```

- **Arm nothing.** Auto-merge is armed by `/btclib-pr`, on a head whose
  reviews it has read.

## Handing over

Once each pull request is open:

- **The collateral has numbers, and goes back now** to that pull
  request's writer/reviewer pair (the shared *Collateral*), before
  anything new starts.
- **Remove the worktrees** — yours, and tell the writer to remove its
  own. The branch is on the forge; `/btclib-pr` works it from a worktree
  of its own.
- **Report to the human** each pull request as a `PR` link, what it
  closes, and whom it waits on. The next step is `/btclib-pr`, by the
  author once reviews arrive, and by another owner to approve it.

Then the shared *Wrap-up*.
