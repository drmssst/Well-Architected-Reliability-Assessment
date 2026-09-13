# Investigation: #1 — chore: port Copilot issue-lifecycle tooling from sfmc-tubfactory into wara

**Issue:** [#1](https://github.com/drmssst/Well-Architected-Reliability-Assessment/issues/1)
**Alias:** `0001-port-issue-lifecycle-tooling`
**Branch:** `investigate/issue-1-port-issue-lifecycle-tooling`
**Milestone:** `release/20260910`

## Phase A — Findings

### Problem and desired outcome

`wara` had no Copilot-driven issue-lifecycle workflow (raise → investigate → plan →
implement → release) of the kind used in `sfmc-tubfactory`. Because raising an issue
through that workflow itself depends on the workflow's own tooling (project-board
constants, labels, prompt files), the tooling had to be ported and made to run in this
repo *before* issue #1 — the issue that is supposed to track and review that porting —
could even be created. That bootstrap work was done ahead of this investigation and
exists today only as uncommitted, unreviewed changes in this worktree, in the GitHub
repo's label/project configuration, and in an empty `docs/main` orphan branch.

The desired outcome is a fully reviewed, committed, and documented issue-lifecycle
toolchain: prompt files, PowerShell tools, config, markdownlint/PSScriptAnalyzer
tooling, and the `docs/main` convention all landed on `main` (or the active
`release/20260910` branch per whatever commit strategy Phase B decides), with the
GitHub-side configuration (labels, project status field) reconciled to match, and with
documentation describing the workflow for future contributors — the one piece
confirmed **not** to exist yet. The remainder of Phase A establishes what is true today
against that outcome so that the gap is clear and Phase B decisions are grounded.

---

### A1. The porting work exists only as uncommitted local changes

`git status --porcelain` in this worktree shows one modified file (`README.md` —
markdownlint-driven prose/list-numbering fixes, unrelated to the port itself) and 20
new, untracked files:

- 8 prompt files in `.github/prompts/` (`raise-issue`, `investigate-issue`,
  `plan-issue`, `implement-issue`, `approve-ready-for-plan`,
  `approve-ready-for-implement`, `approve-ready-for-release`, `groom-backlog`,
  `next-issues`) plus `.github/COMMIT_GUIDELINES.md`
- 7 PowerShell tools in `tools/` (`Get-GhProjectConstants.ps1`, `Get-NextIssues.ps1`,
  `Add-SubIssue.ps1`, `New-IssueWorktree.ps1`, `Invoke-MarkdownLint.ps1`,
  `Invoke-Pester.ps1`, `Invoke-PsScriptAnalyzer.ps1`)
- 3 config files (`config/settings.json`, `config/issue-priority-weights.json`,
  `config/PSScriptAnalyzerSettings.psd1` — the last relocated from `src/tests/` during
  this session)
- `package.json`, `package-lock.json`, `.gitignore`, `.markdownlint.json`,
  `wara-0001.code-workspace`

None of this is on `main`. Other pre-existing `.github/` assets (`PULL_REQUEST_TEMPLATE.md`,
`ISSUE_TEMPLATE/*`, `policies/resource-management.yml`, `scripts/Generate-Documentation.ps1`,
`scripts/RunPesterTests.ps1`, `workflows/*.yml`) are already tracked and predate the port
— they belong to the upstream WARA repo, not to this effort.

**Gap against desired outcome:** every file above needs to be committed (per whatever
grouping Phase B decides) before this issue can close. Nothing has been committed yet.

### A2. GitHub label taxonomy required reconciliation against a reference set

The repo initially had a partial, inconsistent label set (e.g. `type:chore` with the
wrong description, no `status:*` labels at all, extra labels like `accessibility` and
`documentation` not part of the intended taxonomy). During this session the full
34-label set (status/type/urgency/importance plus workflow labels like
`awaiting-approval`, `implementing`, `project:1`, `released`, `roadmap`) was created,
corrected, or removed to match a reference taxonomy, and verified against every
`status:*` reference in the prompt files and `tools/Get-NextIssues.ps1` /
`config/issue-priority-weights.json` — no naming drift was found there.

**Gap against desired outcome:** the label set is now correct, but this reconciliation
happened ad hoc in chat rather than through a reviewable, reproducible mechanism (e.g.
a checked-in label-definition file or script). There is no artifact recording what the
correct label set is, so it cannot be re-applied or audited later.

### A3. The GH Project board status field has a smaller option set than the label taxonomy

`config/settings.json` (`github.project.statusOptions`) and the live GH Project 1
status field both list exactly: `investigate, investigating, plan, planning,
implement, implementing, release, shipped, done` (9 options) — confirmed identical via
`gh project field-list`. Neither has `releasing` or `superseded`, both of which exist
as repo labels; the project field also has a `done` option with no corresponding
label. No prompt file currently drives the project board to `releasing` or
`superseded`, so this isn't yet exercised in practice.

**Gap against desired outcome:** config and live state agree with each other (no
sync bug), but neither agrees with the full label taxonomy. Closing this requires
either adding `releasing`/`superseded` options to the live project field (an action
outside repo version control) or explicitly deferring those states from project-board
tracking.

### A4. `docs/main` — the orphan branch every future prompt depends on — has zero commits

The `docs/main` worktree at `C:\wt\wara\docs` exists locally with a `README.md`
describing the convention and an `issues/backlog/.gitkeep` placeholder, but
`git status` in that worktree shows both as untracked, `git log` reports "your current
branch 'docs/main' does not have any commits yet", and `gh ls-remote origin docs/main`
returns nothing — the branch has never been pushed. Every prompt in this workflow
(`investigate-issue`, `plan-issue`, `implement-issue`, and all three
`approve-ready-for-*` gates) commits or reads from `docs/main`.

**Gap against desired outcome:** `docs/main` must receive an initial commit and push
before this investigation doc (or any future doc) can be committed there per Step 4 of
this very prompt. This is a hard prerequisite, not just a nice-to-have.

### A5. Spot-checked tooling correctness during this session

Three concrete corrections were made and verified while reviewing the ported tooling:
`config/PSScriptAnalyzerSettings.psd1` was moved out of `src/tests/` (a test-fixture
directory) into `config/` (where the repo's other settings files live) with its one
reference in `tools/Invoke-PsScriptAnalyzer.ps1` updated and re-verified by running the
linter against itself; `markdownlint-cli` was upgraded from the pinned `0.48.0` to the
latest `0.49.1` in `package.json`, `package-lock.json`, and the warning string in
`tools/Invoke-MarkdownLint.ps1`, with `node_modules` installed locally in this worktree
(0 vulnerabilities); and `.gitignore` was extended beyond the initial `node_modules/`
entry to cover OS cruft and — after tracing `Get-Location`/`$PWD`-based output paths in
`src/modules/wara/{wara.psm1,analyzer,reports}` — the timestamped WARA runtime-output
artifacts (`WARA-File-*.json`, `Expert-Analysis-v1-*.xlsx`,
`Assessment-Findings-Report-v1-*.xlsx`, `Executive Summary Presentation - *.pptx`,
`Impacted Resources and Recommendations Template *.csv`) those scripts can drop into
whatever directory they're invoked from.

**Gap against desired outcome:** these three fixes are already applied in the working
tree; no further change needed here, only inclusion in whatever commit(s) Phase B
defines.

### A6. No documentation of the workflow itself exists anywhere

Beyond the prompt files' own front-matter `description:` fields and inline prose (which
target Copilot Chat execution, not human onboarding), there is no README section,
CONTRIBUTING doc, or `docs/main` page that explains the raise → investigate → plan →
implement → release lifecycle, the label taxonomy, the `docs/main` convention, or how
the worktree-per-stage model (`C:\wt\wara\<stage>\...`) works for a contributor
encountering this for the first time. `README.md`'s only change in this session was
markdownlint prose fixes unrelated to the workflow.

**Gap against desired outcome:** this is the one gap the user explicitly flagged as
still open — some documentation artifact describing this tooling needs to be written
and land somewhere (exact location and form is a Phase B decision).

### A7. Open questions for Phase B

1. What commit strategy should land the 20 uncommitted files from A1 — one chore
   commit, or split by concern (prompts / tools / config / package.json)? Does
   `COMMIT_GUIDELINES.md`'s own format apply to the commit(s) that introduce it?
2. Should the label reconciliation from A2 be captured as a checked-in, re-runnable
   artifact (e.g. a label-definitions file/script), or is the current live GitHub
   state sufficient with no repo-tracked record?
3. How should the GH Project status field gap from A3 be resolved — add
   `releasing`/`superseded` options to the live field, or explicitly scope
   `status:releasing`/`status:superseded` out of project-board automation for now?
4. What commit sequence resolves the `docs/main` bootstrap problem from A4 — does the
   initial `docs/main` commit (README + `.gitkeep`) need to land *before* this issue's
   own investigation doc, as a separate prerequisite step outside this issue's scope,
   or as part of Step 4 of this very investigation?
5. Where should the workflow documentation from A6 live, and how much detail does it
   need — a new top-level doc, a `README.md` section, a `CONTRIBUTING.md`, or a
   `docs/main` page alongside the issue docs it governs?

## Phase B — Approach decisions

### B1. Commit strategy for the ported tooling (resolves A7.1)

**Decision:** Split into four commits by concern, landed in this order: (1) config —
`config/settings.json`, `config/issue-priority-weights.json`,
`config/PSScriptAnalyzerSettings.psd1`; (2) tools — the 7 scripts in `tools/`; (3)
prompts — the 8 prompt files plus `.github/COMMIT_GUIDELINES.md`; (4) tooling
infra — `package.json`, `package-lock.json`, `.gitignore`, `.markdownlint.json`,
`.markdownlint-cli2.jsonc`, `wara-0001.code-workspace`, and the `README.md` prose
fixes. `COMMIT_GUIDELINES.md`'s own format applies starting with commit 1 — it
describes the convention, not a one-time exemption for its own introduction. These
four commits are created in the **implement** worktree, not here — investigation is
observation-only by design (see C1), so the working-tree changes already present in
this investigate worktree are carried forward via stash push/pop through plan and
into implement, where they are finally committed in this order.

**Rationale:** Config, tools, and prompts have different reviewers in practice
(config is data, tools are executable logic, prompts are process/workflow text), and
splitting by concern keeps each commit's diff reviewable in isolation. Ordering
config → tools → prompts follows the dependency direction: tools read config at
runtime, and prompts invoke tools — landing dependencies first means each commit
stands on top of code that already exists.

**Alternatives considered:** A single "chore: port issue-lifecycle tooling" commit
was rejected — 20 files spanning prompts, tools, and config in one diff is hard to
review meaningfully, and a future `git revert` or `git bisect` on just the tooling
infra (e.g. the markdownlint-cli2 migration) would drag in unrelated prompt-file
changes. Splitting by individual file was also rejected as too granular — the
prompts and tools are only meaningful as a working set, not file-by-file.

### B2. Label taxonomy — no new artifact, defer to a follow-up issue (resolves A7.2)

**Decision:** Do not create a label-definitions file or script as part of this issue.
Record the current 34-label taxonomy (name, color, description) as a fixed reference
table in this issue's Phase D file-in-scope notes, and open a follow-up issue titled
something like "chore: add re-runnable label sync artifact" scoped separately.

**Rationale:** This issue's problem statement is porting the *workflow tooling*
(prompts, scripts, config), not building a labels-as-code system. Live GitHub label
state is already reconciled and verified against every prompt/tool reference — adding
a re-runnable sync mechanism (e.g. a `gh label create` script driven by a JSON
manifest) is a reasonable idea but is net-new tooling, not a port, and would expand
this issue's scope materially.

**Alternatives considered:** Building a `config/labels.json` + sync script now was
considered but rejected as scope creep for a porting/chore issue; the reconciliation
work already done is preserved as a reviewable table in the doc even without a
script, so nothing is lost by deferring the automation.

### B3. GH Project status field gap — scope `releasing`/`superseded` out of project-board automation (resolves A7.3)

**Decision:** Do not add `releasing` or `superseded` options to the live GH Project
status field in this issue. Explicitly document in Phase D that project-board
automation only drives the 9 existing options, and that `status:releasing` /
`status:superseded` are label-only states with no project-board mirror until a
future issue extends the field.

**Rationale:** No prompt file currently transitions the project board to
`releasing` or `superseded` (confirmed in A3), so there is no active breakage to
fix — this is a latent gap, not a live bug. Modifying a live GH Project field's
option set is an action outside repo version control (no config file drives it),
so making that change now, disconnected from any prompt that would exercise it,
adds risk without immediate benefit.

**Alternatives considered:** Adding the two missing options immediately was
considered — it's a small, reversible GH UI action — but rejected for this issue
specifically because nothing in the ported tooling references them yet; bundling an
unrelated project-board schema change into a tooling-port issue would blur the
issue's scope and its Phase D file-in-scope table (project-board options aren't a
repo file at all).

### B4. `docs/main` bootstrap sequencing — initial commit lands as part of this issue's Step 4 (resolves A7.4)

**Decision:** The `docs/main` initial commit (the existing untracked `README.md` and
`issues/backlog/.gitkeep`) lands in the *same* `git push` as this investigation
doc's commit in Step 4 — not as a separate prerequisite issue, and not before this
doc is written. Step 4 will run `git add` against both the bootstrap files and the
investigation doc, in one commit, before the first `docs/main` push.

**Rationale:** `docs/main` cannot be pushed empty-then-appended in a meaningfully
separate step — there is nothing on the branch yet, so "bootstrap first, doc
second" would just be two commits in immediate succession with no intervening
review opportunity. Folding the bootstrap into this issue's own Step 4 keeps the
dependency explicit: this is the issue whose investigation *depends on* `docs/main`
existing, so it is the natural place to create it.

**Alternatives considered:** A separate zero-content "bootstrap docs/main" issue
was considered but rejected as unnecessary process overhead for a two-file, one-time
initialization that only this issue currently needs.

### B5. Workflow documentation location and depth (resolves A7.5)

**Decision:** Add a new `## Issue lifecycle workflow` section to the root
`README.md`, covering: the five stages (raise → investigate → plan → implement →
release) and their `status:*` labels, the worktree-per-stage model
(`C:\wt\wara\<stage>\...` and `docs/main` at `C:\wt\wara\docs`), and a pointer to
`.github/prompts/*.prompt.md` as the source of truth for exact steps. Target length:
roughly half a page — a map for a new contributor, not a duplicate of the prompt
files' own detail.

**Rationale:** `README.md` is the first file a contributor opens, and the lifecycle
tooling is now a core part of how work moves through this repo, not a peripheral
concern deserving a separate `CONTRIBUTING.md`. Keeping it short and pointing to the
prompt files as source of truth avoids the two drifting out of sync — the prompt
files already contain the authoritative step-by-step detail (labels, commands,
gates), so the README's job is orientation, not duplication.

**Alternatives considered:** A dedicated `CONTRIBUTING.md` was considered but
rejected — this repo has no existing `CONTRIBUTING.md`, and introducing one for a
single section is disproportionate. A `docs/main` page was also considered but
rejected: `docs/main` is scoped to per-issue investigation/plan docs (per A4/A6),
not general contributor-facing documentation, and a contributor deciding whether to
raise an issue in the first place wouldn't think to look there first.

## Phase C — Risks and prerequisites

### C1. The 20 ported files sitting in this investigate worktree will not automatically reach the plan/implement worktrees

**Mechanism:** `tools/New-IssueWorktree.ps1` creates every new stage worktree with
`git worktree add $worktreePath -b $branchName HEAD` — a fresh branch cut from
whatever branch `HEAD` resolves to *at the moment that command runs*, not from this
investigate branch. `approve-ready-for-plan` (and, by the same pattern,
`approve-ready-for-implement`) is required to run from the **release worktree**
(`C:\wt\wara\release\<release>`, branch `release/*`) — confirmed in
`.github/prompts/approve-ready-for-plan.prompt.md` Step 0. So each new stage
worktree branches off `release/20260910`'s current tip, with none of this
investigate worktree's working-tree changes present. This is intentional, not an
oversight: the lifecycle's own protection model requires investigation to be
observation-only (per this prompt's golden rule), so the design does not allow — and
must not be made to allow — code changes to reach `release/20260910` directly out of
an investigate worktree.

**Mitigation:** Carry the working-tree changes forward by hand across stage
boundaries rather than committing them early: `git stash push -u` in this
investigate worktree before transitioning, create the plan worktree via
`approve-ready-for-plan` → `New-IssueWorktree.ps1 -Stage plan`, then `git stash pop`
there (stashes are stored in the shared object database, so they're visible across
worktrees of the same repository). Repeat the same push/pop pair moving from the
plan worktree into the implement worktree. The four B1 commits are made only once,
in the implement worktree, where committing code is the expected activity — never in
investigate or plan.

### C2. First-ever push to `docs/main` may hit branch protection or remote rules not yet exercised

**Mechanism:** `docs/main` has never been pushed (A4) — this issue's Step 4 will be
the first `git push origin docs/main` this repo has ever executed for this branch
name. If the remote has branch-protection rules requiring pull requests on all
branches, or a ruleset matching `main`-suffixed branch names, the direct push could
be rejected, which Step 4 does not currently handle (no fallback to opening a PR).

**Mitigation:** Before running Step 4, check
`gh api repos/drmssst/Well-Architected-Reliability-Assessment/branches/docs%2Fmain/protection`
(expect 404 if unprotected) or `gh repo view --json ...` for org-wide rulesets. If a
push is rejected, the fallback is to open a PR for this one branch instead of a
direct push — this doc's Step 4 instructions would need a documented exception.

### C3. Deferred GH Project options (B3) will silently no-op if a future prompt ever targets them

**Mechanism:** `gh project item-edit --single-select-option-id` requires a valid
option ID for the target field. If a future prompt is authored assuming
`status:releasing`/`status:superseded` have project-board mirrors (since those
labels already exist), the option ID lookup in `tools/Get-GhProjectConstants.ps1`
would return nothing for those two states, and the `item-edit` call would either
error or silently fail depending on how the calling prompt handles a missing ID.

**Mitigation:** This is a latent risk, not a live one — no current prompt exercises
either state (confirmed in A3). Whoever authors a future prompt touching
`releasing`/`superseded` project-board transitions must add the two options to the
live field first and update `config/settings.json`'s `statusOptions` to match, or
explicitly guard against a missing option ID.

### C4. Pinned `markdownlint-cli2`/`smol-toml` versions will drift out of date without a recurring check

**Mechanism:** `package.json` pins `markdownlint-cli2` to an exact version
(`0.23.2`, no semver range) and forces `smol-toml` to `1.8.0` via `overrides` to
close a specific advisory found during this session. Neither pin auto-updates;
a *new* advisory in either package (or a dependency introduced by a future
`markdownlint-cli2` release) would not be caught until someone manually re-runs
`npm audit`.

**Mitigation:** No action needed as part of this issue — `npm audit` currently
reports 0 vulnerabilities. This is ordinary dependency-maintenance risk, not
specific to the port; noted here so it isn't mistaken for a new gap introduced by
this issue if it resurfaces later.

### C5. Hardcoded absolute worktree paths assume a single-contributor, single-machine setup

**Mechanism:** Every prompt file's pre-flight check hardcodes `C:\wt\wara\<stage>\
issue-<N>` and `C:\wt\wara\docs\issues` (Windows-specific absolute paths, not
derived from a repo-relative or environment-variable base). This works for the
current solo-maintainer usage this port was built for, but would not work
unmodified for another contributor with a different worktree root, nor
cross-platform (macOS/Linux paths).

**Mitigation:** No change needed for this issue — flagged as a known, accepted
limitation of the ported-as-is tooling. Parameterizing the worktree root (e.g. an
environment variable or repo-local config default) would be a reasonable follow-up
if/when a second contributor or machine is onboarded, but is out of scope for a
straight port.

### C6. Sequential multi-commit landing (B1) creating a broken intermediate state — false alarm

**Mechanism considered:** Landing config, tools, prompts, and infra as four separate
commits could in principle leave the branch in a broken intermediate state between
commits (e.g., a prompt commit referencing a tool that doesn't exist yet).

**Conclusion:** Not a real risk here. B1's commit order (config → tools → prompts →
infra) already follows the dependency direction — tools read config, prompts invoke
tools — so every commit in the sequence only ever depends on files already landed
in an earlier commit. No mitigation needed beyond preserving that ordering when the
commits are actually made.

## Phase D — Ready-to-plan summary

### D1. Files in scope

| File | Group | Notes |
| --- | --- | --- |
| `config/settings.json` | config | GH Project constants; statusOptions has 9 of 11 status states (A3) |
| `config/issue-priority-weights.json` | config | scoring weights consumed by `Get-NextIssues.ps1` |
| `config/PSScriptAnalyzerSettings.psd1` | config | relocated from `src/tests/` this session (A5) |
| `tools/Get-GhProjectConstants.ps1` | tools | resolves project/field/option IDs |
| `tools/Get-NextIssues.ps1` | tools | priority-weighted backlog ordering |
| `tools/Add-SubIssue.ps1` | tools | sub-issue linking |
| `tools/New-IssueWorktree.ps1` | tools | per-stage worktree + workspace bootstrap |
| `tools/Invoke-MarkdownLint.ps1` | tools | markdown lint wrapper (migrated to `markdownlint-cli2` this session) |
| `tools/Invoke-Pester.ps1` | tools | Pester test runner wrapper |
| `tools/Invoke-PsScriptAnalyzer.ps1` | tools | PSScriptAnalyzer wrapper (path updated this session, A5) |
| `.github/prompts/raise-issue.prompt.md` | prompts | |
| `.github/prompts/investigate-issue.prompt.md` | prompts | this document's own source of process |
| `.github/prompts/plan-issue.prompt.md` | prompts | |
| `.github/prompts/implement-issue.prompt.md` | prompts | |
| `.github/prompts/approve-ready-for-plan.prompt.md` | prompts | |
| `.github/prompts/approve-ready-for-implement.prompt.md` | prompts | |
| `.github/prompts/approve-ready-for-release.prompt.md` | prompts | |
| `.github/prompts/groom-backlog.prompt.md` | prompts | |
| `.github/prompts/next-issues.prompt.md` | prompts | |
| `.github/COMMIT_GUIDELINES.md` | prompts | |
| `package.json` | infra | pins `markdownlint-cli2@0.23.2`, overrides `smol-toml@1.8.0` (this session) |
| `package-lock.json` | infra | |
| `.gitignore` | infra | node_modules, OS cruft, WARA runtime-output artifacts (A5) |
| `.markdownlint.json` | infra | shared rule config, extended by `.markdownlint-cli2.jsonc` |
| `.markdownlint-cli2.jsonc` | infra | new this session; replaces `.markdownlintignore` |
| `wara-0001.code-workspace` | infra | multi-root workspace definition |
| `README.md` | infra | markdownlint prose fixes; **new lifecycle section pending (B5)** |

`.markdownlintignore` was created and then deleted again within this session (superseded
by `.markdownlint-cli2.jsonc`) — it is not part of the final file set and is omitted
from this table.

### D2. Label taxonomy reference (from A2/B2)

Recorded here as the fixed reference table B2 calls for, since no repo-tracked
artifact holds it. All 34 labels below are live on
`drmssst/Well-Architected-Reliability-Assessment` today:

| Name | Color | Description |
| --- | --- | --- |
| `awaiting-approval` | `eb8b34` | PR open; submitter done — waiting for approver to run approve prompt |
| `bug` | `d73a4a` | Something isn't working |
| `duplicate` | `cfd3d7` | This issue or pull request already exists |
| `enhancement` | `a2eeef` | New feature or request |
| `good first issue` | `7057ff` | Good for newcomers |
| `help wanted` | `008672` | Extra attention is needed |
| `implementing` | `1d76db` | Plan approved; coding in progress |
| `importance:high` | `B60205` | High impact on quality or correctness |
| `importance:low` | `0E8A16` | Low impact |
| `importance:medium` | `FBCA04` | Moderate impact |
| `invalid` | `e4e669` | This doesn't seem right |
| `project:1` | `8250df` | Tracked in GH Project 1 (WARA) |
| `question` | `d876e3` | Further information is requested |
| `released` | `cfd3d7` | Successfully merged from release into main |
| `roadmap` | `c2c2c2` | Future / aspirational |
| `status:implement` | `0052cc` | Idle: implementation plan committed and approved |
| `status:implementing` | `d93f0b` | Active: coding in progress |
| `status:investigate` | `ededed` | Idle: issue filed, not yet being investigated |
| `status:investigating` | `1d76db` | Active: investigation in progress |
| `status:plan` | `ededed` | Idle: investigation done, ready to write implementation plan |
| `status:planning` | `fbca04` | Active: implementation plan being written |
| `status:release` | `0e8a16` | Idle: merged to release branch, pending merge to main |
| `status:releasing` | `5319e7` | Active: release in progress |
| `status:shipped` | `006b75` | Idle: successfully merged to main and released |
| `status:superseded` | `c2c2c2` | Issue superseded by another issue or PR |
| `type:chore` | `a8a400` | Maintenance, cleanup, dead code removal |
| `type:docs` | `0075CA` | Documentation only |
| `type:feat` | `0e8a16` | New capability or feature |
| `type:fix` | `D73A4A` | Defect correction |
| `urgency:low` | `0E8A16` | Nice to have, no rush |
| `urgency:medium` | `FBCA04` | Address when convenient |
| `urgency:now` | `B60205` | Address immediately |
| `urgency:soon` | `D93F0B` | Address in next cycle |
| `wontfix` | `ededed` | This will not be worked on |

### D3. Decisions deferred to planning

- **Integration branch confirmation (C1):** verify whether `release/20260910` or
  `main` is the correct target for the four B1 commits before the first
  `git stash pop` in the implement worktree — Phase B assumed `release/20260910` per
  the milestone, but plan phase should confirm against the standing branching model.
- **Branch-protection check (C2):** run the `gh api .../protection` check before
  Step 4's `docs/main` push; if protected, decide the PR fallback mechanics.
- **Label-sync follow-up issue (B2):** decide whether to open the "add re-runnable
  label sync artifact" follow-up issue now (during plan) or leave it for a later
  backlog grooming pass.
- **GH Project field extension (B3):** no action expected during plan/implement for
  this issue; revisit only if/when a future issue needs `releasing`/`superseded`
  project-board transitions.
- **README lifecycle section wording (B5):** plan phase should draft the actual
  section content (D1 flags `README.md` as having this pending); this doc only fixes
  its scope and target length, not its exact prose.

### D4. Recommended commit strategy

Two separate commit actions, in two different worktrees:

1. **This investigation doc + `docs/main` bootstrap** — one commit, made from the
   `docs/main` worktree as this prompt's own Step 4 (`README.md` +
   `issues/backlog/.gitkeep` + this investigation doc), pushed to `origin docs/main`
   for the first time (see C2).
2. **The ported tooling itself** — four commits (config → tools → prompts → infra,
   per B1), made in the **implement** worktree after carrying the working-tree
   changes forward from this investigate worktree via `git stash push -u` /
   `git stash pop` through the plan worktree and into implement (per C1). Not made
   here, and not made during plan.

### D5. Are new tests required?

No Pester tests currently reference any of the 7 ported `tools/*.ps1` scripts
(confirmed — no matches in `src/tests/`), and none existed for them in the source
port either. Recommend **not** requiring new tests as a condition of this issue: most
of these scripts are thin wrappers around `gh`/`git`/external processes whose value
lies in exercising the real CLI, not mockable pure logic. The one exception worth a
future look is `tools/Get-NextIssues.ps1`'s priority-weight scoring (reads
`config/issue-priority-weights.json` and produces an ordering) — that is pure
computation and would be cheap to unit test, but adding it here would expand a
porting/chore issue into new test-authoring work. Defer to a follow-up issue if
test coverage for that scoring logic is wanted.

### Sizing estimate

**Estimate:** M

| Driver | Weight | Reasoning |
| --- | --- | --- |
| Stash push/pop carry-forward across two worktree boundaries (C1) | High | Order-sensitive, manual, no tooling support today; a missed step silently drops files rather than erroring |
| `docs/main` first-ever push (C2) | Medium | Branch-protection status unverified; may require an unplanned PR fallback |
| Four-commit split of already-existing files (B1) | Low | Files are already written and reviewed this session; this is mechanical grouping, not new code |
| README lifecycle section authoring (B5) | Medium | Net-new prose; needs to stay accurate without duplicating the prompt files |
| Label/GH Project state (A2/A3/B2/B3) | Low | Already fully reconciled and verified this session; only recording as reference tables remains |

**Primary uncertainty drivers:**

- Whether `release/20260910` or `main` is confirmed as the correct integration
  branch before implement-stage commits are pushed.
- Whether the `docs/main` push hits branch protection, requiring a PR-based
  fallback not currently documented in Step 4.
- Whether the plan → implement stash pop encounters conflicts against a moving
  `release/20260910` tip.

*Upgrade to the next size if the `docs/main` push is blocked and requires a
PR-based fallback to be designed, or if the stash carry-forward hits conflicts
that require manual resolution rather than a clean pop.*
