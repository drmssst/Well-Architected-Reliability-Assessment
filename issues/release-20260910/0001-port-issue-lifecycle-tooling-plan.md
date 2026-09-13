# Issue #1: chore: port Copilot issue-lifecycle tooling from sfmc-tubfactory into wara

**Issue:** [#1](https://github.com/drmssst/Well-Architected-Reliability-Assessment/issues/1)
**Alias:** `0001-port-issue-lifecycle-tooling`

---

## Implementation plan — Issue #1: chore: port Copilot issue-lifecycle tooling from sfmc-tubfactory into wara

### Phase A — Scope and approach

The core change is landing the issue-lifecycle tooling that was ported and adapted
during investigation — 8 prompt files, 7 PowerShell tools, 3 config files, and
package/lint/gitignore infra — plus one new documentation addition, across
dependency-ordered commits made in the implement worktree. None of this is currently
committed anywhere; it exists only as working-tree changes carried forward from the
investigate worktree into this plan worktree.

**What it delivers:** a working, committed `raise → investigate → plan → implement →
release` Copilot Chat workflow for this repo — prompt files that drive each stage,
PowerShell tools those prompts call (project-board constants, backlog prioritisation,
sub-issue linking, per-stage worktree creation, markdownlint/Pester/PSScriptAnalyzer
wrappers), the config those tools read, and a new `README.md` section orienting a
contributor to the workflow and where to find its authoritative detail
(`.github/prompts/*.prompt.md`).

**Commit strategy (confirmed during this survey):** four commits, in dependency
order — (1) config, (2) tools, (3) prompts, (4) infra (`package.json`,
`package-lock.json`, `.gitignore`, `.markdownlint.json`, `.markdownlint-cli2.jsonc`,
`wara-0001.code-workspace`, and the `README.md` prose fixes + new lifecycle
section) — landing on `release/20260910`. `release/20260910` and `main` are
currently identical (`8683227`), so this is a safe, low-risk target; it will reach
`main` through the repo's normal release merge, not directly here.

**Resolved from investigation's deferred decisions (D3):**

- **Integration branch (C1):** confirmed `release/20260910` — it does not diverge
  from `main` today, so no rebase/merge conflict risk from targeting it now.
- **`docs/main` branch protection (C2):** confirmed unprotected
  (`gh api .../branches/docs%2Fmain/protection` → 404 "Branch not protected"), and
  the investigation doc's own commit already pushed there successfully — no PR
  fallback needed.
- **README lifecycle section wording (B5):** drafted in Phase B below (Affected
  documents table) — content is written as part of this issue's own commits, not
  deferred further.

- **Label-sync follow-up issue (B2):** deferred — not opened as part of this issue;
  left for a later backlog-grooming pass.

No sub-issues are warranted for the core porting work — it is a single cohesive
effort best reviewed as four small, concern-scoped commits rather than split across
separate issues. The label-sync artifact (B2) and any future GH Project
`releasing`/`superseded` field extension (B3) are explicitly out of scope here and
would be their own issues if pursued.

### Phase B — Document impact

No other in-flight investigation/plan doc under `C:\wt\wara\docs\issues\` references
this issue's scope (searched for the ported functions/tools/prompts) — this issue's
own investigation doc is the only match, so nothing else needs invalidation flags.

### Affected documents

| File | Change needed |
| ---- | ------------- |
| `CHANGELOG.md` | Create the file (does not exist yet in this repo) with an `[Unreleased]` section and one `patch` entry for this port |
| `README.md` | Add new `## Issue lifecycle workflow` section: the five stages and their `status:*` labels, the worktree-per-stage model (`C:\wt\wara\<stage>\...`, `docs/main` at `C:\wt\wara\docs`), and a pointer to `.github/prompts/*.prompt.md` as source of truth. Prose/list-numbering fixes already applied. |

### Affected source files

| File | Change needed |
| ---- | ------------- |
| `config/settings.json` | New — GH Project constants |
| `config/issue-priority-weights.json` | New — backlog scoring weights |
| `config/PSScriptAnalyzerSettings.psd1` | New — relocated from `src/tests/` |
| `tools/Get-GhProjectConstants.ps1` | New |
| `tools/Get-NextIssues.ps1` | New |
| `tools/Add-SubIssue.ps1` | New |
| `tools/New-IssueWorktree.ps1` | New |
| `tools/Invoke-MarkdownLint.ps1` | New |
| `tools/Invoke-Pester.ps1` | New |
| `tools/Invoke-PsScriptAnalyzer.ps1` | New |
| `.github/prompts/*.prompt.md` (8 files) | New; 4 (`investigate-issue`, `plan-issue`, `implement-issue`, `approve-ready-for-release`) additionally carry a `node_modules` pre-flight check added during this plan session |
| `.github/COMMIT_GUIDELINES.md` | New |
| `package.json`, `package-lock.json` | New — pins `markdownlint-cli2`, `smol-toml` override |
| `.gitignore` | New |
| `.markdownlint.json`, `.markdownlint-cli2.jsonc` | New |
| `wara-0001.code-workspace` | New — multi-root workspace definition |

### Version impact

**Classification:** `patch`

| Term | Meaning |
| ---- | ------- |
| `major` | Breaking — existing consumers must update |
| `minor` | Additive, non-breaking new capability |
| `patch` | Invisible to consumers — bug fix, doc correction |

**Rationale:** This issue ports contributor-facing tooling (prompts, scripts,
config) and adds a README section for future contributors. It does not add,
change, or remove any function exported by the WARA PowerShell module, so an end
user running `Install-Module WARA` sees no behavioral difference — the change is
invisible to module consumers.

### Testing requirements

No new or modified Pester tests are required for this issue. The 7 ported
`tools/*.ps1` scripts are thin wrappers around `gh`/`git`/external processes —
their value lies in exercising the real CLI, not in mockable pure logic — and no
Pester file under `src/tests/` currently references any of them. The one function
worth unit-testing later, `tools/Get-NextIssues.ps1`'s priority-weight scoring
(pure computation over `config/issue-priority-weights.json`), is explicitly
deferred to a follow-up issue rather than added here, to keep this a straight port
rather than new test-authoring work.

Verification for this issue is manual instead: run each ported tool once against
live `gh`/GitHub state (already exercised during investigation — `Get-GhProjectConstants.ps1`,
`Get-NextIssues.ps1`, and `New-IssueWorktree.ps1` all ran successfully creating this
plan worktree and transitioning the issue), and confirm `tools/Invoke-MarkdownLint.ps1`
and `tools/Invoke-PsScriptAnalyzer.ps1` both exit clean against the ported files
themselves.

### Acceptance criteria

- [x] D1. The four commits (config → tools → prompts → infra) exist on
      `release/20260910`, each containing exactly the files listed in its Phase B
      group, with no other pending changes left uncommitted in the worktree.
- [x] D2. `CHANGELOG.md` exists at the repo root with an `[Unreleased]` section
      containing one `patch`-classified entry for this port.
- [x] D3. `README.md` contains a `## Issue lifecycle workflow` section covering the
      five stages and their `status:*` labels, the worktree-per-stage model, and a
      pointer to `.github/prompts/*.prompt.md`.
- [x] D4. `tools/Invoke-MarkdownLint.ps1` and `tools/Invoke-PsScriptAnalyzer.ps1`
      both exit `0` against every file in the Phase B Affected Documents and
      Affected Source Files tables.
- [x] D5. `npm audit` reports 0 vulnerabilities against the committed
      `package.json`/`package-lock.json`.

### Sizing estimate

**Estimate:** S

| Driver | Weight | Reasoning |
| ------ | ------ | --------- |
| Commit splitting (config → tools → prompts → infra) | Medium | Requires careful per-group staging and verification, not one bulk commit |
| README lifecycle section authoring | Low | New prose is scope-bounded by Phase B (~half page) |
| `CHANGELOG.md` bootstrap | Low | New file, but standard `[Unreleased]` structure with one entry |
| Test authoring | None | Phase C confirms no new Pester tests required |
| `docs/main` first-push risk | Low | Branch protection already confirmed absent; first push already succeeded during investigation |

Primary uncertainty drivers:

- Whether `tools/Invoke-PsScriptAnalyzer.ps1` surfaces violations on the ported
  scripts not caught during investigation's spot-check (A5).
- Whether the config → tools → prompts → infra ordering hits an unanticipated
  interdependency once split into real commits.

*Upgrade to the next size if PSScriptAnalyzer or markdownlint surface violations
across the ported files requiring rework, or if the four-commit split needs
re-sequencing due to file interdependencies not identified in Phase B.*

### Definition of done

- [x] All acceptance criteria verified
- [x] All affected documents updated
- [x] All tests in Testing Requirements written and passing
- [x] Full PowerShell suite (`tools/Invoke-Pester.ps1 src/tests/`) green
- [x] Manual smoke test passed (verify behavior against testbed artifacts, where applicable)
- [x] CHANGELOG entry added with correct classification
- [x] All modified Markdown files pass lint
- [ ] PR opened targeting the release branch
