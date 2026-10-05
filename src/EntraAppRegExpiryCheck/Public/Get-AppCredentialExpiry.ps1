function Get-AppCredentialExpiry {
    <#
    .SYNOPSIS
    Lists every client secret and certificate on the tenant's App Registrations, with its expiry status.

    .DESCRIPTION
    Reads App Registrations from Microsoft Graph v1.0 and returns one record per credential. Each
    record is classified as Expired, Expiring (ends within -ThresholdDays), Healthy, or Unknown
    (no end date).

    Needs an existing Microsoft Graph connection (Connect-MgGraph) whose token carries the
    Application.Read.All permission. The function only reads; it never changes the tenant.

    .PARAMETER ThresholdDays
    How many days ahead a credential counts as Expiring. Default 30.

    .PARAMETER IncludeOwners
    Also read each app's owners. Graph returns at most about 20 owners per app this way. To get names
    and email addresses rather than bare object IDs, the token also needs a user-read permission
    (User.Read.All for app-only sign-in, User.ReadBasic.All for interactive sign-in).

    .PARAMETER IncludeServicePrincipals
    Also report credentials added directly to service principals (Enterprise applications), such as
    SAML signing certificates. Managed identities are skipped because Azure rotates their
    credentials itself.

    .PARAMETER ExclusionPath
    Path to an exclusions JSON file. Excluded credentials are still returned, with Excluded = $true
    and the reason from the file. See docs/configuration.md for the format.

    .PARAMETER AsOf
    The moment to evaluate expiry against. Defaults to now. Mostly useful for tests and for
    "what will be expiring at the end of the month" questions.

    .EXAMPLE
    Connect-MgGraph -Scopes Application.Read.All
    Get-AppCredentialExpiry | Where-Object Status -ne 'Healthy'

    .EXAMPLE
    Get-AppCredentialExpiry -ThresholdDays 60 -IncludeOwners -ExclusionPath ./exclusions.json |
        Where-Object { -not $_.Excluded -and $_.Status -in 'Expired', 'Expiring' } |
        Sort-Object EndDateTime |
        Format-Table Status, DaysRemaining, AppDisplayName, CredentialType, CredentialName, OwnerContacts
    #>
    [CmdletBinding()]
    [OutputType('EntraAppRegExpiryCheck.Credential')]
    param(
        [ValidateRange(0, 3650)]
        [int] $ThresholdDays = 30,

        [switch] $IncludeOwners,

        [switch] $IncludeServicePrincipals,

        [string] $ExclusionPath,

        [datetime] $AsOf = [datetime]::UtcNow
    )

    if (-not (Get-Command -Name 'Invoke-MgGraphRequest' -ErrorAction SilentlyContinue)) {
        throw 'Invoke-MgGraphRequest was not found. Install the Microsoft Graph authentication module with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
    }

    $asOfUtc = ConvertTo-UtcDateTime $AsOf

    $exclusions = $null
    if ($ExclusionPath) {
        $exclusions = Read-ExclusionFile -Path $ExclusionPath -AsOf $asOfUtc
    }

    $select = 'id,appId,displayName,passwordCredentials,keyCredentials'
    if ($IncludeOwners) {
        # Expanded relationships stop at about 20 items and can't be paged, so keep Graph's default
        # page size here rather than asking for 999 objects at a time.
        $queryTail = '&$expand=owners($select=id,displayName,userPrincipalName,mail)'
    }
    else {
        $queryTail = '&$top=999'
    }

    $sources = [System.Collections.Generic.List[object]]::new()
    $sources.Add([pscustomobject]@{
            ObjectType = 'Application'
            Uri        = 'https://graph.microsoft.com/v1.0/applications?$select=' + $select + $queryTail
        })

    if ($IncludeServicePrincipals) {
        $sources.Add([pscustomobject]@{
                ObjectType = 'ServicePrincipal'
                Uri        = 'https://graph.microsoft.com/v1.0/servicePrincipals?$select=' + $select + ',servicePrincipalType' + $queryTail
            })
    }

    foreach ($source in $sources) {
        Write-Verbose "Reading $($source.ObjectType) objects from Microsoft Graph"
        $count = 0

        foreach ($item in (Invoke-GraphPagedRequest -Uri $source.Uri)) {
            $count++
            if ($source.ObjectType -eq 'ServicePrincipal' -and [string]$item.servicePrincipalType -eq 'ManagedIdentity') {
                continue
            }

            ConvertTo-CredentialRecord -InputObject $item -ObjectType $source.ObjectType -AsOf $asOfUtc -ThresholdDays $ThresholdDays -Exclusions $exclusions
        }

        Write-Verbose "Read $count $($source.ObjectType) objects"
    }
}
