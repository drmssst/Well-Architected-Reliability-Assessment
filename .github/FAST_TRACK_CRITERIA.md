# Fast-Track Criteria

The fast-track route is a second, governed path through the issue lifecycle for
low-risk `XS` papercuts. A flagged item carries the `lifecycle:fast-track` label and
sits at `status:plan`; it gets a compact plan behind one review gate and keeps every
release-side control. The normal route is unchanged.

This file is the single definition of the route's shared rules, names and templates.
These skills point to it instead of copying it:
[investigate-issue](skills/investigate-issue/SKILL.md),
[approve-ready-for-plan](skills/approve-ready-for-plan/SKILL.md),
[plan-issue](skills/plan-issue/SKILL.md),
[approve-ready-for-implement](skills/approve-ready-for-implement/SKILL.md) and
[implement-issue](skills/implement-issue/SKILL.md).

## Eligibility checklist

An issue is eligible only if all six conditions are true. Whoever is reading the code
at that point answers each one explicitly, with evidence: the investigator at scan 1 or
in the Phase D fast-track assessment, and again in the compact plan's
`### Fast-track check`. The approver verifies the recorded evidence. The scan comment,
the Phase D assessment and the plan's check all record the answers in the same
three-column table (Condition, Met, Evidence), with the rows below in this order. Each
answer is `Yes` or `No`, and a row without evidence is `No`. The one exception is scan
1, which may answer `Likely` under the [provisional flag](#provisional-flag-at-scan-1).

| # | Condition | Rule |
| --- | --- | --- |
| 1 | Size is XS | The self-assessed size is `XS` (see [XS definition](#xs-definition)). |
| 2 | Type is fix, chore or docs | The type label is `type:fix`, `type:chore` or `type:docs`. `type:feat` is never eligible. |
| 3 | Named, uniform edit | Every affected file is named up front, one path per row, with no globs and no numeric cap. Every named file other than the standard `CHANGELOG.md` entry receives the same uniform, mechanical class of edit, such as an identical substitution or an identical single-line value change. A mix of unrelated or judgment-dependent edits fails. |
| 4 | No public surface change | The change leaves the [public surface](#public-surface) as it is. |
| 5 | Fully reversible | A single revert commit undoes the change. No data migration and no irreversible external side effect, for example a live GitHub label or project taxonomy change. |
| 6 | No new dependency | No `package.json` addition and no new module import. |

### Public surface

Condition 4 holds when, comparing the base and head versions of every changed file, all
of these stay exactly as they are:

- Function names and parameter declarations (name, type, attributes and default value),
  including a script-level `param` block, in `src/modules/**/*.psm1` and
  `src/modules/**/*.ps1`.
- `FunctionsToExport` in `src/modules/**/*.psd1`.
- The set of key paths in `config/*.json`. A value-only change in a JSON file passes.

A function body change, or a `.psd1` change outside `FunctionsToExport` such as
`Description`, does not change the public surface. The guard in `implement-issue`
Step 9a compares only the items above. Anything else a module exposes, for example the
classes in `runbook.classes.ps1` that `runbook.psd1` loads through `ScriptsToProcess`,
is not compared, so the plan-time answer and review must cover it.

### Provisional flag at scan 1

Scan 1 runs before the investigation, so when the author did not know the issue was
trivial, some rows cannot be evidenced yet. For those rows only, scan 1 may answer
`Likely`: not yet evidenced, and nothing seen argues against it. Row 2 is never
`Likely`, because the type label is known. `Likely` appears nowhere else. The Phase D
assessment, the post-investigation decision and the plan's `### Fast-track check` answer
`Yes` or `No`.

Scan 1 also records an XS likelihood, its opinion that the work will turn out to be `XS`:

| Likelihood | Meaning |
| --- | --- |
| High | You can state the likely fix in one sentence, what changes and roughly where, and it fits the [XS definition](#xs-definition). Nothing seen argues against any row. |
| Medium | The fix is plausible, but you cannot yet say what changes or where, or one row looks doubtful. |
| Low | The issue reads as a feature, a design question or a multi-part change. |

Row 1 follows the likelihood: `Yes` when the size is evidenced, for example the issue
names a one-line change; `Likely` when the likelihood is High but not evidenced; `No`
when it is Medium or Low. The result then follows the rows:

| Rows | Result at scan 1 |
| --- | --- |
| All six `Yes` | `FLAGGED`, after the user confirms |
| None `No`, at least one `Likely` | `FLAGGED (provisional)`, after the user confirms |
| Any `No` | `NOT FLAGGED`; the user is not asked |

A provisional flag is a bet that the plan-time check confirms it. The compact plan's
`### Fast-track check` is the first full read of the code and must answer all six rows
`Yes`. A row that the plan cannot evidence is `No`, and the item escapes. The bet is
cheap; see [Calibration](#calibration) for the break-even.

## XS definition

`XS` is implementation work, not investigation or planning, that an experienced
contributor completes and verifies in about an hour. Repository history is a
non-binding note: the median fix, chore or docs change touches 1 file and about 6
lines, and 77% change at most 30 lines. That is guidance, not a cap.

## Comment templates

Every scan and every escape is recorded as one issue comment. The first line of the
comment is the heading shown below, so the comments can be found by that prefix:

```powershell
gh issue view <N> --json comments --jq '.comments[].body | select(startswith("## Fast-track"))'
```

Use `startswith("## Fast-track scan")` or `startswith("## Fast-track escape")` to find
one kind.

### Scan comment

Posted by `investigate-issue` (scan 1) and by `approve-ready-for-plan` (post-investigation
decision), whether or not the item is flagged.

```markdown
## Fast-track scan

**Context:** <scan 1 or post-investigation decision>
**Result:** <FLAGGED, FLAGGED (provisional) or NOT FLAGGED>
**XS likelihood:** <High, Medium or Low> (<one-line reason>)

| Condition | Met | Evidence |
| --- | --- | --- |
| Size is XS | <Yes, Likely or No> | <evidence> |
| Type is fix, chore or docs | <Yes or No> | <evidence> |
| Named, uniform edit | <Yes, Likely or No> | <evidence> |
| No public surface change | <Yes, Likely or No> | <evidence> |
| Fully reversible | <Yes, Likely or No> | <evidence> |
| No new dependency | <Yes, Likely or No> | <evidence> |

**Failing conditions:** <none, or the rows answered No>
**Confirmed by:** @<login>
```

| Field | Value |
| --- | --- |
| Context | `scan 1` or `post-investigation decision` |
| Result | `FLAGGED` when every row is `Yes` and the person confirms it; `FLAGGED (provisional)` when no row is `No`, at least one is `Likely` and the person confirms it; otherwise `NOT FLAGGED` |
| XS likelihood | Scan 1 only: `High`, `Medium` or `Low`, with a one-line reason, as defined under [provisional flag](#provisional-flag-at-scan-1). Leave the line out of a post-investigation decision, where the Sizing estimate is the evidence for row 1 |
| Met | `Yes` or `No` for each row, in checklist order. At scan 1 only, `Likely` is also allowed, except for row 2 |
| Evidence | The file, line, command output or finding that supports the answer |
| Failing conditions | The rows answered `No`, each as its number and name, comma-separated; `none` when there are none. For an item with no `No` rows that the person declines to flag, write `none (declined: <reason>)` |
| Confirmed by | The GitHub login (`gh api user --jq .login`) of the person who confirmed the result: the person running `investigate-issue` at scan 1, or the approver at `approve-ready-for-plan` |

### Escape comment

Posted once by the [escape procedure](#escape-procedure).

```markdown
## Fast-track escape

**Trigger:** <trigger and its specifics>
**Stage:** <skill and step where it fired>
**Returned to:** <status:plan or status:investigate>
```

| Field | Value |
| --- | --- |
| Trigger | A trigger from the [escape triggers](#escape-triggers) table with its specifics: the guard rule and file, the failing test, the failed check row, or the human reason |
| Stage | The skill and step that ran the procedure, for example `implement-issue Step 9a`; for a human escalation, `human escalation` and the status label the issue held |
| Returned to | `status:plan` or `status:investigate` |

## Escape procedure

One procedure handles every trigger. It returns the item to the earliest normal stage
whose artifact is missing: an item that skipped investigation receives the
investigation it skipped, and an item with an approved investigation does not repeat
it. Nothing is deleted. The comments, the compact plan and any implementation branch
or worktree stay as they are.

### Escape triggers

| Where | Trigger |
| --- | --- |
| `plan-issue`, compact mode | Any row of the plan's `### Fast-track check` is `No`, including a row that scan 1 left `Likely` and the plan cannot evidence, or the final sizing estimate is not `XS` |
| `approve-ready-for-implement` | The plan's fast-track check is missing or does not show all six conditions met with evidence, the estimate is not `XS`, or an affected-file row does not name exactly one file |
| `implement-issue` Step 4 and Step 9b Gate 1 | Any test fails; an escape is proposed instead of fix-and-retry |
| `implement-issue` Step 9a guard | Rule 1 (a changed file is not in the plan's affected tables) or rule 2 (a public surface change) |
| Any stage | The assignee or the approver judges that the item is not a papercut; no automated detection is needed |

Guard rule 3, the outlier flag, is never a trigger. The user decides at the Step 9a
pause.

### Confirming an escape

A trigger is a proposal, not a verdict. The skill that finds it can be wrong, and the
person working with it often knows something it does not. Where a person is working with
the skill (`plan-issue`, and `implement-issue` for a failed test or guard rule), the skill
does not run the procedure on its own:

1. Stop and show the trigger with its evidence: the failing rows or rule, the file or
   test, and what the skill found.
2. Say what you recommend, naming the state the item would return to, and ask what the
   person knows that you may not.
3. If the person gives information that answers the trigger, for example that a function
   is internal or that the edit really is the same in every file, use it as the evidence:
   re-answer the row or rerun the check, naming the person as the source, and carry on. If
   they disagree without giving a reason, ask for one; a row stays `No` until something
   answers it.
4. If the person agrees that the item is not a fast-track papercut, run the procedure and
   put their view in the trigger.

`approve-ready-for-implement` is the exception. The approver is already reviewing the
plan, so it tells them which check failed and why, then runs the procedure without
asking. A human escalation needs no confirmation.

### Target state

`status:plan` when an investigation document (`<N-padded>-*-investigation.md` in the
issue's release folder on `docs/main`) exists, otherwise `status:investigate`.

### Outcome

- `lifecycle:fast-track`, the item's current `status:*` label and, if present,
  `awaiting-approval` are removed.
- The target `status:*` label is added, plus `lifecycle:fast-track-escaped` only when the
  target is `status:investigate`.
- The project board status is set to the target.
- One `## Fast-track escape` comment is posted.
- The compact plan, committed or still a draft, is renamed from
  `<N-padded>-<slug>-plan.md` to `<N-padded>-<slug>-plan-fast-track.md`, so that
  `<N-padded>-*-plan.md` lookups no longer return it.

### Steps

Run E1 to E4 in order from a worktree that contains `tools/`. E1 defines the variables
the later steps use; double any single quote in the values you put in `$stage` and
`$trigger`. If a command fails, stop, report which steps completed, and ask how to
proceed.

#### E1. Determine the target state

```powershell
$n = <N>
$stage = '<skill and step that fired the trigger>'
$trigger = '<trigger and its specifics>'
$padded = '{0:D4}' -f $n
$milestone = gh issue view $n --json milestone --jq '.milestone.title // "backlog"'
$releaseFolder = if ($milestone -match '^Backlog$') { 'backlog' } else { $milestone -replace 'release/', 'release-' }
$issueDocDir = "C:\wt\wara\docs\issues\$releaseFolder"
$target = if (Get-ChildItem $issueDocDir -Filter "$padded-*-investigation.md" -ErrorAction SilentlyContinue) { 'plan' } else { 'investigate' }
Write-Host "Escape target: status:$target"
```

#### E2. Move the labels and the board

```powershell
$c = & tools/Get-GhProjectConstants.ps1
$present = @(gh issue view $n --json labels --jq '.labels[].name')
$remove = @('lifecycle:fast-track', 'status:plan', 'status:planning', 'status:implement', 'status:implementing', 'awaiting-approval') |
  Where-Object { $present -contains $_ -and $_ -ne "status:$target" }
$add = @("status:$target")
if ($target -eq 'investigate') { $add += 'lifecycle:fast-track-escaped' }
$add = $add | Where-Object { $present -notcontains $_ }
$labelArgs = @(foreach ($l in $remove) { '--remove-label'; $l }) + @(foreach ($l in $add) { '--add-label'; $l })
if ($labelArgs) { gh issue edit $n @labelArgs }

$statusOptionId = $c.statusOptions.$target
$itemId = gh project item-list $c.number --owner $c.owner --format json --limit 100 |
  ConvertFrom-Json | Select-Object -ExpandProperty items |
  Where-Object { $_.content.number -eq $n } |
  Select-Object -ExpandProperty id
if ($itemId) {
    gh project item-edit --project-id $c.id --id $itemId `
      --field-id $c.statusFieldId `
      --single-select-option-id $statusOptionId
} else {
    Write-Warning "Issue #$n is not on the project board; skipped the board update."
}
```

#### E3. Post the escape comment

```powershell
$body = @'
## Fast-track escape

**Trigger:** {0}
**Stage:** {1}
**Returned to:** status:{2}
'@ -f $trigger, $stage, $target
$body | gh issue comment $n --body-file -
```

#### E4. Rename the compact plan

A committed plan is renamed with `git mv` and pushed to `docs/main`; a draft that is not
committed is renamed in place. If no plan exists yet, nothing happens.

```powershell
Push-Location C:\wt\wara\docs
try {
    $plan = Get-ChildItem $issueDocDir -Filter "$padded-*-plan.md" | Select-Object -First 1
    if ($plan) {
        $newName = $plan.Name -replace '-plan\.md$', '-plan-fast-track.md'
        if (git ls-files -- "issues/$releaseFolder/$($plan.Name)") {
            git mv "issues/$releaseFolder/$($plan.Name)" "issues/$releaseFolder/$newName"

            # Guard: docs/main must only receive .md files
            $nonMd = git diff --cached --name-only | Where-Object { $_ -notmatch '\.md$' }
            if ($nonMd) { throw "docs/main gate: non-.md file(s) staged: $($nonMd -join ', '). Unstage them before pushing." }

            git commit -m "docs(#$n): rename compact plan for fast-track escape"
            git push origin docs/main
        } else {
            Move-Item $plan.FullName (Join-Path $issueDocDir $newName)
        }
    }
} finally {
    Pop-Location
}
```

### After an escape

- Report the trigger, the new state and the next skill: `/investigate-issue <N>` for
  `status:investigate`, or `/plan-issue <N>` for `status:plan`. Make no further changes in
  the current worktree.
- The normal documents are still required for whatever was skipped: a full investigation
  document when none exists, and always a full plan document. No phase carries over from
  the fast-track attempt.
- Size and priority are recalculated by the normal estimates, the investigation's Phase D
  estimate or the full plan's sizing estimate. The fast-track `XS` is not carried forward.
- The next investigation or plan reads the scan and escape comments and any
  `-plan-fast-track.md` as prior art.

## Labels

| Label | Color | Description |
| --- | --- | --- |
| `lifecycle:fast-track` | `c5def5` | Fast-track route: low-risk XS papercut, compact plan, proportionate approvals |
| `lifecycle:fast-track-escaped` | `c5def5` | Escaped the fast-track route: back in the normal lifecycle, do not re-flag |

`lifecycle:fast-track` is added with the move to `status:plan`, by scan 1 or by the
post-investigation decision, and removed only by the escape procedure. It stays on a
shipped item as a record. `lifecycle:fast-track-escaped` is added only by the escape
procedure, and only when the item returns to `status:investigate`, the one place scan 1
runs. Scan 1 skips an item that carries it or already has a `## Fast-track scan`
comment, which also keeps the rerun inside the investigate worktree from scanning twice.

Create both labels once, before the first use:

```powershell
gh label create "lifecycle:fast-track" --color c5def5 --description "Fast-track route: low-risk XS papercut, compact plan, proportionate approvals"
gh label create "lifecycle:fast-track-escaped" --color c5def5 --description "Escaped the fast-track route: back in the normal lifecycle, do not re-flag"
```

To roll back, delete each with `gh label delete "<name>" --yes`.

## Calibration

The six conditions, and the rule that only a `High` XS likelihood can flag provisionally,
are an initial calibration, not a settled threshold. No test suite or CI tunes them; the
signals come from records the lifecycle already keeps.

| Signal | Reading | Where to find it |
| --- | --- | --- |
| A flagged item escapes | Too lenient | The issue timeline shows `lifecycle:fast-track` removed, with its timestamp, and the `## Fast-track escape` comment states the trigger |
| A flagged item's recorded size later moves up from `XS` | Too lenient | The estimates in the investigation, the plan and its reflection |
| An item that was not flagged later reaches `XS` | Too strict | The same estimates: the investigation estimate, the plan estimate or the reflection verdict |
| The most frequent failing condition | The condition that rejects most items | `Failing conditions` in the `## Fast-track scan` comments |
| A provisional flag escapes at the plan-time check | The expected cost of the lenient screen; compare the survival rate with the break-even below | The `## Fast-track escape` comment with Stage `plan-issue`, on an item whose scan comment says `FLAGGED (provisional)` |
| The XS likelihood differs from the final size | A `High` that ends above `XS` is too optimistic; a `Medium` or `Low` that ends at `XS` is too cautious | `XS likelihood` in the scan comment, against the plan's estimate and reflection |

The timeline records label and board-status changes but has no event for the Size field,
so the estimates in the documents are the size history.

Review after the first ten scans, or at the end of the release if that comes first,
using ad hoc queries over the timeline, the scan and escape comments and the estimates.
The review decides whether the checklist and the provisional-flag threshold are
tightened or loosened.

Counting the STOP and confirm prompts in the skills as gates, an item flagged at the
start needs 4 pre-implementation gates instead of 13, and one flagged after
investigation needs 9. A correct flag at scan 1 saves 9 gates and a rejected one wastes
about 3, so scan 1 pays off while about one in four flagged items survives the plan-time
check. For the post-investigation decision the figures are 4, 2 and one in three.
Provisional flags are the lenient part of the screen, so track their survival separately
from firm flags.
