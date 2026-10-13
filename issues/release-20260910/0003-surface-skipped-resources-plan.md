# Issue #3: fix: surface resources skipped when recommendation metadata is inconsistent

**Issue:** [#3](https://github.com/drmssst/Well-Architected-Reliability-Assessment/issues/3)
**Alias:** `0003-surface-skipped-resources`

---

## Implementation plan — Issue #3: fix: surface resources skipped when recommendation metadata is inconsistent

### Phase A — Scope and approach

The core change gives the collector a stable, tested way to report the resources it could
not give an APRL verdict. Today the validation step drops a resource whose type
`WARAinScopeResTypes.csv` flags as covered but for which `recommendations.json` has no
recommendation, automated or manual (outcome 4 of `createValidationResourceObjects()`).
Its only trace is a `Write-Error` raised inside a class method, which reaches `$Error` and
no other channel. Outcome 4 raises that error as well for a resource whose type has
automated recommendations but no manual one to validate, such as
`virtualMachineScaleSets`; automated checks cover those resources, so the change reports
nothing for them (D2.8). The change replaces the error with a top-level `skippedResources`
array in the output of `Start-WARACollector`, one record per skipped resource, and one
aggregated warning from function scope. It edits one source file (`wara.psm1`), one test file
(`wara.tests.ps1`), three documentation pages and `CHANGELOG.md`. No exported function,
parameter or `FunctionsToExport` entry changes.

Section references such as A1, B3, C1, D2 and F1 point to the investigation,
`0003-surface-skipped-resources-investigation.md`. Line numbers refer to the release
branch at `64517cb`.

#### What it delivers

- **The record (D2.8, B2).** A resource is skipped when `WARAinScopeResTypes.csv` flags its
  type as covered but `recommendations.json` has no recommendation for the type, automated
  or manual, so no check runs for it: validation ends at outcome 4 and no recommendation
  of the type is `Active`. It has no APRL verdict: it is neither compliant nor
  non-compliant, and neither "covered" nor "uncovered". Each skipped resource is one
  record with seven string properties: `id`, `name`, `type`, `location`, `subscriptionId`,
  `resourceGroup` and `reason`. This issue defines one reason code,
  `NoMatchingRecommendation`.
- **The output key (B3, B7).** `skippedResources` is a top-level key of the object
  `Start-WARACollector` builds, so it is in the `-PassThru` object and in the JSON file. It
  is always an array, empty when nothing is skipped and never `$null` or omitted, and it
  has no cap. It goes through the same tag filter as `impactedResources` only when it has
  entries (C1), and it is sorted after that filter (C4, C10).
- **The warning (B4, C5).** One `Write-Warning` per run, from function scope after the tag
  filter, built from the list the output holds. It gives the counts, names the ten largest
  types, says that no APRL verdict was produced because `recommendations.json` has no
  automated or manual recommendation for the type although the CSV flags it as covered, and
  points to `skippedResources` for the IDs. It claims no cause. The class `Write-Error` is
  removed, and the class writes to no stream.
- **Behavior (B5, B6).** A skipped resource has no row in `impactedResources`: automated
  rows exist only for types that have a recommendation, and the validation step gives rows
  only to the resources it does not skip. Row counts and the workbook the analyzer builds
  stay as they are. Because a skipped resource raises no error, an explicit
  `-ErrorAction Stop` or a global `Stop` no longer aborts the run at the first one.
  `-WarningAction Stop` is the fail-fast switch.
- **Documentation and release (B8, B11).** The comment-based help and the hand-maintained
  page of `Start-WARACollector` carry the same `OUTPUTS` text, the class pages describe the
  new class, and `CHANGELOG.md` gets a `### Minor` entry that states the behavior change.
- **Lint baseline (D2.7).** The lint findings that the edited files already carry are
  cleared in a first commit, so the lint gates of `implement-issue` hold.
- **Follow-up issues (B10).** The other gaps the investigation found become issues on the
  board during implementation, one Definition-of-done checkbox each.

#### The contract this plan commits to

The shape the maintainer is agreeing to, with values from the test fixture:

```json
"skippedResources": [
  {
    "id": "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-A1/providers/Microsoft.Network/vpnSites/vpnSite1",
    "name": "vpnSite1",
    "type": "Microsoft.Network/vpnSites",
    "location": "eastus",
    "subscriptionId": "11111111-1111-1111-1111-111111111111",
    "resourceGroup": "rg-A1",
    "reason": "NoMatchingRecommendation"
  }
]
```

The matching warning, written once per run:

```text
WARNING: 4 resource(s) of 1 type(s) received no APRL verdict: recommendations.json has no automated or manual recommendation for the type, although WARAinScopeResTypes.csv flags the type as covered. The resource IDs are in 'skippedResources'. Types (resources): Microsoft.Network/vpnSites (4).
```

- **Stable once released (B2, C11):** the key name and its presence in every output as an
  array; the seven property names, all strings; the code `NoMatchingRecommendation`; and the
  order, `type` then `id` under `System.StringComparison.OrdinalIgnoreCase`. Properties
  and codes may be added later, and a reader of the file ignores the ones it does not know.
- **Not part of the contract:** the wording of the warning and its ten-type limit, and the
  name of the PowerShell class.

#### Out of scope

The gaps in the follow-up table below (F1 to F11) stay out: rows or analyzer support for
skipped resources, failed automated queries, outcome 1, Advisor coverage,
`Available in APRL/ADVISOR?`, manual-row labels, making the existing `-PassThru` test
hermetic (the mock rename of D2.7 is its only edit), plan-approval tooling, the rest of the
output documentation, the empty-input rejection of `Get-WAFFilteredResourceList` and the
exit code of `tools/Invoke-Pester.ps1`. The guard of C1 is correct whether or not F10 later
relaxes that function, so F10 is not folded in. `wara.psd1`, `scope.psm1`, `collector.psm1`,
the analyzer, the report generator and `README.md` are not changed.

#### Resolved from the investigation's deferred decisions (D2)

Each decision states what was decided and why. The Phase A review accepted all of them as
written, and confirmed the commit strategy below.

- **D2.1 Record type.** Decision (confirmed): a class, `skippedResourceObj`, with the seven
  `[string]` properties, defined directly after `aprlResourceObj` with the same
  help-comment header as its neighbors. The module's other output records are classes
  (`aprlResourceObj`, `aprlResourceTypeObj`, `advisorResourceObj`), and
  `wara-module-classes.md` documents them. A module's classes are not visible to a test's
  own scope (confirmed in an experiment: "Unable to find type"), so unit tests create and
  check instances inside `InModuleScope 'wara'`, and end-to-end tests read the
  `-PassThru` object by property name, as the existing test does for
  `advisory[0].gettype().Name`. Alternative considered: a `PSCustomObject` built in the
  loop; one class fewer, but the shape is then defined only by the code.
- **D2.2 How the list leaves the class.** Decision (confirmed):
  `Build-ValidationResourceObj` gains an optional `-SkippedResources` parameter, a
  `List[skippedResourceObj]` that is not mandatory (a mandatory collection parameter
  rejects an empty list, C1) and defaults to a new empty list. Before it calls
  `createValidationResourceObjects()` the function assigns
  that list to a new `SkippedResources` property of the factory, which defaults to its own
  empty list, so outcome 4 adds its records to the caller's list in place. The constructor,
  the `return , $r` of the rows and the append at `wara.psm1:397` stay as they are (C6).
  `Start-WARACollector` creates the list and passes it at the one call site
  (`wara.psm1:391`). The function appends to the list and never clears it. An experiment
  confirmed the list is filled in place (22 of 22 records), the parameter can be omitted,
  and a factory works on its own. The function is not in `FunctionsToExport`, so no
  exported signature changes. Alternative considered: a composite return of rows and list;
  C6 rejects it because it rewrites the call site and the append.
- **D2.3 Where the sort and the warning live.** Decision (confirmed): a new internal function,
  `Build-SkippedResourceObj`, named like its four `Build-` siblings, with a singular noun
  and `[OutputType([object[]])]`. It takes the tag-filtered list, sorts it by `type` and
  then `id` with `OrdinalIgnoreCase`, writes the one warning when the list has entries, and
  returns the sorted array with the unary comma. `Start-WARACollector` calls it once, after
  the tag-filter block (after `wara.psm1:466`), and stores the result as
  `skippedResources`. One function, because the message and the record then come from the
  same list by construction (C5), and because the unit layer of B9 can then pin the order,
  the ten-type limit and the empty case without running the collector. Experiments on
  PowerShell 7.6.6 verified the sort with LINQ `OrderBy` then `ThenBy` and
  `[System.StringComparer]::OrdinalIgnoreCase` (the module already uses LINQ in
  `Get-WAFFilteredResourceList`): 133 ms for 20,000 records, and the order `vm-a`, `vm.a`,
  `vm1`, `VmB`, `vm_a`, where `Sort-Object` under this machine's culture (`en-CA`) gives
  `vm_a`, `vm-a`, `vm.a`, `vm1`, `VmB`. The per-type counts in the warning come from
  `Group-Object`, which ignores case, and a stable descending sort over the type-ordered
  groups, so tied types list in type order. Alternative considered: inline in
  `Start-WARACollector`; smaller, but the order, the limit and the empty case are then
  reachable only through the collector.
- **D2.4 Casing of `type`.** Decision (confirmed): keep what the validation resource carries.
  Impacted-resource objects take the recommendation's casing and inventory entries take
  Resource Graph's (C9), so one type can show two casings in one list. The contract
  compares `type` case-insensitively, and both the order and the warning's counts already
  ignore case. Alternative considered: lower-case it to match Resource Graph and
  `advisory`; that adds a normalization rule that `impactedResources` does not follow.
- **D2.5 Where the follow-up checkboxes live.** Decision (confirmed): the Definition of done, one
  checkbox per follow-up, ticked when the issue is on the board. Acceptance criteria are
  feature-specific conditions, and raising an issue is a process step. Alternative
  considered: the Acceptance criteria.
- **D2.6 Final contract names.** Decision (confirmed): the names in the contract above stand
  as written; they are fixed once released (C11). C10 asks that the comparison be named: this
  plan names `OrdinalIgnoreCase`, which folds to upper case, so `_` sorts after the
  letters.
- **D2.7 Lint findings in the edited files (new, from the survey).** At `64517cb`,
  `tools/Invoke-PsScriptAnalyzer.ps1` exits 1 on both PowerShell files this issue edits.
  `wara.psm1` has 9 findings: `PSUseShouldProcessForStateChangingFunctions` on
  `Start-WARACollector`; five `PSUseOutputTypeCorrectly`, on the four `Build-` functions
  and `Get-WARAOtherRecommendations`; `PSUseSingularNouns` on `Get-WARAOtherRecommendations`;
  and two `PSAvoidUsingCmdletAliases`, `group` and `where` at line 969. `wara.tests.ps1`
  has 6 `PSUseDeclaredVarsMoreThanAssignments`, at lines 13, 19, 25, 31, 37 and 308.
  `tools/Invoke-MarkdownLint.ps1` reports 22 findings in `docs/wara/Start-WARACollector.md`
  (19 `MD022`, 2 `MD034`, 1 `MD059`) and none in the other docs this plan edits. Steps 3, 6
  and 7 of `implement-issue` require that no violation remains in the modified files, and
  the Definition of done requires that all modified Markdown files pass lint, so the
  findings are cleared here rather than deferred. Decision (confirmed): one first commit,
  `chore(#3)`, so the feature diff stays reviewable, with these fixes:
  - `[OutputType([object[]])]` on the five functions.
  - `Group-Object` and `Where-Object` in place of the two aliases.
  - `Get-WARAOtherRecommendations` renamed to `Get-WARAOtherRecommendation`: the
    definition, the call in `Start-WARACollector`, and in the tests the mock, the
    `Describe` and the call.
  - A `SuppressMessageAttribute` for `PSUseShouldProcessForStateChangingFunctions`, with a
    justification, on `Start-WARACollector`. `SupportsShouldProcess` would add `-WhatIf`
    and `-Confirm` to an exported function, and `-WhatIf` would skip only the output-file
    write while the Azure queries still ran.
  - In the tests, the five unused `$result = Start-WARACollector ...` assignments become
    `$null = Start-WARACollector ...`, and the sixth becomes a `Should -Not -Throw`
    assertion, which is all that test checks today.
  - In `Start-WARACollector.md`, a blank line under 19 headings, the two bare URLs in angle
    brackets (the stale `-RecommendationResourceTypesUri` default text stays for F9), and
    descriptive text for the `[here]` link.

  Alternative considered: leave the findings and raise a chore issue; the lint gates of
  `implement-issue` then cannot be met for this issue.
- **D2.8 Definition of skipped (revises B1; added after the implementation review).**
  Decision (confirmed 2026-10-13): a resource is skipped when `WARAinScopeResTypes.csv`
  flags its type as covered but `recommendations.json` has no recommendation for the type,
  automated or manual, so no check runs for it. The test is that no recommendation of the
  type has `recommendationMetadataState` `Active`. A `Disabled` recommendation does not
  count, so a type whose recommendations are all disabled is skipped, because the outcome
  is the same as for a type with none. A resource whose type has any `Active`
  recommendation is never listed, even when it gets no manual-validation row.

  B1 listed every resource that ends at outcome 4, which also listed a type that has
  recommendations but no manual one to validate. In the live metadata that is
  `virtualMachineScaleSets`: six automated queries that run, two automated recommendations
  with a `recommendationTypeId`, and one manual recommendation that also has one. The test
  for a fully automated type counts that manual recommendation, and the filter for manual
  rows excludes it because of its type ID, so the type falls through to outcome 4 although
  automated queries cover it. B1's rationale, that a skipped resource has neither an
  automated nor an Advisor finding, did not hold for such a type, and neither did the
  contract sentence that a skipped resource has no row in `impactedResources` (C9 noted
  the overlap only as a casing question). A scratch run of `Start-WARACollector -PassThru`
  on the fixture, with the three manual API Management recommendations deactivated, gave
  `impactedResources` the same 39 rows on the module at `64517cb` and on the branch at
  `24b4c43`. The four API Management resources carry 3, 2, 1 and 1 automated rows; the
  old code raised its error for them and the first implementation lists them as skipped,
  so the rows were always there and the list contradicted the contract.

  The rule applies at outcome 4 only. `createValidationResourceObjects()` computes once the
  set of types that have an `Active` recommendation, and records a resource that reaches
  outcome 4 only when its type is not in that set. A resource whose type has a
  recommendation but no manual one to validate gets neither a row nor a record, as at
  outcome 1. Outcomes 1 to 3 and every other section are unchanged, and so are the record,
  its `reason` code, the key, the order and the preference behavior. The wording changes
  from "no qualifying recommendation" to "no automated or manual recommendation for the
  type" in the warning, the help and the documentation. Not fixed here: a type whose
  recommendations are all automated and all disabled is caught by outcome 1 first and is
  dropped without a record (F3).

  The change is a fourth commit, `fix(#3)`, on top of the first three, so the history is
  not rewritten. Alternatives considered: keep B1's rule and correct only the wording, so
  that `virtualMachineScaleSets` stays listed under a description that says only that
  validation added no manual row; and leave the text as it is and raise the question as a
  follow-up. Both keep a list that mixes "no check exists" with "automated checks cover
  this type", which is the distinction the contract exists to make.

#### Findings from the context survey that refine the investigation

- **Anchors hold.** The plan worktree is at `64517cb`, equal to the tip of
  `release/20260910`, and the line references in the investigation (`wara.psm1` for A1, A4
  and D1, `wara.tests.ps1` for A6, `scope.psm1:294-295` for C1) match the current files.
- **Baselines.** The full suite passes 115 of 115 in about 29 seconds in a fresh process
  (`tools/Invoke-Pester.ps1 src/tests/`, exit 0). The lint baselines are in D2.7.
- **Mechanics verified in a scratch module outside the repository (PowerShell 7.6.6).**
  - The list is filled in place (D2.2). Whether it holds none, one or many records, the
    value that reaches the output is an `Object[]`: the serialized key is `[]` or an array
    of objects, and the round trip through `ConvertFrom-Json` is an array in all three
    cases (C3).
  - `-WarningVariable` on the exported function captures the one warning that a helper
    function it calls writes, and `-ErrorVariable` and `$Error` stay empty. A `Stop`
    preference inside the module does not abort the validation function, and
    `-ErrorAction Stop` and `$global:ErrorActionPreference = 'Stop'` on the exported
    function both complete with the full result. `-WarningAction Stop` throws
    `ActionPreferenceStopException` and returns nothing (B6).
  - A stand-in for the tag filter that is called only when the list has entries completes
    on zero entries, and a filter that keeps nothing yields `[]` with no warning (C1).
  - Declaring `[OutputType([object[]])]` on a scratch function that returns an array with
    the unary comma removed the `PSUseOutputTypeCorrectly` finding that five functions in
    `wara.psm1` have today (D2.7).
- **When the fail-fast fires.** Validation runs before the tag filter, so the warning
  cannot be written there (C5). `Build-SkippedResourceObj` runs after the Advisor queries
  and before the outage, retirement, support-ticket and service-health queries, so
  `-WarningAction Stop` ends a run at that point and returns nothing.
- **The old prototype worktree (C14) is still there.** `git worktree list` shows
  `C:/wt/wara/implement` on `issue-000-swallowed-error` at `8683227`. The implementation
  worktree is created inside it by `tools/New-IssueWorktree.ps1`, so create it from the
  release worktree, and do not run `git add -A`, `git clean -ffd` or
  `git worktree remove --force` in the old one.

#### Follow-up issues to raise (B10)

Raised during implementation, with the `raise-issue` workflow, one Definition-of-done
checkbox each (D2.5). F8 and F9 were proposals in the investigation and F10 was added in its
Phase C; all three were confirmed at the Phase A review. F9's basis is updated: after this
issue `OUTPUTS` describes `skippedResources` and nothing else. F11 was not in the plan: it
was found during implementation, when the exit code of `tools/Invoke-Pester.ps1` was
checked. The first column gives the issue that each follow-up was raised as.

| # | Proposed title | Type | Basis |
| --- | --- | --- | --- |
| F1 (#11) | Package skipped resources for assessors | `type:feat` | B5: a skipped resource appears only on the `2.WorkloadInventory` sheet today, not in the analysis sheets |
| F2 (#12) | Record failed automated queries in the collector output | `type:fix` | A7: `Invoke-WAFQueryLoop` writes a console error and continues, leaving no record, so absent results read as compliant (code read; not run) |
| F3 (#13) | Report types whose automated recommendations are all inactive | `type:fix` | A1, A3: outcome 1 ignores `recommendationMetadataState`; no live type is affected today |
| F4 (#14) | Report whether Advisor covers a skipped resource's type | `type:feat` | A3: Advisor silence cannot be told apart from no coverage (21 / 26 / 5 of the 52 skipped types after D2.8; 22 / 26 / 5 of 53 before) |
| F5 (#15) | Derive `Available in APRL/ADVISOR?` from recommendations as well as the CSV flag | `type:fix` | A2: the field echoes the CSV flag only, "Yes" for skipped types and "No" for live `vpnSites` and `dnsResolvers`, which have manual recommendations |
| F6 (#16) | Stop manual-row labels asserting reasons the data does not state | `type:fix` | Of 246 live manual recommendations, 19 are labelled "under development" by the `*Azure Resource Graph*` clause and 21 "cannot be validated with ARGs" by the default clause (empty query), with no marker |
| F7 (#17) | Make the `Start-WARACollector -PassThru` test hermetic | `type:chore` | A6: the CSV mock URI never matches and `Find-Module` is unmocked |
| F8 (#18) | Raise follow-up issues as a standard step of plan approval | `type:chore` | `plan-issue` and `approve-ready-for-implement` have no step for it |
| F9 (#19) | Document the full `Start-WARACollector` output shape | `type:docs` | A4: after this issue `OUTPUTS` describes only `skippedResources`, and the help and docs give `raw.githubusercontent.com` as the default of `-RecommendationResourceTypesUri` while the parameter default is `azure.github.io` |
| F10 (#20) | Stop the collector aborting on an empty filter input | `type:fix` | C2: `Get-WAFFilteredResourceList` rejects an empty list, so the unmodified collector throws at `wara.psm1:427` when Advisor returns nothing in scope (verified with the fixture mocks; the real helper returns `$null` for an empty query), and the tag-filter calls are exposed the same way |
| F11 (#21) | Make `tools/Invoke-Pester.ps1` exit non-zero under `pwsh -File` when a test fails | `type:fix` | Found during implementation: run as `pwsh -File`, the wrapper exits 0 for a failing test, because of its `#Requires -Modules` line, and for a test file that fails to parse, which its `FailedCount` does not count (checked with scratch tests; a call in the same session is not affected) |

#### Commit strategy and sub-issues

Three commits on the feature branch, in this order (confirmed at the Phase A review), and
a fourth that D2.8 adds:

1. `chore(#3)`: the lint fixes of D2.7 in `wara.psm1`, `wara.tests.ps1` and
   `Start-WARACollector.md`, with the body that `.github/COMMIT_GUIDELINES.md` requires for
   source and test files.
2. `feat(#3)`: the source change and its tests, `wara.psm1` and `wara.tests.ps1`. They
   cannot be split, because removing the class `Write-Error` is only correct together with
   the record, the key and the warning, and the tests pin them.
3. `docs(#3)`: `Start-WARACollector.md`, `wara-module-classes.md`, `wara.md` and
   `CHANGELOG.md`.
4. `fix(#3)` (D2.8): outcome 4 records a skipped resource only when its type has no
   recommendation, with the tests, the help and the two documentation pages that follow
   from it: `wara.psm1`, `wara.tests.ps1`, `Start-WARACollector.md` and
   `wara-module-classes.md`. It sits on top of the first three, so the history is not
   rewritten.

The type `feat` follows B8: the guidelines define it as a new capability visible to a
consumer, and the issue's `type:fix` label does not decide the classification.

No sub-issues are warranted: the change is one cohesive contract, reviewed as four
commits. The follow-ups are independent issues, not sub-issues of this one. None blocks
this issue and this issue blocks none; each names issue 3 as its origin.

### Phase B — Document impact

Docs scan: searched `docs/` and `README.md` for the changed names and the behavior being
replaced (`validationResourceFactory`, `Build-ValidationResourceObj`,
`No recommendation found`, `No Recommendations`, `TypesNotInAPRLOrAdvisor`, `Write-Error`,
`-ErrorAction`, `skipped`, and any description of the output file or its keys). No page
describes the class error, the abort behavior or the output keys. Three pages describe
things the change touches: `docs/wara/Start-WARACollector.md` (its `OUTPUTS` section is
empty), `docs/wara/wara-module-classes.md` (the factory and the record classes) and
`docs/wara/wara.md` (the list of the module's classes). Reviewed and unchanged:
`README.md` only shows how to run the collector and pass its file to the analyzer;
`docs/wara/aprlResourceObj.md` is an empty file; `Start-WARAAnalyzer.md` says only that the
analyzer processes the file the collector creates, and `Start-WARAReport.md` does not
mention that file; `docs/wara/contribution-guide.md` asks for documentation and tests with
code changes, which this plan follows.

In-flight scan of `C:\wt\wara\docs\issues\`: the other documents belong to issues 1 and 4,
both merged to the release branch. The only match for the in-scope names and files is a path
mention of `wara.psm1` in the issue 1 investigation, about ignoring runtime-output files,
which this issue does not change. No in-flight plan or investigation is invalidated. This
issue's own investigation is refined by Phase A and is not edited.

### Affected documents

| File | Change needed |
| ---- | ------------- |
| `docs/wara/Start-WARACollector.md` | Commit 1 (D2.7): clear the 22 markdownlint findings: a blank line under the headings at lines 4, 33, 65, 80, 95, 110, 125, 140, 156, 172, 188, 204, 221, 238, 254, 270, 285, 301 and 308, angle brackets around the bare URLs at lines 240 and 256 (the stale `-RecommendationResourceTypesUri` default text stays for F9), and descriptive text for the `[here]` link at line 224. Commit 3: `DESCRIPTION` (line 33) gains the aggregated warning, the no-abort behavior and `-WarningAction Stop` as fail-fast; `OUTPUTS` (line 306, empty today) gets the `skippedResources` contract, worded the same as the `.OUTPUTS` of the comment-based help (C13): the key and its array shape, the seven properties, the `reason` code, the order, the tag filter, and that a skipped resource has no row in `impactedResources`. Commit 4 (D2.8): the description and `OUTPUTS` say that a resource is skipped when `recommendations.json` has no automated or manual recommendation for its type, and that a type with any recommendation is not listed. |
| `docs/wara/wara-module-classes.md` | Commit 3. Diagram (the mermaid block, lines 9-74): a `skippedResourceObj` class box with its seven `string` properties, a `+List~skippedResourceObj~ SkippedResources` entry in the `validationResourceFactory` box (line 53), and the relation `validationResourceFactory ..> skippedResourceObj : creates` (after line 72). A new `skippedResourceObj` section after `aprlResourceObj` (line 124), in the same SYNOPSIS, DESCRIPTION and PROPERTIES form, stating the `reason` code. In the `validationResourceFactory` section (line 182): the new `SkippedResources` property (properties at lines 192-196) and a sentence in the `createValidationResourceObjects()` description that a resource with no verdict is recorded there and gets no row. Commit 4 (D2.8): the `skippedResourceObj` description and the `SkippedResources` property say that no automated or manual recommendation exists for the type. |
| `docs/wara/wara.md` | Commit 3. A bullet for `skippedResourceObj` in the "WARA Classes" list (lines 44-51), after `aprlResourceObj`. |
| `CHANGELOG.md` | Commit 3. A new `### Minor` heading above `### Patch` under `## [Unreleased]`, with one entry that covers the issue; the lint fixes are invisible to users and need no entry of their own. Draft: "Report resources that receive no APRL verdict: `Start-WARACollector` adds a top-level `skippedResources` array to its output and writes one warning per run, in place of an error raised inside a class method. Because no error is raised, `-ErrorAction Stop` and a global `Stop` preference no longer end the run at the first such resource; use `-WarningAction Stop` for fail-fast. (#3)" |

### Affected source files

| File | Change needed |
| ---- | ------------- |
| `src/modules/wara/wara.psm1` | Commit 1 (D2.7): `[OutputType([object[]])]` on `Build-ImpactedResourceObj` (line 572), `Build-ValidationResourceObj` (591), `Build-ResourceTypeObj` (610), `Build-SpecializedResourceObj` (625) and `Get-WARAOtherRecommendations` (640); that function renamed `Get-WARAOtherRecommendation`, with its call at line 409; `Group-Object` and `Where-Object` for the two aliases at line 969; a `SuppressMessageAttribute` for `PSUseShouldProcessForStateChangingFunctions`, with a justification, above the `[CmdletBinding()]` of `Start-WARACollector` (line 76). Commit 2: a new class `skippedResourceObj` after `aprlResourceObj` (line 826), with the help-comment header of its neighbors (D2.1); in `validationResourceFactory` (line 952) a `SkippedResources` property and, at outcome 4 (lines 1021-1023), a recorded `skippedResourceObj` with `reason = 'NoMatchingRecommendation'` in place of the `Write-Error`, with the class help comment updated; in `Build-ValidationResourceObj` the optional `-SkippedResources` parameter, assigned to that property before `createValidationResourceObjects()` is called (D2.2); a new `Build-SkippedResourceObj` directly after it (D2.3); in `Start-WARACollector`, the list created and passed at the call (line 391), a fourth tag-filter call in the tag block (lines 430-466) guarded by the list having entries (C1), the call to `Build-SkippedResourceObj` after that block, the `skippedResources` key after `impactedResources` in `$outputJson` (lines 545-555), and in its comment-based help (lines 1-73) a `.DESCRIPTION` that gains the warning, the no-abort behavior and `-WarningAction Stop`, and a new `.OUTPUTS` section with the contract text of `Start-WARACollector.md` (C13). Commit 4 (D2.8): `createValidationResourceObjects()` computes once the set of types that have an `Active` recommendation, and the final `else` of outcome 4 becomes an `elseif` that records a resource only when its type is not in that set; the warning text, the help and the class help say "no automated or manual recommendation for the type" in place of "no qualifying recommendation". |
| `src/tests/wara/wara.tests.ps1` | Commit 1 (D2.7): the five unused `$result =` assignments (lines 13, 19, 25, 31, 37) become `$null =`; the `Get-WARAOtherRecommendations` mock (line 101), `Describe` (line 298) and call (line 308) take the new name, and the call becomes a `Should -Not -Throw` assertion. Commit 2: the tests of Phase C: the empty `Describe 'Build-ValidationResourceObj'` (line 266) is filled, a `Describe 'Build-SkippedResourceObj'` is added, and a new hermetic `Context` goes under `Describe 'Start-WARACollector'`, beside the `-passthru` one (line 74), whose assertions and mocks stay as they are apart from the renamed mock. Commit 4 (D2.8): T2 to T4 count three records because `t1` is no longer skipped, the `Context` of T9 is renamed, the mock of the recommendations URI reads the `$state` hashtable, and T19 is added. |

Not changed: `src/modules/wara/wara.psd1`, `src/modules/wara/scope/scope.psm1`,
`src/modules/wara/collector/collector.psm1`, the analyzer and report scripts, `README.md`,
and the test data under `src/tests/data/wara/`: the drift fixture of the end-to-end tests is
built at run time from the existing CSV fixture.

### Version impact

**Classification:** `minor`

| Term | Meaning |
| ---- | ------- |
| `major` | Breaking — existing consumers must update |
| `minor` | Additive, non-breaking new capability |
| `patch` | Invisible to consumers — bug fix, doc correction |

**Rationale:** The change adds a top-level output key and a visible warning to
`Start-WARACollector` (the first `Write-Warning` in the module), so it is an additive
capability that anyone reading the output or the host sees; it is not `patch`. The issue's `type:fix` label does
not decide the classification, which follows what a user of the module sees (B8). `major`
is for a change to an exported name, parameter or output section, and none changes here:
every existing output section keeps its content. The one changed behavior,
`-ErrorAction Stop` no longer ending a run at a skipped resource, follows from removing the
class error and is stated in the CHANGELOG entry (B6).

### Testing requirements

All tests are in `src/tests/wara/wara.tests.ps1`; no test data file is added or changed.
The suite has 115 tests today, 16 of them in this file, and passes in about 29 seconds.
This issue adds 19 `It` blocks that generate 22 tests, so the file is expected to report 38
passed and the suite 137 passed with no failures (37 and 136 before the `fix(#3)` commit of
D2.8). Each end-to-end run of the collector takes about 3 seconds and the new tests make 9
of them, so the suite takes about 27 seconds longer.
Run the file and then the suite in a fresh process
(`pwsh -NoProfile -File tools/Invoke-Pester.ps1 <path>`). This concerns the machine that
runs the tests, not users of the module: `InModuleScope 'wara'` finds the module by name, so
a session that already holds a different copy of `wara`, for example one auto-loaded from
the PowerShell Gallery or imported earlier from another path, fails with "Multiple script or
manifest modules named 'wara' are currently loaded". CI does not fail on a failing test
either, so the local run is the gate (C12).
The 115 existing tests are not re-specified; only the three edits in the last table touch
them.

#### How the new tests are built

- **Unit layer.** Inside `InModuleScope 'wara'`, because the module's classes are private
  (D2.1). The fixture of `Build-ValidationResourceObj` is inline: five recommendations and
  seven validation resources over fictitious `Microsoft.Test/...` types named for their
  outcome (table below). Run against the unmodified factory, it gives exactly two rows and
  sends the other four resources to the `Write-Error` branch.
- **End-to-end layer.** One new outer `Context` under `Describe 'Start-WARACollector'`,
  after the `-passthru` one, defines these mocks in its `BeforeAll`, all with
  `-ModuleName 'wara'`: `Find-Module` (returns version 1.0.0), `Connect-WAFAzure`,
  `Invoke-WAFQuery`, `Invoke-WAFQueryLoop`, `Get-WAFAdvisorMetadata`, `Invoke-RestMethod`
  for the recommendations URI and for the resource-types CSV URI, both at the module's
  default values, `Get-WARAOtherRecommendation`, `Get-WAFAdvisorRecommendation`,
  `Get-WAFTaggedResourceGroup`, `Get-WAFTaggedResource`, `Get-WAFOldOutage`,
  `Get-WAFResourceRetirement`, `Get-WAFSupportTicket` and `Get-WAFServiceHealth`, with the
  data files of the existing `-passthru` Context. A scratch run of six scenarios against the
  unmodified module confirmed that this set runs the collector end to end and reproduces the
  figures below: 51 rows for the unchanged CSV, 47 rows and four dropped resources for the
  drift, a tag-scoped run that completes, and `-ErrorAction Stop` aborting.
- **The one-flag drift.** The CSV text is served with
  `yes,Microsoft.Network/vpnSites,VPN Sites,No` replaced by `yes,Microsoft.Network/vpnSites,VPN Sites,Yes`
  at run time, and a guard asserts that the replacement changed the text. The four
  `vpnSites` resources of `test_allresourcesdata.json` then reach outcome 4.
- **Switching fixtures.** The mock bodies read a `$state` hashtable created in the outer
  `BeforeAll` (the CSV text, the recommendations and the two tag lists), so each test sets
  its fixture before its run. The scratch run switched fixtures this way.
- **What can tell the old behavior from the new.** On the unmodified code, a direct call of
  `Build-ValidationResourceObj` that reaches the `Write-Error` branch leaves `$Error` and
  `-ErrorVariable` empty, and throws `WriteErrorException` when `$ErrorActionPreference` is
  `Stop` in module scope; through `Start-WARACollector`, `$Error` gains four records and
  `-ErrorAction Stop` throws. So the unit tests prove "no error" with the `Stop` preference,
  and the end-to-end tests with `$Error` and `-ErrorAction Stop`; asserting on `$Error` or
  `-ErrorVariable` at unit level would pass on both.

The unit fixture, shared by T1 to T4:

| Type | Recommendations | Validation resources | Outcome |
| --- | --- | --- | --- |
| `Microsoft.Test/automatedOnly` | `g-1`: automated | `a1` | 1: no row, no record |
| `Microsoft.Test/manualActive` | `g-2`: manual, `Active`, empty type ID | `m1` | 2: one row |
| `Microsoft.Test/notInAprl` | none; listed in `TypesNotInAPRLOrAdvisor` | `n1` | 3: one "No Recommendations" row |
| `Microsoft.Test/noRecommendation` | none | `r1`, `r2` | 4: skipped |
| `Microsoft.Test/typeIdOnly` | `g-3`: automated; `g-4`: manual, `Active`, with a type ID | `t1` | 4, but not skipped: the type has `Active` recommendations, so no row and no record (mirrors `virtualMachineScaleSets`, A3, D2.8) |
| `Microsoft.Test/disabledOnly` | `g-5`: manual, `Disabled` | `d1` | 4: skipped (no `Active` recommendation, D2.8) |

The four vpnSites of the end-to-end drift, as the fixture holds them (type
`Microsoft.Network/vpnSites`):

| Name | Location | Resource group | Subscription |
| --- | --- | --- | --- |
| `vpnSite1` | `eastus` | `rg-A1` | `11111111-1111-1111-1111-111111111111` |
| `vpnSite2` | `westus` | `rg-A2` | `11111111-1111-1111-1111-111111111111` |
| `vpnSite3` | `eastus2` | `rg-B1` | `22222222-2222-2222-2222-222222222222` |
| `vpnSite4` | `westus2` | `rg-B2` | `22222222-2222-2222-2222-222222222222` |

#### New tests: unit layer, `Describe 'Build-ValidationResourceObj'`

This fills the empty block at line 266. All four are new.

| # | Context | It (Should ...) | Validates and expected outcome |
| --- | --- | --- | --- |
| T1 | `Validation rows` | return the rows of outcomes 2 and 3 and nothing for outcome 1 | A `System.Object[]` of two `aprlResourceObj` rows. For `m1`, `recommendationId` `g-2` and the action `IMPORTANT - Recommendation cannot be validated with ARGs - Validate Resources manually`. For `n1`, an empty `recommendationId` and an action that starts `IMPORTANT - Resource Type is not available in either APRL or Advisor`. No row for `a1`. Row order is not asserted. |
| T2 | `Skipped resources` | record one `skippedResourceObj` per resource whose type has no recommendation | With a list passed in, it holds three records, for `r1`, `r2` and `d1` (compared as a set), and none for `a1`, `m1`, `n1` or `t1`. Each is a `skippedResourceObj` with `reason` `NoMatchingRecommendation` and `id`, `name`, `type`, `location`, `subscriptionId` and `resourceGroup` equal to its validation resource's. `d1` shows that a type with only a disabled recommendation is skipped like a type with none, and `t1` that a type with an `Active` recommendation but no manual one to validate is not skipped (D2.8). |
| T3 | `Skipped resources` | work without the parameter and append to a supplied list | Without `-SkippedResources` the call returns the same two rows. With a list that already holds one record, that record stays first and the three are added after it, four in all. With a table of `a1`, `m1` and `n1` only, a supplied list stays empty and the two rows are returned. |
| T4 | `Streams and preferences` | write no warning and not raise an error | `-WarningVariable` is empty. With `$ErrorActionPreference = 'Stop'` set in module scope the call does not throw, returns the two rows and fills three records. The unmodified code throws `WriteErrorException` here. |

#### New tests: unit layer, `Describe 'Build-SkippedResourceObj'`

A new `Describe`; all four `It` blocks are new and generate seven tests.

| # | Context | It (Should ...) | Validates and expected outcome |
| --- | --- | --- | --- |
| T5 | `Order` | sort by type and then id with OrdinalIgnoreCase | Seven records given in shuffled order: types `Microsoft.Network/vpnSites`, `microsoft.compute/disks` and `Microsoft.Compute/virtualMachines`, the last with ids ending `vm_a`, `vm-a`, `vm.a`, `vm1` and `VmB`. They come back as the `disks` record, then the five virtual machines ending `vm-a`, `vm.a`, `vm1`, `VmB`, `vm_a`, then the `vpnSites` record. A culture sort such as `Sort-Object` under `en-CA` orders the five ids `vm_a`, `vm-a`, `vm.a`, `vm1`, `VmB`, so the test separates the comparer from it. |
| T6 | `Shape` | always return an array and warn only when there is something to report, with `-ForEach` over 0, 1 and 3 records in a `List[skippedResourceObj]`, and 3 records in an `object[]` (what the tag filter returns) | The result is an array (`GetType().IsArray`) with that many entries. Wrapped as `[PSCustomObject]@{ skippedResources = $result }` and serialized with `ConvertTo-Json -Depth 15`, the key reads back through `ConvertFrom-Json` as an array with that many entries, `[]` for none (C3). `-WarningVariable` holds no warning for none and exactly one otherwise. Four generated tests. |
| T7 | `Warning` | write one warning with the counts, the per-type counts and the pointer | Five records: two of `Microsoft.Compute/availabilitySets` in different casings and three of `Microsoft.Network/vpnSites`. One warning containing `5 resource(s)`, `2 type(s)`, `Microsoft.Network/vpnSites (3)`, the availability-set count of 2 matched without regard to case, and `skippedResources`. The `vpnSites` entry comes first: count order, not type order. `-ErrorVariable` is empty. |
| T8 | `Warning` | name the ten largest types and count the rest | Twelve types `Microsoft.Test/t01` to `t12`: `t11` and `t12` with five records each, `t10` with three, the other nine with one. The text gives `22 resource(s)` and `12 type(s)`, lists `t11 (5)`, `t12 (5)`, `t10 (3)`, then `t01` to `t07` with one each in type order, and ends `and 2 more types`; `t08` and `t09` are absent. A cut by type order would list `t01` to `t10`, so the test separates the two. |

#### New tests: end to end, `Describe 'Start-WARACollector'`

Five `Context`s nested in the outer one, which supplies the mocks above; all eleven `It`
blocks are new. The first nested `Context` runs the collector once in its own `BeforeAll`,
and the others run it inside each `It`. Expected figures for the drift are the unmodified
collector's for the same fixture, except where a test says otherwise.

| # | Context | It (Should ...) | Validates and expected outcome |
| --- | --- | --- | --- |
| T9 | `When the CSV flags a type as covered that has no recommendation` | list the four vpnSites resources in skippedResources, sorted | Run once in `BeforeAll`, no tags. Four records in the order `vpnSite1` to `vpnSite4`, with their full IDs, the values of the vpnSites table, type `Microsoft.Network/vpnSites` and reason `NoMatchingRecommendation`. Serialized, the key reads back as an array of four. |
| T10 | same | leave the other sections as they are | `impactedResources` has 47 rows and none of type `Microsoft.Network/vpnSites`; `resourceInventory` has 16 entries and `advisory` 4. |
| T11 | same | write one warning and no error | `-WarningVariable` holds one warning containing `4 resource(s)`, `1 type(s)`, `Microsoft.Network/vpnSites (4)` and `skippedResources`. `$Error`, cleared before the run, gains no record; the unmodified collector gains four. |
| T12 | `When a preference turns a message into a stop` | complete under `-ErrorAction Stop` | The run returns the object, with four skipped records. The unmodified collector throws `WriteErrorException` and returns nothing. A global `Stop` preference behaves like the explicit parameter (A2), so one test covers both. |
| T13 | same | fail fast under `-WarningAction Stop` | The call throws `ActionPreferenceStopException` and returns no object (B6). |
| T14 | `When the run is scoped with -Tags` | filter the list by tag and sort it after the filter | The tag mocks return resource group `rg-B1` of subscription 2222 (it holds `vpnSite3`) and the resource ID of `vpnSite1`. `skippedResources` is `vpnSite1`, then `vpnSite3`: the filter returns resource-group matches before resource matches, so a sort placed before the filter would give the reverse (C4). The warning says `2 resource(s)`, matching the list (C5). |
| T15 | same | serialize a single record as an array | With the resource list matching nothing, only `vpnSite3` remains, and the key reads back as an array of one (C3). |
| T16 | same | return an empty array and no warning when the filter keeps nothing | Tag lists that match none of the four give an empty array, no warning and no abort, although the filter receives four records. |
| T17 | `When no resource is skipped` | return an empty array and no warning | The CSV is unchanged and there are no tags: `skippedResources` reads back as an empty array and `-WarningVariable` is empty. |
| T18 | same | complete with `-Tags` when nothing is skipped | With the default tag mocks (`rg-B1` and `apiService1`) the run completes, `skippedResources` is an empty array and there is no warning. Without the guard of C1, the empty list fails parameter binding in `Get-WAFFilteredResourceList` and the run aborts. |
| T19 | `When a type has a recommendation but no manual one to validate` | not list the resources of a type that automated queries cover | The recommendations the mock serves have the three manual API Management recommendations set to `Disabled` and keep the three automated ones; the CSV is unchanged and there are no tags. `skippedResources` is an empty array and no warning is written. `impactedResources` has 39 rows, 7 of them automated rows of `apiService1` to `apiService4`, and no ID is in both `impactedResources` and `skippedResources`. The first implementation (D2.8) lists all four resources as skipped here, with the same 39 rows. |

#### Modified tests

All three are mechanical consequences of D2.7 and go in the `chore(#3)` commit; none
changes an assertion.

| # | Describe and location | Test | Change |
| --- | --- | --- | --- |
| M1 | `Start-WARACollector Parameter Sets`, lines 13, 19, 25, 31 and 37 | the five `Should proceed ...` tests | The unused `$result` assignment becomes `$null =`. |
| M2 | `Start-WARACollector`, `Context` `When given correct parameters with -passthru`, line 101 | Should run and return an object that can be measured | The mock of `Get-WARAOtherRecommendations` takes the new name `Get-WARAOtherRecommendation`; the 51-row assertions and every other mock stay. |
| M3 | `Get-WARAOtherRecommendations`, lines 298 to 308 | Should return the right stuff | The `Describe` and the call take the new name, and the unused `$OtherRecommendations` assignment becomes a `Should -Not -Throw` assertion on the call. |

#### Manual checks

No testbed artifact applies. Each check's command and output go in the pull request body and
are named in the acceptance-criteria verification table at `implement-issue` Step 5.

- **V1 The analyzer reads the file with the new key.** The investigation read the analyzer's
  code (A4) and did not run it. Generate the drift output of T9 in a scratch Pester file
  outside the repository, using a copy of the new `Context`'s mocks. Write it with
  `ConvertTo-Json -Depth 15` to a scratch folder twice, once as it is and once with the
  `skippedResources` key removed, and run `Start-WARAAnalyzer -JSONFile` on each in that
  folder. Expected: both runs behave the same, with the same worksheets and row counts. It
  needs the `ImportExcel` module and network access to the recommendations and resource-types
  URIs, which the analyzer fetches.
- **V2 A live run, when a tenant is available.** For a scope that holds a resource of a type
  that reaches outcome 4 (for example an availability set or a snapshot, A3), run
  `Start-WARACollector -PassThru`: it completes, writes one warning, and `skippedResources`
  lists the resource; with `-WarningAction Stop` it ends with no output. Without a tenant,
  T9 to T19 are the evidence. Run it again after the `fix(#3)` commit (D2.8): a type that
  has recommendations, such as `virtualMachineScaleSets`, is no longer listed, and no ID is
  in both `skippedResources` and `impactedResources`. Report counts only, never identifiers.
- **V3 The help and the page agree (C13).** `Get-Help Start-WARACollector -Full` shows the
  new description sentences and the `OUTPUTS` text, and
  `docs/wara/Start-WARACollector.md` carries the same wording. Run again after the
  `fix(#3)` commit (D2.8).
- **V4 The tests can fail.** After they pass, add the `Write-Error` line back next to the
  record at outcome 4 and confirm that T4, T11 and T12 fail, T4 with `WriteErrorException`;
  then remove it. This shows the "no error" assertions are not vacuous.
- **V5 The guard can fail (D2.8).** After the tests pass, change the `elseif` of outcome 4
  back to `else` and confirm that T2 and T19 fail; then restore it. This shows that the
  tests pin the rule, not only the record.

#### Gates

1. After the `chore(#3)` commit: the file reports 16 passed and the suite 115 passed, and
   `tools/Invoke-PsScriptAnalyzer.ps1` exits 0 on `wara.psm1` and `wara.tests.ps1` (D2.7).
2. After the `feat(#3)` commit: the file reports 37 passed and the suite 136 passed, each
   in a fresh process, and the lint exits 0 again.
3. After the `fix(#3)` commit (D2.8): the file reports 38 passed and the suite 137 passed,
   each in a fresh process, and the lint exits 0 again.
4. V1 to V5 are run and recorded before the pull request is opened.

### Acceptance criteria

- [x] D1. Key shape. Every `Start-WARACollector -PassThru` result has a top-level
      `skippedResources` key that is an array: empty when nothing is skipped, never `$null`
      and never omitted. Serialized with `ConvertTo-Json -Depth 15`, the key reads back as
      `[]` for none and as an array of objects for one or more. The JSON file is written
      from the same object. (T6, T9, T15 to T18)
- [x] D2. Records. A resource is listed once, as a record with the seven string properties
      `id`, `name`, `type`, `location`, `subscriptionId`, `resourceGroup` and `reason`,
      taken from its validation resource, with `reason` `NoMatchingRecommendation`, when
      `WARAinScopeResTypes.csv` flags its type as covered and `recommendations.json` has no
      recommendation for the type, automated or manual: a type with no recommendation and a
      type whose recommendations are all disabled are both skipped. A type that has an
      `Active` recommendation is not listed, including one whose recommendations are an
      automated one plus a manual one that carries a `recommendationTypeId`, even though it
      gets no manual-validation row. Resources that end at outcomes 1 to 3 are not listed.
      (T2, T9, T19, V5)
- [x] D3. Rows. A skipped resource gets no row, and no ID is in both `impactedResources` and
      `skippedResources`. For the drift fixture `impactedResources` has 47 rows and none of
      type `Microsoft.Network/vpnSites`, outcomes 1 to 3 give the rows they give today, and
      the existing `-passthru` test still reports its 51 rows. (T1, T10, T19, M2)
- [x] D4. Order. Records are ordered by `type` and then `id` under
      `System.StringComparison.OrdinalIgnoreCase`, applied after the tag filter: `vm-a`,
      `vm.a`, `vm1`, `VmB`, `vm_a` for the five virtual machine ids of T5, and `vpnSite1`
      before `vpnSite3` when the tag filter returns them the other way round. (T5, T9, T14)
- [x] D5. Tags. With `-Tags`, `skippedResources` holds only the skipped resources that
      remain in scope after the tag filter. A tag-scoped run that skips nothing completes
      and returns `[]`, because the tag filter is called with the list only when it has
      entries. (T14 to T16, T18)
- [x] D6. Warning. When at least one resource is skipped, the run writes exactly one
      warning from function scope, which `-WarningVariable` captures. It gives the resource
      and type counts (types counted without regard to case), names the ten largest types
      with their counts, largest first and ties in type order, adds `and N more types` for
      the rest, says that no APRL verdict was produced because `recommendations.json` has
      no automated or manual recommendation for the type although the CSV flags it as
      covered, and points to `skippedResources`. Its counts are those of the list the
      output holds, also under `-Tags`. When nothing is skipped, no warning is written.
      (T6 to T8, T11, T14, T17)
- [x] D7. No error. Nothing is written to the error stream for a skipped resource: outcome 4
      no longer calls `Write-Error`, `Build-ValidationResourceObj` writes no warning and
      does not throw under a `Stop` preference in module scope, and `$Error` gains no record
      during a run through `Start-WARACollector`. With the `Write-Error` line put back, T4,
      T11 and T12 fail. (T4, T11, V4)
- [x] D8. Preferences. `-ErrorAction Stop` completes and returns the full object with its
      `skippedResources`; `-WarningAction Stop` throws `ActionPreferenceStopException` and
      returns no object. (T12, T13)
- [x] D9. No exported change. `src/modules/wara/wara.psd1` is not in the diff, so
      `FunctionsToExport` is as it is, and the `param` block of `Start-WARACollector` is
      not in the diff. (`git diff origin/release/20260910`)
- [x] D10. Internal functions. `Build-ValidationResourceObj` takes an optional,
      non-mandatory `-SkippedResources` list that it fills in place and appends to without
      clearing, and it works with the parameter omitted. `Build-SkippedResourceObj` returns
      the sorted records as an array with the unary comma, declares
      `[OutputType([object[]])]`, and accepts a `List[skippedResourceObj]` and an
      `object[]`. (T3, T6)
- [x] D11. Help and page. The comment-based help of `Start-WARACollector` and
      `docs/wara/Start-WARACollector.md` carry the same new description sentences (the
      warning, the absence of an abort, `-WarningAction Stop` for fail-fast) and the same
      `OUTPUTS` text: the key and its array shape, the seven properties, the `reason` code,
      the order, the tag filter, that a skipped resource has no row in `impactedResources`,
      that a type with any recommendation is not listed and that a `Disabled` recommendation
      does not count, and that a reader ignores properties and codes it does not know. (V3)
- [x] D12. Class pages. `docs/wara/wara-module-classes.md` shows `skippedResourceObj` in the
      diagram and in a section after `aprlResourceObj`, with the `SkippedResources` property
      of `validationResourceFactory`, and `docs/wara/wara.md` lists the class. (file diff)
- [x] D13. CHANGELOG. `CHANGELOG.md` has a `### Minor` heading above `### Patch` under
      `## [Unreleased]`, with one entry that names the new key and the warning, states that
      `-ErrorAction Stop` no longer ends a run at a skipped resource, and names
      `-WarningAction Stop` for fail-fast. (file diff)
- [x] D14. Lint baseline. The findings of D2.7 are gone: `tools/Invoke-PsScriptAnalyzer.ps1`
      exits 0 on `wara.psm1` and `wara.tests.ps1` (9 and 6 findings at `64517cb`),
      `tools/Invoke-MarkdownLint.ps1` exits 0 on `docs/wara/Start-WARACollector.md` (22
      findings), and `Get-WARAOtherRecommendations` appears nowhere under `src/`. (tool exit
      codes; a search for the old name)
- [x] D15. Analyzer. `Start-WARAAnalyzer` behaves the same on the drift output with and
      without the `skippedResources` key: the same worksheets and row counts, or the same
      failure point if the file generated from the fixture cannot be analyzed at all. (V1)

### D16. Sizing estimate

**Estimate:** M

| Driver | Weight | Reasoning |
| ------ | ------ | --------- |
| Commit 2: source change in `wara.psm1` (the class, the factory, `Build-ValidationResourceObj`, `Build-SkippedResourceObj`, `Start-WARACollector` and its help) | High | About 150 lines across five places in one file, with silent failure modes that each need their own test: the empty-list binding of the tag filter (C1), the array shape (C3), the filter's reordering (C4) and a warning that disagrees with the record (C5) |
| Commit 2: tests in `wara.tests.ps1` | High | 18 `It` blocks generating 21 tests, a seven-resource inline fixture, a 15-mock hermetic setup with switchable state and 8 collector runs; module-private classes force `InModuleScope`, and the "no error" assertions must be chosen so that they can fail (T4, V4) |
| Commit 1: lint baseline in `wara.psm1`, `wara.tests.ps1` and `Start-WARACollector.md` | Medium | 15 PowerShell and 22 Markdown findings, mechanical, but the rename touches five references in two files including the existing `-passthru` test, and a second analyzer run after the edits can show findings the first did not |
| Follow-up issues F1 to F10 | Medium | Ten issues written from the B10 table and put on the board during implementation, each with a body, labels and a milestone |
| Verification V1 to V4 and fresh-process runs | Medium | V1 runs the analyzer on generated JSON and needs `ImportExcel` and network access; V4 edits and restores the source; the suite takes about a minute per run |
| Commit 3: four documentation files | Low | Bounded prose and one diagram edit; the help and the page carry the same text (C13) |
| Deferred design | Low | All seven decisions of D2 are settled in Phase A, and their mechanics were checked in scratch experiments |

Same size as the investigation's estimate, at the upper end of `M`. The lint baseline (D2.7)
adds a first commit that the investigation had not sized, but its findings are listed and
mechanical. Both upgrade triggers of the investigation are gone: F10 is not folded in, and a
scratch run showed that the end-to-end tests need no mock beyond the existing `Context`'s set
plus `Find-Module` and the corrected CSV URI.

Primary uncertainty drivers:

- Whether V1 can run and agree: the analyzer fetches two URIs and needs `ImportExcel`, and
  its handling of the new key was only read (A4). A rejection would change the contract or
  the scope (B3).
- Whether the lint baseline stays mechanical: the analyzer is run again after the edits, and
  the suppression's justification and the rename are reviewed.
- Whether the end-to-end `Context`s behave as the scratch run did: switching the CSV and the
  tag lists through the `$state` hashtable was checked in a flat scratch file against the
  unmodified module, not in nested `Context`s with their own `BeforeAll`.
- How much each follow-up issue needs beyond the basis column of B10.

*Upgrade to L if V1 or the end-to-end tests show that the contract has to change, for example
the analyzer rejecting the new key or the tag filter needing a change in `scope.psm1`, or if
clearing the lint baseline needs behavior changes beyond the fixes of D2.7.*

### Definition of done

The manual smoke test item is met by V1, and by V2 where a tenant is available; no testbed
artifact applies. The follow-up items are ticked when the issue is on the board (D2.5); each
is raised with the `raise-issue` workflow and names issue 3 as its origin.

- [x] All acceptance criteria verified
- [x] All affected documents updated
- [x] All tests in Testing Requirements written and passing
- [x] Full PowerShell suite (`tools/Invoke-Pester.ps1 src/tests/`) green
- [x] The file and the suite are run in a fresh process (`pwsh -NoProfile`):
  `src/tests/wara/wara.tests.ps1` reports 38 passed and the suite 137 passed, with no
  failures
- [x] Manual smoke test passed (verify behavior against testbed artifacts, where applicable)
- [x] Manual checks V1 to V5 run, with their commands and output recorded in the pull
  request body
- [x] Scratch files from V1 and V2 removed and the V4 and V5 edits reverted, so that
  `git status` shows only the planned files
- [x] `tools/Invoke-PsScriptAnalyzer.ps1` exits 0 on every modified PowerShell file
- [x] CHANGELOG entry added with correct classification
- [x] All modified Markdown files pass lint
- [x] The work is committed as `chore(#3)`, `feat(#3)`, `docs(#3)` and `fix(#3)`, in that
  order, each message following `.github/COMMIT_GUIDELINES.md`
- [x] F1 raised as #11: Carry skipped resources into the analyzer and report outputs (`type:feat`)
- [x] F2 raised as #12: Record failed recommendation queries in the collector output (`type:fix`)
- [x] F3 raised as #13: Report types whose automated recommendations are all disabled (`type:fix`)
- [x] F4 raised as #14: Report whether Advisor covers the type of a skipped resource (`type:feat`)
- [x] F5 raised as #15: Derive `Available in APRL/ADVISOR?` from recommendations as well as the CSV
  flag (`type:fix`)
- [x] F6 raised as #16: Stop manual-row labels asserting reasons the data does not state
  (`type:fix`)
- [x] F7 raised as #17: Make the `Start-WARACollector -PassThru` test hermetic (`type:chore`)
- [x] F8 raised as #18: Raise follow-up issues as a standard step of plan approval (`type:chore`)
- [x] F9 raised as #19: Document the full `Start-WARACollector` output shape (`type:docs`)
- [x] F10 raised as #20: Stop the collector aborting on an empty filter input (`type:fix`)
- [x] F11 raised as #21: `tools/Invoke-Pester.ps1` exits 0 under `pwsh -File` when a test fails (`type:fix`)
- [x] PR opened targeting the release branch (#22)

## Reflection

**Estimate:** `M`

**Actual:** Harder, by about one size (4 commits, 6 files, 717 lines added): the change
itself matched `M`, but redefining "skipped" (D2.8) and grounding eleven follow-ups added
a fourth commit and a second round of verification that the estimate did not include.

**Drivers that materialised:**

- Commit 2, source change in `wara.psm1` (High), and the silent failure modes: as
  estimated, at 151 changed lines against about 150; the empty-list binding of the tag
  filter, the array shape, the filter's reordering and a warning that disagrees with the
  record each have a named test (T6, T7, T14 to T18).
- Commit 2, tests in `wara.tests.ps1` (High), and "no error" assertions that can fail: as
  estimated, plus one test, at 19 `It` blocks generating 22 tests and 9 collector runs
  against 18, 21 and 8; the assertions use the `Stop` preference (T4), and V4 showed that
  they can fail.
- Commit 1, lint baseline (Medium), and whether it stays mechanical: it did, with 3 files
  at 39 lines added and 14 removed and the suite unchanged at 115 passing.
- Follow-up issues (Medium), and how much each needs beyond its basis: more than
  estimated. There were eleven, not ten, and at least eight needed a scratch run before a
  body could be written (live published data, a hermetic repro of the collector or an
  isolation matrix). Each was raised by running the steps of the `raise-issue` workflow by
  hand, because the skill is user-invoked.
- Verification V1 to V4 (Medium), and whether V1 can run and agree: V1 ran and agreed, so
  the analyzer needed no change. V2 ran twice, before and after D2.8, and V5 was added for
  D2.8. V4 ran only before D2.8; its assertions are unchanged except for T4's record count.
- Deferred design (Low): did not hold. D2.8 revised B1, an investigation decision that the
  plan had carried forward as settled.
- Commit 3, documentation (Low): as sized, bounded prose and one diagram edit; D2.8 later
  changed the same wording in the help and in two pages, in commit 4.

**Surprises (not in sizing estimate):**

- B1's rule was wrong for types that have automated recommendations but no manual one to
  validate (live: `virtualMachineScaleSets`). It surfaced while grounding F3, not in a
  planned check. The fix, D2.8, cost a fourth commit (4 files, 69 lines added and 23
  removed, one new test), a plan revision, four reviewed groups, a wording round because
  "active" read as a passed check, re-runs of V2 and V3, and the new V5.
- F10 proved wider than its row: the empty-list rejection sits in four scope helpers with
  seven call sites in the collector, and `-Tags` turns a run that completes without it into
  an abort.
- F11 was not in the plan: `tools/Invoke-Pester.ps1` loses its exit code under
  `pwsh -File`. Pester results in this issue were read from the summary lines, so none is
  affected.
- The correction that the collector's JSON is a complete deliverable, with the workbook
  and report as optional consumers, changed the text of F1 and the framing of the other
  follow-ups.

**Revised size verdict:** `L`: D2.8 changed the contract, which the plan names as its
trigger for upgrading to `L`, and the follow-up work was larger than its Medium weight.
