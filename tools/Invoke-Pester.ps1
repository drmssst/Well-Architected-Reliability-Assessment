#Requires -Version 7.5
#Requires -Modules @{ModuleName='Pester'; ModuleVersion='5.0.0'}
<#
.SYNOPSIS
    Runs the Pester test suite and prints a fixed-format summary that is easy
    to parse from both the terminal and automated tooling.
.DESCRIPTION
    Thin wrapper around Invoke-Pester that:
      - Uses Pester's Detailed output so every test result is visible
      - Exits with code 0 only when Failed = 0
      - Prints a compact SUMMARY block at the end with counts that can be
        reliably grepped regardless of Pester version output width
.PARAMETER Path
    One or more paths to test files or directories.  Defaults to
    src/tests/ relative to the repo root.
.PARAMETER Tag
    Optional Pester tag(s) to filter which tests run.
.EXAMPLE
    tools/Invoke-Pester.ps1
.EXAMPLE
    tools/Invoke-Pester.ps1 src/tests/wara/wara.tests.ps1
.EXAMPLE
    tools/Invoke-Pester.ps1 -Tag unit
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]] $Path,

    [string[]] $Tag
)

$repoRoot = Join-Path -Path $PSScriptRoot -ChildPath '..'

if (-not $Path) {
    $Path = @((Join-Path -Path $repoRoot -ChildPath 'src' -AdditionalChildPath 'tests'))
}

$cfg = New-PesterConfiguration
$cfg.Run.Path      = $Path
$cfg.Output.Verbosity = 'Detailed'
$cfg.Run.PassThru = $true

if ($Tag) {
    $cfg.Filter.Tag = $Tag
}

$result = Invoke-Pester -Configuration $cfg

# Always print a deterministic summary block — easy to locate in large output
Write-Host ''
Write-Host '========================================='
Write-Host 'PESTER SUMMARY'
Write-Host "  Passed  : $($result.PassedCount)"
Write-Host "  Failed  : $($result.FailedCount)"
Write-Host "  Skipped : $($result.SkippedCount)"
Write-Host "  Total   : $($result.TotalCount)"
Write-Host "  Result  : $($result.Result)"
Write-Host '========================================='

if ($result.FailedCount -gt 0) {
    Write-Host ''
    Write-Host 'FAILED TESTS:'
    foreach ($t in $result.Failed) {
        Write-Host "  [-] $($t.ExpandedName)"
        Write-Host "      $($t.ErrorRecord.Exception.Message)"
    }
    Write-Host ''
}

exit ($result.FailedCount -gt 0 ? 1 : 0)
