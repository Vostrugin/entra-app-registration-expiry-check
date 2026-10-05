function ConvertTo-UtcDateTime {
    <#
    .SYNOPSIS
    Normalises a Microsoft Graph timestamp to a UTC DateTime.

    .DESCRIPTION
    Depending on the PowerShell version and on how the JSON was parsed, Graph timestamps arrive as
    strings ("2026-11-02T10:15:00Z"), as DateTime values, or as DateTimeOffset values. All of them
    come out of this function as a DateTime with Kind = Utc. Graph always returns UTC, so a DateTime
    with an unspecified kind is treated as UTC rather than shifted.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [AllowNull()]
        $Value
    )

    process {
        if ($null -eq $Value) {
            return $null
        }

        if ($Value -is [datetime]) {
            if ($Value.Kind -eq [DateTimeKind]::Unspecified) {
                return [datetime]::SpecifyKind($Value, [DateTimeKind]::Utc)
            }
            return $Value.ToUniversalTime()
        }

        if ($Value -is [datetimeoffset]) {
            return $Value.UtcDateTime
        }

        $text = [string]$Value
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $null
        }

        $styles = [Globalization.DateTimeStyles]::AssumeUniversal
        return [datetimeoffset]::Parse($text, [Globalization.CultureInfo]::InvariantCulture, $styles).UtcDateTime
    }
}
