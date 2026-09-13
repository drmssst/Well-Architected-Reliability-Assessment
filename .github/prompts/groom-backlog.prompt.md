---
agent: agent
description: >
  Backlog grooming workflow. Presents all open issues in the Backlog milestone,
  sorted by urgency and importance, and guides the decision-maker through promoting,
  deferring, or closing each one. Promoted issues are moved to the active release
  milestone. Run from the release workspace.
argument-hint: "No argument needed — lists all Backlog issues automatically"
tools:
  - agent
  - execute
  - read
  - github.vscode-pull-request-github/github-pull-request_issue_fetch

---

# Groom Backlog Workflow

## Step 0 — Verify release workspace

```powershell
git branch --show-current
(Get-Location).Path
```

- Path **must** match `C:\wt\wara\release\*`.
- Branch **must** match `release/*`.

If either check fails, **stop**:
> "This prompt must be run from the release workspace (`C:\wt\wara\release\*` on
> `release/*`). Please switch to that VS Code window and rerun `/groom-backlog`."

---

## Step 1 — Fetch the backlog

```powershell
$releaseBranch = git branch --show-current   # e.g. release/20260724
$activeMilestone = $releaseBranch -replace '^release/', 'release/'

# List all Backlog issues sorted by urgency then importance
gh issue list --milestone "Backlog" --state open --limit 200 `
  --json number,title,labels,body `
  --jq 'sort_by(.labels[].name) | .[] | {number, title, labels: [.labels[].name]}'
```

Build a sorted display table:

| # | Title | Type | Urgency | Importance |
| - | ----- | ---- | ------- | ---------- |
| ... | | | | |

Sort order: `urgency:now` first, then `urgency:soon`, then `urgency:medium`, then
`urgency:low`. Within each urgency tier, sort by `importance:high` before
`importance:medium` before `importance:low`.

Present the table to the user and confirm: **"Ready to begin grooming? I'll walk
through each issue one at a time."**

---

## Step 2 — Review each issue

For each issue in sorted order, present:

```text
Issue #N — <title>
Type: <type label>   Urgency: <urgency>   Importance: <importance>

Problem statement:
<first paragraph of the issue body>

Why investigate:
<second paragraph of the issue body>
```

Then ask: **"Decision for #N: [P]romote to `<active-milestone>` / [D]efer (leave in
Backlog) / [C]lose (won't do) / [A]djust labels first"**

Wait for the user's decision before moving to the next issue.

**Promote:** move to active milestone (Step 3).
**Defer:** no action — the issue stays in `Backlog`.
**Close:** close the issue with a won't-do comment (Step 4).
**Adjust labels:** update urgency/importance labels as specified, then re-ask the
decision question.

---

## Step 3 — Execute promotions

For each issue the user chose to promote:

```powershell
gh issue edit <N> --milestone "<active-milestone>"
Write-Host "Issue #N promoted to $activeMilestone"
```

No `status:*` label change — the issue stays at `status:investigate`. Grooming only
changes the milestone.

---

## Step 4 — Execute closures

For each issue the user chose to close:

```powershell
gh issue close <N> --comment "Won't do: <user-provided reason>"
Write-Host "Issue #N closed (won't do)"
```

---

## Step 5 — Summary

Present a summary table:

| Decision | Issues |
| -------- | ------ |
| Promoted to `<active-milestone>` | #N1, #N2, ... |
| Deferred (remain in Backlog) | #N3, #N4, ... |
| Closed (won't do) | #N5, ... |

> **Grooming complete.** Promoted issues are now in the `<active-milestone>` swimlane
> on the project board and are eligible for investigation.
