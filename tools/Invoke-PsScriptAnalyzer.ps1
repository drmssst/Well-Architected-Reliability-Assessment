#Requires -Version 7.5
<#
.SYNOPSIS
    Lints one or more PowerShell files and returns a non-zero exit code if any
    violations are found.
.DESCRIPTION
    Thin wrapper around Invoke-ScriptAnalyzer so that callers (prompts, scripts,
    CI) are decoupled from the underlying implementation. Uses the project
    PSScriptAnalyzer settings at config/PSScriptAnalyzerSettings.psd1.

    Real-time background analysis is disabled in .vscode/settings.json
    (powershell.scriptAnalysis.enable = false) to eliminate false-positive errors
    from stale Copilot Chat editing buffers. Run this wrapper explicitly before
    committing instead.
.PARAMETER Path
    One or more paths to PowerShell files or directories. Relative paths are
    resolved from the current working directory.
.EXAMPLE
    tools/Invoke-PsScriptAnalyzer.ps1 scripts/run.ps1
.EXAMPLE
    tools/Invoke-PsScriptAnalyzer.ps1 scripts tools
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
    [string[]] $Path
)

$settingsPath = Join-Path -Path $PSScriptRoot -ChildPath '../config/PSScriptAnalyzerSettings.psd1'

$requiredVersion = (Get-Content (Join-Path -Path $PSScriptRoot -ChildPath '../config/settings.json') -Raw |
    ConvertFrom-Json).devTools.psScriptAnalyzerVersion

$installed = Get-Module -Name PSScriptAnalyzer -ListAvailable |
    Where-Object { $_.Version -eq [version] $requiredVersion } |
    Select-Object -First 1

if (-not $installed) {
    $any = Get-Module -Name PSScriptAnalyzer -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    $hint = if ($any) { "found $($any.Version) — install the pinned version: Install-Module PSScriptAnalyzer -RequiredVersion $requiredVersion" } `
            else      { "not installed — run: Install-Module PSScriptAnalyzer -RequiredVersion $requiredVersion" }
    Write-Warning "PSScriptAnalyzer $requiredVersion required; $hint"
    exit 1
}

$results = @()
foreach ($p in $Path) {
    $resolved = Resolve-Path $p -ErrorAction SilentlyContinue
    if (-not $resolved) { Write-Warning "Path not found: $p"; continue }
    $results += Invoke-ScriptAnalyzer -Path $resolved.Path -Settings $settingsPath -Recurse
}

if ($results.Count -gt 0) {
    $results | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize
    exit 1
}

exit 0
