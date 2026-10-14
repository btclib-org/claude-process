---
description: btclib-iss — from an issue to an open pull request, locally reviewed before GitHub and followed as its author, measuring rather than asserting
argument-hint: [--night] [--land] <issue numbers or URLs>
---

# From an issue to a pull request

Take on the issues named in $ARGUMENTS, in a repository of `btclib-org`,
and take each to an open pull request, written, gated and cleared by a
local review (*Opening the pull request*). Then follow each as its
author (*Following it*).

**First read `~/.claude/process/btclib-common.md`, whole.** Its opening
says what it holds and what this file holds. What the session writes,
and this file, follow its *Write plainly*.

**Where $ARGUMENTS names no issue, ask the human which, before reading
anything**: no tracker, no checkout, and no earlier context stands in for
the answer. Where the repository is not named either, that question comes
first (the shared *Where you work*).

GitHub numbers issues and pull requests together, so `gh pr view <n>`
says which a number is. A pull request among the arguments is
`/btclib-pr`'s: skip it and tell the human.

**Which sections are yours**, beyond the shared file's map:

- **The writer**: *What the issue still asks*, and `/btclib-pr`'s *What
  was raised*, *Answering it* and *Rebase and CI*.
- **The reviewer**: `/btclib-pr`'s *Rebase and CI*'s first bullet, for
  the delta it reads.
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

An issue labelled `upstream-dependent` is taken only once its wait is
over; taking it removes `upstream-dependent`, and `blocked` where the
wait was its reason. The wait is what the issue names, in its body or a
later comment: an upstream issue, pull request, release or draft. Read
its state there.

```shell
gh issue edit <n> --repo <owner>/<repo> --remove-label upstream-dependent
```

Where `blocked` waited on the same thing:

```shell
gh issue edit <n> --repo <owner>/<repo> --remove-label blocked
```

## Opening the pull request

The orchestrator's. **Before opening, and the last item once it is
open:**

- [ ] the latest fresh reviewer's `CLEARED` (the shared *Local review*)
      names the branch's content, or *A rebase and the clearance*
      carries it to the rebased branch
- [ ] no conflict with `origin/main` (`/btclib-pr`'s *Rebase and CI*);
      where there was one, rebased and the gates re-run (the shared *A
      rebase and the clearance*)
- [ ] the subject that lands carries the right citation (the shared
      *Citations and closing keywords*)
- [ ] the body carries one closing keyword per line, and the sweep finds
      no other
- [ ] a reserved decision, if any, is the body's first paragraph
- [ ] `closingIssuesReferences` counts what you meant to close

- **A change to `claude-review.yml` is its own pull request**: the bot
  does not review it (`/btclib-pr`'s *The human's own pull request*).
- **The body also says which gates ran on the head**, with their exit
  codes, and which rebase case the clearance is in.
- **Count what GitHub will close**:
  `gh pr view <n> --json closingIssuesReferences --jq
  '.closingIssuesReferences | length'`. The field lags creation by
  seconds to minutes; ask again.
- **Unless `--land` covers it (`/btclib-pr`'s *Landing*), request the
  reviews** that `/btclib-pr`'s *The human's own pull request* names.

## Following it

Once a pull request is open, the session follows it as its author.
`~/.claude/commands/btclib-pr.md` holds the rules, read there and not
restated here: *What was raised*, *Answering it*, *Rebase and CI*,
*The human's own pull request*, and *Landing*'s first four bullets and
its *Check what landed*. Under `--land`, all of *Landing* applies.

- **The `/btclib-pr` *Landing* bullets on the collateral and on the
  worktrees hold here**, and the worktrees are also removed once the
  session hands the pull request over to whom it waits on.
- **Report to the human** each pull request as a `PR` link, what it
  closes, and whom it waits on or that it landed. What arrives after
  the session ends — a review, a conflict with `main` — is
  `/btclib-pr`'s.

Then the shared *Wrap-up*.
