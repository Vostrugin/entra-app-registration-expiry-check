function Measure-AppCredentialExpiry {
    <#
    .SYNOPSIS
    Counts credential records by status.

    .DESCRIPTION
    Expired, Expiring, Healthy, and Unknown count only credentials that aren't excluded. Excluded
    credentials are counted once, in Excluded, whatever their status. Applications is the number of
    distinct objects that have at least one credential.

    .EXAMPLE
    $records = Get-AppCredentialExpiry
    Measure-AppCredentialExpiry -InputObject $records
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $InputObject
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
        $active = @($records | Where-Object { -not $_.Excluded })

        [ordered]@{
            applications = @($records | ForEach-Object { $_.ObjectId } | Sort-Object -Unique).Count
            credentials  = $records.Count
            expired      = @($active | Where-Object { $_.Status -eq 'Expired' }).Count
            expiring     = @($active | Where-Object { $_.Status -eq 'Expiring' }).Count
            healthy      = @($active | Where-Object { $_.Status -eq 'Healthy' }).Count
            unknown      = @($active | Where-Object { $_.Status -eq 'Unknown' }).Count
            excluded     = @($records | Where-Object { $_.Excluded }).Count
        }
    }
}
