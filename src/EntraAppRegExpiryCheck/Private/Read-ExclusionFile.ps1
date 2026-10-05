function Read-ExclusionFile {
    <#
    .SYNOPSIS
    Loads an exclusions file into two case-insensitive lookups: by appId and by credential keyId.

    .DESCRIPTION
    The file is JSON with two optional arrays:

      {
        "applications": [ { "appId": "...", "reason": "...", "until": "2026-12-31" } ],
        "credentials":  [ { "keyId": "...", "reason": "...", "until": "2026-12-31" } ]
      }

    "until" is optional. Once that date has passed (compared with AsOf), the entry is ignored, so a
    temporary exclusion can't quietly become a permanent one. Each lookup maps an id to its reason.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [datetime] $AsOf
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Exclusion file not found: $Path"
    }

    try {
        $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Exclusion file '$Path' is not valid JSON: $($_.Exception.Message)"
    }

    $appIds = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    $keyIds = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    $lapsed = 0

    $sections = @(
        @{ Entries = $json.applications; IdProperty = 'appId'; Lookup = $appIds }
        @{ Entries = $json.credentials; IdProperty = 'keyId'; Lookup = $keyIds }
    )

    foreach ($section in $sections) {
        foreach ($entry in @($section.Entries)) {
            if ($null -eq $entry) {
                continue
            }

            $id = [string]$entry.($section.IdProperty)
            if ([string]::IsNullOrWhiteSpace($id)) {
                Write-Warning "Skipping an exclusion with no $($section.IdProperty) in $Path."
                continue
            }

            $until = ConvertTo-UtcDateTime $entry.until
            if ($null -ne $until -and $until -lt $AsOf) {
                $lapsed++
                continue
            }

            $section.Lookup[$id.Trim()] = [string]$entry.reason
        }
    }

    if ($lapsed -gt 0) {
        Write-Verbose "$lapsed exclusion(s) in $Path have passed their 'until' date and were ignored."
    }

    [pscustomobject]@{
        AppIds = $appIds
        KeyIds = $keyIds
    }
}
