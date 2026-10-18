---
description: btclib-table — one table of every btclib-org repository, measured now: open issues, open pull requests, last release, whether a new one is due
---

# The btclib-org table

Show the human one table of every repository of `btclib-org` that is not
archived, read from the API now: never from memory, and never from an
earlier run.

The command only reads. It writes nothing, comments nowhere and takes no
decision, so it needs no worktree and none of the roles of
`~/.claude/process/btclib-common.md`. What it writes after the table
follows that file's *Write plainly*.

## Measure

Run this, which only reads:

```shell
ti=0 tp=0
for r in $(gh repo list btclib-org --no-archived --limit 200 \
    --json name --jq '.[].name' | sort); do
  iss=$(gh issue list -R "btclib-org/${r}" --state open --limit 1000 \
    --json number --jq length)
  prs=$(gh pr list -R "btclib-org/${r}" --state open --limit 1000 \
    --json number --jq length)
  ti=$(( ti + iss )) tp=$(( tp + prs ))
  bp=$(gh api "repos/btclib-org/${r}/readme" \
      -H 'Accept: application/vnd.github.raw' 2>/dev/null |
    grep -oE 'bestpractices\.dev/projects/[0-9]+' | head -n 1 | sed 's|.*/||')
  pkg=$(gh api "repos/btclib-org/${r}/contents/pyproject.toml" \
      -H 'Accept: application/vnd.github.raw' 2>/dev/null |
    uv run --no-project --python 3.15 python -c '
import json, sys, tomllib, urllib.request
try:
    p = tomllib.loads(sys.stdin.read()).get("project", {})
except Exception:
    p = {}
name, pypi = p.get("name", "-"), "-"
if name != "-":
    url = f"https://pypi.org/pypi/{name}/json"
    try:
        pypi = json.load(urllib.request.urlopen(url))["info"]["version"]
    except Exception:
        pass
deps = ", ".join(p.get("dependencies", [])) or "-"
r, bp = sys.argv[1:]
bl3 = gold = "-"
if bp:
    url = f"https://www.bestpractices.dev/projects/{bp}.json"
    b = json.load(urllib.request.urlopen(url))
    url_seen = b["repo_url"]
    if url_seen.rstrip("/").split("/")[-1] not in (r, name):
        bl3 = gold = f"mismatch: {url_seen}"
    else:
        bl3 = b["badge_percentage_baseline_3"]
        gold = b["badge_percentage_2"]
print(f"{name} | pypi={pypi} | bl3={bl3} gold={gold} | deps: {deps}")' \
    "${r}" "${bp}")
  rel=no
  gh api "repos/btclib-org/${r}/contents/.github/workflows/release.yml" \
    > /dev/null 2>&1 && rel=yes
  tag=$(gh api "repos/btclib-org/${r}/tags?per_page=100" --jq '.[].name' \
    2>/dev/null | sort -V | tail -n 1)
  since=""
  [ -n "${tag}" ] && since=$(gh api \
    "repos/btclib-org/${r}/compare/${tag}...HEAD" --jq '
      .base_commit.commit.committer.date[:10] + " | since: "
      + ([.commits[].commit.message | split("\n")[0]] | join(" || "))' \
    2>/dev/null)
  echo "${r} | iss=${iss} | pr=${prs} | ${pkg} | release.yml=${rel}" \
    "| tag=${tag:-none} ${since}"
done
echo "total | iss=${ti} | pr=${tp}"
```

The last line gives the totals the table's headings carry. The badge
project is the first `bestpractices.dev/projects/` link of the README;
its `repo_url` names the repository, or its package where the two
differ.

A PyPI project of the same name with no tag of ours is someone else's:
say so in one line.

## Order

Top to bottom, in five groups, with no group heading (the human knows
them):

1. packages whose runtime `dependencies` are empty: the standard library
   only;
1. packages that depend on third-party packages only, none of the
   organization's;
1. packages that depend on other packages of the organization, each
   below every one it depends on;
1. repositories that release by tag only, not on PyPI;
1. repositories that do not release.

Within a group, alphabetical, unless the dependency order says otherwise.

A repository with a `release.yml` workflow sits in its dependency group
even before its first release, with `never`. One with a tag and no
`release.yml` is group 4. One with neither does not release, and is
group 5.

## The Release due? column

Judge it from the commit subjects since the last tag:

- `in progress`: a release pull request or tag is under way;
- `YES (#n)`: a user of the package would notice a change, and the
  release is due. `#n` is the one pull request that makes it urgent;
- `yes`: the same, with no urgency (lowercase means not urgent);
- `no`: only tests, CI, docs, process files or the next cycle landed;
- `-`: the repository does not release.

No value but `YES` carries a pull request number.

## Show it

A box-drawn table inside a code block, at most 80 columns wide, so that it
reads in the terminal:

```text
┌───────────────┬───────┬─────┬─────┬──────┬─────────────┬─────────────┐
│ Repository    │ Issue │ PR  │ BL3 │ Gold │ Last        │ Release     │
│               │ (X)   │ (Y) │ (%) │ (%)  │ release     │ due?        │
├───────────────┼───────┼─────┼─────┼──────┼─────────────┼─────────────┤
│ base58-bech32 │     1 │   0 │   0 │    0 │ never       │ in progress │
│ bip39-slip39  │     3 │   0 │ 100 │   87 │ v2026.10.17 │ YES (#283)  │
├───────────────┼───────┼─────┼─────┼──────┼─────────────┼─────────────┤
│ …             │       │     │     │      │             │             │
└───────────────┴───────┴─────┴─────┴──────┴─────────────┴─────────────┘
```

The columns are Repository, Issue, PR, BL3, Gold, Last release and
Release due?, in that order, each heading on two lines. The second line of
Issue and PR is the total over every row, `X` and `Y` above, from the
measure's last line. BL3 and Gold are the badge percentages, `-` where
the repository has no badge project.

Last release is the latest tag, `never` where there is none. A cell
holds its value and nothing else.

Each column is as wide as its longest cell, plus one space on each side.
Numbers are right-aligned. A horizontal rule goes between two groups,
never between two rows of one group. Where the table would pass 80
columns, a cell too long goes on in a continuation line, its other cells
empty. No Markdown table.

After it, at most two lines: what a reader cannot see in the table, such
as a repository whose package name differs from its own (`bip39-slip39`
publishes `btclib-mnemonics`).
