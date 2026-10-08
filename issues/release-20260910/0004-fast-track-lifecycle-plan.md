# Issue #4: feat: add a fast-track lifecycle for low-risk papercuts

**Issue:** [#4](https://github.com/drmssst/Well-Architected-Reliability-Assessment/issues/4)
**Alias:** `0004-fast-track-lifecycle`

---

## Implementation plan — Issue #4: feat: add a fast-track lifecycle for low-risk papercuts

### Phase A — Scope and approach

The core change adds a second, governed route through the issue lifecycle for
low-risk `XS` papercuts and leaves the normal route untouched. It is delivered
entirely as contributor-facing workflow content: one new shared contract file
(`.github/FAST_TRACK_CRITERIA.md`), edits to five existing skills, a README
update, a CHANGELOG entry, and two one-time repository labels. No function exported
by the WARA module changes, and no GH Project status option is added or changed.

#### What it delivers

- **Entry (B2).** `investigate-issue` evaluates the shared eligibility checklist
  (investigation B1, six conditions) in a new scan 1 that runs before its worktree
  step. When the findings suggest an item qualifies, the investigator records the
  same checklist as a Phase D entry placed before the sizing estimate, and
  `approve-ready-for-plan` carries the decision inside its existing quality
  confirmation, so it adds no gate. Both entries end the same way: the issue
  carries `lifecycle:fast-track` and sits at `status:plan`. Every scan, flagged or
  not, is recorded as one issue comment in a fixed format (B9).
- **Compact plan (B4, B5).** `plan-issue` writes a compact plan in one pass behind
  one review gate. `approve-ready-for-implement` verifies its fast-track check and
  is the only pre-implementation approval for an item that skipped investigation.
- **Guard and escape (B6, B8, B9).** `implement-issue` checks the diff and the
  test results against the plan before the pull request is opened. Any failed
  trigger runs one escape procedure, defined once in the criteria file, that
  returns the item to the earliest normal stage whose artifact is missing.
- **Unchanged (B5).** Every release-side control (release-branch pull request,
  doc-content gate, pre-merge full Pester run, human merge confirmation, closing
  transition) and the changelog and version-classification requirements.

Out of scope: a Pester suite for the skills (B9), new GH Project status options
(B3), a ranking bonus (D2.7), changes to `raise-issue`, `groom-backlog`,
`next-issues`, `approve-ready-for-release` or the ranking, worktree and
project-constants tools, and the follow-up validation papercut (B10), which is
raised after this issue merges.

#### Compact plan profile (D2.1, option a)

- Same file path, header and heading names as a full plan, so the section checks,
  the sizing parse, the checkbox sections and the affected-file tables that
  `approve-ready-for-implement` and `implement-issue` read keep working unchanged.
- A short `### Fast-track check` section comes first and re-answers the six
  checklist conditions with plan-level evidence. A failed answer stops `plan-issue`
  before the rest is written and runs the escape procedure.
- Content is terse: Phase A is one short paragraph; each affected-file row names
  one file (no globs) and states its uniform edit; version impact is `patch` or
  `minor`; testing requirements may be an explicit "no new or modified tests" with
  the reason; the sizing section is the estimate line plus one sentence; the
  Definition of done keeps its standard items.
- One pass, one lint run, one review gate: the user reviews the whole document once
  and "go ahead" commits it and stamps `awaiting-approval`. If the final estimate
  is not `XS`, `plan-issue` runs the escape procedure instead of committing.

#### Guard rules (B9, exact rules)

Run only for issues carrying `lifecycle:fast-track`, as a pre-flight inside Step 9a
of `implement-issue`, before the pull request is opened:

1. **File scope.** Every path in `git diff --name-only origin/<release-branch>...HEAD`
   must appear in the plan's Affected documents or Affected source files table.
   `CHANGELOG.md` is always listed there.
2. **Public surface.** Compare the base and head versions of each changed file:
   function names and parameter declarations, including a script-level `param`
   block, in `src/modules/**/*.psm1` and `src/modules/**/*.ps1` (through the
   PowerShell parser); `FunctionsToExport` in `src/modules/**/*.psd1`; and the set
   of key paths in `config/*.json`. A value-only change in a JSON file passes; any
   other difference triggers the escape.
3. **Outlier flag (non-blocking).** With three or more declared files other than
   `CHANGELOG.md`, flag a file whose changed-line count (`git diff --numstat`) is
   at least three times the median and at least ten lines above it. The user
   decides at the existing Step 9a pause.
4. **Tests.** Any failing test in the runs the skill already has (Step 4, and
   Gate 1 after the merge in Step 9b) triggers the escape instead of fix-and-retry.

The guard cross-checks the plan-time evidence; it is not proof. For example, it
does not read the class definitions in `runbook.classes.ps1`, which `runbook.psd1`
loads through `ScriptsToProcess`, so those rest on the plan-time check and review.

#### Resolved from the investigation's deferred decisions (D2)

- **D2.1 Compact plan profile:** option (a), above.
- **D2.2 Scan evidence comment:** one template. Heading `## Fast-track scan`; fields
  Context (scan 1 or post-investigation decision), Result (`FLAGGED` or
  `NOT FLAGGED`), a table of the six conditions in the B1 order (Condition, Met,
  Evidence), Failing conditions, and Confirmed by. The Phase D entry and the plan's
  fast-track check reuse the same condition rows. Defined once in the criteria file.
- **D2.3 Escape marker:** option (a), label `lifecycle:fast-track-escaped`, added
  only when the item returns to `status:investigate`, the one place scan 1 runs.
  Scan 1 skips an item that carries it or already has a `## Fast-track scan`
  comment, which also stops the rerun inside the investigate worktree from
  scanning twice.
- **D2.4 Compact plan rename on escape:** `<N-padded>-<slug>-plan-fast-track.md`,
  applied to a compact plan at the normal path whether committed or still a draft.
  The investigation's example name ends in `-plan.md`, which the
  `<N-padded>-*-plan.md` lookups in `approve-ready-for-implement` and
  `implement-issue` would match alongside the new full plan.
- **D2.5 Criteria file:** `.github/FAST_TRACK_CRITERIA.md`, option (a). It holds the
  checklist, the `XS` definition, the comment templates, the escape procedure, the
  label definitions and the calibration signals.
- **D2.6 Labels:** `lifecycle:fast-track` ("Fast-track route: low-risk XS papercut,
  compact plan, proportionate approvals") and `lifecycle:fast-track-escaped`
  ("Escaped the fast-track route: back in the normal lifecycle, do not re-flag").
  Both use color `c5def5`, a neutral color no existing label uses. Created once with
  `gh label create` before commit 2; rollback is `gh label delete`.
- **D2.7 Ranking bonus (was O1):** option (a), none, confirmed at review. A flagged
  item scores the same before and after flagging (`status:investigate` 10 plus the
  WIP bonus 4 equals `status:plan` 14) and then follows the normal stage scores, so
  `tools/Get-NextIssues.ps1` and `config/issue-priority-weights.json` stay
  unchanged. A bonus can be revisited with the calibration data (D2.10).
- **D2.8 Guard placement:** option (a), Step 9a; test failures are handled where the
  skill already runs tests (guard rule 4).
- **D2.9 Calibration records:** option (a), one scan comment per scan. The escape
  comment (`## Fast-track escape`) states the trigger, the stage it fired at and
  the state the item returned to.
- **D2.10 Calibration review:** cadence as in the investigation (after the first
  ten scans or at the end of the release); method (a), ad hoc queries over the
  issue timeline, comments and estimates, with the signals listed in the criteria
  file. The gate counts were re-verified against the current skills: 13
  pre-implementation gates on the normal route, 4 when flagged at the start and 9
  when flagged after investigation, so the break-even rates in the investigation
  (one in four, one in three) stand.
- **D2.11 `XS` definition (was O2):** time-based, with the repository history as a
  non-binding note, confirmed at review. `XS` is implementation work (not
  investigation or planning) that an experienced contributor completes and verifies
  in about an hour. The history anchor (the median fix, chore or docs change touches
  1 file and about 6 lines, and 77% change at most 30 lines, per C11) is guidance,
  not a cap. Defined in the criteria file, with one-line pointers from the Phase D
  sizing steps of `investigate-issue` and `plan-issue`.

#### Findings from the context survey that refine the investigation

- A6 and D4 refer to one existing Pester test file. There are ten
  (`src/tests/<module>/<module>.tests.ps1`); none references the lifecycle skills,
  tools or configuration, so B9's decision to add no Pester suite stands.
- Exports are declared in each module's `.psd1` (`FunctionsToExport`); there is no
  `Export-ModuleMember` under `src/modules/`. `Start-WARAAnalyzer` and
  `Start-WARAReport` also splat `@PSBoundParameters` into script-level `param`
  blocks in `2_wara_data_analyzer.ps1` and `3_wara_reports_generator.ps1`. B1's and
  B9's `.psm1`-only wording would miss both; guard rule 2 and the criteria file's
  public surface condition cover them (was O3, confirmed at review).
- The README lifecycle section still names `.github/prompts/*.prompt.md` as the
  source of truth, although the skills moved to `.github/skills/*/SKILL.md`. The
  README edit corrects the pointer in the same change that adds the fast-track
  route (was O4, confirmed at review).
- C1 holds at plan time: `7d4cbbf` is an ancestor of `release/20260910` (`d60b0c5`),
  `.github/skills/` is present on it, and no prerequisite issue remains.

#### Commit strategy and sub-issues

Five commits in this order, with the labels created before the second: (1) criteria
file; (2) `investigate-issue` and `approve-ready-for-plan`; (3) `plan-issue` and
`approve-ready-for-implement`; (4) `implement-issue` guard and escape; (5)
`README.md` and `CHANGELOG.md`.

No sub-issues are warranted: the criteria file and the five skill edits are one
cohesive change reviewed as five commits. The follow-up validation papercut (B10)
is not a sub-issue; it is raised only after this issue merges so that it cannot
enter the full lifecycle before the route exists.

### Phase B — Document impact

Docs scan: outside `.github/skills/` and the `issues` folder, only `README.md`
describes the lifecycle (its Issue Lifecycle Workflow section), and
`.github/COMMIT_GUIDELINES.md` mentions "the issue-workflow prompts" in passing.
`docs/` has no lifecycle content, and `docs/wara/contribution-guide.md` covers the
upstream pull-request flow only. Reviewed and unchanged: `raise-issue`,
`groom-backlog`, `next-issues` and `approve-ready-for-release` (the release-side
controls are unchanged, B5), `.github/COMMIT_GUIDELINES.md` and
`.github/policies/resource-management.yml` (no `status:*` or `lifecycle:*` rules).

In-flight scan of `C:\wt\wara\docs\issues\`: the only other documents belong to #1,
which is closed, so no in-flight plan or investigation is invalidated. Two
historical statements go stale and stay as records: the 34-label reference table in
the #1 investigation (D2) is two labels short once the D2.6 labels exist, and AC D3
of the #1 plan names the old `.github/prompts` pointer that the README edit
corrects. This issue's own investigation is refined by Phase A and is not edited.

### Affected documents

| File | Change needed |
| ---- | ------------- |
| `.github/FAST_TRACK_CRITERIA.md` | Commit 1. New. The six-condition eligibility checklist (B1, with the public-surface condition worded as guard rule 2); the `XS` definition (D2.11); the `## Fast-track scan` and `## Fast-track escape` comment templates (D2.2, D2.9); the escape procedure (triggers, target state, label and board transition, plan rename to `<N-padded>-<slug>-plan-fast-track.md`, D2.3, D2.4); the two label definitions (D2.6); the calibration signals and cadence (D2.10). |
| `.github/skills/investigate-issue/SKILL.md` | Commit 2. Add scan 1 ahead of Step 0: skip when the escape marker or a scan comment exists; otherwise evaluate the checklist and ask for confirmation; on confirmation post the scan comment, add `lifecycle:fast-track`, move `status:investigate` to `status:plan` (label and board) and stop; if not confirmed or not eligible, post the not-flagged scan comment and continue into Step 0. The Step 3 survey reads earlier scan and escape comments and any `-plan-fast-track.md` as prior art. Phase D gains a fast-track assessment entry before the sizing estimate, and the sizing step points to the `XS` definition. The frontmatter description mentions scan 1. |
| `.github/skills/approve-ready-for-plan/SKILL.md` | Commit 2. Step 2 reads the Phase D fast-track assessment and folds the fast-track decision into the existing quality confirmation (no extra gate). Step 3 adds `lifecycle:fast-track` in the same `gh issue edit` that moves `status:investigating` to `status:plan` when the answer is yes, and posts the scan comment (post-investigation decision) either way. The Step 6 report names the compact-plan path for a fast-track item. |
| `.github/skills/plan-issue/SKILL.md` | Commit 3. Step 1: draft from the issue body and comments, including the scan comment, when no investigation document exists, and announce compact mode when the issue carries `lifecycle:fast-track`. The Step 3 survey reads scan and escape comments and any `-plan-fast-track.md` as prior art. New compact-mode section implementing the compact plan profile (check section first, terse content rules, one pass, one lint run, one review gate), with the plan-time escape on a failed answer or a final estimate other than `XS`. The Phase D sizing step points to the `XS` definition. The frontmatter description mentions compact mode. |
| `.github/skills/approve-ready-for-implement/SKILL.md` | Commit 3. Step 2: when the issue carries `lifecycle:fast-track`, also verify the plan's `### Fast-track check` (all six conditions met with evidence), the `XS` estimate, and one named file per row (no globs) in the affected-file tables; on a failure, run the escape procedure instead of advancing. The compact form satisfies the existing section checks, and `lifecycle:fast-track` stays on the issue through Step 4. |
| `.github/skills/implement-issue/SKILL.md` | Commit 4. Step 4 and the Step 9b Gate 1 run: for `lifecycle:fast-track`, a failing test runs the escape procedure instead of fix-and-retry. Step 9a: new fast-track guard pre-flight before the pull request is opened (guard rules 1 to 3 as inline PowerShell: plan file scope, public-surface comparison through the PowerShell parser, `Import-PowerShellDataFile` and JSON key paths, and the outlier flag for the user's decision), with the escape procedure on a rule 1 or 2 hit. |
| `README.md` | Commit 5. Issue Lifecycle Workflow section: add the fast-track route (eligibility in `.github/FAST_TRACK_CRITERIA.md`, the two entry points, the `lifecycle:fast-track` label, the compact plan, the guard and escape) and correct the stale `.github/prompts/*.prompt.md` pointer to `.github/skills/*/SKILL.md` (O4). |
| `CHANGELOG.md` | Commit 5. Add a `patch` entry under `[Unreleased]`, in the existing `### Patch` list: the fast-track route, with no change to any function exported by the WARA module (#4). |

### Affected source files

None. No script, module or configuration file changes: the guard's PowerShell lives
inline in `.github/skills/implement-issue/SKILL.md` (listed above), and no ranking
change is made (D2.7). The two labels (D2.6) are live GitHub state created once with
`gh label create`, not repository files.

### Version impact

**Classification:** `patch`

| Term | Meaning |
| ---- | ------- |
| `major` | Breaking — existing consumers must update |
| `minor` | Additive, non-breaking new capability |
| `patch` | Invisible to consumers — bug fix, doc correction |

**Rationale:** The change is contributor-facing workflow content (skills, one shared
contract file, the README) and changes no function exported by the WARA module or
its parameters, so a user running `Install-Module WARA` sees no difference. The
issue is `type:feat` because it adds a maintainer workflow capability; the
classification follows the module consumer's view, as it did for #1, which ported
the same tooling and was classified `patch`.

### Testing requirements

No new or modified Pester tests (B9, D4). The change adds instructions and inline
PowerShell to skill and contract files and changes no module code. None of the ten
existing test files under `src/tests/<module>/<module>.tests.ps1` covers the
lifecycle skills, tools or configuration, and a skill-testing harness is out of
scope. The full suite runs once as the standard regression gate, and no result is
expected to move.

The guard and the escape procedure are first-of-their-kind inline PowerShell with no
automated coverage (C5), so implementation runs the manual checks below. They are
this issue's manual smoke test, since there is no testbed artifact to run. Each
check's command and output are recorded in the pull request body and named in the
acceptance-criteria verification table at `implement-issue` Step 5. All five are
new; none modifies an existing test. V4 runs before V2 because V2 applies the
labels.

- **V1 Guard dry run (rules 1 to 3).** Extract the Step 9a guard block to a scratch
  `.ps1`, run `tools/Invoke-PsScriptAnalyzer.ps1` on it, then run it in a scratch
  worktree against a throwaway plan file and scratch commits. The block only
  reports (PASS, or ESCAPE with the rule that fired, plus any outlier flags) and
  takes no GitHub action; the skill runs the escape procedure on ESCAPE.
  - Rule 1: only declared files plus `CHANGELOG.md` changed reports PASS; one
    undeclared file reports ESCAPE naming it.
  - Rule 2: ESCAPE for a renamed parameter or changed default in a `.psm1`
    function, a changed script-level `param` default in a `.ps1` under
    `src/modules`, a name added to `FunctionsToExport` in a `.psd1`, an added,
    removed or renamed key in a `config/*.json` file, and a file that cannot be
    parsed (fail closed). PASS for a function-body-only change, a `.psd1`
    `Description` change and a JSON value-only change.
  - Rule 3: three declared files plus `CHANGELOG.md` with one far larger edit flags
    that file and still reports PASS; with two declared files nothing is flagged.
- **V2 Escape procedure dry run.**
  - Target state, read-only: the determination returns `status:plan` for #4 (its
    investigation document exists) and `status:investigate` for an issue number
    with no investigation document.
  - Live transition, on a throwaway issue added to the project board at
    `status:plan` and carrying `lifecycle:fast-track` with no investigation
    document: afterwards it carries `status:investigate` and
    `lifecycle:fast-track-escaped` but not `lifecycle:fast-track` or
    `status:plan`; its board status is `investigate`; and one
    `## Fast-track escape` comment names the trigger, the stage and the state it
    returned to. The throwaway issue is then closed and its board item removed.
  - Plan rename, in a scratch repository: the rename step moves
    `<N-padded>-<slug>-plan.md` to `<N-padded>-<slug>-plan-fast-track.md`, for a
    committed file and for an uncommitted draft, and
    `Get-ChildItem -Filter '<N-padded>-*-plan.md'` no longer returns it.
- **V3 Compact plan parse check.** Run the guard's table parser against this plan's
  Affected documents table (eight paths expected) and against a sample compact plan
  written to the new profile in a scratch location. The sample yields one path per
  row, the sizing regex from `approve-ready-for-implement` Step 5 returns `XS`, and
  the required headings are present. This addresses the C3 uncertainty: the compact
  form works with the existing parse points.
- **V4 Label check.** After the one-time `gh label create`, `gh label list` shows
  both labels with color `c5def5` and the D2.6 descriptions.
- **V5 Cross-reference check.** Search the five skills, `README.md` and the criteria
  file for the label names, the `## Fast-track scan` and `## Fast-track escape`
  headings, the plan rename pattern and the criteria file path. Each occurrence
  matches the criteria file's definition, and every pointer to the file resolves.

Afterwards, `git worktree list` and `git branch --list` show no scratch worktree or
branch left by V1 and V2. Not part of this issue: the B10 follow-up papercut
exercises scan 1, the compact plan, the single approval, the guard on a real diff
and the release controls end to end.

### Acceptance criteria

- [ ] D1. `.github/FAST_TRACK_CRITERIA.md` states the six eligibility conditions,
      with the public-surface condition covering function names and parameter
      declarations in `.psm1` and `.ps1` files under `src/modules`,
      `FunctionsToExport` in `.psd1` files and `config/*.json` key paths. It
      defines `XS` as implementation an experienced contributor completes and
      verifies in about an hour, with the repository history as a non-binding note.
- [ ] D2. The criteria file defines the `## Fast-track scan` and
      `## Fast-track escape` comment templates (fields as defined in Phase A), one
      escape procedure (triggers, target-state rule, label and board transitions,
      escape comment, plan rename to `<N-padded>-<slug>-plan-fast-track.md`), the
      two label definitions, and the calibration signals with the review cadence.
- [ ] D3. `lifecycle:fast-track` and `lifecycle:fast-track-escaped` exist on the
      repository with color `c5def5` and the descriptions defined in Phase A (V4).
- [ ] D4. `investigate-issue` runs scan 1 before Step 0, so no investigate worktree
      is created for a flagged item. It skips an item that carries
      `lifecycle:fast-track-escaped` or already has a `## Fast-track scan` comment.
      On confirmation it posts the scan comment, adds `lifecycle:fast-track`, moves
      label and board from `status:investigate` to `status:plan` and stops;
      otherwise it posts a not-flagged scan comment listing the failing conditions
      and continues into Step 0.
- [ ] D5. `investigate-issue` Phase D has a fast-track assessment entry before the
      sizing estimate, and its Step 3 survey reads earlier scan and escape
      comments and any `-plan-fast-track.md` as prior art. `approve-ready-for-plan`
      folds the fast-track decision into its existing quality confirmation, adds
      `lifecycle:fast-track` in the same `gh issue edit` that moves
      `status:investigating` to `status:plan` when the answer is yes, and posts a
      `## Fast-track scan` comment either way.
- [ ] D6. For an issue carrying `lifecycle:fast-track`, `plan-issue` writes a
      compact plan at the normal plan path: `### Fast-track check` first, the same
      headings as a full plan, one pass, one lint run and one review gate. With no
      investigation document it drafts from the issue body and comments, including
      the scan comment, and its Step 3 survey reads scan and escape comments and
      any `-plan-fast-track.md` as prior art. A failed check answer, or a final
      estimate other than `XS`, runs the escape procedure instead of committing.
- [ ] D7. For an issue carrying `lifecycle:fast-track`, `approve-ready-for-implement`
      verifies the plan's `### Fast-track check`, the `XS` estimate and one named
      file per row (no globs) in the affected-file tables, and runs the escape
      procedure instead of advancing on a failure. It keeps the label on the issue
      through Step 4.
- [ ] D8. The `implement-issue` Step 9a guard runs only for an issue carrying
      `lifecycle:fast-track`, takes no GitHub action, and its outcomes match V1:
      rule 1 reports an undeclared file; rule 2 reports a public-surface change in
      a `.psm1`, `.ps1`, `.psd1` or `config/*.json` file (and fails closed on an
      unparsable file) while passing body-only, `Description`-only and JSON
      value-only changes; rule 3 flags an outlier only with three or more declared
      files.
- [ ] D9. For an issue carrying `lifecycle:fast-track`, `implement-issue` runs the
      escape procedure instead of fix-and-retry when a test fails at Step 4 or at
      the Gate 1 run in Step 9b.
- [ ] D10. The escape procedure's outcomes match V2: target `status:plan` when an
      investigation document exists and `status:investigate` otherwise;
      `lifecycle:fast-track` and the current status label removed, plus
      `awaiting-approval` if present; `lifecycle:fast-track-escaped` added only for
      `status:investigate`; the board status updated; one `## Fast-track escape`
      comment; and the compact plan, committed or draft, moved to
      `<N-padded>-<slug>-plan-fast-track.md` so the `<N-padded>-*-plan.md` lookups
      no longer return it.
- [ ] D11. The compact form works with the existing parse points (V3): the sizing
      regex from `approve-ready-for-implement` returns `XS` for a sample compact
      plan, the guard's table parser extracts one path per row from it and eight
      paths from this plan's Affected documents table, and the headings the
      downstream skills search for are present.
- [ ] D12. The normal route keeps all of its existing steps and gates: for an issue
      that is not flagged, the five skills remove or reorder no existing step or
      STOP, and a recount of the STOP and confirm prompts gives 13
      pre-implementation gates on the normal route, 4 when flagged at the start and
      9 when flagged after investigation.
- [ ] D13. `README.md` documents the fast-track route and points to
      `.github/FAST_TRACK_CRITERIA.md`, its lifecycle section names
      `.github/skills/*/SKILL.md` as the source of truth, and no `.github/prompts`
      reference remains in it.
- [ ] D14. Names agree everywhere (V5): the label names, the `## Fast-track scan`
      and `## Fast-track escape` headings, the plan rename pattern and the criteria
      file path match the criteria file's definitions in every skill and in the
      README, and every pointer to the criteria file resolves.
- [ ] D15. The pull request changes only the eight files in the Affected documents
      table: no `src/modules/**`, `config/**`, `tools/**`, `raise-issue`,
      `groom-backlog`, `next-issues` or `approve-ready-for-release` change.

### D16. Sizing estimate

**Estimate:** M

| Driver | Weight | Reasoning |
| ------ | ------ | --------- |
| Commit 4: guard and test triggers in `implement-issue/SKILL.md` | High | First-of-its-kind inline PowerShell with no automated coverage: parser-based comparison of function names and parameter declarations for `.psm1` and `.ps1`, `FunctionsToExport` and JSON key-path comparison, a plan table parser and the outlier rule, proven only by the V1 scratch-worktree dry run |
| Commit 1: `.github/FAST_TRACK_CRITERIA.md` | High | The single contract five skills point to; it also carries the executable escape procedure (target state, label and board transition, comment, plan rename with a docs/main commit and push), proven by V2 on a throwaway issue and a scratch repository |
| Commit 3: compact mode in `plan-issue/SKILL.md` and verification in `approve-ready-for-implement/SKILL.md` | Medium | The largest prose edit: input fallback, check-first profile, one-pass flow and plan-time escape; V3 covers only the code parse points |
| Commit 2: scan 1 in `investigate-issue/SKILL.md` and the decision in `approve-ready-for-plan/SKILL.md` | Medium | Scan 1 runs ahead of the worktree step and must skip on the rerun; the decision must fold into the existing confirmation without adding a gate |
| Verification V1 to V5 and the one-time label creation | Medium | A dozen guard scenarios, a throwaway issue and board item, a scratch repository and a cross-reference search, each needing setup and cleanup |
| Commit 5: `README.md` and `CHANGELOG.md` | Low | Bounded prose: one route description, one pointer fix and one `patch` entry |

Same size as the investigation's estimate. Dropping the ranking bonus (Phase A,
D2.7) removes one of the investigation's two upgrade triggers, while the escape
procedure living in the criteria file and the V1 to V5 checks add effort the
investigation had not sized.

Primary uncertainty drivers:

- Whether the parser-based comparison holds on the real files: the generator and
  analyzer scripts are large with many functions, line endings can differ between
  base and head, and the base `.psd1` must be read through a temporary file. V1 may
  force changes to the comparison.
- Whether the escape procedure's live commands behave as written: removing a label
  an issue lacks, an item missing from the board, and the docs/main rename, commit
  and push from another worktree. V2 is their first real exercise.
- Whether the compact form is accepted by the heading-based edits `implement-issue`
  makes in Steps 5 and 8. V3 covers only the code parse points; the rest is proven
  by the B10 follow-up after merge.
- Cross-skill drift: five skills, the criteria file and the README must agree on
  names and templates with no include mechanism (C6), and each V5 fix can ripple.

*Upgrade to the next size if V1 or V2 shows that the guard or the escape procedure
needs redesign rather than fixes, or if the compact form requires changing an
existing parse point in `approve-ready-for-implement` or `implement-issue` beyond
the additions in Phase B.*

### Definition of done

No Pester tests are written for this issue, so the test items below are met by V1 to
V5 passing and the full suite staying green. The manual smoke test is V1 to V5; no
testbed artifact applies because no module code changes.

- [ ] All acceptance criteria verified
- [ ] All affected documents updated
- [ ] All tests in Testing Requirements written and passing
- [ ] Full PowerShell suite (`tools/Invoke-Pester.ps1 src/tests/`) green
- [ ] Manual smoke test passed (verify behavior against testbed artifacts, where applicable)
- [ ] Manual checks V1 to V5 run, with their commands and output recorded in the
  pull request body
- [ ] Scratch worktrees, branches, repositories and files from V1 to V3 removed, and
  the V2 throwaway issue closed with its board item removed
- [ ] CHANGELOG entry added with correct classification
- [ ] All modified Markdown files pass lint
- [ ] PR opened targeting the release branch
