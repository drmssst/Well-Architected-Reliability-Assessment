BeforeAll {
    $modulePath = "$PSScriptRoot/../../modules/wara/wara.psd1"
    Import-Module -Name $modulePath -Force
}

Describe 'Start-WARACollector Parameter Sets' {
    BeforeAll {

        Mock Start-WARACollector { return $null } -Verifiable -RemoveParameterValidation "TenantID", "SubscriptionIds", "ConfigFile", "ResourceGroups"
    }
    Context 'ConfigFile' {
        It 'Should proceed when used alone.' {
            $null = Start-WARACollector -ConfigFile "$PSScriptRoot/../data/wara/test_configfiledata.txt"
            Assert-MockCalled Start-WARACollector -Exactly 1 -Scope It
        }
    }
    Context 'ConfigFile + Specialized' {
        It 'Should proceed with ConfigFile + Specialized.' {
            $null = Start-WARACollector -ConfigFile "$PSScriptRoot/../data/wara/test_configfiledata.txt" -SAP -AVS -AVD -HPC -AI_GPT_RAG -ORACLE
            Assert-MockCalled Start-WARACollector -Exactly 1 -Scope It
        }
    }
    Context 'TenantId + SubscriptionIds' {
        It 'Should proceed with TenantId + SubscriptionIds' {
            $null = Start-WARACollector -TenantID $(New-Guid).Guid -SubscriptionIds '/subscriptions/11111111-1111-1111-111111111111'
            Assert-MockCalled Start-WARACollector -Exactly 1 -Scope It
        }
    }
    Context 'TenantId + SubscriptionIds + ResourceGroups' {
        It 'Should proceed with TenantId + SubscriptionIds + ResourceGroups' {
            $null = Start-WARACollector -TenantID $(New-Guid).Guid -SubscriptionIds '/subscriptions/11111111-1111-1111-111111111111' -ResourceGroups 'RG1'
            Assert-MockCalled Start-WARACollector -Exactly 1 -Scope It
        }
    }
    Context 'TenantId + SubscriptionIds + ResourceGroups + Specialized' {
        It 'Should proceed with TenantId + SubscriptionIds + ResourceGroups + Specialized' {
            $null = Start-WARACollector -TenantID $(New-Guid).Guid -SubscriptionIds '/subscriptions/11111111-1111-1111-111111111111' -ResourceGroups 'RG1' -SAP -AVS -AVD -HPC -AI_GPT_RAG -ORACLE
            Assert-MockCalled Start-WARACollector -Exactly 1 -Scope It
        }
    }
}

Describe 'Start-WARACollector' {
    Context 'When given the Default parameter set without SubscriptionIds and ResourceGroups' {
        It 'Should throw an exception with the specified message' {
            $scriptBlock = { Start-WARACollector -TenantID $(new-guid).guid }
            $scriptBlock | Should -Throw
        }
    }
    Context 'Default Parameter Set' {
        It 'Should throw an exception when TenantID is invalid GUID' {
            $scriptBlock = { Start-WARACollector -TenantID 'invalid-guid' -SubscriptionIds '/subscriptions/11111111-1111-1111-111111111111' }
            $scriptBlock | Should -Throw
        }

        It 'Should throw an exception when SubscriptionIds are invalid' {
            $scriptBlock = { Start-WARACollector -TenantID $(New-Guid).Guid -SubscriptionIds 'invalid-subscription-id' }
            $scriptBlock | Should -Throw
        }

    }
    Context 'ConfigFileSet Parameter Set' {
        It 'Should throw an exception when ConfigFile does not exist' {
            $scriptBlock = { Start-WARACollector -TenantID $(new-guid).guid -ConfigFile 'C:\invalid\path\config.json' }
            $scriptBlock | Should -Throw
        }
    }
    Context 'Different Parameter Sets' {
        It 'Should throw an exception when parameters from both sets are provided' {
            $scriptBlock = { Start-WARACollector -TenantID $(new-guid).guid -ConfigFile 'C:\invalid\path\config.json' -SubscriptionIds '/subscriptions/11111111-1111-1111-111111111111' }
            $scriptBlock | Should -Throw
        }
    }
    Context 'When given correct parameters with -passthru' {
        BeforeAll {
            $AllResources_TestData = get-content "$PSScriptRoot/../data/wara/test_allresourcesdata.json" -raw | ConvertFrom-Json -depth 20
            $QueryLoop_TestData = get-content "$PSScriptRoot/../data/wara/test_queryloopdata.json" -raw | ConvertFrom-Json -depth 20
            $AdvisorMeta_TestData = get-content "$PSScriptRoot/../data/wara/test_advisormetadata.json" -raw | ConvertFrom-Json -depth 20
            $RecommendationObject_TestData = get-content "$PSScriptRoot/../data/wara/test_recommendationobjectdata.json" -raw | ConvertFrom-Json -depth 20
            $RecommendationResourceTypes_TestData = get-content "$PSScriptRoot/../data/wara/test_recommendationresourcetypesdata.csv" -Raw
            $Advisor_TestData = get-content "$PSScriptRoot/../data/wara/test_advisordata.json" -raw | ConvertFrom-Json -depth 20
            $TaggedResourceGroup_TestData = @("/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-B1")
            $TaggedResource_TestData = @("/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-A1/providers/Microsoft.ApiManagement/service/apiService1")
            $Outage_TestData = get-content "$PSScriptRoot/../data/outage/restApiMultipleResponseData.json" -raw | ConvertFrom-Json -depth 20 | Select-Object Name, Properties
            $Retirement_TestData = get-content "$PSScriptRoot/../data/wara/test_retirementdata.json" -raw | ConvertFrom-Json -depth 20
            $SupportTicket_TestData = get-content "$PSScriptRoot/../data/wara/test_supportticketdata.json" -raw | ConvertFrom-Json -depth 20
            $ServiceHealth_TestData = get-content "$PSScriptRoot/../data/wara/test_servicehealthdata.json" -raw | ConvertFrom-Json -depth 20

            Mock Connect-WAFAzure { write-host "Mocked Connect-WAFAzure" } -ModuleName 'wara'

            Mock Invoke-WAFQuery { return $AllResources_TestData } -ModuleName 'wara'

            Mock Invoke-WAFQueryLoop { return $QueryLoop_TestData } -ModuleName 'wara'

            Mock Get-WAFAdvisorMetadata { return $AdvisorMeta_TestData } -ModuleName 'wara'

            Mock Invoke-RestMethod { return $RecommendationObject_TestData } -ParameterFilter { $uri -eq 'https://azure.github.io/WARA-Build/objects/recommendations.json' } -ModuleName 'wara'

            Mock Invoke-RestMethod { return $RecommendationResourceTypes_TestData } -ParameterFilter { $uri -eq 'https://raw.githubusercontent.com/Azure/Azure-Proactive-Resiliency-Library-v2/refs/heads/main/tools/WARAinScopeResTypes.csv' } -ModuleName 'wara'

            Mock Get-WARAOtherRecommendation { return $null } -ModuleName 'wara'

            Mock Get-WAFAdvisorRecommendation {

                $AdvData = InModuleScope 'advisor' -Parameters @{
                        Advisor_TestData = $Advisor_TestData
                    } {
                        Build-WAFAdvisorObject -AdvQueryResult $Advisor_TestData
                    }
                return $AdvData
            } -ModuleName 'wara'


            Mock Get-WAFTaggedResourceGroup { return $TaggedResourceGroup_TestData } -ModuleName 'wara'

            Mock Get-WAFTaggedResource { return $TaggedResource_TestData } -ModuleName 'wara'

            Mock Get-WAFOldOutage { return $Outage_TestData } -ModuleName 'wara'

            Mock Get-WAFResourceRetirement { return $Retirement_TestData } -ModuleName 'wara'

            Mock Get-WAFSupportTicket { return $SupportTicket_TestData } -ModuleName 'wara'

            Mock Get-WAFServiceHealth { return $ServiceHealth_TestData } -ModuleName 'wara'

        }
        It 'Should run and return an object that can be measured' {
            $tenantId = $(New-Guid).Guid
            $test_subscriptionIds = "11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222"
            $scriptBlock = Start-WARACollector -TenantID $tenantId -SubscriptionIds $test_subscriptionIds -Debug -PassThru

            # Validate the output of impacted resources
            $scriptblock.impactedresources.count | Should -BeExactly 51

            # Validate the output of impacted resources by type
            $scriptblock.impactedresources.where({ $_.type -eq "Microsoft.ApiManagement/service" }).count | Should -BeExactly 19
            $scriptblock.impactedresources.where({ $_.type -eq "Microsoft.ContainerService/managedClusters" }).count | Should -BeExactly 28
            $scriptblock.impactedresources.where({ $_.type -eq "Microsoft.Network/vpnSites" }).count | Should -BeExactly 4

            # Validate the output of impacted resources by validationAction
            $scriptblock.impactedresources.where({ $_.validationAction -eq "APRL - Queries" }).count | Should -BeExactly 7
            $scriptblock.impactedresources.where({ $_.validationAction -eq "IMPORTANT - Query under development - Validate Resources manually" }).count | Should -BeExactly 4
            $scriptblock.impactedresources.where({ $_.validationAction -eq "IMPORTANT - Recommendation cannot be validated with ARGs - Validate Resources manually" }).count | Should -BeExactly 36
            $scriptblock.impactedresources.where({ $_.validationAction -eq "IMPORTANT - Resource Type is not available in either APRL or Advisor - Validate Resources manually if applicable, if not delete this line" }).count | Should -BeExactly 4

            # Validate the output of advisor recommendations by type
            $scriptblock.advisory.count | Should -BeExactly 4
            $scriptblock.advisory[0].gettype().Name | Should -Be 'advisorResourceObj'
            $scriptblock.advisory.where({ $_.type -eq "microsoft.subscriptions/subscriptions" }).count | Should -BeExactly 1
            $scriptblock.advisory.where({ $_.type -eq "microsoft.apimanagement/service" }).count | Should -BeExactly 3

            # Validate the output of resourcetype
            $scriptblock.resourcetype.count | Should -BeExactly 3
            $scriptblock.resourcetype.where({ $_."Available in APRL/ADVISOR?" -eq "No" }).count | Should -BeExactly 1
            $scriptblock.resourcetype.where({ $_."Available in APRL/ADVISOR?" -eq "Yes" }).count | Should -BeExactly 2

            # Validate the output of retirements
            $scriptblock.retirements.count | Should -BeExactly 3
            $scriptblock.retirements.subscription | Should -Contain "11111111-1111-1111-1111-111111111111"

            #Validate the output of support tickets
            $scriptblock.supporttickets.count | Should -BeExactly 3

            #Validate the output of service health
            $scriptblock.servicehealth.count | Should -BeExactly 9
        }
    }

    Context 'When skipped resources are reported with hermetic mocks' {
        BeforeAll {
            $allResources = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_allresourcesdata.json" | ConvertFrom-Json -Depth 20
            $queryLoop = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_queryloopdata.json" | ConvertFrom-Json -Depth 20
            $advisorMetadata = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_advisormetadata.json" | ConvertFrom-Json -Depth 20
            $recommendations = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_recommendationobjectdata.json" | ConvertFrom-Json -Depth 20
            $advisor = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_advisordata.json" | ConvertFrom-Json -Depth 20
            $outage = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/outage/restApiMultipleResponseData.json" | ConvertFrom-Json -Depth 20 | Select-Object Name, Properties
            $retirement = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_retirementdata.json" | ConvertFrom-Json -Depth 20
            $supportTicket = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_supportticketdata.json" | ConvertFrom-Json -Depth 20
            $serviceHealth = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_servicehealthdata.json" | ConvertFrom-Json -Depth 20
            $resourceTypesCsv = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_recommendationresourcetypesdata.csv"

            # The three manual API Management recommendations are disabled, so the type keeps only its three automated ones
            $deactivatedRecommendations = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_recommendationobjectdata.json" | ConvertFrom-Json -Depth 20
            $deactivated = 0
            foreach ($recommendation in $deactivatedRecommendations) {
                if ($recommendation.recommendationResourceType -eq 'Microsoft.ApiManagement/service' -and $recommendation.automationAvailable -eq $false) {
                    $recommendation.recommendationMetadataState = 'Disabled'
                    $deactivated++
                }
            }
            $deactivated | Should -Be 3 -Because 'the fixture holds three manual API Management recommendations'

            # Flags vpnSites as covered, so its four resources end with no recommendation for their type
            $driftCsv = $resourceTypesCsv.Replace('yes,Microsoft.Network/vpnSites,VPN Sites,No', 'yes,Microsoft.Network/vpnSites,VPN Sites,Yes')
            ($driftCsv -ne $resourceTypesCsv) | Should -BeTrue -Because 'the drift replacement must change the CSV text'

            # The mock bodies read this hashtable, so each test sets its fixture before its run
            $state = @{
                OriginalCsv                 = $resourceTypesCsv
                DriftCsv                    = $driftCsv
                ResourceTypesCsv            = $resourceTypesCsv
                OriginalRecommendations     = $recommendations
                DeactivatedRecommendations  = $deactivatedRecommendations
                Recommendations             = $recommendations
                DefaultTaggedResourceGroups = @('/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-B1')
                DefaultTaggedResources      = @('/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-A1/providers/Microsoft.ApiManagement/service/apiService1')
                TaggedResourceGroups        = @()
                TaggedResources             = @()
                Parameters                  = @{
                    TenantID        = (New-Guid).Guid
                    SubscriptionIds = '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'
                    PassThru        = $true
                }
            }

            Mock Find-Module { [PSCustomObject]@{ Version = [version]'1.0.0' } } -ModuleName 'wara'
            Mock Connect-WAFAzure { } -ModuleName 'wara'
            Mock Invoke-WAFQuery { return $allResources } -ModuleName 'wara'
            Mock Invoke-WAFQueryLoop { return $queryLoop } -ModuleName 'wara'
            Mock Get-WAFAdvisorMetadata { return $advisorMetadata } -ModuleName 'wara'
            Mock Invoke-RestMethod { return $state.Recommendations } -ParameterFilter { $uri -eq 'https://azure.github.io/WARA-Build/objects/recommendations.json' } -ModuleName 'wara'
            Mock Invoke-RestMethod { return $state.ResourceTypesCsv } -ParameterFilter { $uri -eq 'https://azure.github.io/WARA-Build/objects/WARAinScopeResTypes.csv' } -ModuleName 'wara'
            Mock Get-WARAOtherRecommendation { return $null } -ModuleName 'wara'
            Mock Get-WAFAdvisorRecommendation {
                $advisorObjects = InModuleScope 'advisor' -Parameters @{ Advisor_TestData = $advisor } {
                    Build-WAFAdvisorObject -AdvQueryResult $Advisor_TestData
                }
                return $advisorObjects
            } -ModuleName 'wara'
            Mock Get-WAFTaggedResourceGroup { return $state.TaggedResourceGroups } -ModuleName 'wara'
            Mock Get-WAFTaggedResource { return $state.TaggedResources } -ModuleName 'wara'
            Mock Get-WAFOldOutage { return $outage } -ModuleName 'wara'
            Mock Get-WAFResourceRetirement { return $retirement } -ModuleName 'wara'
            Mock Get-WAFSupportTicket { return $supportTicket } -ModuleName 'wara'
            Mock Get-WAFServiceHealth { return $serviceHealth } -ModuleName 'wara'
        }

        BeforeEach {
            $state.ResourceTypesCsv = $state.OriginalCsv
            $state.Recommendations = $state.OriginalRecommendations
            $state.TaggedResourceGroups = $state.DefaultTaggedResourceGroups
            $state.TaggedResources = $state.DefaultTaggedResources
        }

        Context 'When the CSV flags a type as covered that has no recommendation' {
            BeforeAll {
                $state.ResourceTypesCsv = $state.DriftCsv
                $parameters = $state.Parameters
                $Error.Clear()
                $script:driftResult = Start-WARACollector @parameters -WarningVariable collectedWarnings -WarningAction SilentlyContinue
                $script:driftErrorCount = $Error.Count
                $script:driftWarnings = @($collectedWarnings)
            }

            It 'Should list the four vpnSites resources in skippedResources, sorted' {
                $expected = @(
                    @{ Name = 'vpnSite1'; Location = 'eastus'; Group = 'rg-A1'; Subscription = '11111111-1111-1111-1111-111111111111' }
                    @{ Name = 'vpnSite2'; Location = 'westus'; Group = 'rg-A2'; Subscription = '11111111-1111-1111-1111-111111111111' }
                    @{ Name = 'vpnSite3'; Location = 'eastus2'; Group = 'rg-B1'; Subscription = '22222222-2222-2222-2222-222222222222' }
                    @{ Name = 'vpnSite4'; Location = 'westus2'; Group = 'rg-B2'; Subscription = '22222222-2222-2222-2222-222222222222' }
                )
                $skipped = $script:driftResult.skippedResources

                $skipped.Count | Should -Be 4
                for ($i = 0; $i -lt $expected.Count; $i++) {
                    $skipped[$i].GetType().Name | Should -Be 'skippedResourceObj'
                    $skipped[$i].id | Should -Be "/subscriptions/$($expected[$i].Subscription)/resourceGroups/$($expected[$i].Group)/providers/Microsoft.Network/vpnSites/$($expected[$i].Name)"
                    $skipped[$i].name | Should -Be $expected[$i].Name
                    $skipped[$i].type | Should -Be 'Microsoft.Network/vpnSites'
                    $skipped[$i].location | Should -Be $expected[$i].Location
                    $skipped[$i].subscriptionId | Should -Be $expected[$i].Subscription
                    $skipped[$i].resourceGroup | Should -Be $expected[$i].Group
                    $skipped[$i].reason | Should -Be 'NoMatchingRecommendation'
                }

                $readBack = ($script:driftResult | ConvertTo-Json -Depth 15 | ConvertFrom-Json).skippedResources
                ($readBack -is [array]) | Should -BeTrue
                @($readBack).Count | Should -Be 4
            }

            It 'Should leave the other sections as they are' {
                $script:driftResult.impactedResources.Count | Should -Be 47
                $script:driftResult.impactedResources.type | Should -Not -Contain 'Microsoft.Network/vpnSites'
                $script:driftResult.resourceInventory.Count | Should -Be 16
                $script:driftResult.advisory.Count | Should -Be 4
            }

            It 'Should write one warning and no error' {
                $script:driftWarnings.Count | Should -Be 1
                $text = [string]$script:driftWarnings[0]
                $text | Should -BeLike '*4 resource(s)*'
                $text | Should -BeLike '*1 type(s)*'
                $text | Should -BeLike '*Microsoft.Network/vpnSites (4)*'
                $text | Should -BeLike "*'skippedResources'*"
                $script:driftErrorCount | Should -Be 0
            }
        }

        Context 'When a preference turns a message into a stop' {
            BeforeEach {
                $state.ResourceTypesCsv = $state.DriftCsv
            }

            It 'Should complete under -ErrorAction Stop' {
                $parameters = $state.Parameters
                $result = Start-WARACollector @parameters -ErrorAction Stop -WarningAction SilentlyContinue

                $result.skippedResources.Count | Should -Be 4
            }

            It 'Should fail fast under -WarningAction Stop' {
                $parameters = $state.Parameters

                { Start-WARACollector @parameters -WarningAction Stop } | Should -Throw -ExceptionType ([System.Management.Automation.ActionPreferenceStopException]) -ExpectedMessage '*received no APRL verdict*'
            }
        }

        Context 'When the run is scoped with -Tags' {
            BeforeEach {
                $state.ResourceTypesCsv = $state.DriftCsv
            }

            It 'Should filter the list by tag and sort it after the filter' {
                $state.TaggedResources = @('/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-A1/providers/Microsoft.Network/vpnSites/vpnSite1')
                $parameters = $state.Parameters

                $result = Start-WARACollector @parameters -Tags 'Environment=~Production' -WarningVariable collectedWarnings -WarningAction SilentlyContinue

                # The filter returns resource group matches before resource matches, so a sort before the filter would give vpnSite3 first
                ($result.skippedResources.name -join ',') | Should -BeExactly 'vpnSite1,vpnSite3'
                @($collectedWarnings).Count | Should -Be 1
                [string]$collectedWarnings[0] | Should -BeLike '*2 resource(s)*'
            }

            It 'Should serialize a single record as an array' {
                $state.TaggedResources = @('/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/rg-none/providers/Microsoft.Network/vpnSites/none')
                $parameters = $state.Parameters

                $result = Start-WARACollector @parameters -Tags 'Environment=~Production' -WarningAction SilentlyContinue

                $result.skippedResources.Count | Should -Be 1
                $result.skippedResources[0].name | Should -Be 'vpnSite3'
                $readBack = ($result | ConvertTo-Json -Depth 15 | ConvertFrom-Json).skippedResources
                ($readBack -is [array]) | Should -BeTrue
                @($readBack).Count | Should -Be 1
            }

            It 'Should return an empty array and no warning when the filter keeps nothing' {
                $state.TaggedResourceGroups = @('/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/rg-none')
                $state.TaggedResources = @('/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/rg-none/providers/Microsoft.Network/vpnSites/none')
                $parameters = $state.Parameters

                $result = Start-WARACollector @parameters -Tags 'Environment=~Production' -WarningVariable collectedWarnings -WarningAction SilentlyContinue

                $result.skippedResources.GetType().IsArray | Should -BeTrue
                $result.skippedResources.Count | Should -Be 0
                $readBack = ($result | ConvertTo-Json -Depth 15 | ConvertFrom-Json).skippedResources
                ($readBack -is [array]) | Should -BeTrue
                @($readBack).Count | Should -Be 0
                @($collectedWarnings).Count | Should -Be 0
            }
        }

        Context 'When no resource is skipped' {
            It 'Should return an empty array and no warning' {
                $parameters = $state.Parameters

                $result = Start-WARACollector @parameters -WarningVariable collectedWarnings -WarningAction SilentlyContinue

                $result.skippedResources.GetType().IsArray | Should -BeTrue
                $result.skippedResources.Count | Should -Be 0
                $readBack = ($result | ConvertTo-Json -Depth 15 | ConvertFrom-Json).skippedResources
                ($readBack -is [array]) | Should -BeTrue
                @($readBack).Count | Should -Be 0
                @($collectedWarnings).Count | Should -Be 0
            }

            It 'Should complete with -Tags when nothing is skipped' {
                $parameters = $state.Parameters

                $result = Start-WARACollector @parameters -Tags 'Environment=~Production' -WarningVariable collectedWarnings -WarningAction SilentlyContinue

                $result.skippedResources.GetType().IsArray | Should -BeTrue
                $result.skippedResources.Count | Should -Be 0
                @($collectedWarnings).Count | Should -Be 0
            }
        }

        Context 'When a type has a recommendation but no manual one to validate' {
            BeforeEach {
                $state.Recommendations = $state.DeactivatedRecommendations
            }

            It 'Should not list the resources of a type that automated queries cover' {
                $parameters = $state.Parameters

                $result = Start-WARACollector @parameters -WarningVariable collectedWarnings -WarningAction SilentlyContinue

                $result.skippedResources.GetType().IsArray | Should -BeTrue
                $result.skippedResources.Count | Should -Be 0
                @($collectedWarnings).Count | Should -Be 0

                # The manual rows of the type are gone and its automated rows stay
                $result.impactedResources.Count | Should -Be 39
                $apiManagement = @($result.impactedResources.where({ $_.type -eq 'Microsoft.ApiManagement/service' }))
                $apiManagement.Count | Should -Be 7
                ($apiManagement.validationAction | Select-Object -Unique) | Should -Be 'APRL - Queries'
                ($apiManagement.name | Sort-Object -Unique) -join ',' | Should -BeExactly 'apiService1,apiService2,apiService3,apiService4'

                $impactedIds = @($result.impactedResources.id)
                @($result.skippedResources | Where-Object { $_.id -in $impactedIds }).Count | Should -Be 0
            }
        }
    }
}


Describe 'Build-ImpactedResourceObj' {
    Context 'When called with valid parameters' {
        BeforeAll {
            # Recommendation object hash
            $recommendationObject = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/recommendations-subset.json" | ConvertFrom-Json -Depth 10
            $recommendationObjectHash = @{}
            $recommendationObject.ForEach({ $recommendationObjectHash[$_.aprlGuid] = $_ })

            # All resources hash
            $allResources = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/all-resources-data.json" | ConvertFrom-Json -Depth 10
            $allResourcesHash = @{}
            $allResources.ForEach({ $allResourcesHash[$_.id] = $_ })
        }

        It 'Should return an array of type aprlResourceObj with a single element' {
            $impactedResource = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/impacted-resources-data-single.json" | ConvertFrom-Json -Depth 10

            InModuleScope 'wara' -Parameters @{
                ImpactedResource     = $impactedResource
                AllResources         = $allResourcesHash
                RecommendationObject = $recommendationObjectHash
            } {
                $result = Build-ImpactedResourceObj -ImpactedResources $ImpactedResource -AllResources $AllResources -RecommendationObject $RecommendationObject

                $result.GetType().FullName | Should -Be 'System.Object[]'
                $result[0].GetType().FullName | Should -Be 'aprlResourceObj'
            }
        }

        It 'Should return an array of type aprlResourceObj with multiple elements' {
            $impactedResources = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/impacted-resources-data-multiple.json" | ConvertFrom-Json -Depth 10

            InModuleScope 'wara' -Parameters @{
                ImpactedResources    = $impactedResources
                AllResources         = $allResourcesHash
                RecommendationObject = $recommendationObjectHash
            } {
                $result = Build-ImpactedResourceObj -ImpactedResources $ImpactedResources -AllResources $AllResources -RecommendationObject $RecommendationObject

                $result.GetType().FullName | Should -Be 'System.Object[]'
                $result | ForEach-Object {
                    $_.GetType().FullName | Should -Be 'aprlResourceObj'
                }
            }
        }

        It 'Should set the properties correctly' {
            $impactedResource = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/impacted-resources-data-single.json" | ConvertFrom-Json -Depth 10

            InModuleScope 'wara' -Parameters @{
                ImpactedResource     = $impactedResource
                AllResources         = $allResourcesHash
                RecommendationObject = $recommendationObjectHash
            } {
                $expected = @{
                    validationAction = 'APRL - Queries'
                    RecommendationId = $ImpactedResource.recommendationId
                    Name             = $ImpactedResource.name
                    Id               = $ImpactedResource.id
                    type             = $RecommendationObject[$ImpactedResource.recommendationId].recommendationResourceType ?? $AllResources[$ImpactedResource.id].type ?? 'Unknown'
                    location         = $AllResources[$ImpactedResource.id].location ?? 'Unknown'
                    subscriptionId   = $AllResources[$ImpactedResource.id].subscriptionId ?? $ImpactedResource.id.split('/')[2] ?? 'Unknown'
                    resourceGroup    = $AllResources[$ImpactedResource.id].resourceGroup ?? $ImpactedResource.id.split('/')[4] ?? 'Unknown'
                    Param1           = $ImpactedResource.param1 ?? ''
                    Param2           = $ImpactedResource.param2 ?? ''
                    Param3           = $ImpactedResource.param3 ?? ''
                    Param4           = $ImpactedResource.param4 ?? ''
                    Param5           = $ImpactedResource.param5 ?? ''
                    checkName        = $ImpactedResource.checkName ?? ''
                    selector         = $ImpactedResource.selector ?? 'APRL'
                }

                $result = Build-ImpactedResourceObj -ImpactedResources $ImpactedResource -AllResources $AllResources -RecommendationObject $RecommendationObject
                $actual = $result[0]

                $actual.validationAction | Should -Be $expected.validationAction
                $actual.RecommendationId | Should -Be $expected.RecommendationId
                $actual.Name | Should -Be $expected.Name
                $actual.Id | Should -Be $expected.Id
                $actual.type | Should -Be $expected.type
                $actual.location | Should -Be $expected.location
                $actual.subscriptionId | Should -Be $expected.subscriptionId
                $actual.resourceGroup | Should -Be $expected.resourceGroup
                $actual.Param1 | Should -Be $expected.Param1
                $actual.Param2 | Should -Be $expected.Param2
                $actual.Param3 | Should -Be $expected.Param3
                $actual.Param4 | Should -Be $expected.Param4
                $actual.Param5 | Should -Be $expected.Param5
                $actual.checkName | Should -Be $expected.checkName
                $actual.selector | Should -Be $expected.selector
            }
        }
    }
}

Describe 'Build-ValidationResourceObj' {
    BeforeAll {
        $subscription1 = '11111111-1111-1111-1111-111111111111'
        $subscription2 = '22222222-2222-2222-2222-222222222222'

        # Outcome 1: automatedOnly. 2: manualActive. 3: notInAprl. 4: noRecommendation and disabledOnly are skipped; typeIdOnly has Active recommendations, so it is not.
        $recommendationObject = @(
            [PSCustomObject]@{ aprlGuid = 'g-1'; recommendationResourceType = 'Microsoft.Test/automatedOnly'; automationAvailable = $true; recommendationMetadataState = 'Active'; recommendationTypeId = ''; query = 'resources | project id' }
            [PSCustomObject]@{ aprlGuid = 'g-2'; recommendationResourceType = 'Microsoft.Test/manualActive'; automationAvailable = $false; recommendationMetadataState = 'Active'; recommendationTypeId = ''; query = '// cannot-be-validated-with-arg' }
            [PSCustomObject]@{ aprlGuid = 'g-3'; recommendationResourceType = 'Microsoft.Test/typeIdOnly'; automationAvailable = $true; recommendationMetadataState = 'Active'; recommendationTypeId = ''; query = 'resources | project id' }
            [PSCustomObject]@{ aprlGuid = 'g-4'; recommendationResourceType = 'Microsoft.Test/typeIdOnly'; automationAvailable = $false; recommendationMetadataState = 'Active'; recommendationTypeId = '00000000-0000-0000-0000-000000000004'; query = '// cannot-be-validated-with-arg' }
            [PSCustomObject]@{ aprlGuid = 'g-5'; recommendationResourceType = 'Microsoft.Test/disabledOnly'; automationAvailable = $false; recommendationMetadataState = 'Disabled'; recommendationTypeId = ''; query = '// cannot-be-validated-with-arg' }
        )
        $typesNotInAPRLOrAdvisor = @('Microsoft.Test/notInAprl')

        $validationResources = @{}
        @(
            @{ Name = 'a1'; Type = 'Microsoft.Test/automatedOnly'; Location = 'eastus'; Subscription = $subscription1; Group = 'rg-a' }
            @{ Name = 'm1'; Type = 'Microsoft.Test/manualActive'; Location = 'eastus'; Subscription = $subscription1; Group = 'rg-m' }
            @{ Name = 'n1'; Type = 'Microsoft.Test/notInAprl'; Location = 'westus'; Subscription = $subscription1; Group = 'rg-n' }
            @{ Name = 'r1'; Type = 'Microsoft.Test/noRecommendation'; Location = 'eastus'; Subscription = $subscription1; Group = 'rg-r1' }
            @{ Name = 'r2'; Type = 'Microsoft.Test/noRecommendation'; Location = 'westus'; Subscription = $subscription2; Group = 'rg-r2' }
            @{ Name = 't1'; Type = 'Microsoft.Test/typeIdOnly'; Location = 'eastus2'; Subscription = $subscription2; Group = 'rg-t' }
            @{ Name = 'd1'; Type = 'Microsoft.Test/disabledOnly'; Location = 'westus2'; Subscription = $subscription2; Group = 'rg-d' }
        ).ForEach({
                $id = "/subscriptions/$($_.Subscription)/resourceGroups/$($_.Group)/providers/$($_.Type)/$($_.Name)"
                $validationResources[$id] = [PSCustomObject]@{ id = $id; name = $_.Name; type = $_.Type; location = $_.Location; subscriptionId = $_.Subscription; resourceGroup = $_.Group }
            })

        $script:validationFixture = @{
            ValidationResources     = $validationResources
            RecommendationObject    = $recommendationObject
            TypesNotInAPRLOrAdvisor = $typesNotInAPRLOrAdvisor
        }
    }

    Context 'Validation rows' {
        It 'Should return the rows of outcomes 2 and 3 and nothing for outcome 1' {
            InModuleScope 'wara' -Parameters $script:validationFixture {
                $result = Build-ValidationResourceObj -ValidationResources $ValidationResources -RecommendationObject $RecommendationObject -TypesNotInAPRLOrAdvisor $TypesNotInAPRLOrAdvisor

                $result.GetType().FullName | Should -Be 'System.Object[]'
                $result.Count | Should -Be 2
                $result | ForEach-Object {
                    $_.GetType().FullName | Should -Be 'aprlResourceObj'
                }
                $result.name | Should -Not -Contain 'a1'

                $manual = $result | Where-Object { $_.name -eq 'm1' }
                $manual.recommendationId | Should -Be 'g-2'
                $manual.validationAction | Should -Be 'IMPORTANT - Recommendation cannot be validated with ARGs - Validate Resources manually'

                $noRecommendations = $result | Where-Object { $_.name -eq 'n1' }
                $noRecommendations.recommendationId | Should -BeNullOrEmpty
                $noRecommendations.validationAction | Should -BeLike 'IMPORTANT - Resource Type is not available in either APRL or Advisor*'
            }
        }
    }

    Context 'Skipped resources' {
        It 'Should record one skippedResourceObj per resource whose type has no recommendation' {
            InModuleScope 'wara' -Parameters $script:validationFixture {
                $skipped = [System.Collections.Generic.List[skippedResourceObj]]::new()
                $null = Build-ValidationResourceObj -ValidationResources $ValidationResources -RecommendationObject $RecommendationObject -TypesNotInAPRLOrAdvisor $TypesNotInAPRLOrAdvisor -SkippedResources $skipped

                $skipped.Count | Should -Be 3
                'r1', 'r2', 'd1' | ForEach-Object {
                    $skipped.name | Should -Contain $_
                }
                'a1', 'm1', 'n1', 't1' | ForEach-Object {
                    $skipped.name | Should -Not -Contain $_
                }

                foreach ($record in $skipped) {
                    $source = $ValidationResources[$record.id]
                    $record.GetType().FullName | Should -Be 'skippedResourceObj'
                    $record.reason | Should -Be 'NoMatchingRecommendation'
                    $record.id | Should -Be $source.id
                    $record.name | Should -Be $source.name
                    $record.type | Should -Be $source.type
                    $record.location | Should -Be $source.location
                    $record.subscriptionId | Should -Be $source.subscriptionId
                    $record.resourceGroup | Should -Be $source.resourceGroup
                }
            }
        }

        It 'Should work without the parameter and append to a supplied list' {
            InModuleScope 'wara' -Parameters $script:validationFixture {
                $rows = Build-ValidationResourceObj -ValidationResources $ValidationResources -RecommendationObject $RecommendationObject -TypesNotInAPRLOrAdvisor $TypesNotInAPRLOrAdvisor
                $rows.Count | Should -Be 2

                $existing = [skippedResourceObj]::new()
                $existing.name = 'existing'
                $skipped = [System.Collections.Generic.List[skippedResourceObj]]::new()
                $skipped.Add($existing)
                $null = Build-ValidationResourceObj -ValidationResources $ValidationResources -RecommendationObject $RecommendationObject -TypesNotInAPRLOrAdvisor $TypesNotInAPRLOrAdvisor -SkippedResources $skipped
                $skipped.Count | Should -Be 4
                $skipped[0].name | Should -Be 'existing'

                $withoutOutcome4 = @{}
                foreach ($key in $ValidationResources.Keys) {
                    if ($ValidationResources[$key].name -in 'a1', 'm1', 'n1') {
                        $withoutOutcome4[$key] = $ValidationResources[$key]
                    }
                }
                $untouched = [System.Collections.Generic.List[skippedResourceObj]]::new()
                $rows = Build-ValidationResourceObj -ValidationResources $withoutOutcome4 -RecommendationObject $RecommendationObject -TypesNotInAPRLOrAdvisor $TypesNotInAPRLOrAdvisor -SkippedResources $untouched
                $untouched.Count | Should -Be 0
                $rows.Count | Should -Be 2
            }
        }
    }

    Context 'Streams and preferences' {
        It 'Should write no warning and not raise an error' {
            InModuleScope 'wara' -Parameters $script:validationFixture {
                $ErrorActionPreference = 'Stop'
                $skipped = [System.Collections.Generic.List[skippedResourceObj]]::new()

                $result = Build-ValidationResourceObj -ValidationResources $ValidationResources -RecommendationObject $RecommendationObject -TypesNotInAPRLOrAdvisor $TypesNotInAPRLOrAdvisor -SkippedResources $skipped -WarningVariable warnings

                $warnings | Should -BeNullOrEmpty
                $result.Count | Should -Be 2
                $skipped.Count | Should -Be 3
            }
        }
    }
}

Describe 'Build-SkippedResourceObj' {
    Context 'Order' {
        It 'Should sort by type and then id with OrdinalIgnoreCase' {
            InModuleScope 'wara' {
                $disks = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg/providers/Microsoft.Compute/disks/'
                $machines = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/'
                $sites = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg/providers/Microsoft.Network/vpnSites/'
                $records = @(
                    [skippedResourceObj]@{ type = 'Microsoft.Network/vpnSites'; id = "${sites}vpnSite1" }
                    [skippedResourceObj]@{ type = 'Microsoft.Compute/virtualMachines'; id = "${machines}vm1" }
                    [skippedResourceObj]@{ type = 'Microsoft.Compute/virtualMachines'; id = "${machines}vm_a" }
                    [skippedResourceObj]@{ type = 'microsoft.compute/disks'; id = "${disks}disk1" }
                    [skippedResourceObj]@{ type = 'Microsoft.Compute/virtualMachines'; id = "${machines}VmB" }
                    [skippedResourceObj]@{ type = 'Microsoft.Compute/virtualMachines'; id = "${machines}vm.a" }
                    [skippedResourceObj]@{ type = 'Microsoft.Compute/virtualMachines'; id = "${machines}vm-a" }
                )

                $result = Build-SkippedResourceObj -SkippedResources $records -WarningAction SilentlyContinue

                # Sort-Object under en-CA gives vm_a, vm-a, vm.a, vm1, VmB, so this order tells the comparer from a culture sort
                ($result.id | ForEach-Object { $_.Split('/')[-1] }) -join ',' | Should -BeExactly 'disk1,vm-a,vm.a,vm1,VmB,vm_a,vpnSite1'
            }
        }
    }

    Context 'Shape' {
        It 'Should always return an array and warn only when there is something to report: <Description>' -ForEach @(
            @{ Description = 'no records in a list'; Kind = 'List'; RecordCount = 0 }
            @{ Description = 'one record in a list'; Kind = 'List'; RecordCount = 1 }
            @{ Description = 'three records in a list'; Kind = 'List'; RecordCount = 3 }
            @{ Description = 'three records in an object[]'; Kind = 'Array'; RecordCount = 3 }
        ) {
            InModuleScope 'wara' -Parameters @{ Kind = $Kind; RecordCount = $RecordCount } {
                $list = [System.Collections.Generic.List[skippedResourceObj]]::new()
                for ($i = 1; $i -le $RecordCount; $i++) {
                    $list.Add([skippedResourceObj]@{ type = 'Microsoft.Test/t'; id = "/subscriptions/s/resourceGroups/rg/providers/Microsoft.Test/t/r$i" })
                }
                $records = $list
                if ($Kind -eq 'Array') {
                    $records = @($list)
                }

                $result = Build-SkippedResourceObj -SkippedResources $records -WarningVariable warnings -WarningAction SilentlyContinue

                $result.GetType().IsArray | Should -BeTrue
                $result.Count | Should -Be $RecordCount

                $serialized = [PSCustomObject]@{ skippedResources = $result } | ConvertTo-Json -Depth 15
                $readBack = ($serialized | ConvertFrom-Json).skippedResources
                ($readBack -is [array]) | Should -BeTrue
                @($readBack).Count | Should -Be $RecordCount

                @($warnings).Count | Should -Be ($RecordCount -eq 0 ? 0 : 1)
            }
        }
    }

    Context 'Warning' {
        It 'Should write one warning with the counts, the per-type counts and the pointer' {
            InModuleScope 'wara' {
                $sets = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg/providers/Microsoft.Compute/availabilitySets/'
                $sites = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg/providers/Microsoft.Network/vpnSites/'
                $records = @(
                    [skippedResourceObj]@{ type = 'Microsoft.Compute/availabilitySets'; id = "${sets}set1" }
                    [skippedResourceObj]@{ type = 'microsoft.compute/availabilitysets'; id = "${sets}set2" }
                    [skippedResourceObj]@{ type = 'Microsoft.Network/vpnSites'; id = "${sites}vpnSite1" }
                    [skippedResourceObj]@{ type = 'Microsoft.Network/vpnSites'; id = "${sites}vpnSite2" }
                    [skippedResourceObj]@{ type = 'Microsoft.Network/vpnSites'; id = "${sites}vpnSite3" }
                )

                $null = Build-SkippedResourceObj -SkippedResources $records -WarningVariable warnings -WarningAction SilentlyContinue -ErrorVariable errors

                @($warnings).Count | Should -Be 1
                $text = [string]$warnings[0]
                $text | Should -BeLike '*5 resource(s)*'
                $text | Should -BeLike '*2 type(s)*'
                $text | Should -BeLike "*'skippedResources'*"
                $text | Should -BeLike '*Microsoft.Network/vpnSites (3)*'
                $text | Should -Match 'Microsoft\.Compute/availabilitySets \(2\)'
                $text.IndexOf('Microsoft.Network/vpnSites (3)', [System.StringComparison]::Ordinal) | Should -BeLessThan $text.IndexOf('availabilitySets (2)', [System.StringComparison]::OrdinalIgnoreCase)
                $errors | Should -BeNullOrEmpty
            }
        }

        It 'Should name the ten largest types and count the rest' {
            InModuleScope 'wara' {
                $sizes = @{ t10 = 3; t11 = 5; t12 = 5 }
                $records = foreach ($number in 1..12) {
                    $name = 't{0:00}' -f $number
                    for ($i = 1; $i -le ($sizes[$name] ?? 1); $i++) {
                        [skippedResourceObj]@{ type = "Microsoft.Test/$name"; id = "/subscriptions/s/resourceGroups/rg/providers/Microsoft.Test/$name/r$i" }
                    }
                }

                $null = Build-SkippedResourceObj -SkippedResources $records -WarningVariable warnings -WarningAction SilentlyContinue

                $text = [string]$warnings[0]
                $text | Should -BeLike '*22 resource(s) of 12 type(s)*'
                $text | Should -BeLike '*Microsoft.Test/t11 (5), Microsoft.Test/t12 (5), Microsoft.Test/t10 (3), Microsoft.Test/t01 (1), Microsoft.Test/t02 (1), Microsoft.Test/t03 (1), Microsoft.Test/t04 (1), Microsoft.Test/t05 (1), Microsoft.Test/t06 (1), Microsoft.Test/t07 (1), and 2 more types.'
                $text | Should -Not -BeLike '*t08*'
                $text | Should -Not -BeLike '*t09*'
            }
        }
    }
}

Describe 'Build-ResourceTypeObj' {
    Context 'When given a list of resources and the types not in aprl or advisor' {
        It 'Should return an object with the appropriate resource types' {
            $AllResources_TestData = get-content "$PSScriptRoot/../data/wara/test_allresourcesdata.json" -raw | ConvertFrom-Json -depth 20
            $RecommendationResourceTypes_TestData = get-content "$PSScriptRoot/../data/wara/test_recommendationresourcetypesdata.csv" -Raw
            $RecommendationResourceTypes = $RecommendationResourceTypes_TestData | ConvertFrom-Csv | Where-Object { $_.WARAinScope -eq 'yes' }
            $TypesNotInAPRLOrAdvisor = ($RecommendationResourceTypes | Where-Object { $_.InAprlAndOrAdvisor -eq "No" }).ResourceType


            InModuleScope 'wara' -Parameters @{
                ResourceObj             = $AllResources_TestData
                TypesNotInAPRLOrAdvisor = $TypesNotInAPRLOrAdvisor
            } {
                $result = Build-ResourceTypeObj -ResourceObj $ResourceObj -TypesNotInAPRLOrAdvisor $TypesNotInAPRLOrAdvisor

                $result.GetType().FullName | Should -Be 'System.Object[]'
                $result[0].GetType().FullName | Should -Be 'aprlResourceTypeObj'
            }

        }
    }

}

Describe 'Build-SpecializedResourceObj' {

}

Describe 'Get-WARAOtherRecommendation' {
    Context 'When given correct parameters' {
        It 'Should return the right stuff' {
            $advisorMetadata = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_advisormetadata.json" | ConvertFrom-Json -Depth 10
            $recommendationObject = Get-Content -Raw -LiteralPath "$PSScriptRoot/../data/wara/test_recommendationobjectdata.json" | ConvertFrom-Json -Depth 10

            InModuleScope 'wara' -Parameters @{
                RecommendationObject = $recommendationObject
                AdvisorMetadata      = $advisorMetadata
            } {
                { Get-WARAOtherRecommendation -RecommendationObject $RecommendationObject -AdvisorMetadata $AdvisorMetadata } | Should -Not -Throw
            }

        }
    }

}
