---
agent: agent
description: >
  Implements an approved plan for a status:implement issue. Reads the plan doc from
  docs/main, works through the Affected Documents table, writes and runs tests, then
  opens a PR targeting the release branch. Plan doc is on docs/main; code changes are
  committed to the feature branch. Approve-ready-for-release merges the PR.
argument-hint: "Issue number — e.g. 54"
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

# Issue Processing Workflow

## Gate policy — explicit approvals required

- Treat each numbered step in this workflow as a hard gate.
- Before moving from Step X to Step Y, stop and ask for explicit approval.
- Required transition phrase:
  - `Requesting approval to move from Step X to Step Y.`
- Never continue past a gate based on implied consent, silence, or momentum.
- After each logical file group in Step 3, stop and request review acceptance before
  touching the next group.
- If a gate is crossed accidentally, stop immediately, acknowledge the miss, and ask
  how to proceed before running additional commands.
- Linting, testing, docs updates, commits, labels, and PR actions are all gated and
  must not be executed preemptively.

---

## Prerequisite — Verify tools and feature worktree

> **Required tools:** `execute`, `edit`, `read`, `search`, `GitHub Pull Requests`.

```powershell
git branch --show-current
```

**Stop immediately** if the current branch does not start with `feature/`, `fix/`,
`chore/`, or `docs/`. This prompt must be run from a feature worktree
(`C:\wt\wara\implement\issue-<N>`).

---

**Issue number:** extract from the argument (e.g. `/implement-issue 54`). If no number
was provided, ask: "Which issue number should I implement?"

**Prerequisite check:** The issue must have the `status:implement` label.

```powershell
gh issue view <N> --json labels --jq '[.labels[].name]'
```

If `status:implement` is absent, stop: no approved plan exists.

---

## Step 0 — Verify worktree

**Expected path:** `C:\wt\wara\implement\issue-<N>`

```powershell
(Get-Location).Path
```

If the output does not match, derive the slug and create or open the worktree:

```powershell
$branchPrefix = "<type-from-issue-label>"   # feature, fix, chore, or docs
$slug = "<derived-slug>"
tools/New-IssueWorktree.ps1 -Stage implement -Issue <N> -BranchPrefix $branchPrefix -Slug $slug
```

**Stop.** Tell the user:
> "Worktree ready at `C:\wt\wara\implement\issue-<N>`. Switch to that VS Code
> window and rerun `/implement-issue <N>` from there."

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

## Step 1 — Read the plan

Run in parallel:

1. Fetch the issue with `github-pull-request_issue_fetch` to confirm `status:implement`
   and get the title.
2. Determine the release folder and find the plan doc on docs/main:

   ```powershell
   $milestone = gh issue view <N> --json milestone --jq '.milestone.title // "backlog"'
   $releaseFolder = if ($milestone -match '^Backlog$') { 'backlog' } else { $milestone -replace 'release/', 'release-' }
   Get-ChildItem "C:\wt\wara\docs\issues\$releaseFolder" -Filter "<N-padded>-*-plan.md"
   ```

3. Read the full plan doc and extract:
   - **Affected Documents table** — every file that must change
   - **Testing Requirements** — new and changed tests
   - **Acceptance Criteria** — verifiable feature-specific conditions
   - **Version impact classification** — `major`, `minor`, or `patch`

Present a one-paragraph summary of what will be implemented, then ask: **"Ready to
begin implementation of issue #N?"**

Do not proceed until the user confirms.

---

## Step 2 — Switch label

```powershell
$c = & tools/Get-GhProjectConstants.ps1

gh issue edit <N> --add-label "status:implementing" --remove-label "status:implement" --add-assignee "@me"

$itemId = gh project item-list $c.number --owner $c.owner --format json --limit 100 |
  ConvertFrom-Json | Select-Object -ExpandProperty items |
  Where-Object { $_.content.number -eq <N> } |
  Select-Object -ExpandProperty id

gh project item-edit --project-id $c.id --id $itemId `
  --field-id $c.statusFieldId `
  --single-select-option-id $c.statusOptions.implementing
```

---

## Step 3 — Implement

Work through the **Affected Documents table** one logical group at a time. A logical
group is a set of closely related files — typically one source area plus the docs that
describe it. Do not implement all files in a single pass.

For each group:

1. Implement the changes.
2. Lint every Markdown file in the group:

   ```powershell
   tools/Invoke-MarkdownLint.ps1 <files>
   ```

   Fix all violations before pausing.
3. Lint every PowerShell file in the group:

   ```powershell
   tools/Invoke-PsScriptAnalyzer.ps1 <ps-files>
   ```

   Fix all violations before pausing.
4. Tell the user which files changed and ask them to review in the editor.
5. Wait for the user to accept the group before moving to the next.

Rules:

- Use `replace_string_in_file` / `multi_replace_string_in_file` for all edits — never
  `Set-Content` in the terminal.
- Implement source and schema changes before test changes.
- Do not add features, comments, error handling, or refactoring beyond the plan.

---

## Step 4 — Write and run tests

Write the tests listed in **Testing Requirements**. For each test file:

1. Lint (if `.md`):

   ```powershell
   tools/Invoke-MarkdownLint.ps1 <test-file>
   ```

2. Run targeted Pester tests for the affected file(s) under `src/tests/`:

   ```powershell
   tools/Invoke-Pester.ps1 src/tests/<module>/<file>.tests.ps1
   ```

3. Ask the user to review the test file before continuing.
4. Wait for the user to accept before writing the next test file.

Once all targeted tests are green, run the full suite:

```powershell
tools/Invoke-Pester.ps1 src/tests/
```

Record the result. It must show zero failures before continuing.

---

## Step 5 — Update supporting documents

- **`CHANGELOG.md`**: Add an entry using the correct `minor`/`patch`/`major`
  classification from the plan.
- **Plan doc** (on docs/main): Before touching any checkboxes, produce an explicit
  AC verification table. For every item in `### Acceptance criteria`, state:
  - The AC text (abbreviated)
  - How it was verified: name the test, grep hit, or file diff that confirms it
  - Pass / Fail

  Only mark `- [x]` for ACs that have a named verification artifact. ACs with no
  test coverage and no observable output must remain `- [ ]` and be called out to
  the user before continuing.

  Once the table is produced and any gaps are resolved, make the two mandatory edits:
  1. Change every verified `- [ ]` in `### Acceptance criteria` to `- [x]`.
  2. Change every `- [ ]` in `### Definition of done` to `- [x]` only when the
     corresponding work is demonstrably complete (tests green, files linted, etc.).
  Do **not** mark DoD items complete simply because the AC above them is checked.

  ```powershell
  # Plan doc is on docs/main worktree
  $planDoc = "C:\wt\wara\docs\issues\$releaseFolder\<N-padded>-<slug>-plan.md"
  ```

Once updated, lint both:

```powershell
tools/Invoke-MarkdownLint.ps1 CHANGELOG.md
tools/Invoke-MarkdownLint.ps1 $planDoc
```

Commit the plan doc changes to docs/main:

```powershell
Set-Location C:\wt\wara\docs
git add issues/<release-folder>/<N-padded>-<slug>-plan.md

# Guard: docs/main must only receive .md files
$nonMd = git diff --cached --name-only | Where-Object { $_ -notmatch '\.md$' }
if ($nonMd) { throw "docs/main gate: non-.md file(s) staged: $($nonMd -join ', '). Unstage them before pushing." }

git commit -m "docs(#N): mark plan doc — all acceptance criteria and DoD complete"
git push origin docs/main
Set-Location C:\wt\wara\implement\issue-<N>
```

Ask the user to review the updated documents before continuing.

---

## Step 6 — Final lint sweep

```powershell
tools/Invoke-MarkdownLint.ps1 <all modified .md files>
tools/Invoke-PsScriptAnalyzer.ps1 <all modified .ps1/.psm1 files>
```

Fix any remaining violations.

---

## Step 7 — Commit

Final lint gates:

```powershell
tools/Invoke-PsScriptAnalyzer.ps1 <all modified .ps1/.psm1 files>
```

Do not proceed if any violations remain.

Stage and commit. The commit message must follow `.github/COMMIT_GUIDELINES.md`; a body
is required when source, schema, or test files changed. Show the full proposed commit
message to the user and wait for approval before running `git commit`.

```powershell
git add <files>
git commit -m "<title>

<body>"
git push
```

---

## Step 8 — Manual smoke test

Present the **Definition of Done** checklist, marking each item ✅ (covered by tests)
or ⏳ (needs a live run).

If the plan calls for a manual smoke test against testbed artifacts, ask the user what
test fixture/tenant to use and run the relevant WARA entry point (e.g.
`Start-WARACollector`, `Start-WARAAnalyzer`, or `Start-WARAReport`)
against `C:\tb\wara_tb\<fixture-name>`. Confirm with the user which entry point
applies to this issue before running anything.

After any live run: list generated files with sizes, surface any `WARNING:` lines, and
show the relevant summary/report output if one is produced.

After any code change: run targeted tests first, then the full Pester suite. Report
`Tests Passed: N, Failed: 0`.

When the user says **"all good"**, proceed to the sizing reflection below.

### Sizing reflection

Find the **Sizing estimate** section of the plan doc (search for the heading that
contains "Sizing estimate" — the section number varies by plan). It contains the
estimate (`XS` / `S` / `M` / `L` / `XL`) and the primary uncertainty drivers that
were identified at planning time.

The sizing estimate covers **implementation only** — planning (investigation + plan
phases) is tracked separately and must not be included in the reflection.

Present a brief reflection covering:

1. **Estimate:** what the plan said (`XS` / `S` / `M` / `L` / `XL`)
2. **Actual:** was implementation easier, about right, or harder than estimated?
3. **Drivers that materialised:** which uncertainty drivers from the sizing estimate actually caused
   friction, and how were they resolved?
4. **Surprises:** anything not anticipated in the sizing estimate that added or removed significant
   effort (bugs found during smoke test, pre-existing violations that had to be fixed,
   test isolation issues, etc.)?
5. **Revised size verdict:** would you re-estimate this as the same size or different
   in hindsight? One sentence.

This is observational only — no plan doc edits are required unless the user asks.

Once the user confirms the reflection is accurate, append a `## Reflection` section
to the **end** of the plan doc on docs/main with the following structure:

```markdown
## Reflection

**Estimate:** `<size>`

**Actual:** <one sentence — easier / about right / harder, and degree>

**Drivers that materialised:**

- <driver from sizing estimate>: <how it played out>
- <driver from sizing estimate>: <how it played out>

**Surprises (not in sizing estimate):**

- <unexpected thing that added or removed effort>
- <unexpected thing that added or removed effort>

**Revised size verdict:** <same size or different, one sentence>
```

Lint the plan doc after appending:

```powershell
tools/Invoke-MarkdownLint.ps1 $planDoc
```

Include the reflection in the docs/main commit for the plan doc.

Then proceed to Step 9.

---

## Step 9 — Open the PR

Ask: **"Are you ready to move to PR?"** Do not proceed until they confirm.

### 9a — Pre-flight check

> ⛔ Review the plan doc DoD and all implementation changes. If **anything** does not
> match expectations, **stop immediately**, surface the discrepancy, and wait for an
> explicit decision before proceeding.
>
> Every `- [ ]` in the DoD must be `- [x]`. Any unchecked item is a pre-flight failure.

### 9b — Sync and open PR

```powershell
git fetch origin
git merge origin/<release-branch> --no-edit
```

### Gate 1 — full test suite post-merge

```powershell
tools/Invoke-Pester.ps1 src/tests/
```

**If any tests fail — STOP.** Fix them, push, then open the PR.

Use `github-pull-request_create_pull_request` targeting `<release-branch>`. The PR
body must include: short summary, `Closes #N`, changes table, key design decisions,
test results (`Targeted: X/X passed. Full suite: M/M passed.`).

### 9c — Confirm mergeability

```powershell
gh pr view <PR-number> --json mergeable,mergeStateStatus
```

Report result. Do not proceed to Step 10 until the user confirms the PR looks correct
and is mergeable.

---

## Step 10 — Stamp awaiting-approval and hand off

```powershell
gh issue edit <N> --add-label "awaiting-approval"
```

Verify clean state:

```powershell
git status
git log --oneline origin/<branch>..HEAD
```

Both must show nothing outstanding.

---

> ⛔ **THIS WORKTREE'S WORK IS COMPLETE — DO NOT MAKE FURTHER CHANGES HERE**
>
> **PR #N is open and mergeable.**
> Base: `<release-branch>` · Status: ✅ Mergeable — no conflicts
>
> Issue #N now carries `awaiting-approval`.
>
> **To merge:** close this VS Code session, open a new Copilot Chat from the
> **`wara` release worktree**, and run:
>
> `/approve-ready-for-release <N>`
>
> Do not attempt to run this prompt, simulate it, or perform any of its steps
> from this worktree.
