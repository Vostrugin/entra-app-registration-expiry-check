function Export-AppCredentialExpiryReport {
    <#
    .SYNOPSIS
    Writes credential records to a JSON report, a CSV file, or both.

    .DESCRIPTION
    The JSON report has a summary and every record, including owners, with dates as ISO 8601 UTC
    strings. The CSV has one row per credential and puts owners in a single column. Both are
    sorted by end date, soonest first. Returns the files it wrote.

    .PARAMETER Path
    The folder to write into. It's created if it doesn't exist.

    .PARAMETER ThresholdDays
    Recorded in the JSON report so a reader knows what "Expiring" meant for this run.

    .EXAMPLE
    Get-AppCredentialExpiry | Export-AppCredentialExpiryReport -Path ./report
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $InputObject,

        [Parameter(Mandatory)]
        [string] $Path,

        [ValidateSet('Json', 'Csv')]
        [string[]] $Format = @('Json', 'Csv'),

        [ValidatePattern('^[\w.-]+$')]
        [string] $BaseName = 'credential-expiry',

        [int] $ThresholdDays
    )

    begin {
        $records = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($record in @($InputObject)) {
            if ($null -ne $record) {
                $records.Add($record)
            }
        }
    }

    end {
        $folder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $folder -Force
        }

        # Records without an end date sort last.
        $sorted = @($records | Sort-Object -Property @{ Expression = { if ($null -eq $_.EndDateTime) { [datetime]::MaxValue } else { $_.EndDateTime } } })

        # JSON without a byte order mark, because some parsers (jq among them) reject one. CSV with a
        # byte order mark, because Excel needs it to read non-ASCII app names correctly.
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)

        if ($Format -contains 'Json') {
            $threshold = $null
            if ($PSBoundParameters.ContainsKey('ThresholdDays')) {
                $threshold = $ThresholdDays
            }

            $report = [ordered]@{
                generatedAt   = Format-IsoUtc ([datetime]::UtcNow)
                thresholdDays = $threshold
                summary       = Measure-AppCredentialExpiry -InputObject $records
                credentials   = @($sorted | ConvertTo-ReportObject)
            }

            $jsonPath = Join-Path $folder "$BaseName.json"
            [System.IO.File]::WriteAllText($jsonPath, ($report | ConvertTo-Json -Depth 6), $utf8NoBom)
            Get-Item -LiteralPath $jsonPath
        }

        if ($Format -contains 'Csv') {
            $rows = foreach ($record in $sorted) {
                [pscustomobject][ordered]@{
                    ObjectType      = $record.ObjectType
                    AppDisplayName  = $record.AppDisplayName
                    AppId           = $record.AppId
                    ObjectId        = $record.ObjectId
                    CredentialType  = $record.CredentialType
                    CredentialName  = $record.CredentialName
                    KeyId           = $record.KeyId
                    Thumbprint      = $record.Thumbprint
                    SecretHint      = $record.SecretHint
                    StartDateTime   = Format-IsoUtc $record.StartDateTime
                    EndDateTime     = Format-IsoUtc $record.EndDateTime
                    DaysRemaining   = $record.DaysRemaining
                    Status          = $record.Status
                    Excluded        = $record.Excluded
                    ExclusionReason = $record.ExclusionReason
                    OwnerContacts   = $record.OwnerContacts
                }
            }

            $csvPath = Join-Path $folder "$BaseName.csv"
            if ($null -eq $rows) {
                # Export-Csv writes nothing at all for an empty input, so write the header row by hand.
                $header = '"ObjectType","AppDisplayName","AppId","ObjectId","CredentialType","CredentialName","KeyId","Thumbprint","SecretHint","StartDateTime","EndDateTime","DaysRemaining","Status","Excluded","ExclusionReason","OwnerContacts"'
                [System.IO.File]::WriteAllText($csvPath, $header + [Environment]::NewLine, $utf8WithBom)
            }
            else {
                $lines = $rows | ConvertTo-Csv -NoTypeInformation
                [System.IO.File]::WriteAllLines($csvPath, [string[]]$lines, $utf8WithBom)
            }
            Get-Item -LiteralPath $csvPath
        }
    }
}
