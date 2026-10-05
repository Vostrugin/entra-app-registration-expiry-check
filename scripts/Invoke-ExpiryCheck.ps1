<#
.SYNOPSIS
Checks every App Registration in the tenant for expired and expiring client secrets and certificates.

.DESCRIPTION
Signs in to Microsoft Graph, reads every App Registration's credentials, prints the ones that need
attention, optionally writes JSON and CSV reports, and exits with a code a scheduler or pipeline can
act on:

  0  Nothing needs attention.
  1  The check itself failed: sign-in, permissions, or a Microsoft Graph error.
  2  At least one credential expires within -ThresholdDays. None have expired.
  3  At least one credential has expired.

Excluded credentials never affect the exit code.

Pick one way to sign in:
  (none of the below)     Interactive, delegated sign-in. For running it yourself.
  -ManagedIdentity        Azure Automation, Azure Functions, or an Azure VM.
  -AccessToken            A Graph token you already have, e.g. from workload identity federation
                          in GitHub Actions or Azure DevOps.
  -CertificateThumbprint  An App Registration with a certificate, for anything else.
  -UseExistingConnection  Reuse a Connect-MgGraph session you opened yourself.

.EXAMPLE
./scripts/Invoke-ExpiryCheck.ps1 -ThresholdDays 30 -IncludeOwners -OutputPath ./report

.EXAMPLE
./scripts/Invoke-ExpiryCheck.ps1 -ManagedIdentity -ExclusionPath ./exclusions.json

.EXAMPLE
$token = az account get-access-token --resource-type ms-graph --query accessToken -o tsv |
    ConvertTo-SecureString -AsPlainText -Force
./scripts/Invoke-ExpiryCheck.ps1 -AccessToken $token -OutputPath ./report
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console report for people reading CI logs; results go to files and -PassThru.')]
[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    [Parameter(Mandatory, ParameterSetName = 'ManagedIdentity')]
    [switch] $ManagedIdentity,

    # Client ID of a user-assigned managed identity. Leave empty for a system-assigned identity.
    [Parameter(ParameterSetName = 'ManagedIdentity')]
    [string] $ManagedIdentityClientId,

    [Parameter(Mandatory, ParameterSetName = 'Certificate')]
    [Parameter(ParameterSetName = 'Interactive')]
    [string] $TenantId,

    [Parameter(Mandatory, ParameterSetName = 'Certificate')]
    [string] $ClientId,

    [Parameter(Mandatory, ParameterSetName = 'Certificate')]
    [string] $CertificateThumbprint,

    [Parameter(Mandatory, ParameterSetName = 'AccessToken')]
    [securestring] $AccessToken,

    [Parameter(Mandatory, ParameterSetName = 'ExistingConnection')]
    [switch] $UseExistingConnection,

    [ValidateRange(0, 3650)]
    [int] $ThresholdDays = 30,

    [switch] $IncludeOwners,

    [switch] $IncludeServicePrincipals,

    [string] $ExclusionPath,

    # Folder for the JSON and CSV reports. Nothing is written when this is empty.
    [string] $OutputPath,

    [ValidateSet('Json', 'Csv')]
    [string[]] $Format = @('Json', 'Csv'),

    # Also send the credential records down the pipeline.
    [switch] $PassThru
)

$ErrorActionPreference = 'Stop'
$exitCode = 1
$connectedHere = $false

try {
    $modulePath = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'EntraAppRegExpiryCheck'
    Import-Module (Join-Path $modulePath 'EntraAppRegExpiryCheck.psd1') -Force

    switch ($PSCmdlet.ParameterSetName) {
        'ManagedIdentity' {
            $connect = @{ Identity = $true; NoWelcome = $true }
            if ($ManagedIdentityClientId) {
                $connect.ClientId = $ManagedIdentityClientId
            }
            Connect-MgGraph @connect
            $connectedHere = $true
        }
        'Certificate' {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
            $connectedHere = $true
        }
        'AccessToken' {
            Connect-MgGraph -AccessToken $AccessToken -NoWelcome
            $connectedHere = $true
        }
        'ExistingConnection' {
            if (-not (Get-MgContext)) {
                throw 'There is no Microsoft Graph connection to reuse. Run Connect-MgGraph first, or choose another sign-in option.'
            }
        }
        default {
            $scopes = @('Application.Read.All')
            if ($IncludeOwners) {
                $scopes += 'User.ReadBasic.All'
            }
            $connect = @{ Scopes = $scopes; NoWelcome = $true }
            if ($TenantId) {
                $connect.TenantId = $TenantId
            }
            Connect-MgGraph @connect
            $connectedHere = $true
        }
    }

    $query = @{
        ThresholdDays            = $ThresholdDays
        IncludeOwners            = $IncludeOwners
        IncludeServicePrincipals = $IncludeServicePrincipals
    }
    if ($ExclusionPath) {
        $query.ExclusionPath = $ExclusionPath
    }

    $records = @(Get-AppCredentialExpiry @query)
    $summary = Measure-AppCredentialExpiry -InputObject $records

    Write-Host ('Checked {0} credentials across {1} apps. Threshold: {2} days.' -f $summary.credentials, $summary.applications, $ThresholdDays)
    Write-Host ('Expired: {0}   Expiring: {1}   Healthy: {2}   Excluded: {3}' -f $summary.expired, $summary.expiring, $summary.healthy, $summary.excluded)
    if ($summary.unknown -gt 0) {
        Write-Host ('{0} credential(s) have no end date in Graph and were not classified.' -f $summary.unknown)
    }

    $attention = @($records |
            Where-Object { -not $_.Excluded -and $_.Status -in 'Expired', 'Expiring' } |
            Sort-Object -Property EndDateTime)

    if ($attention.Count -gt 0) {
        $columns = @(
            'Status'
            @{ Name = 'Days'; Expression = { $_.DaysRemaining } }
            @{ Name = 'App'; Expression = { $_.AppDisplayName } }
            @{ Name = 'Type'; Expression = { $_.CredentialType } }
            @{ Name = 'Name'; Expression = { $_.CredentialName } }
            @{ Name = 'Expires (UTC)'; Expression = { $_.EndDateTime.ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture) } }
        )
        if ($IncludeOwners) {
            $columns += @{ Name = 'Owners'; Expression = { $_.OwnerContacts } }
        }

        Write-Host ''
        Write-Host (($attention | Select-Object -Property $columns | Format-Table -AutoSize | Out-String -Width 240).TrimEnd())
    }

    if ($OutputPath) {
        $files = @(Export-AppCredentialExpiryReport -InputObject $records -Path $OutputPath -Format $Format -ThresholdDays $ThresholdDays)
        Write-Host ''
        Write-Host ('Report written to: {0}' -f (($files | ForEach-Object { $_.FullName }) -join ', '))
    }

    if ($PassThru) {
        $records
    }

    if ($summary.expired -gt 0) {
        $exitCode = 3
    }
    elseif ($summary.expiring -gt 0) {
        $exitCode = 2
    }
    else {
        $exitCode = 0
    }
}
catch {
    $exitCode = 1
    $message = $_.Exception.Message
    if ($message -match 'Authorization_RequestDenied|Insufficient privileges|Forbidden|\b403\b') {
        $message += ' The signed-in identity needs the Microsoft Graph Application.Read.All permission, with admin consent. See docs/authentication.md.'
    }
    Write-Error -Message "Credential expiry check failed: $message" -ErrorAction Continue
}
finally {
    if ($connectedHere) {
        $null = Disconnect-MgGraph -ErrorAction SilentlyContinue
    }
}

exit $exitCode
