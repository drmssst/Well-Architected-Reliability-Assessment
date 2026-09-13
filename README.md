# Issue Documentation

Investigation and implementation-plan docs for issues live here, organized under
`issues/<release-folder>/`, where `<release-folder>` is `backlog` (for issues not
yet assigned to a release) or `release-YYYYMMDD` (matching a `release/YYYYMMDD` branch
and its GitHub milestone).

This branch (`docs/main`) is an orphan branch — it shares no commit history with `main`
or any `release/*` branch and never merges into either. It exists solely to hold these
docs long-term.

Doc commits are written directly to this branch (via a worktree checked out at
`C:\wt\wara\docs`) by the `investigate-issue`, `plan-issue`, and `implement-issue`
prompts, and referenced by the `approve-ready-for-plan`, `approve-ready-for-implement`,
and `approve-ready-for-release` quality-gate prompts.
