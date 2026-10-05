function Get-CredentialStatus {
    <#
    .SYNOPSIS
    Classifies one credential as Expired, Expiring, Healthy, or Unknown.

    .DESCRIPTION
    Expired:  the end date is at or before AsOf.
    Expiring: the end date falls within ThresholdDays after AsOf.
    Healthy:  the end date is further out than that.
    Unknown:  Graph returned no end date.

    DaysRemaining is rounded down, so a secret that expires in 20 hours has 0 days remaining and
    one that expired two hours ago has -1.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        $EndDateTime,

        [Parameter(Mandatory)]
        [datetime] $AsOf,

        [Parameter(Mandatory)]
        [int] $ThresholdDays
    )

    if ($null -eq $EndDateTime) {
        return [pscustomobject]@{ Status = 'Unknown'; DaysRemaining = $null }
    }

    $end = [datetime]$EndDateTime
    $daysRemaining = [int][math]::Floor(($end - $AsOf).TotalDays)

    if ($end -le $AsOf) {
        $status = 'Expired'
    }
    elseif ($end -le $AsOf.AddDays($ThresholdDays)) {
        $status = 'Expiring'
    }
    else {
        $status = 'Healthy'
    }

    [pscustomobject]@{ Status = $status; DaysRemaining = $daysRemaining }
}
