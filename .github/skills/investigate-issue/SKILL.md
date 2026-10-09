---
name: investigate-issue
description: Investigates a GitHub issue. A fast-track scan (scan 1) runs first and moves an eligible low-risk XS papercut straight to status:plan with no investigation. Otherwise the skill surveys the codebase, writes four staged investigation phases (Findings, Approach, Risks, Summary) to a new investigation doc on the docs/main branch, then stamps awaiting-approval. No PR is opened — investigation docs go directly to docs/main. Approve-ready-for-plan advances the issue to status:plan.
disable-model-invocation: true
argument-hint: "Issue number — e.g. 117"
---
# Issue Investigation Workflow

**Issue number:** extract from the argument (e.g. `/investigate-issue 117`). If no
number was provided, ask: "Which issue number should I investigate?"

**Prerequisite:** The issue must carry `status:investigate`. Run `gh issue view <N>
--json labels` to confirm. If absent, stop — the issue is not ready to investigate.

**Golden rule:** Investigation is a discovery phase. Phase A (findings) is observation
only — no decisions until Phase B.

**Staged document workflow:** Write one phase at a time. After each phase, stop and ask
the user to review. Do not write the next phase until the user explicitly accepts.

---

## Scan 1 — Fast-track scan

Runs before Step 0, so no investigate worktree is created for a flagged item. The six
conditions, the `XS` definition, the provisional flag rules and the comment template are
defined once in `.github/FAST_TRACK_CRITERIA.md`; read it before scanning and do not
restate it here.

**1a — Skip check.** Skip scan 1 and go straight to Step 0 when the issue carries
`lifecycle:fast-track-escaped` or already has a `## Fast-track scan` comment. The second
case also covers the rerun inside the investigate worktree, so an item is never scanned
twice.

```powershell
$issue = gh issue view <N> --json labels,comments | ConvertFrom-Json
$escaped = $issue.labels.name -contains 'lifecycle:fast-track-escaped'
$scanned = @($issue.comments | Where-Object { $_.body -like '## Fast-track scan*' }).Count -gt 0
"escaped=$escaped scanned=$scanned"
```

**1b — Evaluate.** Answer the six conditions of the Eligibility checklist from the issue
body and comments and a bounded read of the code, only as deep as each row needs. If the
issue names no code, a few searches from its symptom are enough to find the likely
location; stop there. Do not start the investigation and do not write to docs/main.

Scan 1 runs before the investigation, so a row you cannot yet support with evidence is
`Likely` when nothing seen argues against it, and `No` when something does. Row 2 is
never `Likely`. Then give the XS likelihood (High, Medium or Low) as the criteria file
defines it, and set row 1 from it. Present the table (Condition, Met, Evidence), the XS
likelihood and the result in chat.

**1c — Decide.** The result follows the rows, as the criteria file defines:

- Any row is `No`: the result is `NOT FLAGGED`. Post the scan comment (1d), ask nothing,
  and continue to Step 0.
- All six rows are `Yes`: ask **"All six fast-track conditions hold. Flag #N as
  fast-track and skip investigation? (yes / no)"**
- No row is `No` and at least one is `Likely`: ask **"The XS likelihood is High, but the
  rows marked Likely are not yet evidenced. Flag #N provisionally? The compact plan's
  check verifies them, and the item goes back to the normal route if any fails.
  (yes / no)"**

> ⛔ **STOP — post, label and transition nothing until the user answers.**

On **yes** the result is `FLAGGED` (all rows `Yes`) or `FLAGGED (provisional)` (any row
`Likely`): post the scan comment (1d), then flag the issue (1e) and stop. On **no** the
result is `NOT FLAGGED` with `Failing conditions` set to `none (declined: <reason>)`,
taking a one-line reason from the user: post the scan comment (1d) and continue to
Step 0.

**1d — Post the scan comment.** Use the Scan comment template in the criteria file with
Context `scan 1`, including the `XS likelihood` line. `Confirmed by` is the GitHub login
of the person running the skill (`gh api user --jq .login`). The first line must be
`## Fast-track scan`, because the skip check above and the surveys in the other skills
search for it.

```powershell
@'
<scan comment, filled in from the template>
'@ | gh issue comment <N> --body-file -
```

**1e — Flag the issue (`FLAGGED` only).** Add `lifecycle:fast-track` in the same
`gh issue edit` that moves `status:investigate` to `status:plan`, then move the board:

```powershell
$c = & tools/Get-GhProjectConstants.ps1

gh issue edit <N> `
  --remove-label "status:investigate" `
  --add-label "status:plan" `
  --add-label "lifecycle:fast-track"

$itemId = gh project item-list $c.number --owner $c.owner --format json --limit 100 |
  ConvertFrom-Json | Select-Object -ExpandProperty items |
  Where-Object { $_.content.number -eq <N> } |
  Select-Object -ExpandProperty id

gh project item-edit --project-id $c.id --id $itemId `
  --field-id $c.statusFieldId `
  --single-select-option-id $c.statusOptions.plan
```

Then tell the user:
> "Issue #N is flagged fast-track and now at `status:plan`. No investigation document is
> written. **To write the compact plan:** open a Copilot Chat from the `wara` release
> worktree and run `/plan-issue <N>`."

For a provisional flag, add that the rows marked `Likely` are verified by the compact
plan's check, and that the item goes back to the normal route if any of them fails.

> ⛔ **STOP — a flagged issue does not continue to Step 0.**

---

## Step 0 — Pre-flight checks

**0a — Verify worktree:**

**Expected path:** `C:\wt\wara\investigate\issue-<N>`

```powershell
(Get-Location).Path
```

If the output does not match, create or open the worktree:

```powershell
$slug = "<derived-slug>"   # 3-5 kebab words from the issue title
tools/New-IssueWorktree.ps1 -Stage investigate -Issue <N> -BranchPrefix investigate -Slug $slug
```

**Stop.** Tell the user:
> "Worktree ready at `C:\wt\wara\investigate\issue-<N>`. Switch to that VS Code
> window and rerun `/investigate-issue <N>` from there."

**0b — Verify docs worktree:**

```powershell
if (-not (Test-Path 'C:\wt\wara\docs\issues')) {
    Write-Error "ERROR: docs worktree not found. Run: git worktree add C:\wt\wara\docs docs/main"
    exit 1
}
Write-Host "docs/main worktree OK"
```

If the check fails, stop and instruct the user to run the `git worktree add` command
shown in the error message, then rerun this prompt.

**0c — Verify workspace file has issues folder:**

Issue workspace files are generated with `C:\wt\wara\docs\issues` (named
`issues`) already present. Confirm it is there — do not add or modify the workspace
file.

```powershell
$wsFile = Get-ChildItem *.code-workspace | Select-Object -First 1
$ws = Get-Content $wsFile -Raw | ConvertFrom-Json
$hasDocs = $ws.folders | Where-Object { $_.path -eq 'C:\wt\wara\docs\issues' }
if (-not $hasDocs) {
    Write-Error "ERROR: issues folder missing from $($wsFile.Name). Check workspace template."
    exit 1
}
Write-Host "issues folder OK in $($wsFile.Name)"
```

**0d — Verify markdownlint dependencies installed:**

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

## Step 1 — Read the issue and confirm readiness

Run in parallel:

1. Fetch the issue with `github-pull-request_issue_fetch` to confirm the
   `status:investigate` label and get the issue title.
2. Determine the release folder from the issue milestone:

   ```powershell
   $milestone = gh issue view <N> --json milestone --jq '.milestone.title // "backlog"'
   $releaseFolder = if ($milestone -match '^Backlog$') { 'backlog' } else { $milestone -replace 'release/', 'release-' }
   $issueDocDir = "C:\wt\wara\docs\issues\$releaseFolder"
   Write-Host "Doc folder: $issueDocDir"
   ```

3. Check whether an investigation doc already exists at
   `$issueDocDir\<N-padded>-<slug>-investigation.md`. If it does, read it; if not,
   note that it will be created.

Present a 2–3 sentence summary of the issue and ask: **"Ready to investigate #N?"**
Do not proceed until the user confirms.

---

## Step 2 — Transition to INVESTIGATING

```powershell
$c = & tools/Get-GhProjectConstants.ps1

gh issue edit <N> --add-label "status:investigating" `
  --remove-label "status:investigate" --add-assignee "@me"

$itemId = gh project item-list $c.number --owner $c.owner --format json --limit 100 |
  ConvertFrom-Json | Select-Object -ExpandProperty items |
  Where-Object { $_.content.number -eq <N> } |
  Select-Object -ExpandProperty id

gh project item-edit --project-id $c.id --id $itemId `
  --field-id $c.statusFieldId `
  --single-select-option-id $c.statusOptions.investigating
```

---

## Step 3 — Context survey

Derive a reading list from the issue's problem statement and proposed approach. Read
only what is needed to answer the open questions. Common sources:

- Source files named in the proposed approach (`src/modules/wara/`)
- Prompt files that reference the affected area
- Config or schema files in scope
- Existing Pester tests that cover affected functions (`src/tests/`)
- Earlier fast-track records, read as prior art (below)

Earlier fast-track records are prior art, not conclusions: the `## Fast-track scan` and
`## Fast-track escape` comments on the issue and any abandoned compact plan
(`-plan-fast-track.md`). Their evidence shortens the survey.

```powershell
gh issue view <N> --json comments --jq '.comments[].body | select(startswith("## Fast-track"))'
Get-ChildItem $issueDocDir -Filter "<N-padded>-*-plan-fast-track.md"
```

Use `semantic_search` and `grep_search` as needed. Do not narrate survey findings in
chat — they belong in Phase A. Proceed directly to writing Phase A.

---

## Phase pre-flight (applies to every phase)

Before writing any phase, verify the issue is still in the correct state:

```powershell
gh issue view <N> --json labels,assignees
```

If `status:investigating` is absent, re-apply it. If no assignee, run
`gh issue edit <N> --add-assignee "@me"`. Note any correction briefly, then continue.

---

## Investigation doc header format

Every investigation doc uses the following header — **bold fields, not a table**:

```markdown
# Investigation: #N — <issue title>

**Issue:** [#N](<GitHub issue URL>)
**Alias:** `<N-padded>-<slug>`
**Branch:** `investigate/issue-<N>-<slug>`
**Milestone:** `<milestone title>`
```

Do not use a metadata table. Do not include Status or Author fields.

---

## Phase A — Findings

Write what the context survey found: current structure, sizes, dependencies, and any
existing scaffolding. **Observation only** — no decisions, no recommendations. Answer
the open questions with evidence.

**Structure of Phase A:**

1. **Open with a "Problem and desired outcome" subsection.** Two paragraphs: one for
   the problem (what is broken or missing today), one for the desired outcome (what
   the completed issue should achieve). Close with: "The remainder of Phase A
   establishes what is true today against that outcome so that the gap is clear and
   Phase B decisions are grounded."

2. **Separate the intro with a horizontal rule (`---`) before A1.**

3. **End each `A<N>` subsection with a "Gap against desired outcome" paragraph** that
   names the specific gap the finding exposes and, where known, states the minimum
   change needed to close it. Keep it to 2–4 sentences.

4. **Close Phase A with an `A<last>. Open questions for Phase B` subsection.** Use a
   numbered list. Frame each item as a question, not an answer — Phase B resolves
   them. Do not use a table for open questions.

**Target file:** `$issueDocDir\<N-padded>-<slug>-investigation.md`

Create the file if it does not exist. Write the investigation doc header and Phase A
section, then lint:

```powershell
tools/Invoke-MarkdownLint.ps1 "C:\wt\wara\docs\issues\$releaseFolder\<file>"
```

Fix all violations, then tell the user:
> "Phase A written. Please open `issues/<release-folder>/<file>` in the editor
> (visible in the `issues` workspace folder). Review the findings and let me know
> when ready for Phase B."

> ⛔ **STOP — do not write Phase B until the user explicitly accepts Phase A.**

---

## Phase B — Approach decisions

Write the concrete decisions that resolve each open question. For each: state the
decision, give a 1–3 sentence rationale, note alternatives considered and rejected.
If a question needs user input, present options and ask — do not pick arbitrarily.

Lint and tell the user:
> "Phase B written. Please review the approach decisions and let me know when ready
> for Phase C."

> ⛔ **STOP — do not write Phase C until the user explicitly accepts Phase B.**

---

## Phase C — Risks and prerequisites

Write the risks, constraints, and prerequisite issues. For each risk: name it, explain
the mechanism, state the mitigation. If a risk is a false alarm, record that conclusion
explicitly.

Lint and tell the user:
> "Phase C written. Please review the risks and let me know when ready for Phase D."

> ⛔ **STOP — do not write Phase D until the user explicitly accepts Phase C.**

---

## Phase D — Ready-to-plan summary

Write a concise summary: file-in-scope table, decisions deferred to planning (with
options), recommended commit strategy, whether new tests are required.

When the findings suggest the item qualifies for the fast-track route, add a
`### D<N>. Fast-track assessment` entry after the other D entries and immediately before
the Sizing estimate. It is the six-condition table (Condition, Met, Evidence) from the
Eligibility checklist in `.github/FAST_TRACK_CRITERIA.md`, answered `Yes` or `No` with
evidence from this investigation (`Likely` is for scan 1 only), plus one line saying
whether the item qualifies. Do not add the label or change the issue state here;
`approve-ready-for-plan` carries the decision.
Omit the entry when the findings clearly rule the item out.

Close Phase D with a **Sizing estimate** sub-section as the **last item** — written
after all other D entries, immediately before the transition message to the user. Do
not assign it a `D<N>` number — head it simply as `### Sizing estimate`. Use the
T-shirt scale XS / S / M / L / XL, with `XS` as defined in the XS definition section of
`.github/FAST_TRACK_CRITERIA.md`. Structure:

- One-line verdict: `**Estimate:** <size>`
- A driver table (columns: Driver, Weight, Reasoning) with one row per significant
  contributor to size. Weight values: High / Medium / Low.
- A short "Primary uncertainty drivers" bullet list (2–4 items) naming the specific
  unknowns that could push the estimate up by one size.
- A one-sentence upgrade trigger: *"Upgrade to the next size if ..."*

The purpose of this entry is calibration over time: plan phase will add a per-commit
breakdown; post-implementation adds actuals and a variance note; periodic cross-issue
reflection will refine the sizing model. Keep the estimate grounded in the files-in-scope
table — every High-weight driver should correspond to files or logic already named
there.

Lint and tell the user:
> "Phase D written — investigation is complete. Review the summary. When everything
> looks good, say **'transition'** and I'll commit the doc and stamp `awaiting-approval`."

> ⛔ **STOP — do not commit or stamp until the user says "transition".**

---

## Step 4 — Commit and stamp

**4a — Commit investigation doc to docs/main:**

```powershell
Set-Location C:\wt\wara\docs
git add issues/<release-folder>/<N-padded>-<slug>-investigation.md

# Guard: docs/main must only receive .md files
$nonMd = git diff --cached --name-only | Where-Object { $_ -notmatch '\.md$' }
if ($nonMd) { throw "docs/main gate: non-.md file(s) staged: $($nonMd -join ', '). Unstage them before pushing." }

git commit -m "docs(#N): investigation — phases A–D complete"
git push origin docs/main
Set-Location C:\wt\wara\investigate\issue-<N>
```

**4b — Stamp awaiting-approval:**

```powershell
gh issue edit <N> --add-label "awaiting-approval"
```

---

> ⛔ **THIS WORKTREE'S INVESTIGATION IS COMPLETE — DO NOT MAKE FURTHER CHANGES HERE**
>
> Investigation doc is committed to `docs/main` at
> `issues/<release-folder>/<file>`.
>
> Issue #N now carries `awaiting-approval`.
>
> **To advance:** open a new Copilot Chat from the **`wara` release worktree**
> and run:
>
> `/approve-ready-for-plan <N>`
