<#
.SYNOPSIS
Azure Automation runbook that reports expired and expiring App Registration credentials.

.DESCRIPTION
Runs on a PowerShell 7.2 or later runtime and signs in with the Automation account's managed
identity. It writes a summary and one line per credential that needs attention to the job output,
then fails the job when a credential has expired (and, with FailOnExpiring, when one is about to),
so an Azure Monitor alert on failed jobs tells you. A sign-in or Graph error also fails the job,
and the job's exception says which happened.

Setup is described in README.md in this folder.

.PARAMETER ThresholdDays
How many days ahead a credential counts as expiring.

.PARAMETER IncludeOwners
Also read each app's owners. Give the identity User.Read.All to get names instead of object IDs.

.PARAMETER FailOnExpiring
Fail the job for expiring credentials as well as expired ones. On by default, so you hear about a
credential before it breaks something rather than after.

.PARAMETER ManagedIdentityClientId
Client ID of a user-assigned managed identity. Leave empty to use the system-assigned identity.

.PARAMETER ExclusionVariableName
Name of an Automation string variable that holds the exclusions JSON. Leave empty for none.
#>
param(
    [int] $ThresholdDays = 30,
    [bool] $IncludeOwners = $false,
    [bool] $FailOnExpiring = $true,
    [string] $ManagedIdentityClientId = '',
    [string] $ExclusionVariableName = ''
)

$ErrorActionPreference = 'Stop'

$connect = @{ Identity = $true; NoWelcome = $true }
if ($ManagedIdentityClientId) {
    $connect.ClientId = $ManagedIdentityClientId
}
Connect-MgGraph @connect

$query = @{
    ThresholdDays = $ThresholdDays
    IncludeOwners = $IncludeOwners
}

if ($ExclusionVariableName) {
    # The module reads exclusions from a file, so write the variable's JSON to the sandbox's temp folder.
    $exclusionPath = Join-Path ([System.IO.Path]::GetTempPath()) 'exclusions.json'
    Set-Content -LiteralPath $exclusionPath -Value (Get-AutomationVariable -Name $ExclusionVariableName) -Encoding UTF8
    $query.ExclusionPath = $exclusionPath
}

$records = @(Get-AppCredentialExpiry @query)
$summary = Measure-AppCredentialExpiry -InputObject $records

Write-Output ('Checked {0} credentials across {1} apps. Threshold: {2} days.' -f $summary.credentials, $summary.applications, $ThresholdDays)
Write-Output ('Expired: {0}, expiring: {1}, healthy: {2}, excluded: {3}.' -f $summary.expired, $summary.expiring, $summary.healthy, $summary.excluded)

$attention = @($records |
        Where-Object { -not $_.Excluded -and $_.Status -in 'Expired', 'Expiring' } |
        Sort-Object -Property EndDateTime)

foreach ($record in $attention) {
    Write-Output ('{0,-8} {1,5} days  {2} | {3} {4} | ends {5:yyyy-MM-dd HH:mm} UTC | owners: {6}' -f
        $record.Status, $record.DaysRemaining, $record.AppDisplayName, $record.CredentialType,
        $record.CredentialName, $record.EndDateTime, $record.OwnerContacts)
}

$null = Disconnect-MgGraph

if ($summary.expired -gt 0) {
    throw ('{0} credential(s) have expired. The job output lists them.' -f $summary.expired)
}

if ($FailOnExpiring -and $summary.expiring -gt 0) {
    throw ('{0} credential(s) expire within {1} days. The job output lists them.' -f $summary.expiring, $ThresholdDays)
}
