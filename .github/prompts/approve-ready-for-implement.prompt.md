---
agent: agent
description: >
  Quality gate: certifies that planning is complete and advances the issue from
  status:planning to status:implement. Reads the plan doc from docs/main, verifies
  quality, assigns the issue to the active release milestone, then updates GH labels
  and project board. No PR is merged — this is a human quality gate.
argument-hint: "Issue number (e.g. /approve-ready-for-implement 103)"
tools:
  - agent
  - execute
  - read
  - search
  - github.vscode-pull-request-github/github-pull-request_issue_fetch

---

# Approve Ready for Implement

> ⛔ **This prompt must be run from the release worktree (`C:\wt\wara\release\<release>`), not from
> the plan worktree. If either condition is not met, stop immediately.**

**Issue number:** extract from the argument (e.g. `/approve-ready-for-implement 103`).
If no number was provided, ask: "Which issue number should I approve?"

---

## Step 0 — Verify release worktree

```powershell
git branch --show-current
(Get-Location).Path
```

- Branch **must** match `release/*`.
- Path **must** match `C:\wt\wara\release\*`.

If either check fails, **stop** and instruct the user to switch to the release
worktree.

---

## Step 1 — Pre-flight GH state check

```powershell
gh issue view <N> --json title,labels --jq '{title: .title, labels: [.labels[].name]}'
```

**Required conditions:**

- Issue carries `status:planning`.
- Issue carries `awaiting-approval`.

If `awaiting-approval` is absent: the submitter has not finished — ask them to
complete all planning phases and stamp it first.

If `status:implement` is already present: planning was already approved — nothing to do.

Present: title, current labels.

---

## Step 2 — Review plan doc

```powershell
$milestone = gh issue view <N> --json milestone --jq '.milestone.title // "backlog"'
$releaseFolder = if ($milestone -match '^Backlog$') { 'backlog' } else { $milestone -replace 'release/', 'release-' }
Get-ChildItem "C:\wt\wara\docs\issues\$releaseFolder" -Filter "<N-padded>-*-plan.md"
```

Read the plan doc and verify all five phases are present and substantive:

- **Phase A** — Scope and approach (core change described, open decisions resolved)
- **Affected documents** — complete table (includes `CHANGELOG.md`; no placeholder rows)
- **Version impact** — classification stated with rationale
- **Testing requirements** — at least one entry (or explicit "no new tests" statement)
- **Acceptance criteria** — at least one checkable condition
- **Definition of done** — standard checklist present and complete

Present a one-paragraph quality summary. If any section is missing or thin, describe the
gap and ask the user how to proceed.

Ask: **"Does the plan meet your quality bar? Confirm to advance to status:implement."**

Do not proceed until the user confirms.

---

## Step 3 — Determine active release milestone

```powershell
$releaseBranch = git branch --show-current
$releaseMilestone = $releaseBranch -replace 'release/', 'release/'   # e.g. "release/20260724"
Write-Host "Will assign milestone: $releaseMilestone"
```

Confirm with the user if the derived milestone name looks unexpected.

---

## Step 4 — Advance GH labels, board, and milestone

```powershell
$c = & tools/Get-GhProjectConstants.ps1

# Assign to release milestone and advance label
gh issue edit <N> `
  --remove-label "status:planning" `
  --remove-label "awaiting-approval" `
  --add-label "status:implement" `
  --milestone $releaseMilestone

$itemId = gh project item-list $c.number --owner $c.owner --format json --limit 100 |
  ConvertFrom-Json | Select-Object -ExpandProperty items |
  Where-Object { $_.content.number -eq <N> } |
  Select-Object -ExpandProperty id

gh project item-edit --project-id $c.id --id $itemId `
  --field-id $c.statusFieldId `
  --single-select-option-id $c.statusOptions.implement
```

---

## Step 5 — Set size field on project item

The plan doc's Phase D contains a sizing estimate sub-section — the last `D<N>` entry
in that phase. The `D<N>` number varies per issue; search for the `**Estimate:**` line
regardless of which heading it falls under.

```powershell
# $planDocContent = the raw text of the plan doc read in Step 2
# $itemId         = the project item ID obtained in Step 4
$c = & tools/Get-GhProjectConstants.ps1

$sizeMatch = [regex]::Match($planDocContent, '\*\*Estimate:\*\*\s+(XS|S|M|L|XL)')
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

## Step 6 — (Optional) Plan worktree cleanup

```powershell
$headBranch = "plan/issue-<N>-<slug>"
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

---

## Step 7 — Report

> Issue #N is now at `status:implement` on milestone `<release-milestone>`.
>
> **To implement:** open a Copilot Chat from the implementation worktree
> `C:\wt\wara\implement\issue-<N>` and run `/implement-issue <N>`.
