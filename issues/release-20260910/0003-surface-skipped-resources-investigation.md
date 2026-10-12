# Investigation: #3 — fix: surface resources skipped when recommendation metadata is inconsistent

**Issue:** [#3](https://github.com/drmssst/Well-Architected-Reliability-Assessment/issues/3)
**Alias:** `0003-surface-skipped-resources`
**Branch:** `investigate/issue-3-surface-skipped-resources`
**Milestone:** `release/20260910`

## Phase A — Findings

### Problem and desired outcome

`Start-WARACollector` builds a list of in-scope resources that still need a manual
validation row, and for each one looks for a matching active recommendation in
`recommendations.json`. When `WARAinScopeResTypes.csv` flags a resource type as covered
(`InAprlAndOrAdvisor = Yes`) but no qualifying recommendation exists, the resource gets no
row from that step, so it can be absent from `impactedResources` altogether. The only
trace is a `Write-Error` raised inside a PowerShell class method, and that error does not
reach the caller's error stream. Collection therefore finishes normally with resources
missing and no programmatic record of which resource IDs and types were skipped.

The desired outcome is a stable, documented and tested contract for aggregating the
skipped resources and exposing their IDs and types to the caller, so that an incomplete
collection can be detected without depending on error-stream capture. The issue also asks
that the PowerShell error-propagation behavior across the class-method and module
boundary be confirmed first. The remainder of Phase A establishes what is true today
against that outcome so that the gap is clear and Phase B decisions are grounded.

---

### A1. One class method decides each resource's fate, and one outcome drops it

`Start-WARACollector` builds `$validationResources`, a hashtable keyed by resource ID,
from two sources: the resources impacted by automated queries (`wara.psm1:365-371`) and
every resource whose type is a WARA in-scope type (`wara.psm1:380-385`). It passes the
table to `Build-ValidationResourceObj` (`wara.psm1:391`), a function that runs
`[validationResourceFactory]::new(...).createValidationResourceObjects()`
(`wara.psm1:591-608`). For each resource, the method (`wara.psm1:966-1027`) takes the
first of four outcomes that applies:

| # | Condition, in evaluation order | Outcome | Lines |
| --- | --- | --- | --- |
| 1 | Every recommendation for the resource's type has `automationAvailable` other than `$false` | `continue`: no row, no message | 969, 975-977 |
| 2 | At least one recommendation for the type has `automationAvailable = $false`, `recommendationMetadataState = Active` and an empty `recommendationTypeId` | One row per matching recommendation | 979-1000 |
| 3 | The type is in `TypesNotInAPRLOrAdvisor` (CSV rows with `InAprlAndOrAdvisor = No`, derived at `wara.psm1:293`) | One "No Recommendations" row | 1002-1020 |
| 4 | None of the above | `Write-Error "No recommendation found for <type> with resource id <id>"`; nothing is emitted for the resource | 1021-1023 |

Outcome 4 emits only an error, and the returned data holds no trace of the resource.
Outcome 1 also emits nothing, but it applies only to types whose recommendations are all
automated; the grouping behind it ignores `recommendationMetadataState` and
`recommendationTypeId`. The `Write-Error` branch was added in commit `675fd56`
(2024-12-09) together with the "No Recommendations" branch, with no comment on its
intent. The `continue` was added later in `4ee6712` (#161, 2025-04-07).

`Build-ValidationResourceObj` runs at progress step 53, before `Get-WAFAdvisorMetadata`
(`wara.psm1:403`) and `Get-WAFAdvisorRecommendation` (`wara.psm1:415`), so Advisor data is
not available when the outcome is decided.

**Gap against desired outcome:** the skip is a single, well-located branch, but its only
output is an error written from inside the class. The minimum change needed to close the
gap is that outcome 4 produces a record that survives the method as data; what the method
can write to the error stream is not enough (A2).

### A2. A class-method `Write-Error` is recorded in `$Error` and nowhere else

**Documented behavior.** The PowerShell documentation for class methods
(`about_Classes_Methods`, "Method output"; present in the 7.4 and 7.5 references, and
`wara.psd1` requires 7.4) states:

> Nonterminating errors written to the error stream from inside a class method aren't
> passed through. You must use `throw` to surface a terminating error. Using the
> `Write-*` cmdlets, you can still write to PowerShell's output streams from within a
> class method. The cmdlets respect the preference variables in the calling scope.

**Isolated experiment** (PowerShell 7.6.6). A scratch module mirrors the shape of `wara`:
an exported advanced function calls an internal advanced function, which calls a class
method that loops over three items and raises one error for the second. A control repeats
the loop in a function instead of a class method, and every case runs both as a module
and as a dot-sourced script, to separate the effect of the class method from the effect
of the module boundary. The scratch scripts live outside the repository and are not
committed.

| Observation | Class method `Write-Error` | Function `Write-Error` (control) |
| --- | --- | --- |
| Items returned | 2 of 3 (the failing item is dropped) | 2 of 3 |
| Shown on the host with default preferences | No | Yes |
| Merged into the output by `2>&1` | No (0 error records) | Yes (1) |
| Captured by `-ErrorVariable` | No (0) | Yes (1) |
| Present in `$Error` | Yes (1) | Yes (1) |
| `-ErrorAction Stop` on the outer call | Throws `WriteErrorException` | Throws |
| `$global:ErrorActionPreference = 'Stop'` | Throws | Throws |
| `$ErrorActionPreference = 'Stop'` at script scope | Does not throw | Does not throw |
| Module compared with dot-sourced script | Identical | Identical |

A class-method `Write-Warning` behaves differently: it is emitted on the warning stream
(merged by `3>&1`) but is not captured by `-WarningVariable` (0), whereas a function-level
`Write-Warning` is captured (1). The `$Error` record written from a class method has
`FullyQualifiedErrorId` `Microsoft.PowerShell.Commands.WriteErrorException` (the function
control appends the command name, `,Build-FuncError`), category `NotSpecified` and no
`TargetObject`, so the message text is its only carrier of data. `$Error` keeps at most
256 records: 300 class-method errors left 256, with the oldest 44 evicted.

**Reproduction through the real collector.** `Start-WARACollector -PassThru` was run with
the mock set from `src/tests/wara/wara.tests.ps1` (lines 74-125), except that the CSV mock
was pointed at the module's actual default URI (A6) and the CSV was served with one
change: `Microsoft.Network/vpnSites` flipped from `InAprlAndOrAdvisor = No` to `Yes`, so
that the CSV claims coverage that the fixture's `recommendations.json` does not have.

| Observation | Baseline (flag `No`) | Drift (flag `Yes`) |
| --- | --- | --- |
| `impactedResources` rows | 51 | 47 |
| `vpnSites` rows in `impactedResources` | 4 ("No Recommendations") | 0 |
| `resourceInventory` entries | 16 | 16 |
| `resourceType` entry for `Microsoft.Network/vpnSites` | `Available in APRL/ADVISOR?` = `No`, 4 resources | `Yes`, 4 resources |
| `-ErrorVariable` / `-WarningVariable` | 0 / 0 | 0 / 0 |
| Error records merged by `*>&1` | 0 | 0 |
| `$Error` | 0 | 4, each `No recommendation found for Microsoft.Network/vpnSites with resource id <id>` |
| `-ErrorAction Stop` or global `Stop` | Returns the object | Throws `WriteErrorException` for the first skipped resource; no object returned |

What this establishes:

- `-ErrorVariable` captures nothing, and neither the host nor the error stream shows the
  error. The module boundary is not the cause: the module and dot-sourced variants behave
  identically, and the class-method context is what changes the result.
- The issue's statement about `$Error` is true only in a weaker sense: `$Error` does
  receive a record per skipped resource, but it is a shared, capped list of message-only
  records. The type and ID exist only inside the message text, and records beyond 256 are
  lost.
- Whether a run aborts or silently under-reports depends on the caller. Only an explicit
  `-ErrorAction Stop` or a global `Stop` aborts, at the first skipped resource and with no
  output. A script-scope `$ErrorActionPreference = 'Stop'`, the usual top-of-script
  setting, does not reach the module, so that caller gets the silent behavior.
- Function-level reporting is capturable: the control cases show `-ErrorVariable` and
  `-WarningVariable` working for `Write-Error` and `Write-Warning` written from a
  function, and A5 confirms the warning through `Start-WARACollector`.

**Gap against desired outcome:** the error-propagation question in the issue is answered:
the class-method context, not the module boundary, hides the error from `-ErrorVariable`,
the error stream and the host, leaving only an unstructured, capped `$Error` record. A
contract that relies on `-ErrorVariable` or `-WarningVariable` therefore has to carry the
skipped resources out of the class as data and report them from function scope, because
neither variable captures anything written inside the method.

### A3. In the published metadata the condition is routine, not rare

A scratch script replays the four conditions of A1 for a hypothetical resource of each
WARA in-scope type, using the module's own expressions, against the live published files
fetched on 2026-10-09 (the module's default URIs) and against the snapshots in the repo's
test data. It does not know which types a given tenant holds.

| Measure | Live (2026-10-09) | Repository fixture |
| --- | --- | --- |
| `recommendations.json` | 393 recommendations, 80 types, all `Active`; 143 automated, 250 manual; 49 with a `recommendationTypeId` | 450 recommendations, 72 types; 384 `Active`, 66 `Disabled`; 185 automated, 265 manual; 31 with a `recommendationTypeId` |
| CSV rows with `WARAinScope = yes` | 199 (`Yes` 125, `No` 74) | 197 (`Yes` 123, `No` 74) |
| `Yes` types reaching outcome 4 | 53 | 56 |
| `Yes` types reaching outcome 2 | 55 | 52 |
| `Yes` types reaching outcome 1 | 17 | 15 |
| `No` types reaching outcome 3 | 72 | 73 |
| `No` types reaching outcome 2 / outcome 1 | 2 / 0 | 0 / 1 |

Findings from the live run:

- 53 of the 125 `Yes` types (42%) reach the `Write-Error` branch. Four are
  `Specialized.Workload/*` placeholders (`AVD`, `AVS`, `HPC`, `SAP`) that are not ARM
  resource types. The other 49 are real types, including common ones such as
  `Microsoft.Compute/virtualMachines/extensions`, `Microsoft.Compute/snapshots`,
  `Microsoft.Compute/availabilitySets`, `Microsoft.Compute/virtualMachineScaleSets`,
  `Microsoft.Network/firewallPolicies`, `Microsoft.Logic/workflows` and
  `Microsoft.DataFactory/factories`. The error is raised once per resource, not once per
  type.
- 52 of the 53 have no recommendation at all in `recommendations.json`. The exception,
  `Microsoft.Compute/virtualMachineScaleSets`, has 9 active recommendations: 6 automated
  with an empty `recommendationTypeId`, 2 automated with a `recommendationTypeId`, and 1
  manual that carries a `recommendationTypeId`, which outcome 2's filter excludes. It
  escapes outcome 1 because one recommendation is manual, and it has no qualifying manual
  recommendation for outcome 2.
- Advisor cross-check, using the Advisor metadata fixture
  (`src/tests/data/wara/test_advisormetadata.json`: 1,531 recommendation types with
  `supportedResourceType`, age unknown): of the 53 types, 22 have a `HighAvailability`
  type (the category the collector queries in `advisor.psm1`), 26 have types only in other
  categories, and 5 have none (the four placeholders and `Microsoft.Resources/subscriptions`).
  Static metadata cannot show whether Advisor emits a recommendation in a given tenant.
- The reverse inconsistency also exists: live `Microsoft.Network/vpnSites` and
  `Microsoft.Network/dnsResolvers` are flagged `No` yet each has one active manual
  recommendation. They reach outcome 2, so nothing is dropped.
- Outcome 1 ignores recommendation state. Neither data set has a `Yes` type that reaches
  it while lacking an `Active` recommendation, although the fixture does contain 66
  `Disabled` recommendations.
- The existing `Start-WARACollector -PassThru` fixture never reaches outcome 4: the
  baseline run produced 51 rows and an empty `$Error` (A6).

**Gap against desired outcome:** the situation the issue calls inconsistent metadata is
the normal state for about 42% of `Yes` types today, and the static metadata cannot
separate "covered elsewhere" (Advisor or automated checks) from "uncovered". The contract
needs a definition of what counts as skipped, which the code does not state and which
Phase B must settle (A8.1), before the question of where to report it can be closed.

### A4. The collector output has no place for run diagnostics

`Start-WARACollector` assembles `$outputJson` with nine top-level keys: `scriptDetails`,
`impactedResources`, `resourceType`, `advisory`, `outages`, `retirements`,
`supportTickets`, `serviceHealth` and `resourceInventory` (`wara.psm1:545-555`).
With `-PassThru` the object is returned (`wara.psm1:563`); otherwise it is written with
`ConvertTo-Json -Depth 15` to `.\WARA-File-<yyyy-MM-dd-HH-mm>.json` and nothing is
returned (`wara.psm1:567-569`). `scriptDetails` (`wara.psm1:518-540`) records the module
version, elapsed time, switches, scope, URIs and runtime parameters, with no counts or
diagnostics. The README quick start runs the collector and hands the file to
`Start-WARAAnalyzer`, so a caller on that path sees only the JSON.

The analyzer reads the file with `Get-Content | ConvertFrom-Json`
(`analyzer/2_wara_data_analyzer.ps1:214-230`) and then accesses named keys
(`ScriptDetails`, `ImpactedResources`, `Advisory`, `Retirements`, `Outages`,
`SupportTickets` and `resourceInventory`, lines 1142-1198). It does no schema validation
and does not enumerate top-level keys, so an additional key is neither rejected nor read.

The output shape is documented nowhere: the `OUTPUTS` heading in
`docs/wara/Start-WARACollector.md` (line 306) is empty, and the function's comment-based
help has no `.OUTPUTS` section. `docs/wara/wara-module-classes.md` documents the
`validationResourceFactory` properties (lines 192-196) and diagram (lines 53-59). The
`Start-WARACollector` page is maintained by hand: it has no platyPS metadata block (the
pages under `docs/advisor/` have one), its history is manual edits, and
`.github/scripts/Generate-Documentation.ps1` loops only over the sub-module folders of
`src/modules/wara/`, so it never processes the root `wara` module.

**Gap against desired outcome:** no existing field, section or stream carries run
diagnostics. Any contract adds a new element to the returned object and the JSON, or a
new output channel, and today that element would be tolerated by the analyzer but not
consumed by it.

### A5. Prior art: the prototype captured in the issue comment

A comment on the issue (2026-10-09) preserves an uncommitted prototype from a local
branch. It adds an `UnmatchedResources` list to `validationResourceFactory`; changes
outcome 4 so the resource is recorded in that list and still receives a "No
Recommendations" row (types already in `TypesNotInAPRLOrAdvisor` are unchanged); has
`Build-ValidationResourceObj` emit one `Write-Warning` with per-type counts; documents
the property in `wara-module-classes.md`; and adds two tests to `wara.tests.ps1`. The
earlier `## Fast-track scan` comment records `NOT FLAGGED` (XS likelihood Medium; rows 1
and 3 `No`) and is treated here as prior art.

Verified here against a scratch copy of the `64517cb` tree:

- The patch applies cleanly (`git apply --check` and `git apply`).
- In a clean session `wara.tests.ps1` passes 18 of 18: the 16 existing tests and the 2 new
  ones. The comment notes that the exact patch had not been run. (A first attempt in a
  session that already had another `wara` copy loaded failed with "Multiple script or
  manifest modules named 'wara' are currently loaded"; that is a harness artifact.)
- Through `Start-WARACollector -PassThru` with the A2 drift reproduction, `impactedResources`
  stays at 51 (the 4 `vpnSites` rows are kept), `-WarningVariable` captures 1 warning,
  `-ErrorVariable` and `$Error` are empty, and neither `-ErrorAction Stop` nor a global
  `Stop` aborts the run.
- The warning text is: `No recommendation found for 4 resource(s); they are listed as
  'No Recommendations' for manual validation. This usually means WARAinScopeResTypes.csv
  marks a resource type as InAprlAndOrAdvisor='Yes' when recommendations.json has no
  matching active recommendation. Affected type(s): Microsoft.Network/vpnSites (4).`

What the prototype leaves open:

- The 4 kept rows are identical to genuine "No Recommendations" rows: the same
  `validationAction` text ("Resource Type is not available in either APRL or Advisor ...")
  and an empty `recommendationId`. The data does not distinguish them.
- The warning names types and counts, not IDs. The IDs exist only in `UnmatchedResources`
  inside `Build-ValidationResourceObj`, which `return , $r` discards, so no caller can read
  them.
- The row text and the warning explanation say the type is not covered, while the CSV flag
  is `Yes` and, per A3, 22 of the 53 live types have an Advisor `HighAvailability` type in
  the metadata snapshot.
- Rows are now added for every resource of the 49 real types in A3. The resulting volume
  depends on the tenant and was not measured.

**Gap against desired outcome:** the prototype removes the invisible error and the abort,
and its warning is capturable, but it provides no ID-level record to a caller and it
changes the output rows for types that may be legitimately covered. The minimum change it
still needs for this issue is a returned record of skipped resource IDs and types.

### A6. Test and documentation scaffolding

`src/tests/wara/wara.tests.ps1` has an empty `Describe 'Build-ValidationResourceObj'`
(line 266) and an empty `Describe 'Build-SpecializedResourceObj'` (line 294). The only
test that reaches `validationResourceFactory` is `Start-WARACollector ... -PassThru`
(lines 74-168), which pins 51 rows and the `validationAction` counts and does not reach
outcome 4. Internal functions are tested through `InModuleScope 'wara' -Parameters @{...}`
(for example `Build-ImpactedResourceObj`, lines 171-264).

The baseline run at `64517cb` passes 16 of 16 in about 14 seconds. It is not hermetic:

- The CSV mock (line 99) filters on
  `https://raw.githubusercontent.com/Azure/Azure-Proactive-Resiliency-Library-v2/refs/heads/main/tools/WARAinScopeResTypes.csv`,
  but the module's default is `https://azure.github.io/WARA-Build/objects/WARAinScopeResTypes.csv`
  (`wara.psm1:152`), so the mock never matches and the real file is downloaded. The
  baseline log reports 199 in-scope types, which equals the live CSV, while the fixture
  CSV has 197. The recommendations mock (line 97) does match its default URI.
- `Find-Module` (`wara.psm1:158`) is not mocked, so every run queries the PowerShell
  Gallery.
- CI runs each module through `.github/scripts/RunPesterTests.ps1` on `ubuntu-latest`, with
  `continue-on-error: true` on every test step.

The drift reproduction in A2 shows a deterministic fixture is feasible: with the CSV mock
pointed at the correct URI, one flag flip reproduced the drop in about three seconds.
The contribution guide (`docs/wara/contribution-guide.md`, lines 85-86) asks for
documentation and Pester updates with code changes. `CHANGELOG.md` has an
`## [Unreleased]` section with a `### Patch` list. Nothing under `src/modules` uses
`Write-Warning`, `-ErrorVariable`, `-WarningVariable` or `$PSCmdlet.WriteError`, so there
is no in-repo convention for reporting a non-fatal condition.

**Gap against desired outcome:** no test pins the dropped-resource behavior or any
contract for it. A new test needs a fixture that reaches outcome 4 deterministically,
and building it on the current `-PassThru` scaffolding would inherit the live-network
dependency unless the CSV mock URI is corrected.

### A7. A related partial-collection site

The module has one other `Write-Error`: in the `catch` of `Invoke-WAFQueryLoop`
(`collector/collector.psm1:199`). It runs in a function, so by the A2 control it should be
capturable with `-ErrorVariable` (inferred; not run), but it also drops that
recommendation's results and lets collection continue, which is the same silent partial
output with a different cause (a failed query rather than inconsistent metadata). No
other class under `src/modules` calls `Write-Error` or `Write-Warning`.

**Gap against desired outcome:** the issue covers only the metadata-inconsistency cause,
so the failed-query site and outcome 1 sit outside its stated scope. A mechanism chosen
for outcome 4 could be reused for them, but nothing in the issue requires it.

### A8. Open questions for Phase B

1. What does "skipped" mean in the contract? Are resources of types covered through Advisor
   `HighAvailability` recommendations or automated queries (22 of the 53 types in A3 have
   an Advisor `HighAvailability` type) reported as skipped, and which source (CSV,
   `recommendations.json`, Advisor metadata) defines "covered"? If Advisor data is needed,
   is moving the decision after the Advisor calls (A1) acceptable?
2. What fields does a skipped-resource record carry (at least ID and type; possibly name,
   subscription, resource group and a reason), and is it one record per resource or an
   aggregate per type with counts and IDs?
3. Where does the record live: a new top-level key of the collector output (and so the
   JSON file), inside `scriptDetails`, only in the return value of
   `Build-ValidationResourceObj`, or elsewhere? Must it be present for a run without
   `-PassThru`?
4. Which notification accompanies the record: a function-level `Write-Warning` (capturable
   with `-WarningVariable`), a function-level error (capturable with `-ErrorVariable`),
   both, or none?
5. Does a skipped resource stay dropped, or does it get a row as in the prototype (A5), and
   if rows are added, how are they distinguished from genuine "No Recommendations" rows?
6. What does `-ErrorAction Stop`, explicit or global, do: keep aborting at the first
   skipped resource (A2), abort only after aggregating the full list, or never abort?
7. How is volume handled: per-resource records for many resources of one type, warning
   text length, and the 256-record `$Error` cap?
8. Is a new output key a public-surface or version-classification change, given that
   function names, parameters and `FunctionsToExport` stay the same, and does it count as
   a `### Patch` entry in `CHANGELOG.md`?
9. How is the contract tested: through `Start-WARACollector -PassThru`, through
   `InModuleScope` on `Build-ValidationResourceObj`, or both, and is correcting the CSV
   mock URI and the unmocked `Find-Module` (A6) part of this issue?
10. Is the scope limited to outcome 4, or does the same mechanism also cover the failed-query
    site and the silent outcome 1 (A7)?
11. Which documents state the contract: `docs/wara/Start-WARACollector.md` (hand-maintained,
    with an empty `OUTPUTS`), `docs/wara/wara-module-classes.md`, the README, or several?

## Phase B — Approach decisions

Decisions headed **Decision (confirmed)** were settled in discussion with the maintainer.
The others are proposals for this review.

### B1. A skipped resource means "no APRL verdict" (resolves A8.1)

**Decision (confirmed):** A resource is skipped when the validation step ends at outcome 4
(A1): its type is not fully automated, it has no qualifying manual recommendation, and its
type is not flagged `No`. The contract describes it as having "no APRL verdict": not
compliant, not non-compliant, and neither "covered" nor "uncovered". Every resource that
reaches outcome 4 is listed. There is no Advisor lookup, and the validation step is not
moved.

**Rationale:** A recommendation attached to a resource means it failed a check only for
automated APRL queries and Advisor findings; a manual-validation row is a to-do that
establishes nothing about the resource. A skipped resource has neither, so "no verdict" is
all the data supports (A3). A scratch run on the repo's fixtures shows why a stronger claim
would mislead: with the three manual API Management recommendations deactivated and the CSV
still flagging the type as covered, 4 resources were skipped and one of them,
`apiService3`, also carried an Advisor recommendation in `advisory`.

**Alternatives considered:** Excluding types that Advisor `HighAvailability` covers —
rejected: it needs the validation step moved after the Advisor calls, Advisor metadata only
says Advisor has a recommendation type for the resource type (a resource could leave the
list and appear nowhere), and 26 further types covered only in other Advisor categories
would stay on the list anyway. Splitting by cause now, for example `AdvisorCovered` —
deferred: the `reason` property (B2) lets codes be added later without a schema change
(F4). Listing only types with no recommendations — rejected: it would miss
`Microsoft.Compute/virtualMachineScaleSets`, which has recommendations but no qualifying
one.

### B2. One record per skipped resource, with a stable shape (resolves A8.2)

**Decision:** `skippedResources` holds one record per skipped resource with the properties
`id`, `name`, `type`, `location`, `subscriptionId`, `resourceGroup` and `reason`, using the
same names as `aprlResourceObj` for the shared ones. `reason` is a code, and this issue
defines one: `NoMatchingRecommendation`, meaning the type is flagged as covered in
`WARAinScopeResTypes.csv` but `recommendations.json` has no qualifying recommendation for
it. Records are sorted by `type`, then `id`, case-insensitively. The key name, the property
names and types, and the reason codes are the stable contract: properties and codes may be
added, and consumers must ignore the ones they do not know. Whether a record is a class or
a `PSCustomObject` is deferred to planning.

**Rationale:** The issue asks for IDs and types; the other properties already exist on the
validation resource and spare consumers from parsing the ID (the location cannot be
derived from it). The `reason` makes each entry say why it has no verdict, so a consumer
that reads the record without any workbook is told, and it lets later reasons be added
without a schema change. Sorting makes the JSON diffable and the tests deterministic,
because hashtable enumeration order is not a contract.

**Alternatives considered:** A per-type aggregate with counts and IDs — rejected: it hides
the resource-level properties, and consumers can group by `type` themselves. `id` and
`type` only — rejected: consumers would parse the ID or re-query for the rest. No `reason`
— rejected: the record would not say why the resource has no verdict.

### B3. A top-level `skippedResources` key, always present (resolves A8.3)

**Decision:** `Start-WARACollector` adds `skippedResources` as a top-level key of the
object it builds, so it appears in the `-PassThru` object and in the JSON file, next to
`impactedResources` and `resourceInventory`. It is always present: an empty array when
nothing was skipped, never omitted and never `null`. The list passes through the same tag
filter as `impactedResources` (`wara.psm1:431-466`), because the validation step runs
before that filter and an unfiltered list would name resources the run excluded from every
other section; subscription and resource-group scope are already applied before the
validation table is built (`wara.psm1:327`, `wara.psm1:353`). `scriptDetails` and the other
sections are unchanged, and no exported function gains a parameter. How the list travels
from the class through `Build-ValidationResourceObj` (which is not exported) to
`Start-WARACollector` is deferred to planning.

**Rationale:** Downstream consumers that read the collector's data before any packaging see
the key as soon as it exists, and the in-repo analyzer reads only named sections, so it
neither rejects nor reads the new key (A4). An always-present array spares consumers an
existence check and the `null` versus empty-array ambiguity of `ConvertTo-Json`.

**Alternatives considered:** Inside `scriptDetails` — rejected: it describes the run
(parameters, scope, URIs), not result data, and a list that can hold thousands of entries
does not belong there. A new output parameter or variable on `Start-WARACollector` —
rejected: it changes the exported signature and does not reach the JSON file. Only the
return value of `Build-ValidationResourceObj` — rejected: no caller of the collector can
see it.

### B4. One aggregated warning from function scope (resolves A8.4)

**Decision (confirmed):** When at least one resource is skipped, one `Write-Warning` is
emitted per run from function scope, never from inside the class. It states the number of
skipped resources and types, lists per-type counts for the ten largest types followed by
"and N more types" when there are more, says that no APRL verdict was produced because no
qualifying recommendation was found although the CSV flags the type as covered, and points
to `skippedResources` for the IDs. It claims no cause. The `Write-Error` in
`createValidationResourceObjects()` is removed; nothing is written to a stream from inside
the class.

**Rationale:** A function-level warning is captured by `-WarningVariable` through
`Start-WARACollector` (A2, A5), which a class-method warning is not. One message per run
avoids a flood and the 256-record `$Error` cap, and the neutral wording follows B1: for
some types the cause is Advisor coverage rather than drift (A3).

**Alternatives considered:** `Write-Information` only — rejected by the maintainer: it is
silent by default, so a default run looks the same as today. No message, data only —
rejected by the maintainer. A function-level error — rejected: it would abort under
`-ErrorAction Stop` (B6) and calls a missing verdict a failure. One warning per resource —
rejected: it floods the host.

### B5. Skipped resources stay out of `impactedResources` (resolves A8.5)

**Decision (confirmed):** A skipped resource receives no row in `impactedResources`.
Outcomes 1 to 3 and the existing sections are unchanged, so row counts and the workbook the
analyzer builds stay as they are. How a skipped resource is presented to an assessor (rows,
wording, reassigning its outcome later) is "packaging" and is raised as follow-up F1.

**Rationale:** Downstream consumers work from the collector's data until it is accurate and
useful enough to package. Reusing the "No Recommendations" outcome would misrepresent the
resource: its text says "not available in either APRL or Advisor", which the CSV flag
contradicts and which is wrong for types Advisor covers (A5). A distinct record with a
reason tells a reader why the resource has no verdict, with no existing outcome to override
later.

**Alternatives considered:** The prototype's "No Recommendations" rows — rejected as above,
and they cannot be told apart from genuine rows (A5). Rows with new wording — deferred to
F1: the analyzer matches `validationAction` text exactly, and a new text with no
recommendation ID lands in its `Custom` bucket with no instructions
(`analyzer/2_wara_data_analyzer.ps1:493-501`), so it needs an analyzer change.

### B6. A skipped resource never aborts a run (resolves A8.6)

**Decision:** Because a skipped resource raises no error, an explicit `-ErrorAction Stop`
or a global `Stop` preference no longer aborts collection at the first skipped resource. A
caller that wants fail-fast uses `-WarningAction Stop`, which throws
`ActionPreferenceStopException` at the single aggregated warning, so that run ends without
output. The behavior change is documented (B11) and stated in the CHANGELOG entry.

**Rationale:** With 53 of 125 `Yes` types reaching the branch (A3), an aborting run is
unusable for tenants that hold such resources, and abort-at-first names one resource and
returns nothing (A2). A scratch run through `Start-WARACollector` with a function-level
warning (the A5 prototype) confirmed that `-ErrorAction Stop` and a global `Stop` complete
and return the object, while `-WarningAction Stop` throws and returns no object.

**Alternatives considered:** Keeping error severity from function scope (capturable with
`-ErrorVariable`) — rejected: it reintroduces the abort under `Stop` and calls a missing
verdict a failure. A parameter that chooses between abort and continue — rejected:
`-WarningAction Stop` already provides fail-fast without a new parameter.

### B7. No cap on the record, a bounded warning (resolves A8.7)

**Decision:** `skippedResources` has no cap: one record per skipped resource. The warning
text is bounded as in B4. Nothing relies on `$Error`.

**Rationale:** A cap would break the complete-record property that is the point of the
contract, and the section is of the same order as `impactedResources` and
`resourceInventory`, which already hold one entry per resource. One bounded warning avoids
the flood and the 256-record eviction of `$Error` (A2).

**Alternatives considered:** Truncating the list past a threshold — rejected: it
reintroduces silent omission. A warning per resource — rejected (B4).

### B8. Version impact is `minor` (resolves A8.8)

**Decision:** The change is classified `minor` in the plan and in the `CHANGELOG.md` entry
under `[Unreleased]`, which has only a `### Patch` list so far: it is an additive,
non-breaking new capability (a new output key and a new visible warning). No function name,
parameter or `FunctionsToExport` entry changes. The `-ErrorAction Stop` behavior change
(B6) is stated in the entry.

**Rationale:** The repo's definitions (`plan-issue`, Version impact) reserve `patch` for
changes "invisible to consumers", and this one is visible. Nothing breaks for a consumer
that reads named keys, which is how the analyzer reads the file (A4), so it is not `major`.

**Alternatives considered:** `patch` because the issue is `type:fix` — rejected: the
classification follows consumer visibility, not the issue type. `major` — rejected: no
existing consumer breaks.

### B9. Tests: a unit layer and one hermetic end-to-end test (resolves A8.9)

**Decision:** Two layers, both in `src/tests/wara/wara.tests.ps1`.

1. `Build-ValidationResourceObj`, through `InModuleScope 'wara'`, fills the empty
   `Describe` (line 266): rows unchanged; the shape, sorting and reason of the records; one
   warning captured by `-WarningVariable`; no error in `-ErrorVariable` or `$Error`; no
   abort when `$ErrorActionPreference` is `Stop` in module scope; and the empty case.
2. One end-to-end test through `Start-WARACollector -PassThru`, in its own `Context` with
   its own hermetic mocks (the CSV mock at the module's actual default URI, and
   `Find-Module` mocked), using the one-flag drift fixture from A2: the content of
   `skippedResources`, an unchanged `impactedResources` count, the warning captured, no
   `-ErrorVariable` entry, `-ErrorAction Stop` completing and returning the object, and
   `-WarningAction Stop` throwing.

The existing `-PassThru` test is not changed; its live-network dependency is raised as
follow-up F7.

**Rationale:** The contract lives on the output of `Start-WARACollector`, so it needs an
end-to-end test; the unit layer pins the function and keeps failures local. A new `Context`
with its own mocks does not inherit the live-network dependency (A6), and the one-flag
drift fixture reproduced the drop in about three seconds.

**Alternatives considered:** Reusing the existing `Context`'s `BeforeAll` — rejected: it
inherits the unmocked CSV and `Find-Module`. Fixing the existing test here — rejected: a
separate defect with its own issue (F7). Unit tests only — rejected: they cannot show what
a caller of the collector sees.

### B10. Scope is outcome 4; every other gap becomes a follow-up issue (resolves A8.10)

**Decision (confirmed):** This issue is limited to outcome 4 and the `skippedResources`
contract. The other gaps found during the investigation are not fixed here; each is raised
as its own issue on the board. The plan carries a "Follow-up issues to raise" section that
copies the table below, and its Acceptance criteria or Definition of done has one checkbox
per item. Raising happens during implementation. F8 and F9 are proposals, and F10 was added
in Phase C (C2); strike any of them in review if unwanted.

| # | Proposed title | Type | Basis |
| --- | --- | --- | --- |
| F1 | Package skipped resources for assessors | `type:feat` | B5: a skipped resource appears only on the `2.WorkloadInventory` sheet today, not in the analysis sheets |
| F2 | Record failed automated queries in the collector output | `type:fix` | A7: `Invoke-WAFQueryLoop` writes a console error and continues, leaving no record, so absent results read as compliant (code read; not run) |
| F3 | Report types whose automated recommendations are all inactive | `type:fix` | A1, A3: outcome 1 ignores `recommendationMetadataState`; no live type is affected today |
| F4 | Report whether Advisor covers a skipped resource's type | `type:feat` | A3: Advisor silence cannot be told apart from no coverage (22 / 26 / 5) |
| F5 | Derive `Available in APRL/ADVISOR?` from recommendations as well as the CSV flag | `type:fix` | A2: the field echoes the CSV flag only, "Yes" for skipped types and "No" for live `vpnSites` and `dnsResolvers`, which have manual recommendations |
| F6 | Stop manual-row labels asserting reasons the data does not state | `type:fix` | Of 246 live manual recommendations, 19 are labelled "under development" by the `*Azure Resource Graph*` clause and 21 "cannot be validated with ARGs" by the default clause (empty query), with no marker |
| F7 | Make the `Start-WARACollector -PassThru` test hermetic | `type:chore` | A6: the CSV mock URI never matches and `Find-Module` is unmocked |
| F8 | Raise follow-up issues as a standard step of plan approval | `type:chore` | `plan-issue` and `approve-ready-for-implement` have no step for it |
| F9 | Document the full `Start-WARACollector` output shape | `type:docs` | A4: `OUTPUTS` is empty, and the help and docs give `raw.githubusercontent.com` as the default of `-RecommendationResourceTypesUri` while the parameter default is `azure.github.io` |
| F10 | Stop the collector aborting on an empty filter input | `type:fix` | C2: `Get-WAFFilteredResourceList` rejects an empty list, so the unmodified collector throws at `wara.psm1:427` when Advisor returns nothing in scope (verified with the fixture mocks; the real helper returns `$null` for an empty query), and the tag-filter calls are exposed the same way |

**Rationale:** Awareness of the other gaps is only durable if they are issues on the board,
not notes in a document. They have different causes and each needs its own decision (for
example, what a failed query should do), so folding them in would turn a contract change
into an audit of the collector.

**Alternatives considered:** Folding any of F2 to F6 into this issue — rejected: different
causes, and the `reason` property (B2) is designed to take their results later without a
schema change. Raising the issues now, during the investigation — not chosen: the
maintainer is content for raising to happen during implementation, tracked by checkboxes.
Leaving them as notes in this document — rejected: the maintainer wants them on the board.

### B11. Where the contract is documented (resolves A8.11)

**Decision:** The contract is documented in four places.

1. The comment-based help of `Start-WARACollector`: a new `.OUTPUTS` section describes
   `skippedResources` with its properties and the `reason` code, and the description gains
   the warning and the no-abort behavior. This is what `Get-Help` shows.
2. The `OUTPUTS` section of `docs/wara/Start-WARACollector.md` (line 306), edited by hand to
   the same text: the page is not generated (A4).
3. `docs/wara/wara-module-classes.md`, for any class property or class the change adds (the
   `validationResourceFactory` properties and diagram).
4. `CHANGELOG.md`.

The README is not changed. The page states which parts are stable (key name, property names
and types, reason codes) and that consumers must ignore properties they do not know.

**Rationale:** `Get-Help` reads the comment-based help and the docs page is a separate,
hand-maintained file, so the contract has to be written in both (C13); the class page
covers class members; and the contribution guide asks for documentation with code changes
(A6). Documenting the whole output shape is a separate task (F9).

**Alternatives considered:** The README — rejected: it does not describe output keys. A JSON
Schema file — rejected for now: nothing validates the output today, so it would have no
consumer in the repo.

## Phase C — Risks and prerequisites

The risks below follow from the Phase B design. Each entry gives the evidence, the effect
if nothing is done, the mitigation the plan carries, and a rating. Evidence is **verified**
when it was run here on PowerShell 7.6.6 in scratch scripts outside the repository, and
**inferred** when it comes from reading code. Ratings are Low, Medium or High for
likelihood and impact, before the mitigation.

| # | Risk | Evidence | Likelihood | Impact |
| --- | --- | --- | --- | --- |
| C1 | The tag filter rejects an empty list | Verified | High | High |
| C2 | The collector already aborts on an empty filter input | Verified | Not measured | High |
| C3 | A list loses its array shape on the way out | Verified | High | Medium |
| C4 | The tag filter reorders its input | Verified | Medium | Low |
| C5 | The warning can disagree with the record | Inferred | Medium | Medium |
| C6 | A changed return value of `Build-ValidationResourceObj` corrupts the rows | Inferred | Low | High |
| C7 | Callers that relied on the abort see the run complete | Verified | Low | Medium |
| C8 | The warning appears on many runs | Inferred | High | Low |
| C9 | `type` is cased differently within one record set | Inferred | Low | Low |
| C10 | Sorting follows the host culture unless the comparison is ordinal | Verified | Low | Low |
| C11 | The contract is locked in once released | Inferred | Low | Medium |
| C12 | Test and CI hazards | Verified | High | Medium |
| C13 | The contract is written in two places that nothing keeps in step | Verified | Medium | Low |
| C14 | The old prototype worktree sits at the implement folder | Verified | Low | Low |

### C1. The tag filter rejects an empty list

**Evidence (verified):** B3 sends `skippedResources` through the same tag filter as
`impactedResources` (`wara.psm1:457`). `Get-WAFFilteredResourceList` declares
`-UnfilteredResources` as mandatory without `AllowEmptyCollection` (`scope.psm1:294-295`),
so an empty list fails before the function body runs with `Cannot bind argument to
parameter 'UnfilteredResources' because it is an empty collection`. A `$null` fails the
same way.

**Effect:** Zero skipped resources is the normal case for a tag-scoped run, so an unguarded
call would abort every such run that skips nothing and break behavior that works today.

**Mitigation:** Call the filter only when the list has entries; an empty list needs no
filtering. Tests cover `-Tags` with zero and with some skipped resources.

**Likelihood and impact:** High and High unguarded; Low once guarded.

### C2. The collector already aborts on an empty filter input

**Evidence (verified):** The same parameter rule applies to the calls that exist today. With
the baseline mock set of A2 (the mocks of the existing test, with the CSV mock at the
module's default URI) and only `Get-WAFAdvisorRecommendation` changed, the unmodified
collector (`64517cb`) behaves as follows.

| Advisor result | Outcome |
| --- | --- |
| Fixture data | Completes with 51 `impactedResources` and 4 `advisory` entries |
| Empty array | Throws `ParameterBindingValidationException` at the Advisor filter (`wara.psm1:427`) |
| `$null` | Throws the same exception |

The real helpers produce the `$null` case: with a stand-in for `Search-AzGraph` that returns
an empty list with a `SkipToken` property, the shape `Invoke-WAFQuery` reads, that function
returned an empty array and `Get-WAFAdvisorRecommendation` returned `$null`. A result that
holds only subscription-level recommendations reaches the same filter empty, because the
call passes `.where({ $_.type -ne 'microsoft.subscriptions/subscriptions' })`. The three
tag-filter calls (`wara.psm1:451`, `wara.psm1:457` and `wara.psm1:463`) are exposed the same
way under `-Tags` when their list is empty (parameter definition read; not run end to end).

**Effect:** A run against a scope where Advisor has nothing to report ends with no output
and a message that does not name the cause. This exists today and is independent of #3; how
often real tenants hit it was not measured.

**Mitigation:** Not part of this issue: F10 is added to the B10 table. It is not a
prerequisite, because the guard in C1 is correct whether or not the helper later accepts
empty lists. If F10 lands first, the guard becomes redundant and harmless.

**Likelihood and impact:** Not measured and High for the existing calls; no added exposure
from this issue once C1 is guarded.

### C3. A list loses its array shape on the way out

**Evidence (verified):** A function that returns an empty list hands its caller `$null`, and
one that returns a single entry hands over the bare object. Through `ConvertTo-Json`, a plain
return gave `null` for no entries and an object, not an array, for one; returning with the
unary comma, which the module already does for its row lists (`Build-ValidationResourceObj`,
`Get-WAFFilteredResourceList`), gave `[]` and a one-element array.

**Effect:** B3 promises an always-present array. Without care the key is `null` when nothing
is skipped and an object when one resource is, so consumers would meet three shapes, and the
cases a first test is likeliest to use, none and one, are exactly the ones that break.

**Mitigation:** Keep the list an array end to end: return it with the unary comma at every
function boundary, assign it through an `[array]` variable, and build the key from a value
known to be an array. Tests assert the serialized JSON for 0, 1 and several entries rather
than a count, which can read the same for a bare object and a one-element array.

**Likelihood and impact:** High and Medium without the care; Low with the tests.

### C4. The tag filter reorders its input

**Evidence (verified):** `Get-WAFFilteredResourceList` concatenates its matches by kind:
subscription matches, then resource-group matches, then resource matches. An input of
`a1, b1, a2`, with a resource-group filter matching `a1` and `a2` and a resource filter
matching `b1`, came back as `a1, a2, b1`.

**Effect:** A list sorted before the filter loses B2's order whenever tags are used.

**Mitigation:** Sort after the tag filter, as the last step before the key is set (C5). A
test with tags, where the input order and the filtered order differ, pins it.

**Likelihood and impact:** Medium and Low.

### C5. The warning can disagree with the record

**Evidence (inferred):** The validation step runs at `wara.psm1:391`, before the tag filter
(`wara.psm1:431-466`). A warning built inside `Build-ValidationResourceObj`, as in the
prototype (A5), counts resources that the run later removes from every other section.

**Effect:** Under `-Tags` the message would name more resources than `skippedResources`
holds, and some of the IDs it points to would not be there. People act on the message.

**Mitigation:** Build the warning in `Start-WARACollector` after the tag filter, from the
same filtered and sorted list that the output holds, so the message and the record have one
source. This moves the warning assertions of B9's unit layer to wherever that code lives; a
small internal helper called by `Start-WARACollector` keeps them unit-testable, and the plan
settles it.

**Likelihood and impact:** Medium and Medium.

### C6. A changed return value of `Build-ValidationResourceObj` corrupts the rows

**Evidence (inferred):** The function returns the row array with `return , $r`, and the
caller appends it with `$impactedResourceObj += $validationResourceObj` (`wara.psm1:391`
and `wara.psm1:397`). A composite return, rows plus skipped list, would be appended as one
element: the validation rows would be missing and a non-row object would sit in
`impactedResources`.

**Effect:** `impactedResources` silently loses its validation rows. The existing
`Start-WARACollector -PassThru` test pins 51 rows and the `validationAction` counts, so it
would fail, but only if it is run (C12).

**Mitigation:** Leave the row return as it is and carry the skipped list through an additive
channel: an optional list parameter filled in place, or a property read from the factory
object after the call. An optional parameter must not be mandatory, because a mandatory
collection parameter rejects an empty list (C1). The plan chooses.

**Likelihood and impact:** Low and High, and loud when it happens.

### C7. Callers that relied on the abort see the run complete

**Evidence (verified in A2 and B6):** Today an explicit `-ErrorAction Stop` or a global
`Stop` preference throws at the first skipped resource and returns nothing. After the change
the same run completes, returns the object and emits one warning, and the per-resource
`$Error` records are gone. The change also adds the module's first `Write-Warning` (A6), so
a caller whose `$WarningPreference` is `Stop` is newly aborted when something is skipped,
which is what that setting asks for.

**Effect:** A pipeline that used the exception as its signal of inconsistent metadata stops
getting it. A script-scope `$ErrorActionPreference = 'Stop'`, the usual setting, never
reached the module (A2), so most callers saw silent success before and keep it, plus the
warning and the record.

**Mitigation:** B6 documents fail-fast through `-WarningAction Stop`; B11 and the
`CHANGELOG.md` entry state the change; the end-to-end test pins both behaviors (B9).

**Likelihood and impact:** Low and Medium.

### C8. The warning appears on many runs

**Evidence (inferred from A3):** 53 of the 125 `Yes` types (42%) reach outcome 4 in the live
metadata, so a tenant that holds any of them gets the warning on every run. The share of
real runs affected depends on the tenant's mix of types and was not measured.

**Effect:** A message that appears on most runs and that the tenant cannot act on is learned
and ignored, which defeats its purpose.

**Mitigation:** One message per run with bounded text and neutral wording (B4); the warning
can be suppressed with `-WarningAction SilentlyContinue` while the record remains; F1 and F4
are where the signal becomes actionable. The maintainer rejected "no message" (B4).

**Likelihood and impact:** High and Low; accepted in B4.

### C9. `type` is cased differently within one record set

**Evidence (inferred from code):** `$validationResources` takes each ID from the impacted
objects first and from the inventory second (`wara.psm1:366-369`, `wara.psm1:380-383`).
Impacted objects carry the recommendation's `recommendationResourceType`
(`wara.psm1:897`), in mixed case such as `Microsoft.Compute/virtualMachineScaleSets`.
Inventory entries carry the casing that Resource Graph returns, which is lower case in the
collector's own type data (`src/tests/data/collector/test_types.json`) although the `wara`
inventory fixture is mixed case. A type that reaches outcome 4 and also has an impacted
resource, `virtualMachineScaleSets` in the live metadata (A3), can therefore appear under two
casings. The output already mixes casings across sections: `advisory` is lower case because
its query applies `tolower` (`advisor.psm1`).

**Effect:** A consumer that compares `type` case-sensitively, such as a script outside
PowerShell, counts two types. The warning's per-type counts are not affected, because
`Group-Object` ignores case.

**Mitigation:** B11 states that `type` is compared case-insensitively. Whether the record
normalizes the casing is a planning decision; lower case would match Resource Graph and
`advisory`.

**Likelihood and impact:** Low and Low.

### C10. Sorting follows the host culture unless the comparison is ordinal

**Evidence (verified):** `Sort-Object` compares strings by the current culture. On this
machine (`en-CA`), five IDs that differ only in the last segment sorted as `vm_a`, `vm-a`,
`vm.a`, `vm1`, `VmB`; an ordinal, case-insensitive comparison gave `vm-a`, `vm.a`, `vm1`,
`VmB`, `vm_a`. Cultures also differ from each other: `tr-TR` orders `ı` and `i` differently
from `en-US`.

**Effect:** B2's order is part of the contract and the tests compare it, on Windows machines
and on the `ubuntu-latest` CI runner. An order that depends on the host culture makes JSON
diffs noisy and tests host-dependent.

**Mitigation:** Sort with an ordinal, case-insensitive comparer and say so in the contract,
which refines B2's "case-insensitively"; fixture IDs should not differ only by punctuation.

**Likelihood and impact:** Low and Low.

### C11. The contract is locked in once released

**Evidence (inferred):** B2 makes the key, the property names and types, and the reason
codes stable; only additions are free.

**Effect:** A misnamed property, or a `reason` code whose meaning is too broad, cannot be
corrected without a breaking change, and consumers outside this repository can read the key
from the day it ships (B3).

**Mitigation:** The plan review settles the names before implementation; the first code
states only what the data supports, "flagged as covered, no qualifying recommendation" (A1);
the shared property names follow `aprlResourceObj` (B2); consumers are told to ignore
properties and codes they do not know (B2, B11).

**Likelihood and impact:** Low and Medium.

### C12. Test and CI hazards

**Evidence (verified here; the workflow was read):**

- A session that already holds another copy of `wara` makes `InModuleScope 'wara'` fail
  with "Multiple script or manifest modules named 'wara' are currently loaded" (hit in A5).
  `tools/Invoke-Pester.ps1` is a thin wrapper around `Invoke-Pester` and does not start a
  new session.
- `.github/workflows/pestertests.yml` sets `continue-on-error: true` on every test step, so
  a failing test does not fail the workflow.
- The existing `-PassThru` test reaches the network (A6), and a new end-to-end test inherits
  that unless the CSV (at the module's actual default URI), the recommendations and
  `Find-Module` are all mocked (B9).

**Effect:** A regression of the new contract can merge unnoticed, and a test can pass or fail
depending on the network and on what else the session has loaded.

**Mitigation:** The Definition of done includes a local full run in a new process
(`pwsh -NoProfile -File tools/Invoke-Pester.ps1`) with every test passing; the new `Context`
mocks the three external calls (B9).

**Likelihood and impact:** High and Medium.

### C13. The contract is written in two places that nothing keeps in step

**Evidence (verified):** `Get-Help` reads the comment-based help of `Start-WARACollector`,
which has no `.OUTPUTS` section. The page `docs/wara/Start-WARACollector.md` is maintained by
hand: it has no platyPS metadata block (the pages under `docs/advisor/` have one), its
history is manual edits, and `.github/scripts/Generate-Documentation.ps1` loops only over the
sub-module folders of `src/modules/wara/`, so it never processes the root `wara` module.

**Effect:** The help and the page can drift apart, and a later generator run would not repair
either.

**Mitigation:** Write both from the same text in the same commit (B11) and compare them as a
Definition-of-done item; F9 covers documenting the rest of the output shape.

**Likelihood and impact:** Medium and Low.

### C14. The old prototype worktree sits at the implement folder

**Evidence (verified):** `git worktree list` shows `C:/wt/wara/implement` as a worktree
(branch `issue-000-swallowed-error`, based on `8683227`) with three modified files: the
uncommitted prototype from A5. `tools/New-IssueWorktree.ps1` builds
`C:\wt\wara\<stage>\issue-<N>` (line 50), so the implement worktree for this issue is created
inside it. The 75 changed lines of the prototype are identical, as a set of lines, to the
patch preserved in the issue comment (A5), so the old worktree holds nothing that is not
preserved elsewhere.

In a throwaway repository with the same layout, git accepted the nested worktree and it
behaved as its own worktree: its own top level and branch, a clean status, normal commits.
The outer worktree changed only by one untracked entry, `issue-3/`. Nothing else reads or
depends on the old worktree: the creation script tests only the `issue-3` path and runs
`npm ci --prefix` in it; the release cleanup finds the worktree by branch name
(`approve-ready-for-release`, Step 6); the test file imports the module by relative path; and
`PSModulePath` holds no worktree path.

**Effect:** None on creating, testing, linting or releasing the #3 worktree, so keeping the
old worktree until the release is safe. It can only cause harm through commands run in the
old worktree itself. In the throwaway repository, `git add -A` there staged `issue-3` as an
embedded repository, `git clean -ffd` would remove it, and `git worktree remove --force` on
the old worktree while the inner one existed deleted both directories, including an
uncommitted file in the inner one (its branch and commits survived, and its entry stayed
listed as prunable until `git worktree prune`). The creation script also branches from `HEAD`
(`git worktree add ... HEAD`), the commit checked out where it is run, so run from the old
worktree it would start the new branch at `8683227` (2025-06-12) instead of at the release
branch.

**Mitigation:** No action before implementation. Run the creation script from the release
worktree, as for the investigation worktree, which sits at the release `HEAD` (`64517cb`).
Do not run `git add -A` or `git clean -ffd` in the old worktree, and remove it only after
the #3 worktree, which the release cleanup already removes. This investigation does not
touch it.

**Likelihood and impact:** Low and Low.

### C15. Concerns checked and dismissed

| Concern | Finding |
| --- | --- |
| Output size and serialization time | 20,000 flat records serialized with `ConvertTo-Json -Depth 15` to 7.8 MB in 332 ms and sorted in 120 ms (this machine, PowerShell 7.6.6). `resourceInventory` already holds one entry per in-scope resource, so the section adds no new order of magnitude and B7 needs no cap |
| The analyzer rejecting or misreading the new key | It reads named sections only (A4; code read, not run) |
| `$Error` flooding and the 256-record cap | Removed with the class `Write-Error` (B4) |
| The module boundary hiding the error | Ruled out in A2: the module and the dot-sourced script behave the same |
| A resource listed twice | `$validationResources` is keyed by ID and hashtable keys ignore case, so each resource is evaluated once (code read, `wara.psm1:366-383`) |

### C16. Prerequisites

No issue has to be finished first.

| Item | Relation to this issue | Blocks it? |
| --- | --- | --- |
| #8 | Changes how `/implement-issue` starts and creates its worktree; the problems it describes have workarounds | No |
| #9 | Would move the tracking of acceptance criteria and Definition of done into the issue body; until then the plan's checkboxes, including the follow-up ones, are ticked in the plan document | No |
| #10 | Bumps the markdown linter dependency; unrelated | No |
| Open pull requests | None | No |
| Other documents under `docs/issues` | None references the collector functions that this issue changes | No |

No action is needed before implementation starts; C14 is a note, not a prerequisite. The
follow-ups F1 to F10 are raised during implementation, and none of them blocks it.

### C17. Constraints the plan inherits

1. The validation rows, the exported signatures and `FunctionsToExport` do not change, and
   the existing 51-row test stays as it is (B5, B9, C6).
2. Nothing is written to a stream from inside the class (B4).
3. The skipped list is filtered by tags only when it has entries (C1), sorted afterwards with
   an ordinal comparer (C4, C10), and kept an array end to end, with tests on the serialized
   JSON for 0, 1 and several entries (C3).
4. The warning is built after the tag filter from the list that the output holds (C5).
5. The help and the docs page are written from the same text in the same commit, and
   `CHANGELOG.md` gets a `### Minor` heading (B8, B11, C13).
6. A full local test run in a new process is a Definition-of-done item (C12).
7. F1 to F10 are raised during implementation and ticked in the plan (B10).

## Phase D — Ready-to-plan summary

Issue #3 is ready to plan. The change adds a top-level `skippedResources` array to the
collector output, with one record for each resource that reaches outcome 4 of the
validation step (B1 to B3), and replaces the class `Write-Error` with one aggregated
warning that `Start-WARACollector` builds after the tag filter (B4, C5). A skipped
resource gets no row and never aborts a run (B5, B6). Every other gap found becomes a
follow-up issue, F1 to F10 (B10). No issue has to be finished first (C16).

### D1. Files in scope

| File | Change | Basis |
| --- | --- | --- |
| `src/modules/wara/wara.psm1` | Class `validationResourceFactory`: outcome 4 (`wara.psm1:1021-1023`) records the resource and no longer writes an error. `Build-ValidationResourceObj` (`wara.psm1:591-608`): hands the list to its caller and leaves the row return as it is. `Start-WARACollector`: after the tag filter (`wara.psm1:431-466`), filters the list when it has entries, sorts it, builds the one warning and adds the `skippedResources` key to `$outputJson` (`wara.psm1:545-555`). The comment-based help gains `.OUTPUTS` and describes the warning and the no-abort behavior | B1 to B6, B11, C1 to C6 |
| `src/tests/wara/wara.tests.ps1` | Fills the empty `Describe 'Build-ValidationResourceObj'` (line 266) and adds a hermetic end-to-end `Context` under `Describe 'Start-WARACollector'`, beside the `-passthru` one (line 74); the existing `-passthru` test is not changed | B9, C12 |
| `docs/wara/Start-WARACollector.md` | `OUTPUTS` section (line 306), edited by hand | B11, C13 |
| `docs/wara/wara-module-classes.md` | The class or property the change adds, in the `validationResourceFactory` properties (lines 192-196) and diagram (lines 53-59) | B11 |
| `CHANGELOG.md` | New `### Minor` heading under `## [Unreleased]`, with an entry that states a skipped resource no longer raises an error | B8 |

Not changed: `src/modules/wara/wara.psd1` (no function, parameter or `FunctionsToExport`
change), `src/modules/wara/scope/scope.psm1` (F10), `src/modules/wara/collector/collector.psm1`
(F2), the analyzer (F1) and the README (B11).

### D2. Decisions deferred to planning

Each decision has a recommendation; the plan review confirms or changes it.

1. **Record type (B2).** A small class beside `aprlResourceObj`, or a `PSCustomObject`
   built in the loop. Recommended: a class, because the module's other output records are
   classes and `wara-module-classes.md` is where their properties are documented (B11).
2. **How the list leaves the class (C6).** An optional list parameter on
   `Build-ValidationResourceObj` that the class fills in place, or a return value that
   carries the rows and the list together, which rewrites the call site and the append at
   `wara.psm1:397`. Recommended: the optional parameter. It is not mandatory, because a
   mandatory collection parameter rejects an empty list (C1), and the function has one call
   site (`wara.psm1:391`).
3. **Where the warning and the sort live (C4, C5).** Inline in `Start-WARACollector`, or in
   a small internal function that it calls after the tag filter. Recommended: the internal
   function, so that the unit layer of B9 can assert the order, the ten-type limit and the
   empty case without running the collector.
4. **Casing of `type` (C9).** Keep what the validation resource carries and document
   case-insensitive comparison, or lower-case it to match Resource Graph and `advisory`.
   Recommended: keep it. Resource types compare case-insensitively, and lower-casing adds a
   rule that `impactedResources` does not follow.
5. **Where the follow-up checkboxes live (B10).** Acceptance criteria or Definition of done.
   Recommended: Definition of done, one checkbox per row of F1 to F10, ticked when the issue
   is on the board. Acceptance criteria are feature-specific conditions, and raising an
   issue is a process step.
6. **Final contract names (C11).** The key `skippedResources`, the seven properties and the
   reason code `NoMatchingRecommendation` (B2) are stable once released. Recommended:
   confirm them as written at plan review.

### D3. Recommended commit strategy

Two commits on the feature branch, in the group order of `implement-issue` (source, tests,
docs). The first carries the body that `.github/COMMIT_GUIDELINES.md` requires for source
and test files:

1. `feat(#3)`: the source change and its tests, `wara.psm1` and `wara.tests.ps1`. They
   cannot be split, because removing the class `Write-Error` is only correct together with
   the record, the output key and the warning; without them a skipped resource would leave
   no trace at all.
2. `docs(#3)`: `Start-WARACollector.md`, `wara-module-classes.md` and `CHANGELOG.md`.

The type `feat` follows B8: the guidelines define it as a new capability visible to a
consumer, and the issue's `type:fix` label does not decide the classification.

### D4. Tests

New tests are required, all in `src/tests/wara/wara.tests.ps1`. The existing `-passthru`
test stays as it is and must keep passing (B9, C6).

| Layer | What it pins | Basis |
| --- | --- | --- |
| Unit, `Build-ValidationResourceObj` through `InModuleScope 'wara'` | The validation rows are unchanged; the list holds one record per outcome-4 resource with the seven properties and the reason; no error in `-ErrorVariable` or `$Error`; no abort when `$ErrorActionPreference` is `Stop` in module scope; the empty case | B2, B9 |
| Unit, the warning and sort function (if D2 item 3 is accepted) | Ordinal, case-insensitive order; one warning with the ten-type limit and "and N more types"; no warning for an empty list | B4, C5, C10 |
| End to end, `Start-WARACollector -PassThru`, new hermetic `Context` | The content of `skippedResources` with the one-flag drift fixture; the `impactedResources` count unchanged; the warning captured by `-WarningVariable`; `-ErrorAction Stop` completes and returns the object; `-WarningAction Stop` throws | B9 |
| End to end, with `-Tags` | Zero skipped resources: no abort and `[]`; some skipped: the list is tag-filtered and sorted afterwards; the `ConvertTo-Json -Depth 15` text for 0, 1 and several entries | C1, C3, C4 |

The suite is run locally in a new process (`pwsh -NoProfile -File tools/Invoke-Pester.ps1`),
because CI does not fail on a failing test and a session that holds another `wara` copy
breaks `InModuleScope` (C12).

### Sizing estimate

**Estimate:** M

| Driver | Weight | Reasoning |
| --- | --- | --- |
| Source change with several silent failure modes | High | `wara.psm1` changes in the class, `Build-ValidationResourceObj` and `Start-WARACollector`, an estimated 60 to 100 lines with the help; C1, C3, C4, C5 and C6 each fail without an error if missed, so each needs its own test |
| New test layers | High | The empty `Describe` is filled and a hermetic end-to-end `Context` is added with its own mocks (the CSV at the module's default URI, the recommendations, `Find-Module`), a drift fixture and JSON-shape assertions; an estimated 12 to 18 new `It` blocks |
| Ten follow-up issues | Medium | F1 to F10 are written and put on the board during implementation, each with a body drawn from the B10 table |
| Documentation in four places | Low | The help `.OUTPUTS`, the hand-maintained page, the class page and the CHANGELOG are text only, but the help and the page carry the same contract (C13) |
| Deferred design choices | Low | The six decisions in D2 are settled at planning and each has a recommendation |
| Verification | Low | The full suite in a new process; the manual smoke test of implement-issue Step 8 where a tenant is available |

Primary uncertainty drivers:

- Whether the plan folds F10 into this issue, by relaxing `Get-WAFFilteredResourceList`
  instead of guarding the call: `scope.psm1` and its tests would join the scope.
- Whether the hermetic end-to-end test needs mocks beyond the three external calls of C12
  to run without the network.
- Whether a tenant with resources of a skipped type is available for the smoke test; without
  one the hermetic tests are the only evidence.
- How much each follow-up issue needs beyond the basis column of B10.

Upgrade to L if the plan folds F10 or any other follow-up into this issue, or if the
hermetic end-to-end test needs more mocks than the three external calls of C12.
