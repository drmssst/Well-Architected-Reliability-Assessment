---
name: approve-ready-for-plan
description: Quality gate: certifies that investigation is complete and advances the issue from status:investigating to status:plan. Reads the investigation doc from docs/main, verifies quality, then updates GH labels and project board. No PR is merged — this prompt is a human quality gate, not a merge gate.
disable-model-invocation: true
argument-hint: "Issue number (e.g. /approve-ready-for-plan 103)"
---
# Approve Ready for Plan

> ⛔ **This prompt must be run from the release worktree (`C:\wt\wara\release\<release>`), not from
> the investigation worktree. If either condition is not met, stop immediately.**

**Issue number:** extract from the argument (e.g. `/approve-ready-for-plan 103`).
If no number was provided, ask: "Which issue number should I approve?"

---

## Step 0 — Verify release worktree

```powershell
git branch --show-current
(Get-Location).Path
```

- Branch **must** match `release/*`.
- Path **must** match `C:\wt\wara\release\*`.

If either check fails, **stop**:
> "This prompt must be run from the release worktree. Switch to that VS Code window
> and rerun `/approve-ready-for-plan <N>`."

---

## Step 1 — Pre-flight GH state check

```powershell
gh issue view <N> --json title,labels --jq '{title: .title, labels: [.labels[].name]}'
```

**Required conditions:**

- Issue carries `status:investigating`.
- Issue carries `awaiting-approval`.

If `status:investigating` is present but `awaiting-approval` is absent: the submitter
has not finished — ask them to complete all phases and stamp it first.

If `status:plan` is already present: investigation was already approved — nothing to do.

Present: title, current labels.

---

## Step 2 — Review investigation doc

Determine the docs/main doc path:

```powershell
$milestone = gh issue view <N> --json milestone --jq '.milestone.title // "backlog"'
$releaseFolder = if ($milestone -match '^Backlog$') { 'backlog' } else { $milestone -replace 'release/', 'release-' }
Get-ChildItem "C:\wt\wara\docs\issues\$releaseFolder" -Filter "<N-padded>-*-investigation.md"
```

Read the investigation doc and verify all four phases are present and substantive:

- **Phase A** — Findings (observations, not decisions)
- **Phase B** — Approach decisions (each question resolved with rationale)
- **Phase C** — Risks and prerequisites (mitigations stated)
- **Phase D** — Ready-to-plan summary (file scope, deferred decisions, test requirements)

Present a one-paragraph quality summary. If any phase is missing or thin, describe the
gap and ask the user how to proceed before advancing labels.

**Fast-track decision.** Answer the six conditions of the Eligibility checklist in
`.github/FAST_TRACK_CRITERIA.md`, each `Yes` or `No`, from this document, the issue
labels and the Sizing estimate. If Phase D has a fast-track assessment entry, use it as
input and verify its
evidence; if it has none, answer the rows from the document the same way. Present the
table (Condition, Met, Evidence). The result is `FLAGGED` only when all six rows are
`Yes` and the user replies `fast-track` below; otherwise it is `NOT FLAGGED`.

Ask: **"Does the investigation meet your quality bar? Confirm to advance to status:plan."**

When all six rows are `Yes`, add the fast-track choice to the same prompt: **"Does the
investigation meet your quality bar? Confirm to advance to status:plan. Reply
`fast-track` to advance it as a fast-track item (compact plan), or `confirm` to advance
it normally."**

Do not proceed until the user confirms. The one reply settles both the quality
confirmation and the fast-track answer; there is no separate gate.

---

## Step 3 — Advance GH labels and board

Post the scan comment first; it records the decision either way, so post it for a
`NOT FLAGGED` result too. Use the Scan comment template in
`.github/FAST_TRACK_CRITERIA.md` with Context `post-investigation decision`, leave out the
`XS likelihood` line, and answer each row `Yes` or `No`. The result is `FLAGGED` when the
user replied `fast-track`. Otherwise it is `NOT FLAGGED`, with the rows answered `No` as
the failing conditions, or `none (declined: <reason>)` when all six were `Yes` and the
user replied `confirm`. `Confirmed by` is your GitHub login (`gh api user --jq .login`),
and the first line must be `## Fast-track scan`.

```powershell
@'
<scan comment, filled in from the template>
'@ | gh issue comment <N> --body-file -
```

Then advance the labels and the board. For a fast-track item, add
`--add-label "lifecycle:fast-track"` to the same `gh issue edit` command, so the label and
the move to `status:plan` happen together.

```powershell
$c = & tools/Get-GhProjectConstants.ps1

gh issue edit <N> `
  --remove-label "status:investigating" `
  --remove-label "awaiting-approval" `
  --add-label "status:plan"

$itemId = gh project item-list $c.number --owner $c.owner --format json --limit 100 |
  ConvertFrom-Json | Select-Object -ExpandProperty items |
  Where-Object { $_.content.number -eq <N> } |
  Select-Object -ExpandProperty id

gh project item-edit --project-id $c.id --id $itemId `
  --field-id $c.statusFieldId `
  --single-select-option-id $c.statusOptions.plan
```

---

## Step 4 — Set size field on project item

The investigation doc's Phase D contains a sizing estimate sub-section — the last
`D<N>` entry in that phase. The `D<N>` number varies per issue; search for the
`**Estimate:**` line regardless of which heading it falls under.

```powershell
# $docContent = the raw text of the investigation doc read in Step 2
# $itemId     = the project item ID obtained in Step 3
$c = & tools/Get-GhProjectConstants.ps1

$sizeMatch = [regex]::Match($docContent, '\*\*Estimate:\*\*\s+(XS|S|M|L|XL)')
if (-not $sizeMatch.Success) {
    Write-Warning "No sizing estimate found in Phase D — skipping size field update."
} else {
    $sizeLabel    = $sizeMatch.Groups[1].Value          # e.g. 'L'
    $sizeOptionId = $c.sizeOptions.$sizeLabel
    gh project item-edit --project-id $c.id --id $itemId `
      --field-id $c.sizeFieldId `
      --single-select-option-id $sizeOptionId
    Write-Host "Size set to $sizeLabel ($sizeOptionId)"
}
```

If the estimate is absent from Phase D, warn the user but continue — size can be set
manually on the board.

---

## Step 5 — (Optional) Investigate worktree cleanup

If the investigation worktree is still open, clean it up:

```powershell
$headBranch = "investigate/issue-<N>-<slug>"
$match = git worktree list | Select-String ([regex]::Escape($headBranch))
if ($match) {
    $worktreePath = ($match.Line -split '\s+')[0]
    Write-Host "Removing worktree: $worktreePath"
    git worktree remove $worktreePath --force
}
git worktree prune
git branch -D $headBranch 2>$null
git fetch --prune
```

If `git worktree remove` fails because VS Code still holds the folder open, close that
window first and rerun.

---

## Step 6 — Report

> Issue #N is now at `status:plan`.
>
> **To write the implementation plan:** open a Copilot Chat from the
> `wara` release worktree and run `/plan-issue <N>`.

For a fast-track item, report instead:

> Issue #N is now at `status:plan` and carries `lifecycle:fast-track`.
>
> **To write the compact plan:** open a Copilot Chat from the `wara` release worktree and
> run `/plan-issue <N>`. It detects the label and writes a compact plan behind one review
> gate.
