# Issue #26: fix: remove the Find-Module out-of-date checks so the fork runs without PSGallery (tag v1.0.6-eoa.2)

**Issue:** [#26](https://github.com/drmssst/Well-Architected-Reliability-Assessment/issues/26)
**Alias:** `0026-remove-find-module-checks`

---

## Implementation plan — Issue #26: fix: remove the Find-Module out-of-date checks so the fork runs without PSGallery (tag v1.0.6-eoa.2)

### Phase A — Scope and approach

**Core change.** Delete the identical version-check block at the top of `Start-WARACollector`
(`wara.psm1`), `Start-WARAAnalyzer` (`analyzer/analyzer.psm1`) and `Start-WARAReport`
(`reports/reports.psm1`). Each block calls `Find-Module` against PowerShell Gallery and throws
`Module is out of date.` when upstream publishes a higher version than the loaded
`ModuleVersion`. The investigation settled this as removal, not a guard (B1): no parameter,
switch or environment variable replaces it. A current-code check confirmed the survey
findings: the three blocks are textually identical apart from the collector's leading
comment, and `$LocalVersion` and `$GalleryVersion` are used nowhere else in those functions,
so nothing is left dangling after the deletion.

**What it delivers.** After the change the three entry points no longer query PSGallery or
PowerShellGet to decide whether they may run. A vendored copy of the fork no longer stops
when upstream publishes above 1.0.6, and no longer throws under
`$ErrorActionPreference = 'Stop'` when the repository is unreachable or unregistered. The
only visible change is that the `Checking Version..` line no longer prints.

**Supporting changes in the same issue.**

- Delete the `Mock Find-Module` at line 216 of `src/tests/wara/wara.tests.ps1`, in the same
  commit as the three deletions, so no test reaches the real gallery or masks a restored
  call (B4, C7).
- Add one static regression guard to `src/tests/wara/wara.tests.ps1`: an AST search of the
  three source files for calls to `Find-Module`, `Update-Module`, `Install-Module` and the
  three `*-PSResource` equivalents, comparing the part of the command name after the last
  backslash (B3, C4). It lives in the `wara` test folder because the CI runner skips the
  `analyzer` and `reports` folders.
- Add one `Patch` entry to `CHANGELOG.md` under `[Unreleased]`, citing `(#26)`. It says only
  that the version check is gone and names ImportExcel as a prerequisite to install ahead of
  time on offline machines (B6, C2).

**Out of scope, by decision.** The `Install-Module ImportExcel` fallbacks and the dead
`powershell-yaml` comment in `2_wara_data_analyzer.ps1` and `3_wara_reports_generator.ps1`
(B2, B5). `FORK.md`, `ModuleVersion` in `wara.psd1` and the `v1.0.6-eoa.2` tag, which
`ship-release` handles after the tag (B7). `README.md`, `docs/` and `pestertests.yml`.
No sub-issues are warranted: the work is one small, cohesive change, and the ImportExcel
follow-up is deliberately not filed here.

**Planning decisions taken in this scope** (the investigation deferred these to planning):

1. **Guard shape.** One `It` generated with `-ForEach` over three `@{ Name; Path }` cases,
   so a failure names the file. Pester 5 resolves `$PSScriptRoot` at discovery time inside
   `Describe`, so the paths are known when the cases are generated, and the parse runs in
   the `It` body at run time. The three cases are the same `-ForEach` data, not three
   copy-pasted `It` blocks.
2. **Red-before-green proof.** The guard is written first and run against the unchanged
   source in the working tree, where it must fail for all three files. Nothing is committed
   while red. The deletions are then applied, and the same run must pass. No failing commit
   lands on the release branch.
3. **Commits.** Two commits, as the investigation recommended (D3): the fix commit (three
   deletions, the mock removal and the CHANGELOG entry), then the test commit (the guard).
   The fix commit leaves the suite green because the guard is not yet present, and the
   test commit leaves it green because the fix is already in.
4. **Blank lines.** After each deletion, the parameter block's closing parenthesis is
   followed by exactly one blank line and then the next statement, as in the current files.
5. **Coverage.** `RunPesterTests.ps1 -moduleName wara` is run once on the unchanged branch
   and once after the change, and the two coverage results are recorded in the PR (C6). The
   run is a verification step, not a gate on design.

**Open decisions for you before scope is final.** None are blocking. Say so if you want
either of these to change:

- The CHANGELOG entry sits under `Patch`, not `Minor`, as the investigation decided (B6).
- The guard covers `wara.psm1`, `analyzer.psm1` and `reports.psm1` only, so a call added to
  the `2_`/`3_` scripts is not caught (C4). Widening it would trip on the ImportExcel
  fallback that B2 keeps.

### Phase B — Document impact

A grep of `docs/`, `README.md`, `FORK.md` and `src/` for `Find-Module`, `Checking Version`,
`out of date` and `Update-Module` found no document that describes the version check. The
comment-based help of the three functions does not mention it, so the generated function
docs under `docs/` need no edit. The `README.md` hits for `Update-Module` (lines 95, 108,
121) advise updating `Az`, `Az.Accounts` and `Az.ResourceGraph`, which this issue does not
touch.

### Affected documents

| File | Change needed |
| ---- | ------------- |
| `CHANGELOG.md` | Add one entry under `[Unreleased]` → `Patch`, citing `(#26)`. It states that `Start-WARACollector`, `Start-WARAAnalyzer` and `Start-WARAReport` no longer query PowerShell Gallery for a newer module version and no longer throw `Module is out of date.`. It must not claim the module runs without gallery access, and must name ImportExcel as a prerequisite to install ahead of time on offline machines (B6, C2). It also notes that no exported function changes. |

**In-flight docs.** A scan of `C:\wt\wara\docs\issues\` found two other docs that
mention the check: `0003-surface-skipped-resources-investigation.md` and
`0003-surface-skipped-resources-plan.md`. They record that #3 mocked `Find-Module` in its
hermetic test. Issue #3 has merged, and both docs describe the code as it was then, so
this issue does not invalidate them and neither is edited. No in-flight doc under
`release-20261015` or `backlog` references the three functions or the check.

### Affected source files

| File | Change needed |
| ---- | ------------- |
| `src/modules/wara/wara.psm1` | Delete the version-check block and its leading comment from `Start-WARACollector` (lines 169–183), leaving one blank line between the parameter block and `# Start the stopwatch to time the script`. |
| `src/modules/wara/analyzer/analyzer.psm1` | Delete the version-check block from `Start-WARAAnalyzer` (lines 34–47), leaving one blank line between the parameter block and `Write-Host 'Wrapping Analyzer'`. |
| `src/modules/wara/reports/reports.psm1` | Delete the version-check block from `Start-WARAReport` (lines 47–60), leaving one blank line between the parameter block and `Write-Host 'Wrapping Report Generator'`. |
| `src/tests/wara/wara.tests.ps1` | Delete `Mock Find-Module { ... } -ModuleName 'wara'` (line 216). Add one `Describe` with the AST guard over the three source files above. |

`FORK.md`, `wara.psd1` and the `v1.0.6-eoa.2` tag are not changed here (B7). The
`2_wara_data_analyzer.ps1` and `3_wara_reports_generator.ps1` scripts are not changed (B2).

### Version impact

**Classification:** `patch`

| Term | Meaning |
| ---- | ------- |
| `major` | Breaking — existing consumers must update |
| `minor` | Additive, non-breaking new capability |
| `patch` | Invisible to consumers — bug fix, doc correction |

**Rationale:** The change removes a check and adds no parameter, output or export, and the
issue is `type:fix` (B6). The only consumer-visible differences are the missing
`Checking Version..` line and the absence of a throw in cases where the old check would
have thrown, which is the defect being fixed.

### Testing requirements

Only the new guard and one removal are listed. Every other existing test is unchanged and
must keep passing, including the `-PassThru` test (line 74) and the hermetic context
(line 169), which no longer reach `Find-Module`.

#### New test

| Item | Detail |
| ---- | ------ |
| File | `src/tests/wara/wara.tests.ps1`, a new top-level `Describe` placed after the existing `Describe` blocks |
| Name | `Describe 'Entry-point modules (wara, analyzer, reports) do not query PowerShell Gallery'` |
| Cases | One `It 'Contains no <Name> gallery command call'` with `-ForEach`, over three hashtables `@{ Name = 'wara.psm1'; Path = ... }`, `analyzer.psm1` and `reports.psm1`. The paths are built from `$PSScriptRoot/../../modules/wara/...` in the `Describe` body, which Pester 5 evaluates at discovery, so the cases exist when `-ForEach` expands. The parse runs in the `It` body at run time. |
| Validates | None of the three files contains a `CommandAst` whose command name, taken after the last backslash, is `Find-Module`, `Update-Module`, `Install-Module`, `Find-PSResource`, `Update-PSResource` or `Install-PSResource`. |
| Expected outcome | Fails against the unchanged source for all three files; passes after the three deletions. |

**Implementation notes.**

- Parse with `[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)`
  and assert `$errors` is empty first, so a parse failure cannot read as a pass.
- Find calls with `FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)`
  and take `GetCommandName()`. Skip `$null` results (calls through `& $name`, an accepted
  gap in C4). Compare `($name -split '\\')[-1]` with `-in` the six names, so the
  module-qualified form `PowerShellGet\Find-Module` is caught.
- Assert the list of matching names `Should -BeNullOrEmpty`, so a failure prints the
  offending command names and the case name identifies the file.
- No mocks, no network, no module import beyond the file-level `BeforeAll`. The `Describe`
  needs no `BeforeAll` of its own.
- Not covered by design: `2_wara_data_analyzer.ps1` and `3_wara_reports_generator.ps1`
  (B2, C4).

#### Modified test

| Item | Detail |
| ---- | ------ |
| File | `src/tests/wara/wara.tests.ps1` |
| Location | `Context 'When skipped resources are reported with hermetic mocks'`, line 216 |
| Change | Delete `Mock Find-Module { [PSCustomObject]@{ Version = [version]'1.0.0' } } -ModuleName 'wara'`. |
| Expected outcome | The context passes unchanged; the mock has nothing to intercept once the collector block is gone (B4). It goes in the same commit as the deletions (C7). |

#### Verification runs

These are recorded steps for the implementation, not new tests.

1. **Baseline.** On the unchanged branch, run
   `tools/Invoke-Pester.ps1 src/tests/wara/` and
   `.github/scripts/RunPesterTests.ps1 -moduleName wara`. Record the pass count and the
   coverage percentage against the target (C6). If the baseline already fails or sits
   below the target, record it and stop to raise it before changing code.
2. **Red.** Add the guard to the working tree and run it before any deletion. All three
   cases must fail, each reporting `Find-Module` and `Update-Module`. Do not commit.
3. **Matcher check.** Parse the inline string `PowerShellGet\Find-Module -Name x` with the
   same matching code and confirm it is reported, so the module-qualified form is proven
   caught. This is a one-off scratch command, not a committed test.
4. **Green.** Apply the three deletions, the mock removal and the CHANGELOG entry, then
   re-run the `wara` tests. The guard passes for all three cases, and the rest of the
   suite is unchanged from the baseline.
5. **Coverage after.** Re-run `RunPesterTests.ps1 -moduleName wara` and compare the
   coverage result with step 1. Record both in the PR description (C6, C3).
6. **Full suite.** Run `tools/Invoke-Pester.ps1 src/tests/` once at the end.

Commit order follows Phase A: the fix commit (deletions, mock removal, CHANGELOG) first,
then the guard commit. The red proof in step 2 happens in the working tree before either
commit, and each commit stages only its own files, so no failing commit lands.

### Acceptance criteria

- [x] **D1.** `wara.psm1`, `analyzer/analyzer.psm1` and `reports/reports.psm1` contain no
  `Find-Module`, `Update-Module`, `Checking Version` or `Module is out of date` text, and
  `$LocalVersion` and `$GalleryVersion` appear in none of them.
- [x] **D2.** Each of the three functions runs its first working statement straight after
  the parameter block: one blank line, then `# Start the stopwatch to time the script`
  (collector), `Write-Host 'Wrapping Analyzer'` or `Write-Host 'Wrapping Report Generator'`.
- [x] **D3.** The parameter lists of `Start-WARACollector`, `Start-WARAAnalyzer` and
  `Start-WARAReport`, and the module's exported commands, are identical before and after
  the change (compared with `Get-Command ... | Select-Object -ExpandProperty Parameters`
  and `(Get-Module wara).ExportedCommands`). `wara.psd1` is unmodified.
- [x] **D4.** The hermetic `Context` and the `-PassThru` test in `wara.tests.ps1` pass
  with `Mock Find-Module` removed, and the `wara` suite has the same pass count as the
  baseline plus the three new guard cases.
- [x] **D5.** The new guard `Describe` has three cases, one per file. Run against the
  unchanged source in the working tree, all three fail and report `Find-Module`; run
  after the deletions, all three pass. (`Update-Module` appeared only as text inside a
  `Write-Host` string, not as a command, so the AST guard does not report it.)
- [x] **D6.** The guard's matcher reports the module-qualified call
  `PowerShellGet\Find-Module -Name x` when run against that inline string.
- [x] **D7.** `RunPesterTests.ps1 -moduleName wara` still reports coverage as met against
  the Pester target after the change, and the before and after percentages are recorded
  in the PR description.
- [x] **D8.** `CHANGELOG.md` has one new entry under `[Unreleased]` → `Patch`, citing
  `(#26)`. It names the three commands, says they no longer query PowerShell Gallery or
  throw `Module is out of date.`, names ImportExcel as a prerequisite to install ahead of
  time on offline machines, states no exported function changes, and does not claim the
  module runs without gallery access.
- [x] **D9.** `tools/Invoke-PsScriptAnalyzer.ps1` reports no new finding on the three
  modified `.psm1` files compared with the baseline.
- [x] **D10.** The change set contains no edit to `FORK.md`, `wara.psd1`,
  `2_wara_data_analyzer.ps1`, `3_wara_reports_generator.ps1`, `README.md` or
  `pestertests.yml`, and creates no tag.

### D11. Sizing estimate

**Estimate:** S

| Driver | Weight | Reasoning |
| ------ | ------ | --------- |
| Guard test in `wara.tests.ps1` | High | The only new logic: an AST parse, a name comparison that handles the module-qualified form (C4), a Pester 5 discovery and run split, and the red-then-green proof. About 25–35 new lines, estimated. |
| Verification runs | Medium | Baseline and after runs of the `wara` suite with the coverage comparison (C6), the matcher check, a parameter-list comparison (D3) and the full suite. The `wara` suite includes the end-to-end `-PassThru` tests. |
| Three block deletions | Low | About 43 lines removed in total, identical in kind, with no variable used elsewhere (A1). |
| Mock removal and CHANGELOG | Low | One line deleted and one entry added. |

Primary uncertainty drivers:

- Pester 5 scoping for building paths at discovery and parsing at run time.
- Whether the baseline `wara` suite and its coverage target pass on a clean run before the
  change (C6).
- Whether the guard needs more than the six command names to stay useful.

Upgrade to the next size if the ImportExcel fallbacks join this issue, or if coverage falls
below the Pester target and needs extra tests in `wara.psm1`.

### Definition of done

- [x] All acceptance criteria verified
- [x] All affected documents updated
- [x] All tests in Testing Requirements written and passing
- [x] Full PowerShell suite (`tools/Invoke-Pester.ps1 src/tests/`) green
- [ ] Manual smoke test passed (verify behavior against testbed artifacts, where applicable)
- [x] CHANGELOG entry added with correct classification
- [x] All modified Markdown files pass lint
- [ ] PR opened targeting the release branch
- [ ] Red-before-green result for the guard test and the before and after coverage
  percentages recorded in the PR description
