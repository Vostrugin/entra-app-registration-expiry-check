function ConvertTo-CredentialRecord {
    <#
    .SYNOPSIS
    Turns one Graph application (or service principal) into one record per secret and certificate.

    .DESCRIPTION
    A certificate stored with its private key, as Entra does for SAML signing on a service
    principal, appears twice in keyCredentials: once with usage "Sign" and once with usage
    "Verify", with the same identifier and dates. The "Sign" copy is skipped when its "Verify" twin
    is present, so each certificate is reported once.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $InputObject,

        [Parameter(Mandatory)]
        [ValidateSet('Application', 'ServicePrincipal')]
        [string] $ObjectType,

        [Parameter(Mandatory)]
        [datetime] $AsOf,

        [Parameter(Mandatory)]
        [int] $ThresholdDays,

        # Output of Read-ExclusionFile, or $null when no exclusions are in use.
        $Exclusions
    )

    $owners = @(foreach ($owner in @($InputObject.owners)) { ConvertTo-OwnerRecord $owner })
    $ownerContacts = ($owners | ForEach-Object { $_.Contact }) -join '; '

    $appId = [string]$InputObject.appId
    $credentials = [System.Collections.Generic.List[object]]::new()

    foreach ($secret in @($InputObject.passwordCredentials)) {
        if ($null -ne $secret) {
            $credentials.Add([pscustomobject]@{ Type = 'ClientSecret'; Value = $secret })
        }
    }

    $keys = @($InputObject.keyCredentials | Where-Object { $null -ne $_ })
    $verifyIds = @($keys | Where-Object { [string]$_.usage -eq 'Verify' } | ForEach-Object { [string]$_.customKeyIdentifier })
    foreach ($key in $keys) {
        $isSignTwin = [string]$key.usage -eq 'Sign' -and
            -not [string]::IsNullOrEmpty([string]$key.customKeyIdentifier) -and
            $verifyIds -contains [string]$key.customKeyIdentifier
        if (-not $isSignTwin) {
            $credentials.Add([pscustomobject]@{ Type = 'Certificate'; Value = $key })
        }
    }

    foreach ($credential in $credentials) {
        $value = $credential.Value
        $end = ConvertTo-UtcDateTime $value.endDateTime
        $state = Get-CredentialStatus -EndDateTime $end -AsOf $AsOf -ThresholdDays $ThresholdDays
        $keyId = [string]$value.keyId

        $exclusionReason = $null
        if ($null -ne $Exclusions) {
            if ($keyId -and $Exclusions.KeyIds.ContainsKey($keyId)) {
                $exclusionReason = $Exclusions.KeyIds[$keyId]
            }
            elseif ($appId -and $Exclusions.AppIds.ContainsKey($appId)) {
                $exclusionReason = $Exclusions.AppIds[$appId]
            }
        }

        $thumbprint = $null
        $secretHint = $null
        $keyUsage = $null
        if ($credential.Type -eq 'Certificate') {
            $thumbprint = ConvertFrom-CustomKeyIdentifier $value.customKeyIdentifier
            $keyUsage = [string]$value.usage
        }
        else {
            $secretHint = [string]$value.hint
        }

        [pscustomobject]@{
            PSTypeName      = 'EntraAppRegExpiryCheck.Credential'
            ObjectType      = $ObjectType
            ObjectId        = [string]$InputObject.id
            AppId           = $appId
            AppDisplayName  = [string]$InputObject.displayName
            CredentialType  = $credential.Type
            CredentialName  = [string]$value.displayName
            KeyId           = $keyId
            Thumbprint      = $thumbprint
            KeyUsage        = $keyUsage
            SecretHint      = $secretHint
            StartDateTime   = ConvertTo-UtcDateTime $value.startDateTime
            EndDateTime     = $end
            DaysRemaining   = $state.DaysRemaining
            Status          = $state.Status
            Excluded        = $null -ne $exclusionReason
            ExclusionReason = $exclusionReason
            Owners          = $owners
            OwnerContacts   = $ownerContacts
        }
    }
}
