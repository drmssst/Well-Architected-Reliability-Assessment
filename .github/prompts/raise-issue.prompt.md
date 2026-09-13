---
agent: agent
description: >
  Creates a new GitHub issue and adds it to the project board at status:investigate
  in the Backlog milestone. No branch, no PR, no planning doc — a well-formed backlog
  pitch only. Run from the release workspace. Issue is immediately visible on the
  project board.
argument-hint: "Brief description of the issue — e.g. 'add per-site token substitution'"
tools:
  - agent
  - execute
  - read
  - github.vscode-pull-request-github/github-pull-request_issue_fetch

---

# Raise New Issue Workflow

## Step 1 — Gather issue details

Ask the user for the following. Collect all items before proceeding — do not create the
issue until you have them all.

1. **Title** — imperative phrase prefixed with type: `feat:`, `fix:`, `chore:`, or `docs:`
2. **Problem statement** — 2–4 sentences: what gap, defect, or opportunity this addresses
3. **Why investigate** — what is unknown; what risk exists if not addressed
4. **Type label** — `type:feat`, `type:fix`, `type:chore`, or `type:docs`
5. **Urgency label** — `urgency:now`, `urgency:soon`, `urgency:medium`, or `urgency:low`
6. **Importance label** — `importance:high`, `importance:medium`, or `importance:low`

Confirm all details with the user before continuing.

---

## Step 2 — Create the GitHub issue

```powershell
$issueUrl = gh issue create `
  --title "<title>" `
  --label "<urgency>,<importance>,<type>" `
  --milestone "Backlog" `
  --body @'
## Problem statement

<2-4 sentences describing the gap, defect, or opportunity>

## Why investigate

<What is unknown and why it matters; what risk exists if ignored>
'@

$issueNumber = $issueUrl | Split-Path -Leaf
Write-Host "Issue created: $issueUrl"
```

> **WARNING — here-string duplicate trap:**
> After running the `gh issue create` command above, the terminal will echo `>>` lines for
> each line of the here-string body. These are NOT an interactive prompt — the command has
> already completed and the issue has been created. Call `get_terminal_output` ONCE to
> retrieve the result URL. **Never re-run `gh issue create` just because you only see `>>` lines.**
> Doing so will create a duplicate issue.

If the command fails due to an unknown label, run `gh label list` to verify exact label
names before retrying.

---

## Step 3 — Add to project board

```powershell
$c = & tools/Get-GhProjectConstants.ps1

$itemId = gh project item-add $c.number --owner $c.owner --url $issueUrl --format json |
  ConvertFrom-Json | Select-Object -ExpandProperty id

gh project item-edit --project-id $c.id --id $itemId `
  --field-id $c.statusFieldId `
  --single-select-option-id $c.statusOptions.investigate
```

---

## Step 4 — Report

Report to the user:

> Issue #N — title is live.
> Status: `investigate` · Labels: `<type>`, `<urgency>`, `<importance>` · Milestone: `Backlog`
> View on GitHub: `$issueUrl`
>
> **Done.** No worktree, branch, or PR needed. The issue is on the project board.
> Run `/investigate-issue <N>` when ready to begin investigation.
