function ConvertFrom-CustomKeyIdentifier {
    <#
    .SYNOPSIS
    Turns a certificate's customKeyIdentifier into its thumbprint.

    .DESCRIPTION
    When a certificate is uploaded through the Entra admin center or Microsoft Graph, its
    customKeyIdentifier holds the SHA-1 thumbprint as base64-encoded bytes. This returns the familiar
    40-character hex string. Anything else (a missing value, invalid base64, or a value that isn't
    20 bytes long, which happens when a tool set its own identifier) returns $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        $Value
    )

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    try {
        $bytes = [Convert]::FromBase64String($text)
    }
    catch {
        return $null
    }

    if ($bytes.Length -ne 20) {
        return $null
    }

    return ([BitConverter]::ToString($bytes)).Replace('-', '')
}
