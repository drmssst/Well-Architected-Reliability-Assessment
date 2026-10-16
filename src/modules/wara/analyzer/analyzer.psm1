<#
.SYNOPSIS
Well-Architected Reliability Assessment Script

.DESCRIPTION
The function `Start-WARAAnalyzer` will process the JSON file created by the `Start-WARACollector` function and will create the core WARA Action Plan Excel file.

.PARAMETER Help
Switch to display help information.

.PARAMETER RepoUrl
Specifies the git repository URL that contains APRL contents if you want to use custom APRL repository.

.PARAMETER JSONFile
Path to the JSON file created by the "1_wara_collector" script.

.EXAMPLE
Start-WARAAnalyzer -JSONFile 'C:\Temp\WARA_File_2024-04-01_10_01.json' -Debug

.LINK
https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2
#>
function Start-WARAAnalyzer {
    [CmdletBinding()]
    param (
        [ValidatePattern('^https:\/\/.+$')]
        [string] $RecommendationDataUri = 'https://azure.github.io/WARA-Build/objects/recommendations.json',
        [string] $CustomRecommendationObject,
        [Parameter(mandatory = $true)]
        [string] $JSONFile,
        [string] $ExpertAnalysisFile
    )

    Write-Host 'Wrapping Analyzer' -ForegroundColor Cyan
    & "$PSScriptRoot/2_wara_data_analyzer.ps1" @PSBoundParameters
    Write-Host Analyzer Complete -ForegroundColor Cyan
}
