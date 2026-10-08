# Investigation: #4 — feat: add a fast-track lifecycle for low-risk papercuts

**Issue:** [#4](https://github.com/drmssst/Well-Architected-Reliability-Assessment/issues/4)
**Alias:** `0004-fast-track-lifecycle`
**Branch:** `investigate/issue-4-fast-track-lifecycle`
**Milestone:** `release/20260910`

## Phase A — Findings

### Problem and desired outcome

The repository's issue workflow is a single linear path: raise, investigate, plan,
implement, and release. Every change enters investigation, produces a four-phase
investigation document, passes a human approval gate, produces a four-phase plan with
six required content areas, passes another human approval gate, and only then reaches
implementation. That sequence preserves evidence and control, but applies the same
ceremony to an understood, low-risk XS correction as it does to larger or uncertain
work.

The desired outcome is a governed fast-track route for low-risk papercuts. It must use
objective eligibility rules, preserve a compact issue-level micro-plan and traceable
state transitions, apply approval and validation proportionate to the risk, retain
release controls, and return an item to the normal lifecycle if uncertainty or scope
emerges. After delivery, a separate papercut issue correcting `raise-issue`'s missing
`status:investigate` label will manually validate the route. The remainder of Phase A
establishes what is true today against that outcome so that the gap is clear and Phase
B decisions are grounded.

---

### A1. The lifecycle has one mandatory path with two document approval gates

`README.md` documents only `raise → investigate → plan → implement → release`, with
separate investigate, plan, and implement worktrees. Nine skill files under
`.github/skills/` implement that model: one raise skill, three stage skills, three
approval skills, and two backlog skills — migrated from the prior
`.github/prompts/<name>.prompt.md` convention with the same content; only the
frontmatter schema and file location changed. Together they occupy approximately
67 KB of workflow instructions.

The investigation skill requires four separately reviewed phases before it commits
an investigation document and adds `awaiting-approval`. The
`approve-ready-for-plan` skill then requires `status:investigating`,
`awaiting-approval`, and a substantive four-phase document before moving the issue to
`status:plan`. Planning repeats the staged process for scope, affected files and
version impact, tests, acceptance criteria, definition of done, and sizing. The
`approve-ready-for-implement` skill requires those plan sections before assigning
`status:implement`.

**Gap against desired outcome:** no current skill branches around investigation or
the full planning workflow for an eligible papercut. The minimum change must define a
second governed entry and transition path while leaving the existing full path
available for ineligible or escalated work.

### A2. Implementation and release consume full-lifecycle artifacts and states

`implement-issue/SKILL.md` accepts only an issue carrying `status:implement`. Before
implementation it locates a `*-plan.md` document on `docs/main` and extracts its
Affected Documents table, Testing Requirements, Acceptance Criteria, and version
classification. During implementation it uses those sections to group edits, require
lint and review pauses, run targeted and full tests, update the changelog and plan,
record sizing actuals, open a pull request to `release/*`, and finally add
`awaiting-approval`.

`approve-ready-for-release/SKILL.md` then requires `status:implementing`,
`awaiting-approval`, and an open pull request targeting `release/*`. It rejects
investigation and plan documents in the pull request, simulates the merge, runs the
full Pester suite, asks before merging, changes the issue to `status:release`, closes
it, and updates the project board. These controls do not depend on investigation
content directly, but the implementation skill cannot currently operate without the
full plan artifact produced earlier.

**Gap against desired outcome:** the release controls already enforce a pull request,
tests, an approval, and traceable closure, but implementation has no contract for a
compact issue-level micro-plan. At minimum, the implementation entry contract must be
able to consume the fast-track artifact and state without weakening whichever release
controls remain mandatory.

### A3. Fast-track eligibility and state are not represented

`config/settings.json` maps nine project status options: `investigate`,
`investigating`, `plan`, `planning`, `implement`, `implementing`, `release`, `shipped`,
and `done`. It also maps the five size values XS through XL. There is no fast-track
status or other fast-track configuration, and the README lifecycle table has no such
route.

The size field does not establish eligibility at issue creation. The first automated
size update occurs in `approve-ready-for-plan`, which parses the estimate from the
completed investigation document; `approve-ready-for-implement` parses it again from
the completed plan. The issue body captures a problem statement and why investigation
is needed, while `raise-issue/SKILL.md` asks for type, urgency, and importance. None
of those artifacts captures risk, confidence, scope limits, compatibility impact, or
other objective papercut criteria.

**Gap against desired outcome:** neither GitHub state nor repository content can
identify or validate a fast-track candidate before the normal investigation cost has
already been paid. The minimum change must define objective criteria, record their
evidence at the point of selection, and make the selected route visible enough for
later skills to enforce it.

### A4. No compact issue-level micro-plan exists

Investigation and plan artifacts currently live as separate Markdown files on the
orphan `docs/main` branch. The plan template requires an affected-documents table that
always includes `CHANGELOG.md`, an affected-source-files table, semantic version
classification, new or changed testing requirements, independently verifiable
acceptance criteria, a standard eight-item definition-of-done checklist, and a sizing
estimate with drivers and uncertainty triggers. The plan grows across four user-gated
phases and is committed only after a final explicit transition.

GitHub issues contain only the original problem and investigation rationale; the
workflow does not add a structured plan to the issue body or comments. No skill,
schema, or parser defines a reduced plan form, distinguishes required from optional
micro-plan fields, or links such a form to implementation evidence.

**Gap against desired outcome:** there is no compact planning artifact at issue level
and no downstream contract that could validate one. At minimum, a micro-plan format,
storage location, required evidence, and consumption rules must be established.

### A5. Existing helpers centralize IDs and worktree creation, not transitions

`tools/Get-GhProjectConstants.ps1` reads the project, status, size, and estimate IDs
from `config/settings.json`; lifecycle skills use it rather than embedding opaque
GitHub IDs. `tools/New-IssueWorktree.ps1` derives worktree and branch names from a
string `Stage`, creates the worktree, generates the standard three-folder VS Code
workspace, and installs Markdown lint dependencies. Its help lists raise,
investigate, plan, and implement as stages, while its parameter validation does not
restrict the supplied stage value.

Label and project transitions themselves are repeated as `gh issue edit` and
`gh project item-edit` command blocks in the skills. `Get-NextIssues.ps1` ranks work
using `config/issue-priority-weights.json`, whose stage table contains only the normal
lifecycle labels. It gives planning and ready-to-implement work higher stage scores
than investigation work and applies a WIP bonus specifically to
`status:investigate`; no scoring rule recognizes fast-track eligibility or progress.

**Gap against desired outcome:** reusable primitives exist for project IDs,
worktrees, linting, and tests, but there is no shared fast-track transition or backlog
representation. The minimum change depends on the Phase B state model: every new
state used by skills must also be represented consistently in live GitHub state,
repository configuration, documentation, and prioritization where applicable.

### A6. Validation is manual at the workflow layer, and a known raise defect is available

The repository currently contains one discovered `*.Tests.ps1` file under
`src/tests/`, and no test under that tree references the lifecycle skills,
`Get-GhProjectConstants.ps1`, `Get-NextIssues.ps1`, or
`New-IssueWorktree.ps1`. Skill correctness is therefore exercised through human
execution and review. The release gate does run the full Pester suite against product
changes, but that suite does not validate skill text, label transitions, project
field changes, or micro-plan parsing.

The separate manual-validation papercut named in issue #4 is observable today.
`raise-issue/SKILL.md` says that it creates an issue at `status:investigate`, reports
that status to the user, and sets the project item to the `investigate` option, but
its `gh issue create` command supplies only urgency, importance, and type labels. The
required `status:investigate` issue label is omitted, so a newly raised issue cannot
pass the investigation skill's prerequisite without correction.

**Gap against desired outcome:** there is no automated workflow-level test harness,
and the proposed manual validation must prove both the fast-track route and its escape
or completion behavior without confusing project status with issue labels. The
minimum validation scope must include observable label, board, artifact, approval,
test, and release outcomes for the separate papercut issue.

### A7. Files and external state implicated by the current gaps

| Surface | Current role or observed dependency |
| --- | --- |
| `.github/skills/raise-issue/SKILL.md` | Creates the issue and project item; currently omits the declared initial issue status label |
| `.github/skills/investigate-issue/SKILL.md` | Enforces the mandatory four-phase investigation and creates its document |
| `.github/skills/approve-ready-for-plan/SKILL.md` | Validates investigation, sets size, and advances to planning |
| `.github/skills/plan-issue/SKILL.md` | Enforces the full plan schema and staged reviews |
| `.github/skills/approve-ready-for-implement/SKILL.md` | Validates the full plan, sets size, and advances to implementation |
| `.github/skills/implement-issue/SKILL.md` | Requires and consumes the full plan; produces the release pull request |
| `.github/skills/approve-ready-for-release/SKILL.md` | Enforces pull-request, test, approval, merge, and closure controls |
| `.github/skills/groom-backlog/SKILL.md` | Refines issues while retaining `status:investigate` |
| `.github/skills/next-issues/SKILL.md` | Presents ranked work from `Get-NextIssues.ps1` |
| `config/settings.json` | Maps repository skills to live project status and size option IDs |
| `config/issue-priority-weights.json` | Scores only normal lifecycle states |
| `tools/Get-GhProjectConstants.ps1` | Supplies centralized project constants to skills and tools |
| `tools/Get-NextIssues.ps1` | Calculates backlog order from labels and configured stage weights |
| `tools/New-IssueWorktree.ps1` | Creates per-stage worktrees and issue workspaces from a stage string |
| `README.md` | Documents only the five-stage normal lifecycle |
| Live GitHub labels and Project 1 | Hold the issue state and project status that skills transition |

This table is an observed dependency inventory, not a decision that every listed file
must change. The investigation and plan document conventions on `docs/main`, the
Markdown and PowerShell lint wrappers, the Pester wrapper, release branches, and pull
requests are existing scaffolding available to either route.

**Gap against desired outcome:** the desired behavior crosses skill text, checked-in
configuration and documentation, and live GitHub metadata; changing only one surface
would leave the lifecycle inconsistent. Phase B must determine the smallest coherent
subset after it defines the entry, state, artifact, approval, and escape contracts.

### A8. Open questions for Phase B

1. Which objective conditions must all be true for an issue to enter fast-track, and
   what evidence records each condition before work begins?
2. At what point can fast-track be selected: while raising an issue, while grooming
   an existing `status:investigate` issue, or through a separate transition?
3. How should fast-track appear in issue labels and the project status field, and how
   should `Get-NextIssues.ps1` rank an item while it is on that route?
4. Where should the compact issue-level micro-plan live, which fields are mandatory,
   and how should implementation consume and preserve it as audit evidence?
5. Which existing human approval, pull-request, test, changelog, versioning, and
   release gates remain mandatory, and where is the proportionate fast-track approval
   placed?
6. Which discoveries require the escape hatch, and to which normal state does the
   issue move when each trigger occurs?
7. When an item escapes, which fast-track evidence is retained, what normal documents
   must still be produced, and is its size or priority recalculated?
8. Should fast-track reuse an existing implementation worktree and skill or have a
   distinct worktree or skill contract?
9. What automated checks, if any, are needed for eligibility, micro-plan structure,
   and transitions in addition to the separate end-to-end papercut validation?
10. What exact success and rollback observations must the follow-up
    `raise-issue`-label papercut record to validate the completed capability?

## Phase B — Approach decisions

### B1. Eligibility checklist (resolves A8.1)

**Decision:** An issue is fast-track-eligible only if all of the following are true.
Each condition is answered explicitly, with evidence, by whoever is reading the code
at that point: the investigator at scan 1 or in the Phase D assessment (B2), and again
in the compact plan's fast-track check (B4). The approver verifies the recorded
evidence (B5). The criteria live in one shared file that every consuming skill points
to (C6):

- Self-assessed size is `XS`.
- Type label is `type:fix`, `type:chore`, or `type:docs` (`type:feat` is never
  eligible — new capability implies unknowns by definition).
- The affected files are named up front, with no numeric cap — a papercut may
  legitimately touch many files (e.g., a mechanical rename or a repeated
  label/string correction). Eligibility instead requires every named file, other
  than the standard `CHANGELOG.md` entry that every change carries, to receive the
  same uniform, mechanical class of edit (e.g., an identical substitution or an
  identical single-line value change), not a mix of unrelated or
  judgment-dependent edits.
- No public surface changes: no exported function signature under
  `src/modules/**/*.psm1` and no `config/*.json` schema changes.
- Fully reversible by a single revert commit — no data migration, no irreversible
  external side effect (e.g., live GitHub label/project taxonomy changes).
- No new external dependency (no `package.json`/module import additions).

**Rationale:** naming every affected file and classifying the edit presupposes the code
survey that investigation or planning performs, so asking the requester to declare them
at raise time would be a guess. Answering where the code is actually read — and
repeating the check in the compact plan, the first full read for an item that skipped
investigation — makes the evidence real rather than self-declared. A named file list
keeps the automated cross-check in B9 meaningful regardless of count, while gating on
edit uniformity — rather than file count — targets what actually drives risk: a wide
but uniform mechanical fix is not riskier for being spread across many files, and a
single file can still carry high risk if its edit is complex. The conditions are the
initial calibration: whether they admit enough papercuts without admitting
non-papercuts is not yet known, so the route is measured from first use and tuned from
evidence (B9, C11).

**Alternatives considered:** answers declared by the requester at raise time —
rejected, because the affected files and edit class are not knowable before the code
is read; using `XS` alone as the sole gate — rejected, because today no size estimate
exists before investigation (A3), so an unsupported XS guess without the other proxies
would be too easy to satisfy; a hard numeric file-count cap (e.g., at most 3 files) —
considered and rejected, file count alone is only a weak proxy for risk and produces
both false negatives (a wide but uniform mechanical fix) and false positives (a single
complex file); requiring maintainer pre-verification before the checklist can even be
submitted — rejected as an extra manual gate that duplicates the approvals kept in B5.

### B2. Entry points (resolves A8.2)

**Decision:** No new entry skills. Fast-track is decided at two points inside skills
that already exist, and both end the same way: the issue carries `lifecycle:fast-track`
and sits at `status:plan`.

- **Scan 1 — flagged at the start.** A new first step in `investigate-issue/SKILL.md`,
  ahead of Step 0 so that the investigate worktree is never created for a flagged
  item, reads the issue body and comments and evaluates the B1 checklist. It presents
  the result and asks the person running the skill to confirm. On confirmation it
  posts the checklist answers as a structured issue comment, adds
  `lifecycle:fast-track`, moves the issue from `status:investigate` to `status:plan`
  (label and board option), and stops: no investigation document is written. An item
  that does not qualify, or that carries the escape marker (B6, C9), continues into
  Step 0 as today. Either way the outcome and any failing conditions are recorded as
  an issue comment (B9).
- **Post-investigation decision.** When the Phase D findings suggest an item
  qualifies, the investigator records a fast-track assessment (the B1 answers with
  evidence) as a Phase D entry. At `approve-ready-for-plan/SKILL.md`, beside the
  existing quality confirmation, the approver decides whether the item advances as
  fast-track. If so, `lifecycle:fast-track` is added in the same transition that moves
  the issue from `status:investigating` to `status:plan`; nothing else about that
  transition changes. Either way the decision and any failing conditions are recorded
  as an issue comment (B9).

**Rationale:** both points sit where the code is read (the start of the investigation
prompt, or the investigation's own context survey), so the checklist is answered with
evidence rather than by the requester (B1), and the decision runs in both directions:
an item perceived as fast-track at the start can still be unmasked at planning (B4),
and an item perceived as normal can be revealed as fast-track by its investigation.
Reusing existing skills also removes the need for two new entry skills.

**Alternatives considered:** a raise-time entry skill plus a grooming-time conversion
skill — rejected, because they ask the requester to declare affected files before
anyone has surveyed the code and they duplicate the checklist across two new files;
deciding only at `approve-ready-for-plan` — rejected, because it leaves the full
investigation cost in place for obvious papercuts.

### B3. Labels, project board, and backlog ranking (resolves A8.3)

**Decision:** Add one new repository label, `lifecycle:fast-track`, applied as an
orthogonal marker alongside existing `status:*` labels rather than replacing them —
the same layering pattern `awaiting-approval` already uses (A1, A7). No new GH
Project status field option is created, and the state machine is unchanged: a
flagged item moves `status:investigate` → `status:plan` (scan 1) or
`status:investigating` → `status:plan` (post-investigation decision) carrying the
label, then follows the normal path with the existing board options —
`status:planning` with `awaiting-approval`, `status:implement`, `status:implementing`,
`status:release`. Ranking uses the existing stage weights. A `lifecycle:fast-track`
bonus in `config/issue-priority-weights.json` is optional and deferred to planning
(D2): `Get-NextIssues.ps1` reads only the urgency, importance and stage maps, the
dependency keys and two hard-coded WIP rules, so a new key would be ignored and
adopting a bonus requires a script change.

**Rationale:** issue #1's own investigation (finding A3 in
[0001-port-issue-lifecycle-tooling-investigation.md](0001-port-issue-lifecycle-tooling-investigation.md))
already found the live GH Project status field is managed outside repo version
control and flagged the `releasing`/`superseded` gap this creates; adding new
fast-track-specific status options would repeat that same unreviewable, external,
un-rollback-able dependency. A label plus reuse of existing options keeps the entire
change inside version control, and an unchanged state machine means every existing
skill's `status:*` precondition keeps working.

**Alternatives considered:** dedicated new project status options (e.g.
`fast-track`, `fast-track-implementing`) — rejected for the external-dependency
reason above; a `status:fast-track` label replacing `status:*` entirely — rejected,
it would require a parallel state machine and break every existing skill's
`status:investigate`-style precondition checks; parking the issue at `plan` and moving
it directly to `implementing` — rejected, because `implement-issue` starts only for
`status:implement` and its Step 2 switches from that label, so the jump would be
refused unless the skill's prerequisite and label switch were also changed.

### B4. Micro-plan location and structure (resolves A8.4)

**Decision:** The micro-plan the issue calls for is a compact plan document.
`plan-issue/SKILL.md` writes it at the normal plan path on `docs/main`
(`<N-padded>-<slug>-plan.md`) when the issue carries `lifecycle:fast-track`. It keeps
the same required headings and parseable fields as a full plan — affected documents
(always including `CHANGELOG.md`), affected source files, version impact, testing
requirements, acceptance criteria, the standard definition-of-done items, and the
sizing estimate with its `**Estimate:**` line — because `approve-ready-for-implement`
and `implement-issue` read and update them. Version impact is `patch` or `minor`;
`major` is already excluded by B1's no-public-surface-change rule. The content is
terse, and the document is written in one pass with one review gate instead of five.
It adds a short fast-track check section that re-answers the B1 checklist with
plan-level evidence; if any answer fails or the estimate is not `XS`, `plan-issue`
stops and the item escapes (B6). Input: when an investigation document exists the plan
is drafted from it; otherwise it is drafted from the issue body and comments,
including the scan 1 checklist comment. Downstream consumption of the plan is
unchanged, and implementation results are recorded in it as they are today.

**Rationale:** writing the plan is the first full read of the affected code for an item
that skipped investigation, so it gives at least one real opportunity to discover that a
perceived fast-track is not one. Keeping the plan's structure means every downstream
contract works as it does today: the `approve-ready-for-implement` section checks and
size parse, and the `implement-issue` plan read, acceptance-criteria and
definition-of-done updates, sizing reflection and pre-PR definition-of-done check. The
cost is a `docs/main` commit per papercut, accepted in exchange for that opportunity.

**Alternatives considered:** a single structured issue comment — rejected, because it
gives no planning-time verification and would need fast-track branches in
`approve-ready-for-implement` and in `implement-issue` Steps 1, 5, 8 and 9a, all of
which read or write the plan document; a shorter document with a different structure
— rejected, because it would break those parsers; editing the issue body — rejected,
it destroys or bloats the original problem statement rather than appending clean
evidence.

### B5. Mandatory gates and approval placement (resolves A8.5)

**Decision:** All release-side controls stay mandatory and unchanged:
`approve-ready-for-release`'s release-branch check, the doc-content gate (it still
passes, because the compact plan lives on `docs/main` and not in the pull request), the
pre-merge full Pester run, explicit human merge confirmation, and the post-merge
label/board/closure transition. Changelog and version-classification requirements are
retained unchanged from the normal Definition of Done. No new approval gate or skill is
added; the two existing approvals apply under one rule — one approval per artifact. An
item flagged at the start produces one artifact before implementation (the compact
plan), so `approve-ready-for-implement` is its only pre-implementation approval. An item
revealed by investigation produces two (the investigation, then the compact plan) and
keeps both approvals, the first of which carries the fast-track decision (B2). In both
cases `approve-ready-for-implement` also verifies the plan's fast-track check and
accepts the compact form.

**Rationale:** the issue's problem statement explicitly requires preserving
"traceability, validation, and release controls," and release-side gates are where
release-quality validation actually happens (tests, PR review, merge control) at low
relative cost. The ceremony being reduced is the investigation and planning overhead:
the investigation approval disappears for an item that never had an investigation, and
the documents shrink — not the gate count — for an item that did. Because
`approve-ready-for-implement` already requires exactly `status:planning` plus
`awaiting-approval` and sets `status:implement`, the milestone, the board option and the
size, it serves as the fast-track approval without duplicating anything.

**Alternatives considered:** 0 pre-implementation gates — rejected, the issue asks for
proportionate rather than absent approval; a new dedicated fast-track approval skill —
rejected, it would duplicate `approve-ready-for-implement`; a separate approval of the
flag itself at scan 1 — rejected, because the plan approval verifies the same
checklist evidence.

### B6. Escape hatch triggers and target state (resolves A8.6)

**Decision:** Both automated and human-judgment triggers apply. Automated: at planning,
`plan-issue` stops and escapes the item if any answer in the fast-track check fails or
the plan's sizing estimate is not `XS`; at implementation, `implement-issue` stops and
does not open a PR if the diff touches files beyond the plan's affected documents and
affected source files, any test (existing or new) fails, or the diff changes the public
surface (an exported `src/modules/**/*.psm1` function signature, or any
`config/*.json` schema) — the same objective conditions used for entry in B1. A
declared file whose edit looks like an outlier is flagged for a human decision at the
existing review pause instead of blocking (B9). Human: the assignee or the approver may
escalate at any time on subjective grounds, no automated detection required. On any
trigger the issue returns to the earliest normal stage whose artifact is missing:
`status:investigate` when no investigation document exists (an item flagged at the
start), or `status:plan` when one does (an item revealed by investigation). In the
same transition `lifecycle:fast-track` is removed, and an item returning to
`status:investigate` also receives a marker that stops scan 1 from flagging it again
(C9), and the escape posts a comment stating the trigger (B9). The compact plan, if
committed, stays on `docs/main` as prior art, renamed so a full plan can use the
normal filename.

**Rationale:** reusing the B1 checklist as the automated-threshold source means
eligibility and escape share one rule set instead of two to maintain; human override
covers risk categories no static check can see. Returning to the earliest stage whose
artifact is missing re-enters the normal lifecycle exactly where evidence is lacking:
an item that skipped investigation receives the investigation it skipped, and an item
with an approved investigation does not repeat it.

**Alternatives considered:** always returning to `status:investigate` — rejected,
because it discards an approved investigation for an item revealed by investigation;
always returning to `status:plan` — rejected, because it lets an item that skipped
investigation and then proved larger or riskier than assumed bypass the phase that
exists to de-risk exactly this situation; automated-only or human-only — both
rejected in favor of the explicit "Both" choice.

### B7. Escaped-item evidence retention and re-estimation (resolves A8.7)

**Decision:** Nothing is deleted on escalation. The scan 1 checklist comment and the
issue's other comments remain permanently on the issue, and the compact plan, if
committed, stays on `docs/main` as prior art (B6). `investigate-issue/SKILL.md`'s
context-survey step and `plan-issue/SKILL.md`'s context survey read them as prior art
before the next document is written, so the abandoned fast-track attempt shortens
rather than wastes the resulting work. The normal documents are still required for
whatever was skipped: a full investigation document when none exists, and always a full
plan document — no phase is grandfathered in from the fast-track attempt. Size and
priority are recalculated from scratch, via the normal investigation Phase D estimate
when the investigation is redone and via the full plan's sizing estimate otherwise; the
original fast-track `XS` self-assessment is not carried forward.

**Rationale:** preserves full traceability even in the failure path and turns the
fast-track work into a head start instead of a sunk cost; not carrying the size
forward avoids compounding one wrong estimate (the original `XS` guess) into a
second one, since the escalation itself is evidence the first estimate was wrong.

**Alternatives considered:** deleting or hiding the fast-track comments post-
escalation — rejected, conflicts directly with the traceability requirement;
carrying the `XS` estimate forward — rejected per the compounding-error rationale
above.

### B8. Implementation worktree and skill reuse (resolves A8.8)

**Decision:** Reuse `implement-issue/SKILL.md` and
`New-IssueWorktree.ps1 -Stage implement` unchanged at the tooling level. The compact plan
is a normal plan document on `docs/main` (B4) and an approved item reaches the skill at
`status:implement` (B3), so the prerequisite check, the Step 1 plan read, the Step 2
label switch and the plan updates in Steps 5, 8 and 9a work as they do today. The only
addition is a guard for issues carrying `lifecycle:fast-track`, run before the pull
request is opened: it compares the diff against the plan's affected documents and
source files, checks its content for public-surface changes (B6, B9), and carries out
the escape transition when a trigger fires. Its exact placement within Steps 7 to 9 is
a planning detail. No new worktree stage, skill file, or branch-naming convention is
introduced for implementation.

**Rationale:** A5 already found `New-IssueWorktree.ps1` accepts an arbitrary `Stage`
string with no validation, and every downstream implementation step is identical
regardless of how the plan was produced; forking a second implementation skill
would duplicate roughly 14 KB of maintained logic (A1) for a difference that is only
the guard.

**Alternatives considered:** a distinct `implement-fast-track-issue/SKILL.md` —
rejected, duplicates Steps 2–7 verbatim for no behavioral difference beyond the guard,
doubling future maintenance for identical logic; a Step 1 branch that reads the plan
from an issue comment — rejected with B4, because Steps 5, 8 and 9a also read or write
the plan document.

### B9. Automated validation scope (resolves A8.9)

**Decision:** No new Pester test suite is added for the lifecycle skills as part of
this issue. The automated cross-check selected for B1/B6 is implemented as inline
PowerShell validation inside the `implement-issue` fast-track guard (B8): comparing
`git diff --name-only`'s file list against the compact plan's affected documents and
affected source files; flagging, for human decision at the existing per-group review
pause rather than auto-blocking, any declared file other than the `CHANGELOG.md` entry
whose hunk size or shape is an outlier relative to the others, since uniformity is not
fully machine-decidable; checking the diff's content, not merely its paths, for B6
public-surface changes — a changed `param` block, function declaration or export in a
`src/modules/**/*.psm1` file, or an added, removed or renamed key in a `config/*.json`
file, with the exact rules left to planning — not a separate test file, and not new
CI. Skill-level correctness continues to be validated the same
way every other lifecycle skill is today (A6: human execution and review), plus the
specific manual papercut named in the issue.

**Calibration:** the B1 conditions are an initial calibration, not a settled threshold
(C11). No test suite or CI is added to tune them; the signals come from records that the
lifecycle keeps or that this issue adds. Too lenient: a flagged item escapes (the
`lifecycle:fast-track` label is removed, which the issue timeline preserves with its
timestamp, and the escape comment states the trigger), or its recorded size later
moves up from `XS`. Too strict: an item that was not flagged later reaches `XS` in its
investigation estimate, plan estimate or reflection verdict, which is the size history
moving down to `XS`. The issue timeline records label and board-status changes but has
no event for the Size field, so the estimates in the investigation, the plan and its
reflection are the size history. Every scan records its outcome, flagged or not, with
the failing conditions, so the most frequent rejection reason is visible. A review
after the first ten scans, or at the end of the release if that comes first, decides
whether B1 is tightened or loosened (D2 items 9 and 10).

**Rationale:** A6 found zero existing test coverage for any of the nine lifecycle
skills or three helper scripts; building a first-of-its-kind skill-testing harness
is a separately sized effort the issue's own text does not request, and adding it
here would reintroduce the disproportionate-ceremony problem this issue exists to
fix, just relocated into its own delivery. Calibration is measured instead of argued
in advance because the right strictness depends on the issue mix to come, and only
three issues exist to calibrate against (C11).

**Alternatives considered:** a new Pester suite asserting skill structure or
simulating label transitions — rejected as scope creep beyond what issue #4 asks
for; skipping the automated cross-check entirely — rejected in favor of the explicit
"recorded evidence + automated cross-check" choice.

### B10. Follow-up papercut validation evidence (resolves A8.10)

**Decision:** The follow-up papercut (fixing `raise-issue/SKILL.md`'s missing
`status:investigate` label, per A6) must record: (1) a before/after diff of the
`gh issue create` command showing the added `--label` value; (2) a live test run
creating a throwaway issue and confirming via `gh issue view --json labels` that
`status:investigate` is present without manual correction; (3) confirmation that
`investigate-issue/SKILL.md`'s prerequisite check now passes on the first attempt
for a freshly raised issue; (4) a rollback note — this is a single-line skill-text
change with no schema or state migration, so rollback is a plain `git revert` of the
one commit, verified by re-running step (2) against the pre-revert skill text to
confirm the defect reproduces; and (5) route evidence, because the papercut itself
meets the B1 checklist (`type:fix`, `XS`, a single-line edit, no public surface
change): the scan 1 checklist comment and the `lifecycle:fast-track` label on
an issue at `status:plan` with no investigation document, the compact plan with its
fast-track check, the single `approve-ready-for-implement` approval, the pull request
with its test results, and the closing label, board and issue-state transitions.

**Rationale:** derived directly from the exact defect found in A6; framed as
reproducible before/after evidence so the validation itself models the same
objective-evidence standard B1 establishes for eligibility. Evidence (5) covers the
observable label, board, artifact, approval, test and release outcomes that A6 sets as
the minimum validation scope, at no extra cost because the papercut is itself a
fast-track item.

**Alternatives considered:** none — this question has one well-evidenced answer once
A6's finding is treated as the target defect.

## Phase C — Risks and prerequisites

### C1. The skills migration must reach the release branch before implementation (satisfied)

**Risk:** the skills this issue modifies (B2, B4, B5, B8) live under
`.github/skills/<name>/SKILL.md` — the convention that replaced
`.github/prompts/<name>.prompt.md` (A1). If that migration were absent from the branch
the implement worktree is created from, the target paths would not exist.

**Mechanism:** `tools/New-IssueWorktree.ps1 -Stage implement` creates the
implementation worktree from the release branch, not from this investigation branch.

**Mitigation:** satisfied — commit `7d4cbbf` (`chore: migrate lifecycle prompts to
.github/skills/<name>/SKILL.md convention`) is on `release/20260910` and
`origin/release/20260910`, verified on 2026-10-07. Planning should still re-verify that
`.github/skills/` exists on whichever branch the implement worktree is created from,
rather than assuming it.

### C2. The `lifecycle:fast-track` label does not exist in the repository yet

**Risk:** B3 introduces a new repository label, `lifecycle:fast-track`, but A5 and A7
found that every existing lifecycle skill only adds or removes labels that already
exist on the repository (`gh issue edit --add-label`) — none of the nine skills
create new labels.

**Mechanism:** `gh issue edit --add-label` fails if the named label has not already
been created on the repository (`gh label create`). The first item flagged at scan 1 or
advanced by the post-investigation decision would fail at that step if the label was
never created ahead of time.

**Mitigation:** implementation must include a one-time `gh label create
"lifecycle:fast-track" --color <c> --description <d>` step (or manual confirmation
that it already exists) before `investigate-issue` or `approve-ready-for-plan` applies
the label for the first time. If the escape marker is a label (D2 item 3), it needs the
same step.

### C3. The compact plan has no defined profile yet

**Risk:** B4 requires the compact plan to keep the headings and parseable fields that
the downstream skills read and to add a fast-track check, but nothing yet defines which
parts may be terse, what the check contains, or how one review gate replaces five. A4
already found "no prompt, schema, or parser defines a reduced plan form" anywhere in the
repository today.

**Mechanism:** the downstream consumers parse fixed structure.
`approve-ready-for-implement` checks the sections and reads the `**Estimate:**` line;
`implement-issue` reads the affected documents, testing requirements, acceptance
criteria and version impact, then updates the acceptance-criteria and
definition-of-done checkboxes and appends to the sizing section. A compact plan that
drops or renames any of them would fail silently — for example, an absent estimate only
warns and skips the size update.

**Mitigation:** planning defines the compact profile (D2 item 1): the required headings
and fields kept verbatim, what may be terse, the fast-track check section, and the
single review gate. The profile is handed to `plan-issue` (to produce it) and to
`approve-ready-for-implement` (to verify it).

### C4. Escalation may leave a stale `lifecycle:fast-track` label behind

**Risk:** B6 returns an escaped item to an earlier stage; B7 preserves all fast-track
evidence "permanently on the issue." Neither explicitly addresses whether the
`lifecycle:fast-track` label itself is removed on escalation.

**Mechanism:** `plan-issue` selects compact mode from the label being present, not from
the item's history. If the label survives escalation to `status:plan`, the next
`/plan-issue` run would draft a compact plan for an item that has already failed the
fast-track check. If a ranking bonus is adopted (D2 item 7), `Get-NextIssues.ps1` would
also keep applying it to an item that has proven itself ineligible.

**Mitigation:** B6 removes `lifecycle:fast-track` in the same transition that returns
the issue to the earlier stage. The evidence (comments, and the compact plan renamed on
`docs/main`) stays; only the routing label is dropped.

### C5. No automated test coverage for the modified skills (considered and accepted)

**Risk:** B9 adds no Pester suite for the five modified skills or the new
`implement-issue` guard.

**Mechanism:** A6 already found zero existing test coverage for any of the nine
current lifecycle skills or their three helper scripts — this issue does not change
that baseline, it extends it to the new guard logic.

**Mitigation:** none beyond what B9 already states — this is a deliberate,
proportionate choice consistent with existing practice, not a new gap introduced by
this issue. The B10 manual validation papercut is the acceptance check for the one
concrete defect currently known and, through its route evidence, for the fast-track
route itself.

### C6. The shared checklist has no existing cross-skill include mechanism

**Risk:** three skills now consume the B1 checklist — `investigate-issue` (scan 1 and
the Phase D assessment), `approve-ready-for-plan` (the decision) and `plan-issue` (the
fast-track check) — but Phase A found no include, import, or transclusion mechanism
between any of the nine existing skill files; each is a standalone, self-contained
document.

**Mechanism:** without such a mechanism, "sharing" the checklist in practice means
copying it into three skills, which is a documentation-consistency risk (the copies
could drift out of sync on a future edit) rather than a functional one.

**Mitigation:** keep the criteria in one file under `.github/` that each skill points
to instead of copying them. There is precedent: `implement-issue/SKILL.md` already
points at `.github/COMMIT_GUIDELINES.md`. The file's name and exact content are
deferred to planning (D2 item 5).

### C7. The GH Project status field remains externally managed (residual, inherited from issue #1)

**Risk:** issue #1's investigation already found the live GH Project status field is
managed outside repository version control.

**Mechanism:** B3 deliberately avoids adding new status options for exactly this
reason, using the existing options unchanged. The underlying external-management
exposure is therefore unchanged, not introduced by this issue.

**Mitigation:** none beyond what already exists for the rest of the lifecycle — this
issue carries no incremental risk here; B3's design choice is itself the mitigation.

### C8. Fast-track issues double-counting the `status:investigate` WIP bonus (false alarm)

**Risk considered:** A5 found `Get-NextIssues.ps1` "applies a WIP bonus specifically
to `status:investigate`"; if a `lifecycle:fast-track` bonus is adopted (D2 item 7),
could the two stack unexpectedly while a fast-track issue is in flight?

**Mechanism checked:** the label is added only in the same transition that moves an
item to `status:plan` (B2), so it never coexists with `status:investigate`; on
escalation it is removed in the same transition that returns the item there (B6, C4).
The WIP bonus is keyed specifically to `status:investigate`.

**Conclusion:** false alarm — the two bonuses cannot stack because their trigger
conditions (`status:investigate` vs. `lifecycle:fast-track`) are mutually exclusive by
construction. No mitigation needed.

### C9. Scan 1 can re-flag an item that has already escaped

**Risk:** B6 returns an item that was flagged at the start to `status:investigate`,
which is exactly where scan 1 runs.

**Mechanism:** a human-judgment escape, or one whose cause the objective checklist
cannot see, leaves the issue text unchanged, so scan 1 could evaluate the item as
qualifying again and send it back to `status:plan` with the label — a loop.

**Mitigation:** B6 adds a marker in the escape transition, and scan 1 skips any item
that carries it. The marker's form — a label, or an escape comment that the scan
checks for — is deferred to planning (D2 item 3).

### C10. Items flagged at the start skip the investigation approval (considered and accepted)

**Risk:** an item flagged by scan 1 reaches `status:plan` without a maintainer
reviewing an investigation, so a non-qualifying item could be flagged.

**Mechanism:** scan 1 is evaluated and confirmed by whoever runs `investigate-issue`;
no approval occurs until the compact plan reaches `approve-ready-for-implement`.

**Mitigation:** layered checks stand in for the skipped approval. The compact plan's
fast-track check is the first full read of the affected code and escapes the item if
any answer fails (B4, B6); the approver verifies the recorded evidence (B5); the
implementation guard checks the diff against the plan (B8, B9); and every release-side
control stays mandatory (B5). Accepted as proportionate to a risk class limited to `XS`,
reversible, non-public-surface changes.

### C11. The eligibility rules may be too strict or too lenient (accepted, measured)

**Risk:** the B1 checklist and its `XS` gate may reject real papercuts, so the route
saves little, or admit items that are not papercuts, so escapes waste effort. Neither
rate can be known before the route has been used.

**Mechanism:** a backtest of the repository history (565 non-merge commits since
2024-07, of which 115 carry a `fix`, `chore` or `docs` prefix) shows that size is not
the binding constraint: the median such change is 1 file and 6 lines, 65% touch one
file, and 76% are small by a rough proxy (at most 3 files and 30 lines, no
`config/*.json` or `package.json`). The conditions that cannot be backtested are the
qualitative ones: the uniform, mechanical edit, the public-surface check (44% of these
commits touch a module `.psm1`), and an `XS` with no definition in the repository's
Markdown. Only three GitHub issues exist, so there is no issue-level history to
calibrate against. The saving per eligible item is large — counting the STOP and
confirm prompts in the skills as gates, an item flagged at the start needs 4
pre-implementation gates instead of 13, and one flagged after investigation needs 9 —
but implementation and release gates are unchanged, so the overall gain depends on how
many items qualify.

**Mitigation:** accept the uncertainty and measure from first use (B9, D2 items 9 and
10), so that B1 is tuned later with evidence instead of argued now. Escapes, and a
recorded size that moves up from `XS`, signal too much leniency; unflagged items that
later reach `XS` signal too much strictness. The levers identified so far, to be
applied only if the measurements call for them, are: a lenient screen at scan 1 with
the strict check kept at planning, an objective `XS` definition (D2 item 11), and
reading uniformity as one logical change.

## Phase D — Ready-to-plan summary

### D1. Files in scope

| File | Change | Driven by |
| --- | --- | --- |
| `.github/skills/investigate-issue/SKILL.md` | Modified — scan 1 as a new first step ahead of Step 0, recording its outcome and failing conditions; fast-track assessment entry in Phase D | B2, B9 |
| `.github/skills/approve-ready-for-plan/SKILL.md` | Modified — fast-track decision, recorded either way, beside the quality confirmation; add the label in the transition to `status:plan` | B2, B3, B9 |
| `.github/skills/plan-issue/SKILL.md` | Modified — draft from the issue body and comments when no investigation document exists; compact mode, fast-track check and plan-time escape, with a comment stating the trigger, when the label is present | B4, B6, B9 |
| `.github/skills/approve-ready-for-implement/SKILL.md` | Modified — verify the fast-track check and accept the compact plan | B5 |
| `.github/skills/implement-issue/SKILL.md` | Modified — fast-track guard before the pull request is opened, with the escape transition and its comment; no Step 1 branch | B6, B8, B9 |
| `.github/<criteria-file>.md` | New — the shared B1 criteria that the skills above point to; name in D2 | B1, C6 |
| `config/issue-priority-weights.json` | Conditional — only if a ranking bonus is adopted (D2 item 7) | B3 |
| `tools/Get-NextIssues.ps1` | Conditional — required if a ranking bonus is adopted, because the script ignores unknown weight keys (D2 item 7) | B3, C4 |
| `README.md` | Modified — document the fast-track route alongside the existing lifecycle table | A1, A7 |
| `CHANGELOG.md` | Modified — standard release entry | Definition of Done |

The `lifecycle:fast-track` label itself is created once with `gh label create` (C2); it
is not a repository file.

### D2. Decisions deferred to planning

1. **Compact plan profile** (C3). The required headings and fields kept verbatim,
   what may be terse, the content of the fast-track check, and the single review
   gate. Options for the check: (a) a short fixed section placed first in the plan, so
   a failed answer stops `plan-issue` before the rest is written — recommended; (b) a
   checklist inside the definition of done.

2. **Scan evidence comment template** (B2). The literal structure of the issue comment
   that scan 1 posts — named headers for each B1 condition and the result — so that
   scan 1 produces it, `plan-issue` reads it, and the approver verifies it.

3. **Escape marker** (C9). Options: (a) a repository label — visible on the board and
   cheap to check, but a second label to create (C2); (b) an escape comment that
   scan 1 searches for — no new label, but it depends on comment parsing.
   Recommended: (a).

4. **Compact plan rename on escape** (B6). Options: (a) a distinct suffix on the
   filename, e.g. `<N-padded>-<slug>-fast-track-plan.md` — recommended; (b) keep the
   name and let the full plan replace it, relying on git history.

5. **Shared criteria file** (B1, C6). Name and location. Options: (a)
   `.github/FAST_TRACK_CRITERIA.md`, following `.github/COMMIT_GUIDELINES.md` —
   recommended; (b) a page under `docs/`.

6. **Label name, color and description** (C2). `lifecycle:fast-track` is used
   throughout this document; the bare `fast-track` works equally well, and nothing in
   the tooling depends on the choice. For color: (a) match the existing
   `urgency:*`/`importance:*` severity-style palette; (b) a distinct neutral
   color, since B3 frames this label as an orthogonal marker, not a severity
   signal — recommended, to avoid implying false urgency.

7. **Ranking bonus** (B3). Whether to adopt one at all. Options: (a) none — papercuts
   rank by their existing urgency, importance and stage; (b) an additive bonus keyed
   on the label, which needs a new scoring branch in `tools/Get-NextIssues.ps1` and a
   value — either matching the magnitude of the existing `status:investigate` WIP
   bonus or a smaller fractional bonus.

8. **Guard placement in `implement-issue`** (B8). Options: (a) a pre-flight inside
   Step 9a, immediately before the pull request is opened — recommended, because B6
   stops the skill before the PR; (b) additionally before the Step 7 commit.

9. **Calibration records** (B9, C11). Options for the scan outcome record: (a) an
   issue comment on every scan, flagged or not, in a fixed format that lists the
   failing conditions — recommended, because it is uniform, queryable through the
   issue, and independent of whether an investigation document is written; (b) a line
   in the investigation document, which does not exist for an item flagged at the
   start. The escape comment states its trigger in the same format.

10. **Calibration review** (B9, C11). Cadence: after the first ten scans or at the end
    of the release, whichever comes first. Method: (a) ad hoc queries over the issue
    timeline, the comments and the estimates in the documents; (b) a small read-only
    report script under `tools/`. A starting rule from the gate counts in C11: a
    scan 1 flag pays off while about one in four flagged items survives the plan-time
    check (one in three for the post-investigation decision), because a correct flag
    saves 9 gates and a rejected one wastes about 3 (4 and 2 for the post-investigation
    decision); planning re-verifies those counts.

11. **`XS` definition** (B1, C11). The scale XS to XL is named in `investigate-issue`
    and `plan-issue` but not defined in the repository's Markdown, so the size signals
    need one consistent meaning. Options: (a) a time-based definition, such as work an
    experienced contributor completes and verifies within about an hour; (b) an anchor
    from the repository history, where the median fix, chore or docs change is 1 file
    and 6 lines and 77% are at most 30 lines — as guidance rather than a cap.

### D3. Recommended commit strategy

Six commits, in this order, with the one-time `gh label create` (C2) run before the
second:

1. `docs(#4): add shared fast-track criteria` — the new criteria file that the skills
   point to.
2. `feat(#4): flag fast-track candidates in investigate-issue and approve-ready-for-plan`
   — scan 1, the Phase D assessment, the approver decision and the label transition,
   which share the B1 checklist and are naturally reviewed as a pair.
3. `feat(#4): compact plan mode in plan-issue and approve-ready-for-implement` — the
   input fallback, the compact profile and fast-track check, and the approver's
   verification.
4. `feat(#4): fast-track guard and escape in implement-issue` — the isolated guard and
   escape transition.
5. `feat(#4): rank fast-track items` — conditional: only if D2 item 7 adopts a bonus
   (the weights entry and the `tools/Get-NextIssues.ps1` change).
6. `docs(#4): document fast-track route and changelog entry` — `README.md` and
   `CHANGELOG.md`, last, matching the standard pattern A2 describes.

### D4. Test requirements

No new Pester suite is added, per B9's decision. The repository's single existing
test file (A6) does not cover any of the files in D1's table, so there is no
existing regression surface at risk either way. The full Pester suite should still
run once before the release PR, per the standard Definition of Done, but no new
test-writing is expected specifically for this issue. The B10 manual validation
papercut (a separate, later issue) is the acceptance check for the fast-track
route's real-world behavior.

### Sizing estimate

**Estimate:** M

| Driver | Weight | Reasoning |
| --- | --- | --- |
| Entry scan and decision (B2) | Medium | Scan 1 and the Phase D assessment in `investigate-issue`, and the approver decision in `approve-ready-for-plan` — bounded edits, but both skills are staged, human-gated flows that must stay consistent |
| Compact plan mode (B4, B5) | Medium | The largest edit: input fallback, compact profile, fast-track check and one review gate in `plan-issue`, plus the matching verification in `approve-ready-for-implement` |
| Implementation guard and escape (B6, B8, B9) | Medium | New PowerShell comparison of the diff against the plan's tables, plus a content check for public-surface changes and the escape transition, in `implement-issue` |
| Shared criteria file and escape marker (B1, C6, C9) | Low | One short `.github/` file and one marker |
| Label creation (C2) | Low | One `gh label create` (two if the escape marker is a label) |
| Calibration records (B9, C11) | Low | One comment format and recording points in skills that are already being modified; the review is ad hoc or a small read-only script (D2 items 9, 10) |
| Optional ranking bonus (D2 item 7) | Low if dropped, Medium if adopted | `Get-NextIssues.ps1` ignores unknown weight keys, so a bonus needs a scoring branch |
| README/CHANGELOG updates | Low | Standard, bounded documentation additions |

**Primary uncertainty drivers:**

- Whether the compact profile can satisfy `approve-ready-for-implement` and
  `implement-issue` without changing their parsers (C3) — unresolved until planning
  defines the profile against the skills' exact parse points.
- How the guard reads the plan's affected-documents and source-file tables (B9) —
  small logic, but first-of-its-kind and untested (C5).
- Whether a ranking bonus is adopted (D2 item 7) — if so, a scoring change in
  `Get-NextIssues.ps1` joins the scope.
- How many items the B1 rules admit (C11) — this does not change the implementation
  size, but it decides how much of the intended saving is realized, and it is only
  known by measuring.

**Upgrade trigger:** Upgrade to the next size if the compact profile cannot satisfy
`approve-ready-for-implement` and `implement-issue` without changing their parsers, or
if a ranking bonus is adopted, since it adds a scoring change to
`tools/Get-NextIssues.ps1`.
