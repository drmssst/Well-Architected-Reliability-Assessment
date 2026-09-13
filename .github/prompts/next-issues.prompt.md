---
agent: agent
description: >
  Ranks and returns the next best GitHub issues to work on using weighted
  urgency, importance, stage readiness, dependency cues, and WIP fit.
argument-hint: "Optional top count and output format, e.g. /next-issues 5 markdown"
tools:
  - agent
  - browser
  - edit
  - execute
  - read
  - search
  - todo
  - vscode
  - github.vscode-pull-request-github/github-pull-request_issue_fetch
  - github.vscode-pull-request-github/github-pull-request_create_pull_request
  - github.vscode-pull-request-github/github-pull-request_currentActivePullRequest
  - github.vscode-pull-request-github/github-pull-request_pullRequestStatusChecks

---

# Next Issues

Run the ranking script and summarize the top candidates.

## Inputs

- `top` (optional): default 5
- `output` (optional): one of `table`, `json`, `markdown` (default `table`)

If no arguments are provided, use defaults.

## Command

```powershell
pwsh tools/Get-NextIssues.ps1 -Top <top> -Output <output>
```

## Response format

Provide:

1. Top ranked issue (one-line reason)
2. Top 5 list with score and short why
3. Any tie notes or caveats

If script execution fails, report the error and suggest a corrected command.

## Step 2 — Offer board reorder

After presenting the results, ask:

> **Should I reorder the project board to match this ranking? [Y/N]**

If yes, run:

```powershell
pwsh tools/Get-NextIssues.ps1 -Top <top> -Reorder
```

Confirm with: `"Board reordered — top <N> issues now reflect the current ranking."`

If no, skip silently.
