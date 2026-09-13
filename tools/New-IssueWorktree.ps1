<#
.SYNOPSIS
    Creates a per-stage Git worktree for an issue, generates a disposable multi-root
    workspace (issue worktree + issues + test data root), then opens it in VS Code.
    Idempotent: if the worktree already exists, skips creation and refreshes the
    workspace file.

.PARAMETER Stage
    Lifecycle stage prefix: raise, investigate, plan, or implement.

.PARAMETER Issue
    GitHub issue number.

.PARAMETER Slug
    Short kebab-case slug (e.g. "split-next-steps"). Required when creating a new
    worktree; ignored if the worktree already exists.

.PARAMETER WorktreeRoot
    Root directory containing per-stage worktrees (default: C:\wt\wara).

.PARAMETER TestRoot
    Shared manual-testing data root to include as the second workspace folder
    (default: C:\tb\wara_tb).

.PARAMETER WorkspaceFileName
    Name of the disposable workspace file written inside the issue worktree.
    Default: wara-NNNN.code-workspace (zero-padded issue number).

.PARAMETER NoOpen
    Do not open VS Code when provided.

.PARAMETER NoNpmCi
    Skip npm install (markdownlint tooling) on first-time worktree creation.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Stage,
    [Parameter(Mandatory)] [int]    $Issue,
    [string] $Slug = '',
    # Branch prefix — defaults to Stage but can differ (e.g. Stage=implement, BranchPrefix=feature)
    [string] $BranchPrefix = $Stage,
    [string] $WorktreeRoot = 'C:\wt\wara',
    [string] $TestRoot = 'C:\tb\wara_tb',
    [string] $WorkspaceFileName = '',
    [string] $DocsIssuesPath = 'C:\wt\wara\docs\issues',
    [switch] $NoOpen,
    [switch] $NoNpmCi
)

$worktreePath = Join-Path (Join-Path $WorktreeRoot $Stage) "issue-$Issue"
$branchName = if ($Slug) { "$BranchPrefix/issue-$Issue-$Slug" } else { "$BranchPrefix/issue-$Issue" }
$issueTag = '{0:D4}' -f $Issue
if (-not $WorkspaceFileName) {
    $WorkspaceFileName = "wara-${issueTag}.code-workspace"
}
$workspacePath = Join-Path $worktreePath $WorkspaceFileName
$workspaceIssueFolderName = "wara-$issueTag"
$created = $false

if (Test-Path $worktreePath) {
    Write-Host "Worktree already exists: $worktreePath"
}
else {
    if (-not $Slug) {
        Write-Error '-Slug is required when creating a new worktree.'
        exit 1
    }
    git worktree add $worktreePath -b $branchName HEAD
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Worktree created: $worktreePath  (branch: $branchName)"
    $created = $true

    # Install node_modules required by Invoke-MarkdownLint.ps1
    if (-not $NoNpmCi) {
        & npm @('ci', '--prefix', $worktreePath)
    }
}

# Always refresh the workspace file so the window has deterministic folders/cwd.
$workspaceJson = @{
    folders  = @(
        @{ name = $workspaceIssueFolderName; path = '.' },
        @{ name = 'issues'; path = $DocsIssuesPath },
        @{ name = 'testbed'; path = $TestRoot }
    )
    settings = @{
        'terminal.integrated.cwd' = "`${workspaceFolder:$workspaceIssueFolderName}"
    }
}

$workspaceJson | ConvertTo-Json -Depth 6 | Set-Content -Path $workspacePath -Encoding UTF8

if (-not $NoOpen) {
    code --new-window $workspacePath
}

if ($created) {
    Write-Host "Bootstrap complete for new worktree." -ForegroundColor Green
}
else {
    Write-Host "Bootstrap complete for existing worktree." -ForegroundColor Green
}

Write-Host "Expected path: $worktreePath"
Write-Host "Workspace file: $workspacePath"
Write-Host "Test data root: $TestRoot"
