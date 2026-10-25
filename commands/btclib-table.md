---
description: btclib-table — one table of every btclib-org repository, measured now: open issues, open pull requests, CI and README badge status, last release, whether a new one is due
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
# each repository's row goes to "${d}/<repo>.row" and its counts to
# "${d}/<repo>.tot" ("<iss> <prs>", or "err")
d=$(mktemp -d)
trap 'rm -r "${d}"' EXIT
trap 'exit 1' INT TERM
w="${d}/row.sh"
cat > "${w}" <<'EOF_ROW'
# call: a command's output, or "error: <its stderr>" and exit 1 where it
# fails or prints anything on stderr
call() {
  e=$(mktemp "${d}/err.XXXXXX")
  o=$("$@" 2> "${e}")
  s=$?
  if [ "${s}" -ne 0 ] || [ -s "${e}" ]; then
    printf 'error: %s' "$(tr '\n' ' ' < "${e}")"
    rm -f "${e}"
    return 1
  fi
  rm -f "${e}"
  printf '%s' "${o}"
}
r=$1
iss=$(call gh issue list -R "btclib-org/${r}" --state open --limit 1000 \
  --json number --jq length)
prs=$(call gh pr list -R "btclib-org/${r}" --state open --limit 1000 \
  --json number --jq length)
case ${iss}${prs} in
  *[!0-9]*) echo err > "${d}/${r}.tot" ;;
  *) echo "${iss} ${prs}" > "${d}/${r}.tot" ;;
esac
badges="" readme=$(call gh api "repos/btclib-org/${r}/readme" \
  -H 'Accept: application/vnd.github.raw') || case ${readme} in
  *"(HTTP 404)"*) readme="" ;;
  *) badges="${readme}" readme="" ;;
esac
bp=$(printf '%s' "${readme}" |
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
ci="" wfs=$(call gh api \
  "repos/btclib-org/${r}/actions/workflows?per_page=100" \
  --jq '.workflows[] | select(.state == "active")
    | select(.path != ".github/workflows/release.yml") | .id') ||
  ci="${wfs}"
if [ -z "${ci}" ] && [ -n "${wfs}" ]; then
  ids=$(printf '%s' "${wfs}" | paste -sd, -)
  page=$(call gh api -X GET "repos/btclib-org/${r}/actions/runs" \
    -f branch=main -f status=completed -f per_page=100 \
    --jq "[${ids}] as \$ids | .total_count as \$t | .workflow_runs as \$runs
      | \$ids[] as \$w
      | [\$runs[] | select(.workflow_id == \$w)] as \$mine
      | [\$mine[:20][] | select(.head_repository.full_name
          == \"btclib-org/${r}\" and .conclusion != \"cancelled\")][0] as \$c
      | \"\(\$w)\t\" + if \$c != null then
          (if \$c.conclusion | IN(\"success\", \"skipped\") then \"\"
           else \"\(\$c.name)=\(\$c.conclusion)\" end)
        elif (\$mine | length) >= 20 or \$t <= (\$runs | length) then \"\"
        else \"?\" end") || page=""
  while read -r w c; do
    [ -n "${w}" ] || continue
    if [ "${c}" = "?" ] || [ -z "${page}" ]; then
      c=$(call gh api -X GET \
        "repos/btclib-org/${r}/actions/workflows/${w}/runs" \
        -f branch=main -f status=completed -f per_page=20 \
        --jq "[.workflow_runs[] | select(.head_repository.full_name
          == \"btclib-org/${r}\" and .conclusion != \"cancelled\")][0] // empty
          | select(.conclusion | IN(\"success\", \"skipped\") | not)
          | .name + \"=\" + .conclusion") || c="${w}=${c}"
    fi
    [ -z "${c}" ] || ci="${ci:+${ci},}${c}"
  done <<EOF_WFS
${page:-$wfs}
EOF_WFS
fi
[ -n "${badges}" ] || badges=$(printf '%s' "${readme}" |
  uv run --no-project --python 3.15 python -c '
import colorsys, re, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor


def check(url):
    req = urllib.request.Request(url, headers={"User-Agent": "btclib-table"})
    try:
        svg = urllib.request.urlopen(req, timeout=30).read().decode()
    except Exception as e:
        return f"{url}: {e}"
    title = (re.findall(r"<title>([^<]*)", svg) or [url])[0]
    if re.fullmatch(r"openssf best practices: (silver|gold)", title):
        return None
    hues = []
    hexes = r"(?:fill|stop-color)=.#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\W"
    for h in re.findall(hexes, svg):
        h = "".join(c * 2 for c in h) if len(h) == 3 else h
        rgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
        hue, sat, _ = colorsys.rgb_to_hsv(*rgb)
        if sat >= 0.5:
            hues.append(hue * 360)
    if not hues or not all(70 <= hue < 260 for hue in hues):
        return title
    return None


urls = re.findall(r"!\[[^]]*\]\(([^)\s]+)", sys.stdin.read())
urls = [u for u in urls if "/pypi/status/" not in u]
with ThreadPoolExecutor(8) as pool:
    bad = [b for b in pool.map(check, urls) if b]
print(" || ".join(bad))') || badges="error: the badge script failed"
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
  "| ci=${ci:-ok} | badges=${badges:-ok} | tag=${tag:-none} ${since}" \
  > "${d}/${r}.row"
EOF_ROW
export d
gh repo list btclib-org --no-archived --limit 200 \
    --json name --jq '.[].name' | sort > "${d}/repos"
xargs -n 1 -P 6 sh "${w}" < "${d}/repos"
ti=0 tp=0 part=""
while read -r r; do
  cat "${d}/${r}.row"
  i=err
  read -r i p < "${d}/${r}.tot"
  case ${i} in
    err) part=" (rows with an error left out)" ;;
    *) ti=$(( ti + i )) tp=$(( tp + p )) ;;
  esac
done < "${d}/repos"
echo "total | iss=${ti} | pr=${tp}${part}"
```

The last line gives the totals the table's headings carry. The badge
project is the first `bestpractices.dev/projects/` link of the README;
its `repo_url` names the repository, or its package where the two
differ.

`ci` names each active workflow whose latest completed run on `main`
concluded neither `success` nor `skipped`, `ok` where none did.
`release.yml` is left out: on `main` it runs only as a rehearsal, and a
release runs on its tag. Only a workflow's 20 latest completed runs on
`main` are read, so a run still in progress is not among them. A
`cancelled` run and a run from a fork's `main` are passed over for the
one before. A disabled workflow, and one with no run that counts among
those 20, count for nothing. One call reads the repository's 100 latest
completed runs on `main`; a workflow they do not settle gets a call of
its own, and where that call fails, every workflow does.

`badges` names each image of the README that does not render green or
blue, `ok` where none. Every `![…](…)` image counts as a badge. Its
colours are the SVG's `fill` and `stop-color` values with an HSV
saturation of 0.5 or more; the greys, white and black of the frame fall
below that. An image renders green or blue where it has such a colour
and each such colour has a hue from 70° (green) to 260° (blue). An image
that does not download, or is grey only, does not.

A `pypi/status` badge is not read: its colour is the development status,
yellow at beta and red at alpha. A bestpractices badge titled `openssf
best practices: silver` or `…: gold` counts as green: its colour is the
metal, grey `#c0c0c0` for silver.

The other calls behind `iss`, `pr` and `ci`, and the README fetch, go
through `call`: one that fails, or prints anything on stderr, puts
`error:` and its message in that value, or in `badges` for the README,
where a 404 means no README. A badge script that fails puts `error: the badge
script failed` in `badges`. A row whose `iss` or `pr` holds an error is
left out of the totals, and the last line says so.

The measure reads six repositories at once, and the images of one README
eight at a time. The rows print in repository order.

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

## The 🚀 column

Whether a release is due, judged from the commit subjects since the last
tag:

- `⏳`: a release pull request or tag is under way;
- `YES`: a user of the package would notice a change, and one pull
  request makes the release urgent;
- `yes`: the same, with no urgency (lowercase means not urgent);
- `no`: only tests, CI, docs, process files or the next cycle landed;
- `-`: the repository does not release.

## Show it

A box-drawn table inside a code block, at most 80 columns wide, so that it
reads in the terminal:

```text
┌───────────────┬─────┬────┬─────┬─────┬────┬────┬────────────┬─────┐
│ Repository    │ 233 │ 51 │ BL3 │ 🥇% │ CI │ 📛 │ Last       │ 🚀  │
│               │ ISS │ PR │ (%) │     │    │    │ release    │     │
├───────────────┼─────┼────┼─────┼─────┼────┼────┼────────────┼─────┤
│ base58-bech32 │   1 │  0 │   0 │   0 │ ✅ │ ❌ │ never      │ ⏳  │
│ bip39-slip39  │   3 │  0 │ 100 │  🥇 │ ❌ │ ✅ │ 2026.10.17 │ YES │
├───────────────┼─────┼────┼─────┼─────┼────┼────┼────────────┼─────┤
│ …             │     │    │     │     │    │    │            │     │
└───────────────┴─────┴────┴─────┴─────┴────┴────┴────────────┴─────┘
```

The columns are Repository, ISS, PR, BL3, 🥇%, CI, 📛, Last release and
🚀, in that order, each heading on two lines. The first line of ISS and
PR is the total on the measure's last line, which leaves out a row whose
ISS or PR count is an error. BL3 is the badge project's baseline
percentage. 🥇% is its gold percentage, `🥇` where that is 100. Both are
`-` where the repository has no badge project. CI and 📛 are `✅` where
the measure's `ci` and `badges` say `ok`, and `❌` otherwise. An ISS or
PR cell whose value is an error shows `err`.

Last release is the latest tag without its leading `v`, `never` where
there is none. A cell holds its value and nothing else.

Each column is as wide as its longest cell, plus one space on each side.
`✅`, `❌`, `⏳`, `🥇`, `📛` and `🚀` each take two columns of the
terminal, and the widths and the alignment count them so. Numbers are
right-aligned. A horizontal rule goes between two groups,
never between two rows of one group. Where the table would pass 80
columns, a cell too long goes on in a continuation line, its other cells
empty. No Markdown table.

After it, at most two lines: what a reader cannot see in the table, such
as the pull request that makes a `YES` urgent, or a repository whose
package name differs from its own (`.github`'s is
`btclib-alignment`).
