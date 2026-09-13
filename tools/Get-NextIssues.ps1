[CmdletBinding()]
param(
    [int]$Top = 5,
    [string[]]$IncludeStatuses = @('status:investigate', 'status:plan', 'status:planning', 'status:implement', 'status:investigating'),
    [switch]$ExcludeInProgress,
    [ValidateSet('table', 'json', 'markdown')]
    [string]$Output = 'table',
    [string]$RepoOwner,
    [string]$RepoName,
    [string]$Milestone = (git branch --show-current),
    [string]$WeightsPath = 'config/issue-priority-weights.json',
    [switch]$Reorder,
    [string]$ProjectOwner = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LabelScore {
    param(
        [hashtable]$Map,
        [string]$Key
    )

    if ($Key -and $Map.ContainsKey($Key)) {
        return [int]$Map[$Key]
    }

    return [int]$Map['default']
}

function Get-FirstLabelByPattern {
    param(
        [string[]]$Labels,
        [string]$Pattern
    )

    return ($Labels | Where-Object { $_ -like $Pattern } | Select-Object -First 1)
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required but was not found on PATH.'
}

if (-not (Test-Path -Path $WeightsPath -PathType Leaf)) {
    throw "Weights file not found: $WeightsPath"
}

$weights = Get-Content -Path $WeightsPath -Raw | ConvertFrom-Json -AsHashtable

$repoArgs = @()
if ($RepoOwner -and $RepoName) {
    $repoArgs = @('--repo', "$RepoOwner/$RepoName")
}

$milestoneArgs = @()
if ($Milestone) {
    $milestoneArgs = @('--milestone', $Milestone)
}

$allIssues = gh issue list --state open --limit 300 --json number,title,labels,body @repoArgs @milestoneArgs | ConvertFrom-Json

$ranked = foreach ($issue in $allIssues) {
    $labels = @($issue.labels | ForEach-Object { $_.name })
    $status = Get-FirstLabelByPattern -Labels $labels -Pattern 'status:*'

    if (-not $status) { continue }
    if ($IncludeStatuses -notcontains $status) { continue }
    if ($ExcludeInProgress -and $status -eq 'status:implementing') { continue }

    $urgency = Get-FirstLabelByPattern -Labels $labels -Pattern 'urgency:*'
    $importance = Get-FirstLabelByPattern -Labels $labels -Pattern 'importance:*'

    $urgencyScore = Get-LabelScore -Map $weights.urgency -Key $urgency
    $importanceScore = Get-LabelScore -Map $weights.importance -Key $importance
    $stageScore = Get-LabelScore -Map $weights.stage -Key $status

    $dependencyDelta = 0
    $body = [string]$issue.body
    if ($body -match $weights.dependencyPenaltyPattern) {
        $dependencyDelta -= [int]$weights.dependencyPenalty
    }
    if ($body -match $weights.dependencyBonusPattern) {
        $dependencyDelta += [int]$weights.dependencyBonus
    }

    $wipDelta = 0
    if ($status -eq 'status:implementing') {
        $wipDelta -= [int]$weights.wipPenaltyImplementing
    }
    if ($status -eq 'status:investigate') {
        $wipDelta += [int]$weights.wipBonusInvestigate
    }

    $score = $urgencyScore + $importanceScore + $stageScore + $dependencyDelta + $wipDelta

    [pscustomobject]@{
        Issue = [int]$issue.number
        Title = [string]$issue.title
        Status = [string]$status
        Urgency = [string]$urgency
        Importance = [string]$importance
        Score = [int]$score
        Breakdown = "urg=$urgencyScore imp=$importanceScore stage=$stageScore dep=$dependencyDelta wip=$wipDelta"
    }
}

$topIssues = $ranked |
    Sort-Object -Property @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'Issue'; Descending = $false } |
    Select-Object -First $Top

switch ($Output) {
    'json' {
        $topIssues | ConvertTo-Json -Depth 4
        break
    }
    'markdown' {
        "| Issue | Score | Status | Urgency | Importance | Title |"
        "| --- | ---: | --- | --- | --- | --- |"
        foreach ($row in $topIssues) {
            "| #$($row.Issue) | $($row.Score) | $($row.Status) | $($row.Urgency) | $($row.Importance) | $($row.Title) |"
        }
        break
    }
    default {
        $topIssues | Format-Table Issue, Status, Title -AutoSize -Wrap
        break
    }
}

if ($Reorder) {
    $owner = if ($ProjectOwner) { $ProjectOwner } else {
        gh repo view --json owner --jq '.owner.login'
    }

    $projectList = gh project list --owner $owner --limit 20 --format json | ConvertFrom-Json
    $project = $projectList.projects | Select-Object -First 1
    $projectId = [string]$project.id
    $projectNumber = [int]$project.number

    $projectItems = gh project item-list $projectNumber --owner $owner --limit 200 --format json |
        ConvertFrom-Json | Select-Object -ExpandProperty items

    $itemIdMap = @{}
    foreach ($item in $projectItems) {
        if ($null -ne $item.content -and $item.content.PSObject.Properties['number']) {
            $itemIdMap[[int]$item.content.number] = [string]$item.id
        }
    }

    # Iterate in reverse order — move each to top so rank-1 ends up at position 1
    [array]$issueNumbers = @($topIssues | ForEach-Object { $_.Issue })
    [array]::Reverse($issueNumbers)

    foreach ($issueNum in $issueNumbers) {
        if (-not $itemIdMap.ContainsKey($issueNum)) {
            Write-Warning "Issue #$issueNum not found in project — skipping"
            continue
        }
        gh api graphql `
            -f query='mutation($pid:ID!,$iid:ID!){updateProjectV2ItemPosition(input:{projectId:$pid,itemId:$iid}){clientMutationId}}' `
            -f pid=$projectId `
            -f iid=$($itemIdMap[$issueNum]) | Out-Null
        Write-Verbose "  Moved #$issueNum"
    }

    Write-Information "Board reordered — top $($topIssues.Count) issues now match ranking." -InformationAction Continue
}
