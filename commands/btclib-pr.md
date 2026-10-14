---
description: btclib-pr — from an open pull request to the decision to approve, and to main; every review answered, CI green
argument-hint: [--night] [--land] [pull request URLs or numbers]
---

# From a pull request to main

Take the open pull requests named in $ARGUMENTS, in repositories of
`btclib-org`, to the decision to approve and to `main`, through *What
was raised*, *Answering it*, *Rebase and CI*, *The decision* and
*Landing*. With no argument, start from *The sweep*.

**First read `~/.claude/process/btclib-common.md`, whole.** Its opening
says what it holds and what this file holds. What the session writes,
and this file, follow its *Write plainly*.

The shared *Where you work* says how the repository is named.

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
   unanswered, changes requested, a red or missing check, a conflict
   with its base;
- bots';
- outside contributors';
- the rest, listed and not worked.

Each row is a `PR` link and what it waits on. A draft is listed and not
worked. Then put one decision (the shared *When the human has to
decide*): which to work, and in what order, the recommended order first
with its reason. In a repository whose `main` is red, its repair comes
first (*Landing*'s first bullet). At night, work the recommendation.

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

- **The human's.** The session works it as its author, and ends it at
  *The human's own pull request*.
- **Another person's, on a branch of the repository.** The session
  works it as its reviewer, and changes it as *Another person's branch*
  says.
- **Left by a session that no longer runs**: the shared take-over, the
  branch becoming the writer's own. Where a session still holds it,
  stop.
- **A bot's** — Dependabot, pre-commit.ci. The reviewer checks that the
  diff moves what its title says and nothing else, and in which
  direction: Dependabot follows the default branch, so a submodule
  pinned off it is offered a rollback. Its branch is the bot's: where
  it conflicts, or where `CONTRIBUTING.md`'s *Landing it* asks for a
  rebase after a repair, the bot's own rebase command brings it up to
  date, or `gh pr update-branch` for a bot with none, as pre-commit.ci
  is. Never a push but the one below.
  Where the update is wrong, close it with the measurement.

  Where the tree's `CONTRIBUTING.md` says an owner commits a hook's
  output to a bot's branch, that commit is signed, signed off, and
  pushed as a fast-forward only, never with any `--force`. The diff then
  moves a second file, and the reviewer checks that it is the hook's
  output: the hook passes on the head. Dependabot stops rebasing a pull
  request once extra commits are pushed to it ([GitHub's
  documentation][dependabot-rebase]). Where it then needs a rebase,
  `@dependabot recreate` drops the commit, which is then made again.
- **An outside contributor's**: *Outside contributors*.

## What was raised

Collect everything said on the pull request, from the API. Paginate
where a page comes back full.

- **Reviews**, each with its state, author, body and the commit it
  names: `gh pr view <n> --repo <owner>/<repo> --json reviews`. The
  bot's review from `claude-review.yml` is one of them.
- **Review threads**, inline, with whether each is resolved:

  ```shell
  gh api graphql --paginate -F owner=<owner> -F repo=<repo> -F n=<n> \
    -f query='
    query($owner: String!, $repo: String!, $n: Int!, $endCursor: String) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $n) {
          reviewThreads(first: 100, after: $endCursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id isResolved isOutdated path line
              comments(first: 100) {
                totalCount
                nodes { author { login } body url }
              }
            }
          }
        }
      }
    }'
  ```

  A thread whose `totalCount` exceeds its `nodes` is read whole on its
  own.

- **Suggestions**: a fenced `suggestion` block in a thread's comment.
- **Comments** on the pull request itself: `gh pr view <n> --repo
  <owner>/<repo> --json comments`.
- **Checks**: `gh pr checks <n> --repo <owner>/<repo>`.

An unresolved thread is an item. So is a review or comment from anybody
but the human that asks something, where nobody has answered it or it
came after the human's last comment and last push. A resolved thread is
done.

## Answering it

**Each item is re-measured first** (the shared *Orchestration*), then
answered one of three ways:

- **accept**: fixed in a new signed commit on top (the shared
  *Committing and rebasing*). A suggestion is applied in the worktree,
  not with GitHub's button, so the gates run on it.
- **decline**: with the measurement that refutes it.
- **decision**: a choice the tree does not settle — design, scope, a
  reserved decision. It goes to the human or the maintainer, as the
  shared *When the human has to decide* says.

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

- **Minor**: the rebase, a reviewer's suggestion
  applied as written, a typo, a lint or format fix, a red check whose fix
  changes no behaviour, a few lines that take no decision.
- **Substantial**: anything that changes behaviour, an interface, the
  design, or what the pull request says it does — and anything the
  session is not sure is minor.

A substantial item is posted to the author as a review comment, with a
suggestion where it is a few lines and what would settle it otherwise.
The pull request then waits on them, recorded as a hold.

**On the maintainer's pull request, worked by another owner,
substantial changes are the session's too** (the maintainer,
2026-10-11). A change that takes a decision goes to the maintainer, as
the shared *When the human has to decide* says. The owners are those
*The human's own pull request* lists.

Before pushing to another person's branch, the session claims it (the
shared *A claim holds a pull request's branch*), and the push is the
lease push of the shared *Committing and rebasing*, on the sha you built
on. Where the branch moved, they are working: stop and ask.

## Rebase and CI

- **The reviewer reads the delta** from the sha it last read, and the
  rebase case of the shared *A rebase and the clearance*. A fresh
  reviewer's first read is the whole diff from its parent.
- **A pull request is rebased onto the default branch only where
  `CONTRIBUTING.md`'s *Landing it* says, or for a retarget.** An outside
  contributor's branch is never rebased: *Outside contributors* brings
  `main` in by a merge.
- **After a rebase or a merge of `main`, run the gates and push.** Ask
  the merge the forge will compute, locally:
  `git -C <wt> -c merge.union.driver=false merge-tree origin/main
  <branch>` exits `1` where GitHub will refuse. `gh pr view --json
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
  gh pr checks <n> --repo <owner>/<repo>
  ```

  The last command's exit code says how the loop ended: `0` all passed,
  `1` a failure or no checks at all, `8` still pending with none failed.
  The loop gave up wherever that output still lists a pending check or
  says `no checks reported`.

  A `cancelled` run is not a `failure`.
- **A red check is read before anything is done about it**:
  `gh run view <run id> --repo <owner>/<repo> --log-failed`. Then:
    - **caused by the pull request**: fixed as an accepted item, under
      *Another person's branch* where it is not the human's;
    - **red on the default branch too**, same check
      (`gh run list --repo <owner>/<repo> --branch main --workflow
      <file> --limit 5`): not this pull request's. Find or file its
      issue. A required check holds the pull request until the repair
      lands, as *Landing*'s first bullet says. A check that only reports
      is named in the decision;
    - **not reproducing**: the shared *A failure that does not reproduce
      is measured*. One re-run measures it (`gh run rerun <run id>
      --repo <owner>/<repo> --failed`); two different answers are an
      issue, not a green;
    - **review quota exhausted**: the log of `Claude review` holds the
      line `api_error_status 429` (match with that, not with
      `api_error_status` alone: the log also echoes the workflow's own
      source) followed by a line such as `You've hit your weekly limit ·
      resets 11am (UTC)`.

      ```shell
      gh run view <run id> --repo <owner>/<repo> --log-failed |
        grep -E 'api_error_status 429|hit your .* limit'
      ```

      The log gives the reset as `resets Oct 10, 11am (UTC)`, or as
      `resets 11am (UTC)` when it is less than a day away. Where it gives
      no date, the reset is the first such hour after the log line's
      timestamp. Write it as `2026-10-10T11:00`:

      ```shell
      reset=<reset>
      ```

      This prints `ahead` or `passed`:

      ```shell
      expr "${reset:?}" \> "$(date -u +%Y-%m-%dT%H:%M)" > /dev/null &&
        echo ahead || echo passed
      ```

      Where it prints `passed`, the session following the pull request
      re-runs the failed run, and its result stands. This holds for a
      429 read after its reset and for a pull request held until it:

      ```shell
      gh run rerun --repo <owner>/<repo> --failed <run id>
      ```

      Where it prints `ahead`, the quota is held. The quota is the
      organization's, so it is held once, in one open, pinned issue in
      `btclib-org/.github` titled
      `Review quota exhausted, resets <reset> UTC`. The title carries
      the reset so that a reader can tell whether it has passed. Look
      for the issue:

      ```shell
      gh issue list --repo btclib-org/.github --state open \
        --search 'in:title "Review quota exhausted"' --json number,title
      ```

      Where it lists none, open it:

      ```shell
      gh issue create --repo btclib-org/.github \
        --title "Review quota exhausted, resets ${reset:?} UTC" \
        --body 'Claude review fails with 429 until the reset in the title.'
      ```

      Pin it, with the URL that command printed:

      ```shell
      gh issue pin <url>
      ```

      Where it lists one whose title gives another reset, update the
      title:

      ```shell
      gh issue edit --repo btclib-org/.github \
        --title "Review quota exhausted, resets ${reset:?} UTC" <number>
      ```

      The issue stays open and pinned from one quota to the next. A pull
      request whose only red check is this one waits on it: its hold
      comment links the issue, and it takes no `blocked` label. Whether
      it lands before the reset is decided as *The decision* and
      *Landing* say. After the reset, the check above prints `passed`.

- **The bot's review is answered like any other**, iterating to an ACK
  that names the current head.

## The decision

**The session's approval is the human's** (the shared file's *Three
roles this file names*). Their standing instruction covers an obvious
approval, as defined below, and nothing else. Every other approval is
theirs to give.

**GitHub refuses an approval from a pull request's author.** On the
human's own pull request the session never approves: *The human's own
pull request* says what it does instead.

**Before any approval, read `main` as *Landing*'s first bullet says.**
An approval on an armed pull request merges it at once. Where `main` is
red, only its repair is approved.

**The approval is obvious where every item holds**, each measured on the
head `<sha>`. The diff is read once, by two commands that must each
exit `0`:

```shell
gh pr diff <n> --repo <owner>/<repo> --name-only > <list file>
```

```shell
gh pr diff <n> --repo <owner>/<repo> > <diff file>
```

The list omits the old path of a renamed file, so add it from the diff:

```shell
grep '^rename from ' <diff file> | cut -d' ' -f3- >> <list file>
```

- [ ] the author is not the human: `.author.login` differs from
      `gh api user --jq .login`
- [ ] the latest fresh reviewer's `CLEARED` names `<sha>`, or *A rebase
      and the clearance* carries it to `<sha>`
- [ ] every check passed or was skipped, required or not:
      `gh pr checks <n> --repo <owner>/<repo> --json bucket --jq
      'length > 0 and all(.[]; .bucket == "pass" or .bucket ==
      "skipping")'` answers `true`. A cancelled check (bucket
      `cancel`) fails this item until a re-run passes.
- [ ] the bot's latest review starts `ACK <sha>`: `gh pr view <n>
      --repo <owner>/<repo> --json reviews --jq '[.reviews[] |
      select(.author.login == "claude" and .body != "")] | last |
      .body'`
- [ ] no review thread is unresolved, every page read (*What was
      raised*)
- [ ] every item of *What was raised* is answered
- [ ] no other reviewer's changes requested stand: `latestReviews`
      holds no `CHANGES_REQUESTED`
- [ ] no item waits on a decision or on the author, and the branch
      takes no decision its issue reserved
- [ ] the repository is not `btclib-org/claude-process`, whose every
      file gives instructions or rules
- [ ] the list holds no file that gives instructions or rules: the
      first command below prints nothing, and the second, where it
      runs, exits `0`
- [ ] every other file in the list is a doc, a test, `pyproject.toml`
      or `uv.lock`: the third command below prints nothing
- [ ] `pyproject.toml` and `uv.lock` only move dependencies they
      already hold to a new version, never a major one, read from the
      fourth command below

The first prints each file under `.github/` or any `.claude/`, any top-level
`RELEASING.md`, `REPOSITORY.md` or `SECURITY.md`, and any `CLAUDE.md`,
`REVIEWING.md`, `GOVERNANCE.md` or `CONTRIBUTING.md`. It exits `1` where
there is none:

```shell
grep -E -e '^\.github/|^(RELEASING|REPOSITORY|SECURITY)\.md$' \
  -e '(^|/)(\.claude/|(CLAUDE|REVIEWING|GOVERNANCE|CONTRIBUTING)\.md$)' \
  <list file>
```

The second looks for the readme a package publishes: the `readme` of
`[project]` in the head's `pyproject.toml`. Read the file first. Where
`gh` answers `Not Found`, the tree has none, and the second is skipped:

```shell
gh api -H 'Accept: application/vnd.github.raw' \
  "repos/<owner>/<repo>/contents/pyproject.toml?ref=<sha>" > <toml file>
```

The second prints the readme where the list holds it, and exits `0`
only where it does not:

```shell
uv run --no-project --python 3.13 python -c 'import sys, tomllib
r = tomllib.load(open(sys.argv[1], "rb"))["project"].get("readme", "")
r = r if isinstance(r, str) else r.get("file", "")
sys.exit(bool(r) and r in open(sys.argv[2]).read().splitlines() and r)' \
  <toml file> <list file>
```

The third prints each file that fails its item, and exits `1` where
none does:

```shell
grep -Ev '^(docs|tests)/|\.md$|^(pyproject\.toml|uv\.lock)$' <list file>
```

The fourth prints the diff of `pyproject.toml` and `uv.lock`:

```shell
awk '/^diff --git /{p = ($3 == "a/pyproject.toml" || $3 == "a/uv.lock")}
  p' <diff file>
```

Any other change in them fails this item, a new requirement or
`[[package]]` included. A version whose first non-zero number changes
is a major one.

**Where it is obvious, approve `<sha>`, pinned.** `gh pr review` cannot
pin a commit, so the call is the API's:

```shell
gh api repos/<owner>/<repo>/pulls/<n>/reviews -f event=APPROVE \
  -f commit_id=<sha> -F body=@<body file>
```

The body says, one line each:

- the head it approves, `<sha>`;
- the `CLEARED` it relies on, and the rebase case;
- the bot's ACK, as a link;
- that every check passed or was skipped;
- what was not checked.

Then land it, pinned to the same `<sha>` (*Landing*).

**Read the approval back**:

```shell
gh pr view <n> --repo <owner>/<repo> \
  --json headRefOid,reviewDecision,reviews --jq '.headRefOid,
  .reviewDecision, ([.reviews[] | select(.state == "APPROVED")] | last
  | .author.login, .commit.oid)'
```

It answers `<sha>`, `APPROVED`, the human's login, and `<sha>`. Where
the head moved, decide again on the new head. Where the decision is not
`APPROVED`, the ruleset asks for another approval. Request it from an
owner who is neither the human nor the author and pushed no commit to
the branch, and report whom it waits on.

**Where it is not obvious, the human decides**, as one decision (the
shared *When the human has to decide*). Its context is the `PR` link,
the head sha, and each failed item with its measurement. The
alternatives are: approve as it is; ask the author for changes, naming
them; wait, naming on what or whom; close, where that is an option.
Record it as a hold (the shared *When the human has to decide*). On
"approve", approve as above, with a body saying it follows the human's
decision. At night it is a deferred item (the shared *Night mode*).

### The human's own pull request

Where `--land` covers it (*Landing*), the session lands it once every
item above holds but the first and the last four, as *Landing*
qualifies them. Without `--land`, another owner decides; once the same
items hold:

- request the review of every owner but the human who has not approved
  `<sha>`. `btclib-org/.github`'s `GOVERNANCE.md` names the owners, and
  `gh api "orgs/btclib-org/members?role=admin" --jq '.[].login'` lists
  them:

  ```shell
  gh pr edit <n> --repo <owner>/<repo> --add-reviewer <login>
  ```

- arm the landing, so that their approval lands it (*Landing*);
- report whom it waits on.

After a push, request the review again on the new head (*Landing*).

A pull request that changes `claude-review.yml` gets no review from the
bot. The action refuses to run where its workflow differs from the
default branch's, and its check fails. There `--land` does not apply:
the landing is armed without the bot's ACK, every other check green.

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
  in by a signed merge, not a rebase. The fixes are a
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

- **Before approving, arming `--auto` or merging, read `main`'s latest
  push runs**: `gh run list --repo <owner>/<repo> --branch main --event
  push`. `main` is red where a required check failed in the latest run
  of its workflow. A cancelled check is not a failure, and a check that
  only reports does not count (the maintainer, 2026-10-14). While `main`
  is red, only its repair lands (`CONTRIBUTING.md`'s *Landing it*).
  Every other armed `--auto` in the repository is disabled and recorded
  as a hold (the shared *When the human has to decide*). `gh pr list
  --repo <owner>/<repo> --json number,autoMergeRequest` lists them, and
  this disables one:

  ```shell
  gh pr merge --repo <owner>/<repo> --disable-auto <n>
  ```

  Once `main` is green, each held pull request is decided again (*The
  decision*) and armed again.

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

  Never land through the maintainer's bypass (`--admin`, or any other
  route to it) unless the human has instructed it for that pull request.
  It merges with no approval, even with required checks red.

  **`--land` is that instruction**, for the pull requests named with it,
  or opened by `/btclib-iss` for the issues named with it, and no others.
  The human's words in the session, naming the pull requests, count
  too. The bypass then lands only the human's own pull request, once it
  has reached the point *The human's own pull request* names. A check
  that only reports and is red on `main` too does not hold it, and is
  named in the report. In place of the command above:

  ```shell
  gh pr merge <n> --repo <owner>/<repo> --squash --admin \
    --match-head-commit <the head that lands> \
    --subject "<title> (closes #<issue>) (#<n>)" --body-file <message>
  ```

- **The pin is the head as last pushed**, not the sha a verdict named.
- **A stacked pull request lands like any other**: once its base has
  landed, it is rebased onto `main` as `CONTRIBUTING.md`'s *One subject,
  opened as soon as it is written* says, gated, decided again on the new
  head (*The decision*), and armed.
- **Check what landed, once it has.** `--auto` returns before the
  merge: repeat `gh pr view <n> --repo <owner>/<repo> --json
  state,mergeCommit,autoMergeRequest --jq '.state, .mergeCommit.oid,
  .autoMergeRequest'` until it answers `MERGED`, and `<sha>` is that
  oid. Where it is `OPEN` with no `autoMergeRequest`, the merge was
  cancelled: report it. Once it is `MERGED`, `gh api
  repos/<owner>/<repo>/commits/<sha> --jq .commit.verification` is
  `verified: true`, and each issue the pull request declared closed is
  closed. What follows waits for this.

  Then wait for `main`'s workflow runs on `<sha>`, with *Rebase and
  CI*'s loop and this test in place of its own. A workflow run is
  completed only once all its jobs are, including the jobs that wait on
  others and have no check run before they start:

  ```shell
  [ "$(gh api --paginate \
    "repos/<owner>/<repo>/actions/runs?head_sha=<sha>&event=push&per_page=100" \
    --jq '.workflow_runs[].status' | sort -u)" = completed ]
  ```

  Then run this section's first bullet again: a pull request armed
  before the merge would otherwise land on a red `main`.

- **A landing in `btclib-org/claude-process` brings its primary checkout
  forward at once**, by the shared fast-forward. The files under
  `~/.claude/` are symlinks into it, so until then every session reads
  the old process. Then read a landed line back through the symlink of
  the file it changed.
- **The collateral goes back now** (the shared *Collateral*), before
  anything new starts.
- **Remove the worktrees** — yours, and tell the writer to remove its
  own.

Then the shared *Wrap-up*.

[dependabot-rebase]: https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/manage-your-dependency-security/manage-dependabot-prs#allowing-dependabot-to-rebase-and-force-push-over-extra-commits
