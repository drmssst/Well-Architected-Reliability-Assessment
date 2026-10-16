# Investigation: #26 — fix: remove the Find-Module out-of-date checks so the fork runs without PSGallery (tag v1.0.6-eoa.2)

**Issue:** [#26](https://github.com/drmssst/Well-Architected-Reliability-Assessment/issues/26)
**Alias:** `0026-remove-find-module-checks`
**Branch:** `investigate/issue-26-remove-find-module-checks`
**Milestone:** `release/20261015`

## Phase A — Findings

### Problem and desired outcome

`Start-WARACollector`, `Start-WARAAnalyzer` and `Start-WARAReport` each open with a
version check that calls `Find-Module` against the PowerShell Gallery and throws
`Module is out of date.` when the gallery version is higher than the loaded one. A copy
of the fork that a consumer vendors from a tag therefore needs PSGallery at run time,
and it stops working the day upstream publishes a version above 1.0.6. The issue also
notes that an unreachable or unregistered repository throws when the caller runs with
`$ErrorActionPreference = 'Stop'`.

The desired outcome is a fork module whose three entry points never touch PSGallery or
PowerShellGet to decide whether they may run, so a vendored copy behaves the same on a
machine with no gallery access and after upstream moves. The change ships as the fork
tag `v1.0.6-eoa.2`, and a test keeps the check from coming back. The remainder of
Phase A establishes what is true today against that outcome so that the gap is clear and
Phase B decisions are grounded.

---

### A1. The three checks are identical blocks

The same block opens each function body, after the parameter block and before any work:

| Function | File | Lines |
| --- | --- | --- |
| `Start-WARACollector` | `src/modules/wara/wara.psm1` | 169–183 |
| `Start-WARAAnalyzer` | `src/modules/wara/analyzer/analyzer.psm1` | 34–47 |
| `Start-WARAReport` | `src/modules/wara/reports/reports.psm1` | 47–60 |

Each block writes `Checking Version..`, reads `$LocalVersion` from `Get-Module`, reads
`$GalleryVersion` from `Find-Module -Name $MyInvocation.MyCommand.ModuleName`, and when
`$LocalVersion -lt $GalleryVersion` writes seven `Write-Host` lines of update advice and
throws. Only the collector copy has a leading comment (`# Check for module updates and
throw an error ...`). `$LocalVersion` and `$GalleryVersion` are used nowhere else in
any of the three functions, so deleting the block leaves no dangling variable. The block
is the only `Find-Module`, `Update-Module` or gallery-version reference under
`src/modules`.

A runtime probe (Pester mock of `Find-Module` that records `-Name`, then throws) shows
all three functions pass `wara` as the name, even though the analyzer and reports
functions live in nested modules. All three therefore compare against the one `WARA`
gallery package, and the PSGallery entry for it is `1.0.6` today, equal to the local
`ModuleVersion`.

**Gap against desired outcome.** The issue's premise is confirmed: exactly three
uniform blocks, each self-contained. Closing the gap needs the three blocks deleted, and
nothing else in those files depends on them.

### A2. What each failure mode does today

Checked on PowerShell 7.6.7 with PowerShellGet 2.2.5:

| Condition | Result |
| --- | --- |
| PSGallery reachable, gallery version equal to local (today) | Passes, after a network round trip on every call |
| PSGallery reachable, gallery version higher than local | Throws `Module is out of date.` |
| Repository unregistered, `-ErrorAction Stop` (or `$ErrorActionPreference = 'Stop'`) | `Find-Module` throws `SourceNotFound`, so the function throws |
| Repository unregistered, default preference | `Find-Module` writes a non-terminating error, `$GalleryVersion` is `$null`, `[version]'1.0.6' -lt $null` is `$false`, so the function continues |

The first failure is the version-skew case that the fork cannot avoid, because upstream
can publish at any time. The second is the offline case. Both are independent of
anything the fork controls, and the check gives a fork consumer nothing: the advice it
prints (`Update-Module -Name wara`) would replace the vendored fork with upstream.

**Gap against desired outcome.** Under the default preference an offline machine
survives by accident (the check silently disappears), but under `Stop` or after an
upstream release it fails. Removal fixes both; a guard would keep a network call and a
failure path that the fork has no use for.

### A3. Other PSGallery and PowerShellGet dependencies

The grep over `src/` and `.github/` finds these other gallery touch points:

- `src/modules/wara/analyzer/2_wara_data_analyzer.ps1` line 193 and
  `src/modules/wara/reports/3_wara_reports_generator.ps1` line 188: `Test-Requirement` runs `Install-Module -Name ImportExcel -Force
  -SkipPublisherCheck`, but only when `Get-Module -Name ImportExcel -ListAvailable`
  finds nothing. It is called once at script level (analyzer line 1124, reports line
  1310). Where ImportExcel is installed, no gallery access happens; where it is not, the
  call needs PSGallery.
- `2_wara_data_analyzer.ps1` lines 197–204 hold a commented-out `Install-Module
  powershell-yaml` block. It is dead code.
- `src/modules/wara/wara.psd1` lists
  `Az.Accounts` 3.0.0 and `Az.ResourceGraph` 1.0.0 as `RequiredModules`. `utils.psd1`
  and `runbook.psd1` list the same two. The import resolves them from installed modules,
  not from the gallery, and the issue does not ask to change them. ImportExcel is not
  among them.
- `.github/workflows/pestertests.yml` installs `Az.ResourceGraph` and `Az.Accounts` from PSGallery. This is CI setup, not a
  run-time dependency of the module.

Separately from PSGallery, run-time network use exists that the issue does not cover:
the collector and analyzer fetch `recommendations.json` and `WARAinScopeResTypes.csv`
with `Invoke-RestMethod` from `azure.github.io` (`wara.psm1` lines 281 and 294,
`2_wara_data_analyzer.ps1` lines 253 and 1131), and `advisor.psm1` line 310 calls the
Azure REST API. These are not PSGallery or PowerShellGet.

**Gap against desired outcome.** The three blocks are the only gallery use that runs on
every call. The two `Install-Module ImportExcel` fallbacks are conditional and sit
outside the issue's named scope; whether they belong in this issue is a Phase B
decision. No other call to PowerShellGet exists in the module.

### A4. What the existing tests do with `Find-Module`

`src/tests/wara/wara.tests.ps1` is the only test file that reaches these functions. `src/tests/` has no `analyzer` or
`reports` folder, and `.github/scripts/RunPesterTests.ps1` excludes those two directories
from the unfiltered run, so the analyzer and reports checks have no test coverage at all.

- The `-PassThru` test (line 74, `It` at line 126) mocks every collaborator except
  `Find-Module`. It calls the real gallery on every run, so it fails offline under
  `Stop` and fails as soon as upstream publishes a higher version.
- The hermetic context added for #3 (line 169) mocks `Find-Module` at line 216 to return
  `1.0.0`. That mock is the same class of removal as the three blocks: once the check is
  gone it has nothing to intercept.
- The five `Start-WARACollector Parameter Sets` contexts and the `Start-WARACollector` validation
  tests either mock the function itself or fail at parameter validation, so none of them
  reaches the check.

The file has no static or source-level test of any kind today; every `Describe` calls
functions. `.github/scripts/RunPesterTests.ps1` runs the module-name folder under
`src/tests`, so a new test for the analyzer or reports source would have to live in the
`wara` folder to run in CI.

**Gap against desired outcome.** Removing the checks leaves the `-PassThru` test
unmocked but harmless, and the hermetic mock redundant. A regression guard does not
exist: nothing fails if a future change reintroduces a `Find-Module` call.

### A5. Documentation, versioning and release bookkeeping

- The comment-based help of the three functions says nothing about the version check,
  and no file under `docs/` or `README.md` mentions `Checking Version`, `out of date`
  or `Find-Module`. The generated function docs therefore need no edit.
- `FORK.md` states that `ModuleVersion` stays
  numeric (`1.0.6`) and the fork version lives in git tags and in FORK.md. Existing tags
  are `v1.0.6-eoa.0` and `v1.0.6-eoa.1`; the issue asks for `v1.0.6-eoa.2`.
- The `ship-release` skill creates the tag and updates the FORK.md version table and
  change list through a PR that lands after the tag, so the tagged commit is unchanged.
  The tag and the FORK.md row are release-time steps, not part of the code change.
- `CHANGELOG.md` has an `[Unreleased]`
  section with `Minor` and `Patch` subsections. Each entry that touches the module says
  so and cites its issue number.
- The `README.md` tells users to `Install-Module WARA` from the gallery. That is the
  upstream install path, which this fork's FORK.md already supersedes for vendoring; the
  issue does not ask to change it.

**Gap against desired outcome.** Beyond the code and test change, the implementation
needs a CHANGELOG entry and, at release time, the FORK.md row and the tag. The README is
not part of the gap.

### A6. Open questions for Phase B

1. Should the three blocks be removed outright, or kept behind a guard such as an
   opt-in parameter, an environment variable or a catch that tolerates an unreachable
   repository? The issue title says remove; the body says "removed or guarded".
2. Should the `Install-Module ImportExcel` fallbacks in `2_wara_data_analyzer.ps1` and
   `3_wara_reports_generator.ps1` stay as they are, be changed to a clear error, or be
   left for a separate issue? They are not mentioned in the title.
3. What form should the regression guard take: a static test over the three source
   files (text match, or an AST search for `Find-Module`, `Install-Module` and
   `Update-Module` command calls), a behavioural test that mocks `Find-Module` to throw
   and asserts it is never invoked, or both? Where should it live, given that
   analyzer and reports have no test folder and the runner skips them?
4. Does the redundant `Mock Find-Module` at `wara.tests.ps1` line 216 come out in this
   change? Leaving it is harmless; removing it keeps the test file honest.
5. Should the dead commented-out `powershell-yaml` block next to `Test-Requirement` be
   touched? It mentions `Install-Module`, so a text-based guard could trip on it
   depending on the answer to question 3.
6. Which CHANGELOG subsection (`Minor` or `Patch`) fits a removal of a guard that
   changes behavior only where the old check would have thrown?
7. Is the tag `v1.0.6-eoa.2` and its FORK.md row in scope for the implementation PR, or
   only for `ship-release`?

## Phase B — Approach decisions

Each decision below resolves the open question with the same number in A6.

### B1. Remove the three checks outright

**Decision.** Delete the three version-check blocks, including the `Checking Version..`
line, the `$LocalVersion` and `$GalleryVersion` assignments, the `if` and its seven
`Write-Host` advice lines, the `throw`, and the leading comment in `wara.psm1`. Add no
parameter, switch or environment variable in their place.

**Rationale.** The check only compares the vendored fork against the upstream gallery
package, and its advice (`Update-Module -Name wara`) would replace the fork with
upstream (A2). A guard would keep a network call and a failure path that the fork has no
use for, and an opt-in parameter would add public surface to a fix that is otherwise
confined to function bodies.

**Rejected alternatives.**

- An opt-in or opt-out parameter: changes the public parameter sets for no consumer
  benefit.
- An environment variable: hidden behavior that still leaves the check on by default,
  so a vendored copy would still break after an upstream release.
- A `try`/`catch` that tolerates an unreachable repository: fixes only the offline case,
  keeps the network round trip on every call, and still throws `Module is out of date.`
  after an upstream release (A2).

**Visible change.** The `Checking Version..` line no longer appears at the start of the
three commands. No parameter, output object or export changes.

### B2. Leave the ImportExcel `Install-Module` fallbacks out of this issue

**Decision.** Do not change `Test-Requirement` in `2_wara_data_analyzer.ps1` or
`3_wara_reports_generator.ps1`, and do not touch the commented-out `powershell-yaml`
block beside it.

**Rationale.** The issue names only the `Find-Module` out-of-date checks. ImportExcel is
a third-party module, not part of WARA, and the fallback runs only when it is missing
(A3). Changing it would alter behavior in two scripts and might touch the module
manifest, which is a separate decision. The scope stays as the issue states it.

**Rejected alternatives.**

- Replace the install with an error telling the user to install ImportExcel: a behavior
  change outside the issue.
- Declare ImportExcel in `RequiredModules` in `wara.psd1`: a public manifest change that
  would also make the collector require it.

**Consequence.** After this issue, a vendored copy still needs PSGallery on a machine
where ImportExcel is not installed, and only for the analyzer and report steps. Phase C
records this as a known remaining dependency so the release notes do not overclaim.

### B3. A static AST test as the regression guard

**Decision.** Add one `Describe` to `src/tests/wara/wara.tests.ps1` that parses
`wara.psm1`, `analyzer/analyzer.psm1` and `reports/reports.psm1` with
`[System.Management.Automation.Language.Parser]::ParseFile` and asserts that none of
them contains a command call (`CommandAst`) named `Find-Module`, `Update-Module`,
`Install-Module`, `Find-PSResource`, `Update-PSResource` or `Install-PSResource`. The
test runs once per file so a failure names the file. It does not cover the
`2_`/`3_` scripts, which legitimately contain `Install-Module ImportExcel` (B2).

**Rationale.** Matching command calls in the syntax tree ignores comments and string
contents, so the dead `powershell-yaml` comment and any advice text that mentions
`Update-Module` cannot cause a false failure, and a reintroduced call cannot hide
behind a variable name in a string. The test is offline and has no mocks to maintain.
It belongs in `src/tests/wara` because the runner skips `analyzer` and `reports`
(A4), and every test folder holds one `<module>.tests.ps1`, so the new `Describe` joins
the existing file instead of creating a second one.

**Rejected alternatives.**

- A behavioural test (mock `Find-Module` to throw, assert it is never called): covers
  only `Start-WARACollector`, because the analyzer and reports functions need a JSON
  file and a workbook to run, and neither has any test setup today.
- A text match over the file: would fail on comments and strings, and would need an
  exclusion for the `powershell-yaml` comment.
- Both: the behavioural test adds fixture work for no coverage the static test lacks.
- No test: leaves nothing to stop the check from coming back (A4).

**Verification requirement.** Run the new test against the unchanged code first and
confirm it fails for all three files, then confirm it passes after the removal. A guard
that was never seen to fail proves nothing.

### B4. Remove the redundant `Mock Find-Module`

**Decision.** Delete `Mock Find-Module { ... } -ModuleName 'wara'` at line 216 of
`wara.tests.ps1`. Leave the `-PassThru` test at line 74 as it is.

**Rationale.** Once the check is gone the mock intercepts nothing, and leaving it would
suggest the collector still calls `Find-Module`. The `-PassThru` test stops calling the
real gallery as a side effect, so it becomes hermetic with respect to the gallery
without any edit.

**Rejected alternative.** Keep the mock as a safety net: it would mask a reintroduced
call in the collector, which weakens the guard in B3.

### B5. Leave the commented-out `powershell-yaml` block

**Decision.** No change. Covered by B2.

**Rationale.** It is outside the three files, it is dead code, and the AST test in B3
ignores comments, so it cannot trip the guard.

### B6. CHANGELOG entry under `Patch`

**Decision.** Add one entry under `[Unreleased]` → `Patch`, citing `(#26)`, stating that
`Start-WARACollector`, `Start-WARAAnalyzer` and `Start-WARAReport` no longer query
PowerShell Gallery for a newer module version and no longer throw `Module is out of
date.`. The entry must not claim that the module runs without gallery access, because
the ImportExcel fallback (B2) can still reach it.

**Rationale.** The change removes a check and changes no parameter, output or export,
and the issue is `type:fix`. The #3 entry sits under `Minor` because it adds an output
key; this one does not.

**Rejected alternative.** `Minor`: reserved in this file for added behavior.

### B7. The tag and the FORK.md row belong to `ship-release`

**Decision.** The implementation PR changes code, tests and CHANGELOG only. It does not
edit `FORK.md`, change `ModuleVersion` in `wara.psd1`, or create a tag. `ship-release`
tags `v1.0.6-eoa.2` and adds the FORK.md version row and change-list entry in a PR
that lands after the tag.

**Rationale.** `ship-release` owns this sequence so that the tagged commit stays
unchanged (A5), and `FORK.md` states that the numeric `ModuleVersion` stays `1.0.6`.
The issue's mention of the tag is the release target, not an extra code change.

**Rejected alternative.** Add the FORK.md entry to the implementation PR: puts a row for
a tag that does not exist yet into `main`.

## Phase C — Risks and prerequisites

### Prerequisites

None. No other issue blocks this one. The hermetic test context that holds the mock
removed in B4 comes from #3, which has already merged (`acc78b5`), so the line numbers in
Phase A and B are current for this branch.

### C1. The fork stops telling vendored copies they are stale

**Mechanism.** The old check forced a user off an old copy by throwing. After removal, a
consumer who vendored `v1.0.6-eoa.1` is never prompted to move to a later fork tag.

**Mitigation.** Accept it. The check compared against the upstream package, not the
fork, so it never pointed users to a fork release; its advice (`Update-Module -Name
wara`) would have replaced the fork with upstream (A2). Fork versions live in tags and
`FORK.md`, which consumers vendor from by design. No code mitigation is needed.

### C2. The module still needs PSGallery in one case

**Mechanism.** `Test-Requirement` in the analyzer and reports scripts runs `Install-Module
ImportExcel` when ImportExcel is not installed (A3, B2). A vendored copy on an offline
machine without ImportExcel still fails at that step, after the `Find-Module` checks are
gone. The release then does not fully meet the issue's stated goal of running without
PSGallery.

**Mitigation.** The scope stays as decided in B2. The CHANGELOG entry (B6) and the
`v1.0.6-eoa.2` tag message must say only that the version check is gone, and must name
ImportExcel as a prerequisite to install ahead of time on offline machines. The
follow-up issue is not filed here, as you directed.

### C3. The regression guard runs in CI only at release time

**Mechanism.** `.github/workflows/pestertests.yml` triggers on pull requests to `main`,
and implementation PRs merge into the release branch (the `approve-ready-for-release`
skill). The new AST test therefore does not run in CI on the implementation PR. It runs
at the release-to-`main` PR and locally.

**Mitigation.** Run the test locally as part of implementation, including the
fail-before and pass-after proof from B3, and record both results in the PR. Changing
the workflow trigger is outside this issue.

### C4. The guard is a tripwire, not a proof

**Mechanism.** The AST test matches `CommandAst` nodes by name in three files. Three
gaps follow:

- A module-qualified call such as `PowerShellGet\Find-Module` returns a command name that
  includes the module prefix, so a plain name comparison misses it.
- Invocation through `& $name`, `Invoke-Expression` or splatting a variable name has no
  literal command name.
- A check added to a new file or to the `2_`/`3_` scripts is not covered.

**Mitigation.** Compare against the part after the last backslash, so the qualified form
is caught. Accept the other two gaps: they require deliberate obfuscation, and the guard
exists to stop a restored upstream block, which uses the plain call. State the three-file
scope in the test name.

### C5. A later rebase onto upstream can restore the blocks

**Mechanism.** `FORK.md` says the fork is rebased onto new upstream releases. Upstream
still carries the three blocks, so a rebase conflict resolved toward upstream, or a clean
merge of a nearby edit, can bring them back and make a new fork tag stop working offline.

**Mitigation.** The B3 test fails on exactly that regression, which makes this the main
reason to add it. Upstream has been inactive since June 2025 (`FORK.md`), so the
likelihood is low.

### C6. Code coverage changes when the blocks go

**Mechanism.** `.github/scripts/RunPesterTests.ps1` fails the run when coverage of
`wara.psm1` falls below the Pester target. The collector's 15 check lines are executed
today under the `Find-Module` mock, so removing them changes the measured percentage by a
small amount in either direction.

**Mitigation.** Run `RunPesterTests.ps1 -moduleName wara` before and after the change in
implementation and compare the coverage result. This is a verification step, not a
design change.

### C7. Test and code must change together

**Mechanism.** Removing `Mock Find-Module` (B4) while the check still exists would make
the `-PassThru` and hermetic tests hit the real gallery.

**Mitigation.** Remove the three blocks and the mock in the same commit. The AST test can
come first in its own commit, as the failing proof, if the plan wants a red-then-green
history.

### C8. False alarms

- **A live break today.** PSGallery lists `wara` `1.0.6`, equal to the local
  `ModuleVersion`, so the check passes now (A1). The risk is latent: it triggers when
  upstream publishes, or when a caller runs offline under `Stop`. That is why the issue is
  `urgency:soon` and not an outage.
- **Dangling variables.** `$LocalVersion` and `$GalleryVersion` are used nowhere else in
  the three functions, so deleting the blocks leaves nothing that fails to resolve (A1).
- **Public surface.** No parameter, output object or export changes (B1), so no consumer
  contract is affected beyond the missing `Checking Version..` line.
- **Stale data from skipping the check.** The module fetches `recommendations.json` and
  the resource-type CSV from the web on each run (A3), independent of the module version,
  so skipping the version comparison does not leave a vendored copy on stale data.

## Phase D — Ready-to-plan summary

### D1. Files in scope

| File | Change | Lines |
| --- | --- | --- |
| `src/modules/wara/wara.psm1` | Delete the version-check block and its leading comment in `Start-WARACollector` (B1) | 169–183 |
| `src/modules/wara/analyzer/analyzer.psm1` | Delete the version-check block in `Start-WARAAnalyzer` (B1) | 34–47 |
| `src/modules/wara/reports/reports.psm1` | Delete the version-check block in `Start-WARAReport` (B1) | 47–60 |
| `src/tests/wara/wara.tests.ps1` | Delete `Mock Find-Module` (B4); add one `Describe` with the AST guard (B3) | 216; new block |
| `CHANGELOG.md` | One `Patch` entry under `[Unreleased]`, citing `(#26)`, with the wording limit from B6 and C2 | new entry |

Not in scope, by decision: `FORK.md`, `ModuleVersion` in `wara.psd1` and the `v1.0.6-eoa.2`
tag (B7, done by `ship-release`); the ImportExcel fallbacks and the `powershell-yaml`
comment in `2_wara_data_analyzer.ps1` and `3_wara_reports_generator.ps1` (B2, B5);
`README.md`, `docs/` and `pestertests.yml` (A5, C3).

### D2. Decisions deferred to planning

1. **Shape of the guard test.** Options: one `It` per file generated with `-ForEach`
   over the three paths, or one `It` that loops over the files. Constraint: the paths
   must be known at Pester discovery time and the parse must happen at run time, and a
   failure must name the file (B3). The plan picks one after checking Pester 5 scoping.
2. **How to show the guard fails first.** Options: run the new test against the base
   versions of the three files with `git stash` or `git show` into a scratch copy, or
   write the test in its own commit ahead of the fix. Constraint: no failing commit may
   land on the release branch unless the plan accepts it.
3. **Exact CHANGELOG wording.** The B6 text names the three commands and the lost
   throw. The plan fixes the sentence, including the ImportExcel note from C2.
4. **Blank-line cleanup.** After each deletion, the plan sets the blank lines so that
   the parameter block is followed by one blank line and then the next statement, as in
   the current files.
5. **Coverage run.** Whether the before-and-after `RunPesterTests.ps1 -moduleName wara`
   comparison from C6 is one recorded step or part of the final check.

### D3. Commit strategy

Recommended, two commits in this order:

1. `fix(#26): remove the Find-Module out-of-date checks`: the three block deletions, the
   `Mock Find-Module` removal and the CHANGELOG entry. The blocks and the mock go
   together (C7).
2. `test(#26): guard the entry points against PSGallery version checks`: the AST test.

The red-before-green proof from B3 is run locally between the two, as in D2 option one,
and its result goes in the PR description. The plan may merge both into one commit if the
repository's convention is one commit per issue.

### D4. New tests

Yes. One new test is required: the static AST guard (B3), one case per file, three in
all. No behavioural test is added. One existing mock is removed (B4), and the `-PassThru`
test and the hermetic context stay as they are.

### Sizing estimate

**Estimate:** S

| Driver | Weight | Reasoning |
| --- | --- | --- |
| Guard test in `wara.tests.ps1` | High | The only new logic: an AST parse, a name comparison that handles the module-qualified form (C4), a Pester 5 discovery and run split, and a red-then-green proof. About 25–35 new lines, estimated. |
| Three block deletions | Low | About 43 lines removed in total, identical in kind, with no variable used elsewhere (A1). |
| Verification runs | Medium | The `wara` tests before and after, with the coverage comparison (C6). The suite includes the end-to-end `-PassThru` tests. |
| Mock removal and CHANGELOG | Low | One line deleted and one entry added. |

Primary uncertainty drivers:

- Pester 5 scoping for parsing files during discovery versus run time.
- Whether the baseline `wara` suite and its coverage target pass on a clean run before the
  change (C6).
- Whether the guard needs more than the six command names to stay useful.

Upgrade to the next size if the ImportExcel fallbacks join this issue, or if coverage falls
below the Pester target and needs extra tests in `wara.psm1`.
