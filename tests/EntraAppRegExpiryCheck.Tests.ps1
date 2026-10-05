#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeAll {
    # A stand-in so the module's Graph calls can be mocked on machines without
    # Microsoft.Graph.Authentication installed. Pester can only mock commands that exist.
    if (-not (Get-Command -Name 'Invoke-MgGraphRequest' -ErrorAction SilentlyContinue)) {
        function global:Invoke-MgGraphRequest {
            param($Method, $Uri, $Body, $OutputType)
        }
    }

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $manifest = Join-Path (Join-Path (Join-Path $repoRoot 'src') 'EntraAppRegExpiryCheck') 'EntraAppRegExpiryCheck.psd1'
    Import-Module $manifest -Force

    $fixtures = Join-Path $PSScriptRoot 'fixtures'
    $script:page1 = Get-Content -Raw -Encoding UTF8 (Join-Path $fixtures 'applications-page1.json') | ConvertFrom-Json
    $script:page2 = Get-Content -Raw -Encoding UTF8 (Join-Path $fixtures 'applications-page2.json') | ConvertFrom-Json
    $script:servicePrincipals = Get-Content -Raw -Encoding UTF8 (Join-Path $fixtures 'service-principals.json') | ConvertFrom-Json
    $script:exclusionPath = Join-Path $fixtures 'exclusions.json'

    # Every fixture date is relative to this moment.
    $script:asOf = [datetime]::SpecifyKind([datetime]'2026-10-05T00:00:00', [DateTimeKind]::Utc)
}

AfterAll {
    Remove-Module EntraAppRegExpiryCheck -ErrorAction SilentlyContinue
}

Describe 'Get-CredentialStatus' {
    BeforeAll {
        $script:now = [datetime]::SpecifyKind([datetime]'2026-10-05T12:00:00', [DateTimeKind]::Utc)
    }

    It 'reports <Expected> for an end date <Offset> days away' -ForEach @(
        @{ Offset = -1; Expected = 'Expired' }
        @{ Offset = 0; Expected = 'Expired' }
        @{ Offset = 1; Expected = 'Expiring' }
        @{ Offset = 30; Expected = 'Expiring' }
        @{ Offset = 31; Expected = 'Healthy' }
    ) {
        InModuleScope EntraAppRegExpiryCheck -Parameters @{ Now = $now; Offset = $Offset; Expected = $Expected } {
            $result = Get-CredentialStatus -EndDateTime $Now.AddDays($Offset) -AsOf $Now -ThresholdDays 30
            $result.Status | Should -Be $Expected
        }
    }

    It 'rounds days remaining down' {
        InModuleScope EntraAppRegExpiryCheck -Parameters @{ Now = $now } {
            (Get-CredentialStatus -EndDateTime $Now.AddHours(20) -AsOf $Now -ThresholdDays 30).DaysRemaining | Should -Be 0
            (Get-CredentialStatus -EndDateTime $Now.AddHours(-2) -AsOf $Now -ThresholdDays 30).DaysRemaining | Should -Be -1
        }
    }

    It 'reports Unknown when there is no end date' {
        InModuleScope EntraAppRegExpiryCheck -Parameters @{ Now = $now } {
            $result = Get-CredentialStatus -EndDateTime $null -AsOf $Now -ThresholdDays 30
            $result.Status | Should -Be 'Unknown'
            $result.DaysRemaining | Should -BeNullOrEmpty
        }
    }
}

Describe 'ConvertTo-UtcDateTime' {
    It 'parses an ISO 8601 string as UTC' {
        InModuleScope EntraAppRegExpiryCheck {
            $value = ConvertTo-UtcDateTime '2026-11-02T10:15:00Z'
            $value.Kind | Should -Be ([DateTimeKind]::Utc)
            $value.Hour | Should -Be 10
        }
    }

    It 'treats a DateTime with no kind as UTC instead of shifting it' {
        InModuleScope EntraAppRegExpiryCheck {
            $value = ConvertTo-UtcDateTime ([datetime]'2026-11-02T10:15:00')
            $value.Kind | Should -Be ([DateTimeKind]::Utc)
            $value.Hour | Should -Be 10
        }
    }

    It 'returns $null for empty input' {
        InModuleScope EntraAppRegExpiryCheck {
            ConvertTo-UtcDateTime $null | Should -BeNullOrEmpty
            ConvertTo-UtcDateTime '' | Should -BeNullOrEmpty
        }
    }
}

Describe 'ConvertFrom-CustomKeyIdentifier' {
    It 'decodes a 20-byte identifier into a hex thumbprint' {
        InModuleScope EntraAppRegExpiryCheck {
            ConvertFrom-CustomKeyIdentifier 'PyqcTht9ig9sXk07KhkI9+bVxLM=' | Should -Be '3F2A9C4E1B7D8A0F6C5E4D3B2A1908F7E6D5C4B3'
        }
    }

    It 'returns $null for <Case>' -ForEach @(
        @{ Case = 'a missing value'; Value = $null }
        @{ Case = 'invalid base64'; Value = 'not base64!' }
        @{ Case = 'a value that is not 20 bytes'; Value = 'AAEC' }
    ) {
        InModuleScope EntraAppRegExpiryCheck -Parameters @{ Value = $Value } {
            ConvertFrom-CustomKeyIdentifier $Value | Should -BeNullOrEmpty
        }
    }
}

Describe 'Read-ExclusionFile' {
    It 'matches app IDs without regard to case and ignores entries past their until date' {
        InModuleScope EntraAppRegExpiryCheck -Parameters @{ Path = $exclusionPath; AsOf = $asOf } {
            $exclusions = Read-ExclusionFile -Path $Path -AsOf $AsOf
            $exclusions.AppIds.ContainsKey('a0000000-0000-4000-8000-000000000003') | Should -BeTrue
            $exclusions.KeyIds.Count | Should -Be 0
        }
    }

    It 'keeps an entry whose until date has not passed yet' {
        InModuleScope EntraAppRegExpiryCheck -Parameters @{ Path = $exclusionPath } {
            $earlier = [datetime]::SpecifyKind([datetime]'2026-09-01T00:00:00', [DateTimeKind]::Utc)
            (Read-ExclusionFile -Path $Path -AsOf $earlier).KeyIds.Count | Should -Be 1
        }
    }

    It 'fails clearly when the file does not exist' {
        InModuleScope EntraAppRegExpiryCheck -Parameters @{ AsOf = $asOf; Missing = (Join-Path $TestDrive 'missing.json') } {
            { Read-ExclusionFile -Path $Missing -AsOf $AsOf } | Should -Throw '*not found*'
        }
    }
}

Describe 'Get-AppCredentialExpiry' {
    BeforeEach {
        Mock -ModuleName EntraAppRegExpiryCheck Invoke-MgGraphRequest -ParameterFilter { $Uri -like '*/applications?$select=*' } -MockWith { $page1 }
        Mock -ModuleName EntraAppRegExpiryCheck Invoke-MgGraphRequest -ParameterFilter { $Uri -like '*$skiptoken=page2*' } -MockWith { $page2 }
        Mock -ModuleName EntraAppRegExpiryCheck Invoke-MgGraphRequest -ParameterFilter { $Uri -like '*/servicePrincipals?*' } -MockWith { $servicePrincipals }
    }

    It 'follows the next link and returns one record per credential' {
        $records = @(Get-AppCredentialExpiry -AsOf $asOf)
        $records.Count | Should -Be 6
        Should -Invoke Invoke-MgGraphRequest -ModuleName EntraAppRegExpiryCheck -Times 2 -Exactly
    }

    It 'classifies each credential against the threshold' {
        $records = @(Get-AppCredentialExpiry -AsOf $asOf)
        ($records | Where-Object CredentialName -eq 'prod-2025').Status | Should -Be 'Expired'
        ($records | Where-Object CredentialName -eq 'graph-sync').Status | Should -Be 'Expiring'
        ($records | Where-Object CredentialName -eq 'CN=reporting-worker').DaysRemaining | Should -Be 7
        ($records | Where-Object CredentialName -eq 'prod-2026').Status | Should -Be 'Healthy'
    }

    It 'uses a wider threshold when asked' {
        $records = @(Get-AppCredentialExpiry -AsOf $asOf -ThresholdDays 200)
        ($records | Where-Object CredentialName -eq 'prod-2026').Status | Should -Be 'Expiring'
    }

    It 'decodes certificate thumbprints' {
        $certificate = Get-AppCredentialExpiry -AsOf $asOf | Where-Object CredentialName -eq 'CN=hr-sync'
        $certificate.Thumbprint | Should -Be '3F2A9C4E1B7D8A0F6C5E4D3B2A1908F7E6D5C4B3'
    }

    It 'marks excluded credentials and keeps them in the output' {
        $legacy = Get-AppCredentialExpiry -AsOf $asOf -ExclusionPath $exclusionPath | Where-Object AppDisplayName -eq 'legacy-portal'
        $legacy.Excluded | Should -BeTrue
        $legacy.ExclusionReason | Should -BeLike 'Decommissioned*'
        $legacy.Status | Should -Be 'Expired'
    }

    It 'falls back to the object ID when an owner has no readable name' {
        $worker = Get-AppCredentialExpiry -AsOf $asOf -IncludeOwners | Where-Object AppDisplayName -eq 'reporting-worker'
        $worker.OwnerContacts | Should -Be '0bbe0000-0000-4000-8000-000000000003'
    }

    It 'asks Graph for owners only when -IncludeOwners is set' {
        $null = Get-AppCredentialExpiry -AsOf $asOf -IncludeOwners
        Should -Invoke Invoke-MgGraphRequest -ModuleName EntraAppRegExpiryCheck -ParameterFilter { $Uri -like '*$expand=owners*' } -Times 1 -Exactly
    }

    Context 'with -IncludeServicePrincipals' {
        It 'reports a SAML certificate once and skips managed identities' {
            $records = @(Get-AppCredentialExpiry -AsOf $asOf -IncludeServicePrincipals | Where-Object ObjectType -eq 'ServicePrincipal')
            $records.AppDisplayName | Should -Not -Contain 'automation-account-identity'
            @($records | Where-Object CredentialType -eq 'Certificate').Count | Should -Be 1
            ($records | Where-Object CredentialType -eq 'Certificate').KeyUsage | Should -Be 'Verify'
        }
    }
}

Describe 'Measure-AppCredentialExpiry' {
    BeforeAll {
        Mock -ModuleName EntraAppRegExpiryCheck Invoke-MgGraphRequest -ParameterFilter { $Uri -like '*/applications?$select=*' } -MockWith { $page1 }
        Mock -ModuleName EntraAppRegExpiryCheck Invoke-MgGraphRequest -ParameterFilter { $Uri -like '*$skiptoken=page2*' } -MockWith { $page2 }
        $script:records = @(Get-AppCredentialExpiry -AsOf $asOf -ExclusionPath $exclusionPath)
    }

    It 'counts excluded credentials separately from their status' {
        $summary = Measure-AppCredentialExpiry -InputObject $records
        $summary.credentials | Should -Be 6
        $summary.applications | Should -Be 4
        $summary.expired | Should -Be 1
        $summary.expiring | Should -Be 2
        $summary.healthy | Should -Be 2
        $summary.excluded | Should -Be 1
    }

    It 'handles an empty list' {
        $summary = Measure-AppCredentialExpiry -InputObject @()
        $summary.credentials | Should -Be 0
        $summary.applications | Should -Be 0
    }
}

Describe 'Export-AppCredentialExpiryReport' {
    BeforeAll {
        Mock -ModuleName EntraAppRegExpiryCheck Invoke-MgGraphRequest -ParameterFilter { $Uri -like '*/applications?$select=*' } -MockWith { $page1 }
        Mock -ModuleName EntraAppRegExpiryCheck Invoke-MgGraphRequest -ParameterFilter { $Uri -like '*$skiptoken=page2*' } -MockWith { $page2 }
        $script:records = @(Get-AppCredentialExpiry -AsOf $asOf -IncludeOwners)
    }

    It 'writes JSON with ISO dates and a summary, soonest expiry first' {
        $folder = Join-Path $TestDrive 'json'
        $null = Export-AppCredentialExpiryReport -InputObject $records -Path $folder -Format Json -ThresholdDays 30

        $text = Get-Content -Raw (Join-Path $folder 'credential-expiry.json')
        # Checked on the raw text: PowerShell 7's ConvertFrom-Json would turn the string back into a DateTime.
        $text | Should -Match '"endDateTime":\s*"2026-06-01T00:00:00Z"'

        $report = $text | ConvertFrom-Json
        $report.thresholdDays | Should -Be 30
        $report.summary.credentials | Should -Be 6
        $report.credentials[0].appDisplayName | Should -Be 'legacy-portal'
    }

    It 'writes one CSV row per credential with owners in one column' {
        $folder = Join-Path $TestDrive 'csv'
        $null = Export-AppCredentialExpiryReport -InputObject $records -Path $folder -Format Csv

        $rows = @(Import-Csv (Join-Path $folder 'credential-expiry.csv'))
        $rows.Count | Should -Be 6
        ($rows | Where-Object CredentialName -eq 'prod-2025').OwnerContacts | Should -Be 'ana.ruiz@contoso.com'
    }

    It 'writes a header-only CSV when there are no records' {
        $folder = Join-Path $TestDrive 'empty'
        $null = Export-AppCredentialExpiryReport -InputObject @() -Path $folder -Format Csv
        (Get-Content (Join-Path $folder 'credential-expiry.csv') | Select-Object -First 1) | Should -BeLike '"ObjectType",*'
    }
}
