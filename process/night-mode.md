# Night mode

The orchestrator's, in either skill. A section named in italics with
no file is one of `btclib-common.md`'s.

**Night mode has no ceiling and no duration**: it lasts until the human
turns it off.

**At activation, ask only for the repository**, where the skill needs
one and the session has not settled it, and, for `/btclib-iss` with no
issue named, the issues. Where they leave before answering, the night
does not start.

**Turning it off** ends the night at once. The work in flight goes on
under the ordinary rules. The morning report is the next message, unless
it was given while the work waited. Its deferred items are then asked
one at a time (*When the human has to decide*).

**During the night no question is asked interactively.** Every point
where a skill stops for the human — a decision, a refused permission,
a dirty primary checkout that is not provably the session's, an
approval that is not obvious, a
session whose state is uncertain, a branch that takes a decision its
issue reserved — becomes an item of the morning report, and the work that
depends on it stops there. A decision that goes to the maintainer (*When
the human has to decide*) is a hold, not an item. A branch taking a
reserved decision is opened, not landed, and its cut-back is one of the
decision's alternatives.

- **Record each item as a hold**, its comment carrying, in prose, what
  the shape *When the human has to decide* gives; a missing label is not
  created at night.
  An item that belongs to no issue or pull request (a permission refused
  outside any issue's work, a dirty primary checkout not provably the
  session's), and any question about an outside contributor's pull
  request, which they read, go in the report only.
- **Never resolve a deferred item by default**, nor by taking your own
  recommendation. The recommendation goes in the report. The one
  exception is `/btclib-pr`'s *The sweep*, which at night works every
  pull request that is not a draft, as that section says.
- **Everything that does not depend on it goes on**: other issues, other
  pull requests, review rounds, collateral, the approvals and landings
  `/btclib-pr` calls obvious, and the landings `--land` instructs, given
  before the night or during it (`/btclib-pr`'s *Landing*).
- **When nothing left can advance without an answer, the work stops
  and waits**, still in night mode. Nothing is left running: no worker
  mid-turn, no background job. A slot left by a worker you stopped is
  stale, and `gate_take` reclaims it (`$PROCESS/scripts/gate-lock.sh`).
  Worktrees with uncommitted or unpushed work stay standing. The
  morning report may be given then.

**The morning report** is a message to the human. A copy in
`<scratchpad>/night-report-<date>.md` is a convenience, since the
scratchpad may not outlive the session. The record is that message and
the comments on the issues. It holds:

- what was opened, approved and landed, with links, and each landing's
  verification;
- what is open and ready, and what it waits on;
- the deferred items, each in the shape *When the human has to decide*
  gives, with the link where it is also recorded;
- the collateral filed, by number, each with its pull request, in review,
  or excepted with its reason;
- *Wrap-up*'s report, where the session ends with the night.
