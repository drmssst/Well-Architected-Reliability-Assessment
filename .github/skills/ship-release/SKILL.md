---
name: ship-release
description: Ships a release. Brings the release branch into main, tags main with the fork version, moves every issue in the release milestone to status:shipped on the project board, closes the milestone, deletes the merged release branch and updates FORK.md. Run from the release workspace after every PR for the release has merged into the release branch.
disable-model-invocation: true
argument-hint: "Release branch (e.g. /ship-release release/20260910)"
---
# Ship Release Workflow

Run this after every PR for the release has merged into `release/YYYYMMDD` and
validation is complete. It is the step that turns `status:release` into
`status:shipped`. Nothing else in the lifecycle does that.

**Release branch:** extract from the argument (for example `/ship-release release/20260910`).
If none was given, ask: "Which release branch should I ship?"

Never force-push and never delete a branch that is not fully contained in `main`.

---

## Step 0 — Pre-flight

```powershell
git branch --show-current
git status --short
gh repo view --json nameWithOwner --jq '.nameWithOwner'
```

- The release branch must exist on the remote and the working tree must be clean.
- If `gh repo view` cannot resolve the repository, the active `gh` account is the wrong one. Use the
  repository owner's token for the commands below, without switching the active account:

```powershell
$env:GH_TOKEN = (gh auth token --user drmssst)
```

Set `$release` to the branch name and `$repo` to `owner/name` for the steps below.

---

## Step 1 — Inventory the milestone

```powershell
gh issue list --milestone $release --state all --limit 200 `
  --json number,title,state,labels |
  ConvertFrom-Json |
  ForEach-Object { [pscustomobject]@{ N = $_.number; State = $_.state; Labels = ($_.labels.name -join ','); Title = $_.title } } |
  Format-Table -AutoSize
```

Present the table. Every issue should carry `status:release`.

**Stop and ask** if any issue in the milestone does not carry `status:release`: its work has not
reached the release branch, so it should not ship. Offer to move it to the Backlog milestone first.

---

## Step 2 — Check the release branch against main

```powershell
gh api "repos/$repo/compare/main...$([uri]::EscapeDataString($release))" --jq '{status, ahead_by, behind_by}'
```

- `ahead` — `main` has nothing the release branch lacks, so `main` can be fast-forwarded. Proceed.
- `diverged` — `main` has commits the release branch lacks. Merge with a pull request and a merge
  commit instead of a fast-forward, or stop and ask how to reconcile.
- `identical` or `behind` — nothing to ship. Stop.

Ask: **"Bring `<release>` into `main`?"** Do not proceed until the user confirms.

---

## Step 3 — Update main

Fast-forward, without force. GitHub rejects the update if it is not a fast-forward:

```powershell
$sha = gh api "repos/$repo/git/ref/heads/$([uri]::EscapeDataString($release))" --jq .object.sha
gh api -X PATCH "repos/$repo/git/refs/heads/main" -f sha=$sha -F force=false --jq '.ref + " -> " + .object.sha'
```

For a diverged branch, open a PR into `main` and merge it with `gh pr merge <n> --merge`.

---

## Step 4 — Tag main

Fork versions are `<upstream version>-eoa.<N>`, tags are `v<version>`. Read the current state
from `FORK.md`:

```powershell
git fetch --tags origin
gh api "repos/$repo/git/matching-refs/tags/v" --jq '.[].ref' | Select-Object -Last 8
```

- Same upstream base: increment `N`.
- Rebased onto a new upstream release: the version becomes `<new upstream version>-eoa.1`.

Confirm the version, then create an annotated tag whose message lists the fork-only changes in
this release:

```powershell
$t = gh api -X POST "repos/$repo/git/tags" -f tag=$version -f message=$message -f object=$sha -f type=commit --jq .sha
gh api -X POST "repos/$repo/git/refs" -f ref="refs/tags/$version" -f sha=$t --jq .ref
```

Tags are hard to retract in a public repository. Do not push until the user confirms.

---

## Step 5 — Advance the issues

```powershell
$c = & tools/Get-GhProjectConstants.ps1
if ($c.owner -ne $repo.Split('/')[0]) { Write-Warning "Project owner [$($c.owner)] differs from repo owner — check config/settings.json before continuing." }

$items = gh project item-list $c.number --owner $c.owner --format json --limit 200 |
  ConvertFrom-Json | Select-Object -ExpandProperty items

foreach ($n in $issueNumbers) {
    gh issue edit $n --remove-label "status:release" --add-label "status:shipped"
    if ((gh issue view $n --json state --jq .state) -eq 'OPEN') { gh issue close $n --reason completed }

    $itemId = ($items | Where-Object { $_.content.number -eq $n }).id
    if ($itemId) {
        gh project item-edit --project-id $c.id --id $itemId `
          --field-id $c.statusFieldId `
          --single-select-option-id $c.statusOptions.shipped
    } else {
        Write-Warning "Issue #$n is not on the project board — skipped board update."
    }
}
```

---

## Step 6 — Close the milestone

```powershell
$ms = gh api "repos/$repo/milestones?state=all" --jq ".[] | select(.title == `"$release`") | .number"
gh api -X PATCH "repos/$repo/milestones/$ms" -f state=closed --jq '"\(.title) \(.state)"'
```

---

## Step 7 — Delete the merged release branch

A merged release branch is dead. Verify before deleting:

```powershell
gh api "repos/$repo/compare/main...$([uri]::EscapeDataString($release))" --jq .status   # must be 'behind' or 'identical'
gh api "repos/$repo/git/ref/tags/$version" --jq .ref                                    # the tag must exist
```

If either check fails, **stop**. Otherwise:

```powershell
gh api -X DELETE "repos/$repo/git/refs/heads/$([uri]::EscapeDataString($release))"
$wt = git worktree list | Select-String ([regex]::Escape($release))
if ($wt) { git worktree remove (($wt.Line -split '\s+')[0]) --force }
git worktree prune
git branch -D $release 2>$null
git fetch --prune
```

---

## Step 8 — Update FORK.md

Add the new tag to the version table and its fork-only changes to the change list, on a branch
off `main`, through a normal PR. This lands after the tag, so the tagged commit is unchanged.

Consumers vendor from a tag, never from a branch. There is no build artifact.

---

## Step 9 — Verify and report

```powershell
foreach ($n in $issueNumbers) { "#$n " + (gh issue view $n --json labels --jq '[.labels[].name] | join(",")') }
gh api "repos/$repo/milestones/$ms" --jq '.state'
gh api "repos/$repo/branches" --jq '.[].name'
```

Report:

> Release **`<release>`** shipped as **`<version>`**.
>
> | Item | Result |
> | --- | --- |
> | Issues | N moved to `status:shipped` on the board |
> | Milestone | `<release>` closed |
> | Release branch | deleted (contained in `main`, tag `<version>`) |
> | FORK.md | updated via PR #M |

---

## Notes

- When passing a multi-line body to `gh`, use `--body-file -` with stdin. A multi-line string
  passed to `--body` is split into arguments by PowerShell.
- Run from the release workspace, not from an implementation worktree.
