# Repository configuration

What is set on this repository, as the `gh api` call that reads it back
and the answer that call gives today. A setting recorded as prose alone
is one nobody can check; recorded this way, a drift is one command away
from being seen.

Read this before changing a branch rule, a repository setting or a
workflow. `CLAUDE.md` points here rather than carrying it, so that a
session editing the process does not hold it in context.

The rules and the settings live *outside* the tree. What is recorded is
the settings the standard asks about — the ones section 16's checklist
sets on a new repository, the ones a section of the standard states a
rule for, and the ones a behaviour it describes rests on — together with
whatever a call quoted for one of those answers alongside it. That is
this file's scope, and *What this file passes over* at the foot says what
falls outside it.

The endpoints these answers come from are the file's own `gh api` lines,
listed rather than restated in a second place that would have to be kept
true:

```shell
grep -o 'repos/btclib-org/claude-process[a-z/-]*' REPOSITORY.md | sort -u
```

When each answer was read is the commit that wrote it: `git blame
REPOSITORY.md`.

**Where a setting has a reason, the reason is section 11 of
[the organization's standard](https://github.com/btclib-org/.github) and
is not repeated here.** Two copies of an argument are two things to keep
true. What is here instead is the answer this repository gives.

**The repository is public, and that is a prerequisite rather than a
preference.** Rulesets are a paid feature for a private repository on the
free plan, and everything below depends on them.

```shell
gh api repos/btclib-org/claude-process \
  --jq '{visibility, has_issues}'
# {"has_issues":true,"visibility":"public"}
```

## Required checks on main

```shell
gh api repos/btclib-org/claude-process/branches/main/protection \
  --jq '.required_status_checks | {strict, checks}'
# {"checks":[{"app_id":15368,"context":"Lint"},
#            {"app_id":15368,"context":"Dependency review"}],
#  "strict":true}
```

**`lint.yml` runs on every pull request, and a red `Lint` or `Dependency
review` job stops a merge by anyone but the maintainer.** `strict` is on,
so anyone else's pull request must also be up to date with `main`. Both
contexts are bound to `15368`, the Actions app, so nothing else can
report one.

| Check | Produced by |
| --- | --- |
| `Lint` | `lint.yml` |
| `Dependency review` | `lint.yml`'s second job |

**The requirement lives in classic branch protection, not in a ruleset.**
No ruleset on `main` carries a `required_status_checks` rule:

```shell
gh api repos/btclib-org/claude-process/rules/branches/main \
  --jq '[.[] | {type, ruleset_id}]'
```

The protection is the same object `.github`, `portanode` and
`btclib-org.github.io` carry. Its other fields repeat the rulesets, except
two that are off: `enforce_admins` and classic's own `required_signatures`.
[Section 11][s11-branch] gives the reason for both.

```shell
gh api repos/btclib-org/claude-process/branches/main/protection \
  --jq '{reviews: .required_pull_request_reviews
           | {n: .required_approving_review_count,
              dismiss: .dismiss_stale_reviews},
         admins: .enforce_admins.enabled,
         linear: .required_linear_history.enabled,
         threads: .required_conversation_resolution.enabled,
         force: .allow_force_pushes.enabled,
         delete: .allow_deletions.enabled,
         signatures: .required_signatures.enabled}'
# {"admins":false,"delete":false,"dismiss":true,"force":false,
#  "linear":true,"n":1,"signatures":false,"threads":true}
```

The `PUT` sets every field it is given and clears the rest, so it carries
the whole object; the one at the foot of the section of this name in
`btclib-org/.github`'s own `REPOSITORY.md` is the one to send.

**`links.yml` is not a required check and must not become one.** It asks
whether somebody else's server answered, which is a question a merge
cannot depend on. `claude-review.yml` is not one either, and its own
header says why.

## Branch protection and the rulesets

`main` is the repository's default branch and its only one:

```shell
gh api repos/btclib-org/claude-process --jq '.default_branch'
# main
```

```shell
gh api repos/btclib-org/claude-process/rulesets --jq '.[].id' \
  | xargs -I{} gh api \
    repos/btclib-org/claude-process/rulesets/{} \
    --jq '{name, target, enforcement, refs: .conditions.ref_name.include,
           rules: [.rules[].type],
           bypass: [.bypass_actors[]?.bypass_mode]}'
# {"bypass":[],"enforcement":"active","name":"main-integrity",
#  "refs":["refs/heads/main"],
#  "rules":["required_signatures","required_linear_history",
#           "non_fast_forward","deletion"],"target":"branch"}
# {"bypass":["pull_request"],"enforcement":"active",
#  "name":"main-self-merge","refs":["refs/heads/main"],
#  "rules":["pull_request"],"target":"branch"}
# {"bypass":[],"enforcement":"active","name":"tag-integrity",
#  "refs":["refs/tags/v*"],"rules":["required_signatures"],"target":"tag"}
```

- `main-integrity` — required signatures, required linear history, no
  force pushes, no deletions — with **no bypass actor at all**, which is
  what makes every one of those true of an administrator too.
- `main-self-merge` — a pull request, an approving review, stale reviews
  dismissed on push, conversations resolved, and `squash` as the only
  merge method it accepts — bypassed by the maintainer in
  **`pull_request` mode**, which excuses its holder while merging a pull
  request and at no other time.
- `tag-integrity` — required signatures and nothing else, over
  `refs/tags/v*` rather than over a branch, with **no bypass actor**.

```shell
gh api repos/btclib-org/claude-process/rulesets --jq '.[].id' \
  | xargs -I{} gh api \
    repos/btclib-org/claude-process/rulesets/{} \
    --jq '.rules[] | select(.type=="pull_request") | .parameters'
# {"allowed_merge_methods":["squash"],
#  "dismiss_stale_reviews_on_push":true,
#  "dismissal_restriction":{"allowed_actors":[],"enabled":false},
#  "require_code_owner_review":false,
#  "require_extra_approval_for_unattributed_changes":true,
#  "require_last_push_approval":false,"required_approving_review_count":1,
#  "required_review_thread_resolution":true,"required_reviewers":[]}
```

`tag-integrity` matches no ref: `CONTRIBUTING.md`'s *A version, and no
release* is where nothing being tagged is measured. The rule stands ahead
of the first such tag rather than being created alongside one, so a `v*`
pushed here meets it.

## Merge methods

```shell
gh api repos/btclib-org/claude-process \
  --jq '{squash: .allow_squash_merge, merge: .allow_merge_commit,
         rebase: .allow_rebase_merge, auto: .allow_auto_merge,
         delete_on_merge: .delete_branch_on_merge,
         title: .squash_merge_commit_title,
         message: .squash_merge_commit_message}'
# {"auto":true,"delete_on_merge":true,"merge":false,
#  "message":"COMMIT_MESSAGES","rebase":false,"squash":true,
#  "title":"COMMIT_OR_PR_TITLE"}
```

Squash is the only method GitHub can be asked for. `COMMIT_OR_PR_TITLE`
with `COMMIT_MESSAGES` is the pair the standard asks for, and which of
the two titles lands is its *Merge method* rule. `allow_auto_merge` is
`true`, which is what presses the one enabled button once the checks and
the review are in, and `delete_branch_on_merge` removes the branch of a
merged pull request.

## Features

```shell
gh api repos/btclib-org/claude-process \
  --jq '{wiki: .has_wiki, projects: .has_projects, issues: .has_issues}'
# {"issues":true,"projects":false,"wiki":false}
```

Issues are on: this repository's own tracker is where a defect in the
process text is filed. The wiki and the projects board are off. The
standard states no rule about either, so no answer to them is a decision
here.

## Pages, which this repository does not use

**There is no site here, and the endpoint that would describe one
answers with its absence**, so what is read is the status line alone:

```shell
gh api -i repos/btclib-org/claude-process/pages 2>/dev/null | head -1
# HTTP/2.0 404 Not Found
```

The same call against `btclib-org/btclib-org.github.io`, the tree that
serves `btclib.org`, answers `HTTP/2.0 200 OK`, which is what makes the
`404` an absence rather than a permission.

## Topics

```shell
gh api repos/btclib-org/claude-process --jq '.topics'
# ["btclib","claude-code","development-process"]
```

The standard makes a package's `keywords` its topics; there is no package
here and so no keyword list to agree with, which makes the topics a
discoverability question rather than an alignment one. They live here and
nowhere else: a repository restored from a record that passed over them
has no topics.

## The repository description

```shell
gh api repos/btclib-org/claude-process --jq '{description, homepage}'
# {"description":"The btclib-org Claude Code process: the /btclib-org
#  command and the writer and reviewer agents","homepage":null}
```

`homepage` is null. The standard gives that field to a tree that
releases, as the URL its `pyproject.toml` carries; there is no package
here.

## Token permissions

```shell
gh api repos/btclib-org/claude-process/actions/permissions/workflow
# {"default_workflow_permissions":"read",
#  "can_approve_pull_request_reviews":false}
```

`read` is the floor every workflow here starts from. `claude-review.yml`
is the only one whose job elevates it — `pull-requests: write` to post a
comment and `id-token: write` for the OIDC token the action mints at
startup, on the `claude-review` job that calls `btclib-org/.github`'s
`reusable-claude-review.yml`. `lint.yml` and `links.yml` read the tree
and the network and write nothing back.

**What this call cannot say is whether that value is this repository's
own or the organization's**, there being no endpoint that answers.
Whoever moves the organization default reads this repository back
afterwards rather than assuming it moved.

```shell
gh api repos/btclib-org/claude-process/actions/permissions \
  --jq '{enabled, allowed_actions, sha_pinning_required}'
# {"allowed_actions":"all","enabled":true,"sha_pinning_required":true}
```

`sha_pinning_required` is set at the organization level: [section 11 of
the standard has the reasons for both fields][s11-tokens].

## Secret scanning and Dependabot

```shell
gh api repos/btclib-org/claude-process --jq '.security_and_analysis'
# {"dependabot_security_updates":{"status":"enabled"},
#  "secret_scanning":{"status":"enabled"},
#  "secret_scanning_non_provider_patterns":{"status":"disabled"},
#  "secret_scanning_push_protection":{"status":"enabled"},
#  "secret_scanning_validity_checks":{"status":"disabled"}}
```

**The first three are what the standard asks for, and they are on.** The
last two are plan-gated: they need paid Secret Protection, and the API
answers a `PATCH` for them with 200 while leaving them disabled, so that
answer records the plan and not a request. The `detect-secrets` hook in
`.pre-commit-config.yaml` runs before a commit; push protection refuses a
detected secret at the push, and secret scanning reads what has already
landed.

Dependabot alerts answer at their own endpoint, which has no body and
says so with its status — 204 for enabled, 404 for not — and security
updates, the pull requests that answer an alert, at another:

```shell
gh api -i repos/btclib-org/claude-process/vulnerability-alerts | head -1
# HTTP/2.0 204 No Content
gh api repos/btclib-org/claude-process/automated-security-fixes
# {"enabled":true,"paused":false}
```

Version bumps are the other half of what Dependabot does here, and they
are a file rather than a setting: `.github/dependabot.yml` declares
`github-actions`, which the standard gives every tree. Dependabot has a
`pre-commit` ecosystem too, and the maintainer decided to keep
pre-commit.ci for hook `rev:` bumps instead
(btclib-org/.github#1391).

## Private vulnerability reporting

```shell
gh api repos/btclib-org/claude-process/private-vulnerability-reporting
# {"enabled":true}
```

On, as the standard asks of every tier. The policy the Security tab shows
is `btclib-org/.github`'s, this repository carrying none of its own: the
standard gives `SECURITY.md` to the repositories that publish, and this
one publishes nothing.

## Secrets and environments

```shell
gh api repos/btclib-org/claude-process/actions/secrets \
  --jq '[.secrets[].name]'
# []
gh api orgs/btclib-org/actions/secrets/CLAUDE_CODE_OAUTH_TOKEN \
  --jq '.visibility'
# all
gh api orgs/btclib-org/dependabot/secrets/CLAUDE_CODE_OAUTH_TOKEN \
  --jq '.visibility'
# all
```

`claude-review.yml` is the only workflow here that reads a secret, and
this repository holds none of its own. **The two organization commands
are not one asked twice.** A `pull_request` run whose actor is
`dependabot[bot]` is handed the Dependabot secrets rather than the
Actions secrets, so a token registered only in the second resolves to the
empty string on exactly the pull requests `.github/dependabot.yml` opens.

```shell
gh api repos/btclib-org/claude-process/environments \
  --jq '[.environments[].name]'
# []
```

There is no `pypi` environment and no trusted publisher, nothing here
being published.

## Variables

**A switch this repository does not set.** The jobs `claude-review.yml`
calls are guarded by `vars.CLAUDE_REVIEW_ENABLED`, and neither variable
store holds it:

```shell
gh api repos/btclib-org/claude-process/actions/variables \
  --jq '.total_count'
# 0
gh api orgs/btclib-org/actions/variables --jq '.total_count'
# 0
```

The two organization secret stores the section above reads answer `all`,
which is what makes these zeros an absence rather than an endpoint that
answers empty for everyone. Section 11 reads an empty store as
`vars.CLAUDE_REVIEW_ENABLED`'s off state, an undefined `vars.X` being the
empty string. Both stores are read because a variable set here would take
precedence over one of the same name set on the organization.

## What is not configured, and why

- **No code scanning**, and GitHub's default setup off with it:

  ```shell
  gh api repos/btclib-org/claude-process/code-scanning/default-setup \
    --jq '{state, languages}'
  # {"languages":["actions"],"state":"not-configured"}
  ```

  Section 10 of the standard names the trees that run `codeql`, and this
  is not one of them. Default setup would scan `actions`, the workflows
  `actionlint` and `zizmor` read in the gate.
- **No `SECURITY.md`, `RELEASING.md` or `RELEASE_NOTES.md`.** Those are
  the rows section 2 of the standard marks for a repository that
  publishes.

## What this file passes over

The API answers for more than this repository decides, and what is left
out is left out by the scope above rather than by oversight.

**What no call sets.** `gh api repos/btclib-org/claude-process` answers
with the repository document, most of which is URLs, counts and derived
state. The fields of it that are settings are the ones the sections above
quote.

**A facility nobody reached for.** Self-hosted runners, webhooks, deploy
keys, autolinks and custom property values each answer empty here, and an
empty answer records no decision.

**A field the standard states no rule about.** `allow_forking`,
`allow_update_branch`, `has_discussions`, `has_downloads` and
`web_commit_signoff_required` are in the repository document and in none
of the `--jq` objects here.

[s11-tokens]: https://github.com/btclib-org/.github/blob/main/README.md#tokens-publishing-scanning
[s11-branch]: https://github.com/btclib-org/.github/blob/main/README.md#branch-protection-and-rulesets
