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

**Decision:** An issue is fast-track-eligible only if all of the following are true,
each answered explicitly by the requester and recorded verbatim as evidence (issue
body at raise time, or a structured comment at conversion time):

- Self-assessed size is `XS`.
- Type label is `type:fix`, `type:chore`, or `type:docs` (`type:feat` is never
  eligible — new capability implies unknowns by definition).
- The affected files are declared by name up front, with no numeric cap — a
  papercut may legitimately touch many files (e.g., a mechanical rename or a
  repeated label/string correction). Eligibility instead requires every declared
  file to receive the same uniform, mechanical class of edit (e.g., an identical
  substitution or an identical single-line value change), not a mix of unrelated
  or judgment-dependent edits.
- No public surface changes: no exported function signature under
  `src/modules/**/*.psm1` and no `config/*.json` schema changes.
- Fully reversible by a single revert commit — no data migration, no irreversible
  external side effect (e.g., live GitHub label/project taxonomy changes).
- No new external dependency (no `package.json`/module import additions).

**Rationale:** mirrors the existing type/urgency/importance self-declaration already
collected at raise time (A2, A7) rather than introducing a new interaction style; a
declared file list keeps the automated cross-check in B9 meaningful regardless of
count, while gating on edit uniformity — rather than file count — targets what
actually drives risk: a wide but uniform mechanical fix is not riskier for being
spread across many files, and a single file can still carry high risk if its edit is
complex.

**Alternatives considered:** using `XS` alone as the sole gate — rejected, because
today no size estimate exists before investigation (A3), so an unsupported XS guess
without the other proxies would be too easy to satisfy; a hard numeric file-count cap
(e.g., at most 3 files) — considered and rejected, file count alone is only a weak
proxy for risk and produces both false negatives (a wide but uniform mechanical fix)
and false positives (a single complex file); requiring maintainer pre-verification
before the checklist can even be submitted — rejected as an extra manual gate that
duplicates the single approval gate decided in B5.

### B2. Entry points (resolves A8.2)

**Decision:** Support both entry points. (a) A new `raise-fast-track-issue/SKILL.md`
gathers the same core details as `raise-issue/SKILL.md` (title, problem, type,
urgency, importance) plus the B1 checklist, then creates the issue directly with the
`lifecycle:fast-track` label and the board state from B3 — never touching
`status:investigate`. (b) A new `convert-to-fast-track/SKILL.md`, run during backlog
grooming, requires an existing issue at `status:investigate` with no
`awaiting-approval` label, asks the same B1 checklist, and on success removes
`status:investigate` and applies the same label/board state as (a). Both skills
share one checklist step rather than duplicating the eligibility logic.

**Rationale:** papercuts surface two ways in practice — obviously trivial at filing
time, or discovered trivial while grooming an existing backlog item (which
`groom-backlog/SKILL.md` already supports without changing status, per A1) — and
both paths reuse identical criteria, so supporting both costs one shared checklist
plus two thin entry skills rather than duplicated logic.

**Alternatives considered:** raise-time only — rejected, forces every backlog item
later found trivial through full investigation, defeating the proportionality this
issue asks for; conversion only — rejected, forces obviously-trivial-at-filing-time
issues to wait for a grooming pass before gaining any benefit.

### B3. Labels, project board, and backlog ranking (resolves A8.3)

**Decision:** Add one new repository label, `lifecycle:fast-track`, applied as an
orthogonal marker alongside existing `status:*` labels rather than replacing them —
the same layering pattern `awaiting-approval` already uses (A1, A7). No new GH
Project status field option is created. A fast-track issue occupies the existing
`plan` status option while its micro-plan comment awaits the B5 approval gate, then
moves directly to the existing `implementing` option once approved — skipping
`investigate`, `investigating`, and `planning` entirely. `release`/`shipped`
transitions are unchanged. `config/issue-priority-weights.json` gains one new
additive bonus entry, `"lifecycle:fast-track"`, applied on top of whichever
`status:*` stage weight already applies (not a replacement stage); the exact bonus
value is deferred to planning.

**Rationale:** issue #1's own investigation (finding A3 in
[0001-port-issue-lifecycle-tooling-investigation.md](0001-port-issue-lifecycle-tooling-investigation.md))
already found the live GH Project status field is managed outside repo version
control and flagged the `releasing`/`superseded` gap this creates; adding new
fast-track-specific status options would repeat that same unreviewable, external,
un-rollback-able dependency. A label plus reuse of existing options keeps the entire
change inside version control.

**Alternatives considered:** dedicated new project status options (e.g.
`fast-track`, `fast-track-implementing`) — rejected for the external-dependency
reason above; a `status:fast-track` label replacing `status:*` entirely — rejected,
it would require a parallel state machine and break every existing skill's
`status:investigate`-style precondition checks.

### B4. Micro-plan location and structure (resolves A8.4)

**Decision:** The micro-plan is posted as a single structured GitHub issue comment
(`gh issue comment <N> --body ...`) — not a `docs/main` file, not a body edit —
directly matching the issue's own phrase "compact issue-level micro-plan." Mandatory
fields: Scope (1–2 sentences), Affected files (the same declared, uniformly-edited
list from B1 — no numeric cap), Risk/reversibility statement, Test plan (what will
be run and checked), and Version impact (`patch` or `minor`; `major` is already
excluded by B1's no-public-surface-change rule). Implementation reads this comment
the same way
`implement-issue/SKILL.md` reads the plan doc today, and preserves it permanently —
implementation results (test evidence, actual files touched) are posted as a
follow-up comment rather than edited into the original, keeping an append-only trail.

**Rationale:** an issue-level artifact removes `docs/main` from the fast-track path
entirely, cutting one of the two document-producing surfaces (A4) out of the
ceremony; GitHub comments are timestamped and attributable without a separate git
commit/push/lint cycle, which is itself part of what makes the route compact.

**Alternatives considered:** a shorter `docs/main` file mirroring today's convention
— rejected, keeps the exact worktree/commit/push/lint ceremony this issue seeks to
reduce, for marginal structural benefit; editing the issue body — rejected, it
destroys or bloats the original problem statement rather than appending clean
evidence.

### B5. Mandatory gates and approval placement (resolves A8.5)

**Decision:** All release-side controls stay mandatory and unchanged:
`approve-ready-for-release`'s release-branch check, the doc-content gate (fast-track
issues produce no investigation/plan docs, so this trivially passes), the pre-merge
full Pester run, explicit human merge confirmation, and the post-merge label/board/
closure transition. Changelog and version-classification requirements are retained
unchanged from the normal Definition of Done. Exactly one new pre-implementation
approval gate is added: once the B4 micro-plan comment is posted, a human reviewer
confirms it — collapsing today's `approve-ready-for-plan` and
`approve-ready-for-implement` into a single fast-track approval — before the label
moves from `plan` to `implementing`.

**Rationale:** the issue's problem statement explicitly requires preserving
"traceability, validation, and release controls," and release-side gates are where
release-quality validation actually happens (tests, PR review, merge control) at low
relative cost; the ceremony being reduced is specifically the pre-implementation
planning/investigation overhead, matching the issue's call for "proportionate
approval gates" only on that side.

**Alternatives considered:** 0 pre-implementation gates — rejected in favor of the
explicit "1 gate" choice; 2 gates matching today's count — also rejected, and would
be redundant once investigation and the full plan are both already skipped.

### B6. Escape hatch triggers and target state (resolves A8.6)

**Decision:** Both automated and human-judgment triggers apply. Automated: the
implementing skill stops and does not open a PR if the diff touches files beyond
the B4 declared list, any declared file's edit breaks the declared uniform class
(e.g., a materially larger or logic-bearing hunk next to otherwise-identical
substitutions), any test (existing or new) fails, or the diff matches a
public-surface pattern (exported `src/modules/**/*.psm1` signatures, or any
`config/*.json` schema) — the same objective conditions used for entry in B1. Human:
the assignee or the B5 reviewer may escalate at any time on subjective grounds, no
automated detection required. On any trigger, the issue moves to `status:investigate`
— not `status:plan` or `status:implement` — re-entering the normal lifecycle at its
first stage.

**Rationale:** reusing the B1 checklist as the automated-threshold source means
eligibility and escape share one rule set instead of two to maintain; human override
covers risk categories no static check can see; returning to `status:investigate` is
the only state consistent with "escape hatch back to the normal lifecycle" — none of
the normal investigation work has actually been done yet, so re-entering mid-stream
(e.g., at `status:plan`) would skip the phase that exists to de-risk exactly this
situation.

**Alternatives considered:** escalating directly to `status:plan` — rejected, lets an
item that already proved larger or riskier than assumed bypass the investigation
phase; automated-only or human-only — both rejected in favor of the explicit "Both"
choice.

### B7. Escaped-item evidence retention and re-estimation (resolves A8.7)

**Decision:** Nothing is deleted on escalation. The original issue body/comments (B1
checklist answers and the B4 micro-plan) remain permanently on the issue, and
`investigate-issue/SKILL.md`'s context-survey step is read as prior art before
Phase A is written, so the abandoned fast-track attempt shortens rather than wastes
the resulting investigation. A full investigation document and full plan document
are still required — no phase is grandfathered in from the fast-track attempt. Size
and priority are recalculated from scratch via the normal investigation Phase D
estimate; the original fast-track `XS` self-assessment is not carried forward.

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
`New-IssueWorktree.ps1 -Stage implement` unchanged at the tooling level. Add one
conditional branch at the top of `implement-issue/SKILL.md`'s Step 1: if the issue
carries `lifecycle:fast-track`, read the B4 micro-plan issue comment instead of
locating a `docs/main` plan file; every step from Step 2 onward (label switch,
implementation, testing, changelog, PR to `release/*`, `awaiting-approval`) proceeds
unchanged regardless of which source fed Step 1. No new worktree stage, skill file,
or branch-naming convention is introduced for implementation.

**Rationale:** A5 already found `New-IssueWorktree.ps1` accepts an arbitrary `Stage`
string with no validation, and every downstream implementation step is identical
regardless of how the plan was produced; forking a second implementation skill
would duplicate roughly 14 KB of maintained logic (A1) for a difference that is only
where Step 1 reads its input from.

**Alternatives considered:** a distinct `implement-fast-track-issue/SKILL.md` —
rejected, duplicates Steps 2–7 verbatim for no behavioral difference beyond Step 1's
data source, doubling future maintenance for identical logic.

### B9. Automated validation scope (resolves A8.9)

**Decision:** No new Pester test suite is added for the lifecycle skills as part of
this issue. The automated cross-check selected for B1/B6 is implemented as inline
PowerShell validation inside the fast-track skills themselves (comparing
`git diff --name-only`'s file list against the B4 declared list; flagging, for the
B5 reviewer rather than auto-blocking, any declared file whose hunk size or shape is
an outlier relative to the others, since uniformity is not fully machine-decidable;
checking diff paths against the B6 public-surface patterns) — not a separate test
file, and not new CI. Skill-level correctness continues to be validated the same
way every other lifecycle skill is today (A6: human execution and review), plus the
specific manual papercut named in the issue.

**Rationale:** A6 found zero existing test coverage for any of the nine lifecycle
skills or three helper scripts; building a first-of-its-kind skill-testing harness
is a separately sized effort the issue's own text does not request, and adding it
here would reintroduce the disproportionate-ceremony problem this issue exists to
fix, just relocated into its own delivery.

**Alternatives considered:** a new Pester suite asserting skill structure or
simulating label transitions — rejected as scope creep beyond what issue #4 asks
for; skipping the automated cross-check entirely — rejected in favor of the explicit
"Self-declared + automated cross-check" choice.

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
confirm the defect reproduces.

**Rationale:** derived directly from the exact defect found in A6; framed as
reproducible before/after evidence so the validation itself models the same
objective-evidence standard B1 establishes for eligibility.

**Alternatives considered:** none — this question has one well-evidenced answer once
A6's finding is treated as the target defect.
