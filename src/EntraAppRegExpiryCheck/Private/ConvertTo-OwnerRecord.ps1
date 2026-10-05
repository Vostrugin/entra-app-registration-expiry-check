function ConvertTo-OwnerRecord {
    <#
    .SYNOPSIS
    Maps one expanded owner (a user or a service principal) to a small, flat object.

    .DESCRIPTION
    Owners come back from Graph as directoryObjects. Without permission to read users, Graph still
    returns each owner but only with its id and type, so every other property here can be empty.
    Contact is the best available way to reach the owner: mail, then user principal name, then
    display name, then the object id.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        $Owner
    )

    if ($null -eq $Owner) {
        return
    }

    $type = [string]$Owner.'@odata.type'
    if ($type) {
        $type = $type -replace '^#microsoft\.graph\.', ''
    }
    else {
        $type = 'unknown'
    }

    $id = [string]$Owner.id
    $displayName = [string]$Owner.displayName
    $userPrincipalName = [string]$Owner.userPrincipalName
    $mail = [string]$Owner.mail

    $contact = $id
    foreach ($candidate in @($mail, $userPrincipalName, $displayName)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $contact = $candidate
            break
        }
    }

    [pscustomobject]@{
        Id                = $id
        Type              = $type
        DisplayName       = $displayName
        UserPrincipalName = $userPrincipalName
        Mail              = $mail
        Contact           = $contact
    }
}
