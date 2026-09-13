---
agent: agent
description: >
  Merges a completed implementation PR into the release branch and closes the issue.
  Run from the release worktree after /implement-issue stamps awaiting-approval.
  Assumes the PR was already created by the submitter. Advances to status:release
  and closes the GH issue per the close-on-merge-to-release model.
argument-hint: "Issue number (e.g. /approve-ready-for-release 107)"
tools:
  - agent
  - browser
  - execute
  - read
  - search
  - github.vscode-pull-request-github/github-pull-request_issue_fetch
  - github.vscode-pull-request-github/github-pull-request_create_pull_request
  - github.vscode-pull-request-github/github-pull-request_currentActivePullRequest
  - github.vscode-pull-request-github/github-pull-request_pullRequestStatusChecks

---

# Approve Ready for Release

> ⛔ **This prompt must be run from the release worktree (`C:\wt\wara\release\<release>`), not from
> the implementation worktree. If either condition is not met, stop immediately.**

**Issue number:** extract from the argument (e.g. `/approve-ready-for-release 107`).
If no number was provided, ask: "Which issue number should I approve?"

---

## Step 0 — Verify release worktree

```powershell
git branch --show-current
(Get-Location).Path
```

- Branch **must** match `release/*`.
- Path **must** match `C:\wt\wara\release\*`.

If either check fails, **stop** and instruct the user to switch to the release worktree.

**Verify markdownlint dependencies installed:**

```powershell
if (-not (Test-Path 'node_modules')) {
    npm ci
}
Write-Host "node_modules OK"
```

`tools/Invoke-MarkdownLint.ps1` requires `node_modules` installed locally (pinned
`markdownlint-cli2`) — without it, every lint call falls back to `npx` and prompts
for a package install.

---

## Step 1 — Pre-flight GH state check

```powershell
gh issue view <N> --json title,labels --jq '{title: .title, labels: [.labels[].name]}'
```

**Required conditions:**

- Issue carries `status:implementing`.
- Issue carries `awaiting-approval`.

If `awaiting-approval` is absent: the submitter has not finished — ask them to
complete implementation and stamp it first.

If `status:release` is already present: implementation was already approved — nothing to do.

Present: title, current labels.

---

## Step 2 — Locate the PR

```powershell
gh pr list --state open --json number,title,baseRefName,headRefName |
  ConvertFrom-Json |
  Where-Object { $_.headRefName -match "issue-<N>" }
```

**Case A — exactly one result, `baseRefName` is `release/*`:** Proceed to Step 3. ✅

**Case B — multiple results, at least one targeting `release/*`:** Use the
`release/*`-targeted PR. Warn about the mis-targeted PR and ask the user to close it.

**Case C — results exist but none target `release/*`:**
**Stop:**
> "No PR for issue #N targets a `release/*` branch. Close the mis-targeted PR on
> GitHub, then rerun `/implement-issue <N>` Step 9b to open a correctly targeted one."

**Case D — no open PRs:**
**Stop:**
> "No open PR found for issue #N. The submitter must complete
> `/implement-issue <N>` Step 9 before this prompt can run."

---

## Step 3 — Inspect the PR

```powershell
gh pr view <PR-N> --json number,title,state,baseRefName,headRefName,mergeable
```

Check status checks via `github-pull-request_pullRequestStatusChecks`.

Present:

| Field | Value |
| --- | --- |
| PR | #PR-N — title |
| Base branch | must be `release/*` |
| Head branch | |
| Mergeable | |
| Status checks | ✅ all passing / ⚠️ pending / ❌ failing |

**Stop if:**

- `state` is not `OPEN`
- `baseRefName` is not `release/*`
- `mergeable` is `CONFLICTING` — report the conflict and stop
- Any required status check is failing or still pending

### Gate 1b — doc-content check

```powershell
gh pr diff <PR-N> --name-only
```

**Stop if any file matches `*-investigation.md` or `*-plan.md`:**
> "This PR contains an investigation or plan document. These files must live on
> `docs/main` only — they must not merge to `release/*` or `main`. Remove them
> from the branch before merging."

Ask: **"Ready to merge PR #PR-N into `<release-branch>`?"**

Do not proceed until the user confirms.

### Gate 2 — pre-merge test

```powershell
git fetch origin <headRefName>
git merge --no-commit --no-ff origin/<headRefName>
tools/Invoke-Pester.ps1 src/tests/
```

**If any tests fail — STOP.** Abort and fix:

```powershell
git merge --abort
```

Fix the failures in the implementation worktree, push, and rerun. If all tests pass,
abort the simulation and proceed:

```powershell
git merge --abort
```

---

## Step 4 — Merge

```powershell
gh pr merge <PR-N> --squash
```

Confirm:

```powershell
gh pr view <PR-N> --json state,mergedAt
```

If `state` is not `MERGED`, report the error and stop.

---

## Step 5 — Pull and advance GH state

```powershell
git pull
```

Apply the label transition, close the issue, and update the project board:

```powershell
$c = & tools/Get-GhProjectConstants.ps1

gh issue edit <N> `
  --remove-label "status:implementing" `
  --remove-label "awaiting-approval" `
  --add-label "status:release"

# Close the issue — work is complete when merged to release/*
gh issue close <N>

$itemId = gh project item-list $c.number --owner $c.owner --format json --limit 100 |
  ConvertFrom-Json | Select-Object -ExpandProperty items |
  Where-Object { $_.content.number -eq <N> } |
  Select-Object -ExpandProperty id

if (-not $itemId) {
    Write-Warning "Issue #<N> is not on the project board — skipping project status update."
} else {
    gh project item-edit --project-id $c.id --id $itemId `
      --field-id $c.statusFieldId `
      --single-select-option-id $c.statusOptions.release
}
```

---

## Step 6 — Worktree cleanup

```powershell
$headBranch = "<headRefName>"   # e.g. chore/issue-170-workflow-state-tracking
$match = git worktree list | Select-String ([regex]::Escape($headBranch))
if ($match) {
    $worktreePath = ($match.Line -split '\s+')[0]
    Write-Host "Removing worktree: $worktreePath"
    git worktree remove $worktreePath --force
}
git worktree prune
git branch -D $headBranch 2>$null
git fetch --prune

# Remove any stale local branches for this issue
$issueNum = <N>
git branch -vv | Where-Object { $_ -match "issue-$issueNum" -and $_ -notmatch '\[origin/' } |
    ForEach-Object {
        $b = ($_ -split '\s+') | Where-Object { $_ -match '^[a-zA-Z]' } | Select-Object -First 1
        if ($b) { Write-Host "Removing no-upstream branch: $b"; git branch -D $b }
    }
```

Verify:

```powershell
git worktree list
git branch -vv | Select-String "issue-<N>"
```

---

## Step 7 — Report

> Issue #N is **closed** and at `status:release` on milestone `<release-milestone>`.
>
> The implementation is merged to `<release-branch>` and the issue is closed.
> When `<release-branch>` merges to `main`, close the `<release-milestone>` milestone
> — that event marks "now in main".
