#Requires -Version 7.5
<#
.SYNOPSIS
    Lints one or more Markdown files and returns a non-zero exit code if any
    violations are found.
.DESCRIPTION
    Thin wrapper around the configured Markdown linting tool so that callers
    (prompts, scripts, CI) are decoupled from the underlying implementation.
    To swap linters, change only this file.
.PARAMETER Path
    One or more paths to Markdown files or glob patterns (e.g. 'docs/**/*.md').
    Relative paths are resolved from the current working directory.
.EXAMPLE
    tools/Invoke-MarkdownLint.ps1 docs/my-file.md
.EXAMPLE
    tools/Invoke-MarkdownLint.ps1 docs/**/*.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
    [string[]] $Path
)

$localCli = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'node_modules', '.bin', 'markdownlint-cli2.ps1'
if (Test-Path $localCli) {
    & $localCli @Path
}
else {
    Write-Warning "node_modules not found — run 'npm ci' from the repo root to install pinned markdownlint-cli2@0.23.2. Falling back to npx."
    npx markdownlint-cli2 @Path
}
exit $LASTEXITCODE