function ConvertTo-ReportObject {
    <#
    .SYNOPSIS
    Shapes a credential record for the JSON report.

    .DESCRIPTION
    Uses camelCase names and ISO 8601 UTC strings for dates. Windows PowerShell's ConvertTo-Json
    would otherwise write DateTime values as "\/Date(...)\/", which most tools can't read.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Record
    )

    process {
        [ordered]@{
            objectType      = $Record.ObjectType
            objectId        = $Record.ObjectId
            appId           = $Record.AppId
            appDisplayName  = $Record.AppDisplayName
            credentialType  = $Record.CredentialType
            credentialName  = $Record.CredentialName
            keyId           = $Record.KeyId
            thumbprint      = $Record.Thumbprint
            keyUsage        = $Record.KeyUsage
            secretHint      = $Record.SecretHint
            startDateTime   = Format-IsoUtc $Record.StartDateTime
            endDateTime     = Format-IsoUtc $Record.EndDateTime
            daysRemaining   = $Record.DaysRemaining
            status          = $Record.Status
            excluded        = [bool]$Record.Excluded
            exclusionReason = $Record.ExclusionReason
            owners          = @(foreach ($owner in @($Record.Owners)) {
                    if ($null -ne $owner) {
                        [ordered]@{
                            id                = $owner.Id
                            type              = $owner.Type
                            displayName       = $owner.DisplayName
                            userPrincipalName = $owner.UserPrincipalName
                            mail              = $owner.Mail
                        }
                    }
                })
        }
    }
}

function Format-IsoUtc {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    return ([datetime]$Value).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture)
}
