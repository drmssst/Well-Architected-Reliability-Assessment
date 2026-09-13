<#
.SYNOPSIS
    Returns GitHub project constants from config/settings.json.
.DESCRIPTION
    Reads the github.project block from config/settings.json and returns
    a structured object with the project number, IDs, and status option IDs.
    All prompts use this script to avoid hardcoding opaque GH API strings.
.OUTPUTS
    PSCustomObject with properties: number, owner, id, statusFieldId, statusOptions
.EXAMPLE
    $c = & tools/Get-GhProjectConstants.ps1
    gh project item-edit --project-id $c.id --field-id $c.statusFieldId `
        --single-select-option-id $c.statusOptions.implementing
#>
[CmdletBinding()]
param(
    [string] $SettingsPath = (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'config' | Join-Path -ChildPath 'settings.json')
)

$resolved = Resolve-Path $SettingsPath -ErrorAction Stop
$settings = Get-Content $resolved -Raw | ConvertFrom-Json
$settings.github.project
