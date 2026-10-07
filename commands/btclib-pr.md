---
description: btclib-pr — from an open pull request to the decision to approve, and to main; every review answered, rebased, CI green
argument-hint: [--night] [pull request URLs or numbers]
---

# From a pull request to main

Take the open pull requests named in $ARGUMENTS, in repositories of
`btclib-org`, to the point where only the decision to approve is left.
Every review, thread, suggestion and comment is answered, the branch is
rebased onto the default branch, and CI is green. Where the approval is
obvious, approve and land. Where it is not, put the decision to the
human. With no argument, start from *The sweep*.

**First read `~/.claude/process/btclib-common.md`, whole.** It binds
this command, names the roles, and holds every rule the two commands
share. This file holds only what is this command's own.

A pull request URL or `<owner>/<repo>#<n>` names the repository; a bare
number does not, and the shared *Where you work* asks.

**Which sections are yours**, beyond the shared file's map:

- **The writer**: *What was raised*, *Answering it*, *Rebase and CI*,
  *Outside contributors*.
- **The reviewer**: *Rebase and CI*'s first bullet, for the delta it
  reads.
- **The orchestrator**: all of this file.

## The sweep

With no argument, list the organization's open pull requests, read from
the API:

```shell
gh search prs --owner btclib-org --state open --limit 200 \
  --json repository,number,title,author,url,isDraft
```

```shell
gh search prs --owner btclib-org --state open --review-requested @me \
  --limit 200 --json url
```

Show the human one table, grouped:

- waiting on the human's review;
- the human's own, with something to do: a review or thread
   unanswered, changes requested, a red or missing check, the branch
   behind its base;
- bots';
- outside contributors';
- the rest, listed and not worked.

Each row is a `PR` link and what it waits on. A draft is listed and not
worked. Then put one numbered question: which to work, and in what
order, with a recommendation. Within one repository the order is
`CONTRIBUTING.md`'s *The landing queue*: one pull request carried to the
default branch at a time, the cheapest and least contended first. At
night, work the recommendation.

## Whose pull request it is

```shell
gh api user --jq .login
```

```shell
gh pr view <n> --repo <owner>/<repo> --json author,state,isDraft,\
isCrossRepository,maintainerCanModify,headRefName,headRefOid,baseRefName
```

Then the shared *Before starting*, on the pull request. Which case it
is:

- **The human's.** The session works it as its author. GitHub refuses an
  author's own approval, so the session ends it at *The human's own pull
  request*.
- **Another person's, on a branch of the repository.** The session
  works it as its reviewer, and changes it as *Another person's branch*
  says.
- **Left by a session that no longer runs**: the shared take-over, the
  branch becoming the writer's own. Where a session still holds it,
  stop.
- **A bot's** — Dependabot, pre-commit.ci. The reviewer checks that the
  diff moves what its title says and nothing else, and in which
  direction: Dependabot follows the default branch, so a submodule
  pinned off it is offered a rollback. Its branch is the bot's: bring it
  up to date with `gh pr update-branch` or the bot's own rebase command,
  never a push. Where the update is wrong, close it with the
  measurement.
- **An outside contributor's**: *Outside contributors*.

## What was raised

Collect everything said on the pull request, from the API. Paginate
where a page comes back full.

- **Reviews**, each with its state, author, body and the commit it
  names: `gh pr view <n> --repo <owner>/<repo> --json reviews`. The
  bot's review from `claude-review.yml` is one of them.
- **Review threads**, inline, with whether each is resolved:

  ```shell
  gh api graphql -F owner=<owner> -F repo=<repo> -F n=<n> -f query='
    query($owner: String!, $repo: String!, $n: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $n) {
          reviewThreads(first: 100) {
            nodes {
              id isResolved isOutdated path line
              comments(first: 50) { nodes { author { login } body url } }
            }
          }
        }
      }
    }'
  ```

- **Suggestions**: a fenced `suggestion` block in a thread's comment.
- **Comments** on the pull request itself: `gh pr view <n> --repo
  <owner>/<repo> --json comments`.
- **Checks**: `gh pr checks <n> --repo <owner>/<repo>`.

An unresolved thread, a review newer than the last push, and a comment
nobody has answered are all items. A resolved thread is done.

## Answering it

**Each item is re-measured first** (the shared *Orchestration*), then
answered one of three ways:

- **accept**: fixed in a new signed commit on top (the shared
  *Committing and rebasing*). A suggestion is applied in the worktree,
  not with GitHub's button, so the gates run on it.
- **decline**: with the measurement that refutes it.
- **decision**: a choice the tree does not settle — design, scope, a
  reserved decision. It goes to the human, as the shared *When the human
  has to decide* says.

**Every thread gets a reply, and is then resolved.** An accepted one
names the commit that fixes it; a declined one carries its measurement.
A thread waiting on a decision or on the author is replied to and
resolved once that arrives. Write the reply to a file of your own, then:

```shell
gh api graphql -F t=<thread id> -F b=@<reply file> -f query='
  mutation($t: ID!, $b: String!) {
    addPullRequestReviewThreadReply(
      input: {pullRequestReviewThreadId: $t, body: $b}) { comment { url } }
  }'
```

```shell
gh api graphql -F t=<thread id> -f query='
  mutation($t: ID!) {
    resolveReviewThread(input: {threadId: $t}) { thread { isResolved } }
  }'
```

A review or comment outside a thread is answered in one comment on the
pull request, item by item.

### Another person's branch

**On another person's pull request, minor changes are the session's and
substantial ones are the author's.**

- **Minor**: the rebase, the union files, a reviewer's suggestion
  applied as written, a typo, a lint or format fix, a red check whose fix
  changes no behaviour, a few lines that take no decision.
- **Substantial**: anything that changes behaviour, an interface, the
  design, or what the pull request says it does — and anything the
  session is not sure is minor.

A substantial item is posted to the author as a review comment, with a
suggestion where it is a few lines and what would settle it otherwise.
The pull request then waits on them, recorded as a hold.

Before pushing to another person's branch, the shared *Before starting*
says no session of theirs is live on it, and the push is the lease push
of the shared *Committing and rebasing*, on the sha you built on. Where the branch
moved, they are working: stop and ask.

## Rebase and CI

- **The reviewer reads the delta** from the sha it last cleared, and the
  rebase case of the shared *A rebase and the clearance*. A fresh
  reviewer reads the whole diff from its parent.
- **Rebase onto the default branch only the pull request that heads its
  repository's queue** (`CONTRIBUTING.md`'s *The landing queue*). The
  others are answered and wait, untouched otherwise. An outside
  contributor's branch is never rebased: *Outside contributors* brings
  `main` in by a merge. Rebuild the union files, run the gates, and
  push. Ask the merge the forge will compute, locally:
  `git -C <wt> -c merge.union.driver=false merge-tree origin/main
  <branch>` exits `1` where GitHub will refuse; `gh pr view --json
  mergeable` is a cached value.
- **Wait for the checks on the head just pushed**, in the background,
  by asking until none is pending: `gh pr checks --watch` can return
  while runs are still queued. The list covers check runs and commit
  statuses, pre-commit.ci's among them. It must not be empty: right
  after a push nothing has reported yet. The loop gives up after 30
  minutes; say so where it does.

  ```shell
  for i in $(seq 60); do
    [ "$(gh pr checks <n> --repo <owner>/<repo> --json bucket \
      --jq 'length > 0 and all(.[]; .bucket != "pending")')" = true ] &&
      break
    sleep 30
  done
  ```

  A `cancelled` run is not a `failure`.
- **A red check is read before anything is done about it**:
  `gh run view <run id> --repo <owner>/<repo> --log-failed`. Then:
    - **caused by the pull request**: fixed as an accepted item, under
      *Another person's branch* where it is not the human's;
    - **red on the default branch too**, same check
      (`gh run list --repo <owner>/<repo> --branch main --workflow
      <file> --limit 5`): not this pull request's. Find or file its
      issue. A required check holds the pull request, recorded as a
      hold; one that only reports is named in the decision;
    - **not reproducing**: the shared *A failure that does not reproduce
      is measured*. One re-run measures it (`gh run rerun <run id>
      --repo <owner>/<repo> --failed`); two different answers are an
      issue, not a green.
- **The bot's review is answered like any other**, iterating to an ACK
  that names the current head.

## The decision

**Approve only the head of its repository's queue.** A push dismisses an
approval, and `main` is strict, so a pull request that will be rebased
before it lands would need approving again. The others wait with their
reviews answered and CI green; each is rebased, gated and decided when
its turn comes (`CONTRIBUTING.md`'s *The landing queue*).

**The approval is obvious where every item holds:**

- [ ] the human is not the author
- [ ] the pull request heads its repository's queue, and is not behind
      its base
- [ ] the local reviewer's `CLEARED` names the head
- [ ] every check on the head is green, not only the required ones
- [ ] the bot's review names the head with an ACK
- [ ] no thread is unresolved, and nobody else's changes requested
      stand
- [ ] no item is left as a decision, the branch takes no decision its
      issue reserved, and no substantial change waits on the author
- [ ] the diff touches no workflow, no release or publishing machinery,
      no repository setting, no cryptographic or other security-relevant
      code, no new dependency or major version, and nothing the tree's
      `CONTRIBUTING.md` names as decided by CI alone

Where it is obvious, approve, with a body naming the head and what was
checked, and land (*Landing*):

```shell
gh pr review <n> --repo <owner>/<repo> --approve --body-file <body>
```

**Then read the approval back**: `gh pr view <n> --repo <owner>/<repo>
--json reviewDecision --jq .reviewDecision` answers `APPROVED`. Where it
does not, the ruleset asks for another approval — the session's own
commits on the branch can be the reason. Request it from an owner who
wrote nothing on it, and report.

**Where it is not obvious**, put it to the human as numbered questions:
approve, ask the author for changes, or wait, each with its cost, the
recommendation first. At night it is a deferred item.

### The human's own pull request

The decision is somebody else's. Once everything raised is answered,
the pull request heads its repository's queue and is rebased, CI is
green, and the local reviewer's `CLEARED` and the
bot's ACK both name the head:

- re-request the review of every owner but the human who has not
  approved the head (`gh pr edit <n> --repo <owner>/<repo>
  --add-reviewer <login>`);
- arm the landing, so that their approval lands it (*Landing*);
- report whom it waits on.

A pull request that changes `claude-review.yml` gets no review from the
bot: the action refuses to run where its workflow differs from the
default branch's, and its check fails. There the landing is armed
without the bot's ACK, every other check green.

## Outside contributors

Its issue stays theirs, and no competing branch is opened. The reviewer
reviews it against `REVIEWING.md`; the orchestrator delivers the
findings on the pull request, warmly: thanks first, what is right before
what is missing, a one-click suggestion where the fix is a few lines.

**It is completed in place where that is useful and possible**, on the
maintainer's standing instruction: useful where what is missing is small
enough that finishing it beats another round trip; possible where
`maintainerCanModify` is `true`. Otherwise the findings are delivered
and the session waits. Where a branch of ours must land first and
touches their lines, the maintainer decides the order, and the
contributor is told on their pull request what moved and how to resolve
it. Completing it:

- **Add, never rewrite.** Their commits stay byte for byte. `main` comes
  in by a signed merge, not a rebase, with the union files rebuilt
  across it (the shared *Union files after a rebase*). The fixes are a
  signed commit of ours on top, signed off by us.
- **Their sign-off is theirs to add.** A commit of theirs without the
  trailer is not ours to fix: a sign-off we add for them is not their
  attestation. Ask them, before we push anything to their branch, to
  run the command the `Sign-off` check's failure prints and force-push.
- **Push to their fork as a fast-forward only**: `git push <fork url>
  HEAD:refs/heads/<their branch>`, never with any `--force`. Before
  every push, `git ls-remote <fork url> refs/heads/<their branch>` must
  still answer the sha you built on; where it moved, they are working,
  and you stop and ask.
- **The same review and decision, then the squash of their pull
  request.** That keeps their authorship; a branch of ours
  cherry-picking them would leave their pull request closed rather than
  merged, and uncredited. Keep their title with the citation; the
  message says what the change does, corrects anything false in their
  commits, and ends with every `Signed-off-by:` line of the commits it
  squashes and a `Co-authored-by:` line for whoever finished it. The
  `Sign-off` job reads the pull request's commits, not the squash, so
  the message carries their trailers onto `main`. After the landing,
  `gh api repos/<owner>/<repo>/commits/<sha> --jq .author.login` is
  theirs.
- **Thank them in a comment of its own**: what their change does, what
  was added and why, in terms they can learn from, and the open issues
  they might take next.

Where the bot's review does not run — a fork's pull request, and any
other where `gh pr checks` shows no review — the ACK is not an item of
*The decision*, and the approval is never obvious: it goes to the
human.

## Landing

- **What gates a merge on GitHub** is the repository's own
  `REPOSITORY.md`, read from `origin/main`: typically an approval from
  somebody other than the author, `required_signatures`, every review
  thread resolved, and the required status checks. The bot's ACK is a
  comment, not an approval. A push dismisses an approval already given.
- **Squash, with the head pinned, by auto-merge.** The branch carries
  several commits once review has added any, so the subject and the
  message are written, not inherited:

  ```shell
  gh pr merge <n> --repo <owner>/<repo> --squash --auto \
    --match-head-commit <the head that lands> \
    --subject "<title> (closes #<issue>) (#<n>)" --body-file <message>
  ```

  The subject is the pull request's title with its citation (the shared
  *Citations and closing keywords*) and `(#<n>)`; `--subject` replaces the whole
  subject. The message says what the change
  does, and keeps every `Signed-off-by:` and `Co-authored-by:` line of
  the commits it squashes. A finding that lives only in the commit
  message is fixed here, with no new round.
- **The pin is the head as pushed after the final rebase**, not the sha
  a verdict named. A queued pull request that falls `BEHIND` its base
  (`gh pr view <n> --json mergeStateStatus`) is rebased, gated, approved
  again, and armed again on the new head.
- **A stacked pull request lands like any other**: once its base has
  landed, it is rebased onto `main` as `CONTRIBUTING.md`'s *One subject,
  opened as soon as it is written* says, approved, and armed.
- **Check what landed, once it has.** `--auto` returns before the
  merge: repeat `gh pr view <n> --repo <owner>/<repo> --json
  state,mergeCommit,autoMergeRequest --jq '.state, .mergeCommit.oid,
  .autoMergeRequest'` until it answers `MERGED`, and `<sha>` is that
  oid. Where it is `OPEN` with no `autoMergeRequest`, the merge was
  cancelled: report it. Then `gh api
  repos/<owner>/<repo>/commits/<sha> --jq .commit.verification` is
  `verified: true`, and each issue the pull request declared closed is
  closed. What follows waits for this.
- **A landing in `btclib-org/claude-process` brings its primary checkout
  forward at once**, by the shared fast-forward. The files under
  `~/.claude/` are symlinks into it, so until then every session reads
  the old process. Then read a landed line back through the symlink of
  the file it changed.
- **The collateral goes back now** to that pull request's
  writer/reviewer pair (the shared *Collateral*), before anything new
  starts.
- **Remove the worktrees** — yours, and tell the writer to remove its
  own.

Then the shared *Wrap-up*.
