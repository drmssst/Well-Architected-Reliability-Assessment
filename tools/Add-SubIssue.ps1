#Requires -Version 7.5
<#
.SYNOPSIS
    Attaches one or more child issues as sub-issues of a parent issue on GitHub.
.DESCRIPTION
    Resolves each child issue's database ID via the GitHub API and links it to the
    parent using the /sub_issues endpoint. Requires `gh` CLI to be authenticated.
.PARAMETER Parent
    The issue number of the parent issue.
.PARAMETER Child
    One or more child issue numbers to attach to the parent.
.PARAMETER Repo
    The repository in OWNER/REPO format. Defaults to the current repo as reported
    by `gh repo view`.
.EXAMPLE
    tools/Add-SubIssue.ps1 -Parent 100 -Child 102
.EXAMPLE
    tools/Add-SubIssue.ps1 -Parent 100 -Child 102, 103, 104, 105
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [int] $Parent,

    [Parameter(Mandatory, Position = 1, ValueFromRemainingArguments)]
    [int[]] $Child,

    [Parameter()]
    [string] $Repo = (gh repo view --json nameWithOwner --jq '.nameWithOwner')
)

foreach ($childNumber in $Child) {
    $childId = gh api repos/$Repo/issues/$childNumber --jq '.id'
    if (-not $childId) {
        Write-Error "Could not resolve database ID for issue #$childNumber — skipping."
        continue
    }
    $json = "{`"sub_issue_id`": $childId}"
    $result = $json | gh api --method POST repos/$Repo/issues/$Parent/sub_issues --input - 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($result -match 'already') {
            Write-Information "#$childNumber is already a sub-issue of #$Parent — skipping." -InformationAction Continue
        }
        else {
            Write-Error "Failed to link #$childNumber to #$Parent`: $result"
        }
    }
    else {
        Write-Information "Linked #$childNumber as sub-issue of #$Parent" -InformationAction Continue
    }
}
