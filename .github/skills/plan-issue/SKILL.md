---
name: plan-issue
description: Writes a committed, approved implementation plan for a status:plan issue. Creates a plan doc on the docs/main branch with phases A–E (scope, document impact, testing, acceptance criteria, definition of done). An issue carrying lifecycle:fast-track gets a compact plan written in one pass behind one review gate (compact mode). No PR is opened — plan docs go directly to docs/main. Approve-ready-for-implement advances the issue to status:implement.
disable-model-invocation: true
argument-hint: "Issue number — e.g. 54"
---
# Issue Planning Workflow

**Issue number:** extract from the argument (e.g. `/plan-issue 54`). If no number was
provided, ask: "Which issue number should I plan?"

**Prerequisite:** The issue must carry `status:plan`. Run `gh issue view <N> --json
labels` to confirm. If absent, stop — the issue is not ready to plan.

**Golden rule:** No implementation code is written until the plan is committed to
docs/main and the user has explicitly approved it.

**Staged document workflow:** Write one phase at a time. After each phase, stop and ask
the user to review. Do not write the next phase until the user explicitly accepts. The one
exception is an issue carrying `lifecycle:fast-track`, which is written in one pass (see
Compact mode).

---

## Step 0 — Pre-flight checks

**0a — Verify worktree:**

**Expected path:** `C:\wt\wara\plan\issue-<N>`

```powershell
(Get-Location).Path
```

If the output does not match, create or open the worktree:

```powershell
$slug = "<derived-slug>"
tools/New-IssueWorktree.ps1 -Stage plan -Issue <N> -BranchPrefix plan -Slug $slug
```

**Stop.** Tell the user:
> "Worktree ready at `C:\wt\wara\plan\issue-<N>`. Switch to that VS Code window
> and rerun `/plan-issue <N>` from there."

**0b — Verify docs worktree:**

```powershell
if (-not (Test-Path 'C:\wt\wara\docs\issues')) {
    Write-Error "ERROR: docs worktree not found. Run: git worktree add C:\wt\wara\docs docs/main"
    exit 1
}
Write-Host "docs/main worktree OK"
```

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

1. Fetch the issue with `github-pull-request_issue_fetch` to confirm `status:plan` and
   get the issue title.
2. Determine the release folder:

   ```powershell
   $milestone = gh issue view <N> --json milestone --jq '.milestone.title // "backlog"'
   $releaseFolder = if ($milestone -match '^Backlog$') { 'backlog' } else { $milestone -replace 'release/', 'release-' }
   $issueDocDir = "C:\wt\wara\docs\issues\$releaseFolder"
   ```

3. Find and read the investigation doc at
   `$issueDocDir\<N-padded>-<slug>-investigation.md`. If it does not exist, check
   for a legacy combined doc (e.g. `<N-padded>-<slug>-plan.md`).
4. Read `CHANGELOG.md` top section to establish the current version line.
5. Check whether the issue carries `lifecycle:fast-track`, which selects compact mode,
   and read its comments, including any `## Fast-track scan` comment:

   ```powershell
   $issue = gh issue view <N> --json labels,comments | ConvertFrom-Json
   $compact = $issue.labels.name -contains 'lifecycle:fast-track'
   ```

From the investigation doc extract:

- **Problem statement** and **proposed approach**
- **Phase D decisions** deferred to planning (options and constraints)
- **Any prerequisite issues**

In compact mode with no investigation doc, extract the same three things from the issue
body and comments instead, including the `## Fast-track scan` comment. If its Result is
`FLAGGED (provisional)`, the rows it left `Likely` are the first the Fast-track check
must verify.

Present a 2–3 sentence summary and ask: **"Ready to write the implementation plan for #N?"**
In compact mode, add to the summary that this is a fast-track issue and that you will
write a compact plan in one pass behind one review gate.
Do not proceed until the user confirms.

---

## Step 2 — Transition to PLANNING

```powershell
$c = & tools/Get-GhProjectConstants.ps1

gh issue edit <N> --add-label "status:planning" --remove-label "status:plan" --add-assignee "@me"

$itemId = gh project item-list $c.number --owner $c.owner --format json --limit 100 |
  ConvertFrom-Json | Select-Object -ExpandProperty items |
  Where-Object { $_.content.number -eq <N> } |
  Select-Object -ExpandProperty id

gh project item-edit --project-id $c.id --id $itemId `
  --field-id $c.statusFieldId `
  --single-select-option-id $c.statusOptions.planning
```

---

## Step 3 — Implementation context survey

Run in parallel to ground the plan in the current codebase state:

1. **Source files in scope** — read files named in the Phase D summary under
   `src/modules/wara/`.
2. **Existing tests** — for each source file, read relevant Pester test files under
   `src/tests/` and note which functions are already covered.
3. **Docs scan** — search `docs/` for passages describing current behaviour of anything
   this issue changes. Use `grep_search` with function names and old-behaviour terms.
   Every doc that would mislead a reader after this issue ships is a candidate for the
   Affected Documents table.
4. **In-flight docs scan** — search `C:\wt\wara\docs\issues\` for other
   planning or investigation docs that reference in-scope functions or contracts. For
   each match, note whether this issue invalidates their assumptions. Flag them in
   Phase B.
5. **Fast-track prior art** — read the `## Fast-track scan` and `## Fast-track escape`
   comments and any abandoned compact plan, as prior art rather than conclusions:

   ```powershell
   gh issue view <N> --json comments --jq '.comments[].body | select(startswith("## Fast-track"))'
   Get-ChildItem $issueDocDir -Filter "<N-padded>-*-plan-fast-track.md"
   ```

Do not narrate survey findings in chat — they belong in Phase A.

---

## Phase pre-flight (applies to every phase)

Before writing any phase:

```powershell
gh issue view <N> --json labels,assignees
```

If `status:planning` is absent, re-apply it. If no assignee, assign yourself. Note
corrections briefly, then continue.

---

## Plan document structure

The plan doc is created at:
`C:\wt\wara\docs\issues\<release-folder>\<N-padded>-<slug>-plan.md`

If an investigation doc exists for this issue, the plan doc is a **separate file**.
Do not append to the investigation doc.

The structure below shows the document's final shape for reference only. **Do not
pre-write empty headings for phases you haven't reached yet** — each phase's
instructions below tell you exactly which section(s) to append at that point. The
doc grows one phase at a time; a reader should never see an empty heading waiting
to be filled in.

````markdown
# Issue #N: <title>

**Issue:** [#N](https://github.com/drmssst/Well-Architected-Reliability-Assessment/issues/<N>)
**Alias:** <slug>

---

## Implementation plan — Issue #N: <title>

### Phase A — Scope and approach

### Phase B — Document impact

### Affected documents

| File | Change needed |
| ---- | ------------- |
| `CHANGELOG.md` | Add `minor`/`patch`/`major` entry under `[Unreleased]` |

### Affected source files

| File | Change needed |
| ---- | ------------- |

### Version impact

**Classification:** `minor` *(or `patch` or `major`)*

| Term | Meaning |
| ---- | ------- |
| `major` | Breaking — existing consumers must update |
| `minor` | Additive, non-breaking new capability |
| `patch` | Invisible to consumers — bug fix, doc correction |

**Rationale:** <one or two sentences>

### Testing requirements

### Acceptance criteria

- [ ] <condition>

### Definition of done

- [ ] All acceptance criteria verified
- [ ] All affected documents updated
- [ ] All tests in Testing Requirements written and passing
- [ ] Full PowerShell suite (`tools/Invoke-Pester.ps1 src/tests/`) green
- [ ] Manual smoke test passed (verify behavior against testbed artifacts, where applicable)
- [ ] CHANGELOG entry added with correct classification
- [ ] All modified Markdown files pass lint
- [ ] PR opened targeting the release branch
````

---

## Compact mode (`lifecycle:fast-track`)

When the issue carries `lifecycle:fast-track`, skip Phases A to E and write a compact plan
instead, in one pass behind one review gate. It lives at the same path, with the same
header and the same headings as a full plan, so `approve-ready-for-implement` and
`implement-issue` read it unchanged. Read `.github/FAST_TRACK_CRITERIA.md` first: it
defines the Eligibility checklist, the provisional flag rules, the `XS` definition, the
Escape procedure and how to confirm an escape with the user. Run the Phase pre-flight
once, before creating the doc.

**C1 — Fast-track check first.** Create the plan doc with the standard header, the
`## Implementation plan` heading and a `### Fast-track check` section, and nothing else.
Read the code the plan will change, which is the first full read for an item that skipped
investigation, and answer the six conditions of the Eligibility checklist in a Condition,
Met, Evidence table that uses the checklist's condition names, in its order. Answer each
row `Yes` or `No` with plan-level evidence: the file paths, the edit, the signatures you
compared. `Likely` is not allowed here, and a row you cannot evidence is `No`.

If any row is `No`, stop writing and raise it with the user before anything changes. Show
the failing rows with their evidence, recommend escaping and name the state the item would
return to, and ask what the user knows that you may not.

> ⛔ **STOP — do not escape, and do not write the rest of the plan, until the user answers.**

Then follow Confirming an escape in the criteria file. If the user gives information that
answers a row, re-answer it with them as the source and carry on with C2. If they agree
the item is not a fast-track papercut, run the escape procedure with
`$stage = 'plan-issue (fast-track check)'` and a `$trigger` holding the failing rows, their
evidence and the user's view, report as its After an escape section describes, and stop.
The procedure renames the draft, so it stays as prior art.

**C2 — Write the rest in one pass.** Append the remaining sections without pausing, with
the headings and order of the plan document structure above. Keep each section terse:

- **Phase A:** one short paragraph.
- **Phase B:** the docs scan and in-flight scan results, in a sentence or two.
- **Affected documents** and **Affected source files:** one row per file. Each row names
  exactly one file (no globs, no directory rows) and states its uniform edit. Affected
  documents always includes `CHANGELOG.md`. List any test file that changes in Affected
  source files too: the Step 9a guard in `implement-issue` takes its declared scope from
  these two tables.
- **Version impact:** `patch` or `minor`, with a one-sentence rationale. A `major` impact
  is a public surface change, so row 4 of the check would already be `No`.
- **Testing requirements:** may be an explicit "No new or modified tests" with the reason.
- **Acceptance criteria:** verifiable conditions only, one per observable outcome.
- **Sizing estimate:** headed as in Phase D of a full plan (`### D<N>. Sizing estimate`),
  with the `**Estimate:** XS` line and one sentence. No driver table.
- **Definition of done:** the standard checklist, unchanged.

If the `**Estimate:**` you wrote is not `XS`, do not lint or present the doc yet. Raise it
as in C1: say what the estimate is and why, recommend escaping, and ask what the user
knows that you may not.

> ⛔ **STOP — do not escape, and do not continue, until the user answers.**

If they give information that brings the estimate to `XS`, revise the section with them as
the source and carry on. If they agree the item is not `XS`, run the escape procedure with
`$stage = 'plan-issue (sizing estimate)'` and a `$trigger` stating the estimate, the reason
and the user's view, and stop.

**C3 — One lint run.** Lint the doc once and fix every violation:

```powershell
tools/Invoke-MarkdownLint.ps1 'C:\wt\wara\docs\issues\<release-folder>\<N-padded>-<slug>-plan.md'
```

**C4 — One review gate.** Tell the user:
> "Compact plan written. Please open `issues/<release-folder>/<file>` in the `issues`
> workspace folder and review the whole document once. If everything looks good, say
> **'go ahead'** — I'll commit the plan doc and stamp `awaiting-approval`."

> ⛔ **STOP — do not commit or stamp until the user says "go ahead".**

If the review changed the estimate to anything other than `XS`, do not commit yet: raise it
as in C1, and run the escape procedure only if the user agrees. Otherwise continue at
Step 4.

---

## Phase A — Scope and approach

Write the scope section: what the core change is, what it delivers, any open decisions
the user must make before scope can be finalised, whether sub-issues are warranted.

**Lint** — run from the plan worktree root:

```powershell
tools/Invoke-MarkdownLint.ps1 'C:\wt\wara\docs\issues\<release-folder>\<N-padded>-<slug>-plan.md'
```

Fix any errors before continuing.

**Tell the user:**
> "Phase A written. Please open `issues/<release-folder>/<file>` in the
> `issues` workspace folder and review the scope. Let me know when ready for
> Phase B."

> ⛔ **STOP — do not write Phase B until the user explicitly accepts Phase A.**

---

## Phase B — Document impact

Write the `Affected documents`, `Affected source files`, and `Version impact` sections.

- **Affected documents** — every `.md` file a reader would follow and form incorrect
  expectations after this issue ships. Always include `CHANGELOG.md`. Do **not** include
  test files (those are in Phase C). For each in-flight doc in `issues/` that may
  be invalidated, call it out explicitly in the `Change needed` column.
- **Affected source files** — non-markdown source files that change.

**Lint** — run from the plan worktree root:

```powershell
tools/Invoke-MarkdownLint.ps1 'C:\wt\wara\docs\issues\<release-folder>\<N-padded>-<slug>-plan.md'
```

Fix any errors before continuing.

**Tell the user:**
> "Phase B written. Please review Affected Documents, Source Files, and Version Impact.
> Let me know when ready for Phase C."

> ⛔ **STOP — do not write Phase C until the user explicitly accepts Phase B.**

---

## Phase C — Testing requirements

List only tests that are **new** or **must change** — do not re-specify already-passing
tests. For each: what it validates, expected outcome, the Pester test file under
`src/tests/` and function/`Context` block, whether new or modified.

**Lint** — run from the plan worktree root:

```powershell
tools/Invoke-MarkdownLint.ps1 'C:\wt\wara\docs\issues\<release-folder>\<N-padded>-<slug>-plan.md'
```

Fix any errors before continuing.

**Tell the user:**
> "Phase C written. Please review Testing Requirements. Let me know when ready for
> Phase D."

> ⛔ **STOP — do not write Phase D until the user explicitly accepts Phase C.**

---

## Phase D — Acceptance criteria

Write `Acceptance criteria` — each item is a verifiable, feature-specific condition,
independently checkable, not a process gate.

Also include a **Sizing estimate** sub-section as the final entry in Phase D (use the
next sequential `D<N>` number after whatever other AC items Phase D contains). Use the
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
reflection will refine the sizing model. Keep the estimate grounded in the Phase B
Affected source files table — every High-weight driver should correspond to files or
logic already named there.

**Lint** — run from the plan worktree root:

```powershell
tools/Invoke-MarkdownLint.ps1 'C:\wt\wara\docs\issues\<release-folder>\<N-padded>-<slug>-plan.md'
```

Fix any errors before continuing.

**Tell the user:**
> "Phase D written. Please review Acceptance Criteria. Let me know when ready for
> Phase E."

> ⛔ **STOP — do not write Phase E until the user explicitly accepts Phase D.**

---

## Phase E — Definition of done

Write the `Definition of done` section using the standard checklist from the template.
The user may add issue-specific items; the standard items may not be removed.

**Lint** — run from the plan worktree root:

```powershell
tools/Invoke-MarkdownLint.ps1 'C:\wt\wara\docs\issues\<release-folder>\<N-padded>-<slug>-plan.md'
```

Fix any errors before continuing.

**Tell the user:**
> "Phase E written — the plan is complete. Review the Definition of Done. If everything
> looks good, say **'go ahead'** — I'll commit the plan doc and stamp `awaiting-approval`."

> ⛔ **STOP — do not commit or stamp until the user says "go ahead".**

---

## Step 4 — Commit and stamp

**4a — Commit plan doc to docs/main:**

```powershell
Set-Location C:\wt\wara\docs
git add issues/<release-folder>/<N-padded>-<slug>-plan.md

# Guard: docs/main must only receive .md files
$nonMd = git diff --cached --name-only | Where-Object { $_ -notmatch '\.md$' }
if ($nonMd) { throw "docs/main gate: non-.md file(s) staged: $($nonMd -join ', '). Unstage them before pushing." }

git commit -m "docs(#N): implementation plan complete — phases A–E"
git push origin docs/main
Set-Location C:\wt\wara\plan\issue-<N>
```

**4b — Stamp awaiting-approval:**

```powershell
gh issue edit <N> --add-label "awaiting-approval"
```

---

> ⛔ **THIS WORKTREE'S PLANNING IS COMPLETE — DO NOT MAKE FURTHER CHANGES HERE**
>
> Plan doc committed to `docs/main` at `issues/<release-folder>/<file>`.
>
> Issue #N now carries `awaiting-approval`.
>
> **To advance:** open a new Copilot Chat from the **`wara` release worktree**
> and run:
>
> `/approve-ready-for-implement <N>`
