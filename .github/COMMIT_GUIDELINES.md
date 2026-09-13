# Commit Message Guidelines

All commits made through the issue-workflow prompts in this repo follow [Conventional
Commits](https://www.conventionalcommits.org/).

## Format

```text
<type>(#<issue>): <short imperative title>

- <area>: <what changed and why>
- <area>: <what changed and why>
- <N> new tests; <M> total — all passing
- <non-obvious design decision, if any>
```

A body is **required** when the commit touches source, schema, test, or script files.
For commits that only update planning or investigation docs, a one-line title is sufficient.

## Type

| Type | Use |
| --- | --- |
| `feat` | New capability visible to a consumer |
| `fix` | Bug correction |
| `refactor` | Restructure with no behaviour change |
| `test` | Test-only changes |
| `docs` | Documentation or investigation plan only |
| `chore` | Housekeeping — deps, tooling, prompt updates |

## Title line rules

- Imperative mood: "add X", not "added X" or "adds X"
- Under 72 characters including the type prefix
- No period at the end
- `(#N)` references the GitHub issue number

## Body rules

- Blank line between title and body
- One bullet per logical area changed: what changed and, where non-obvious, why
