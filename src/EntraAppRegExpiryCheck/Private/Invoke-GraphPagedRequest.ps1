function Invoke-GraphPagedRequest {
    <#
    .SYNOPSIS
    Runs a Microsoft Graph GET request and follows @odata.nextLink until every page has been read.

    .DESCRIPTION
    Emits the items from each page's "value" array as they arrive. Throttling (429) and transient
    errors (503, 504) are retried by the Microsoft Graph PowerShell SDK itself, so there is no retry
    loop here. Any other error stops the run, because a partial inventory would under-report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Uri
    )

    $next = $Uri
    $page = 0

    while (-not [string]::IsNullOrEmpty($next)) {
        $page++
        Write-Verbose "GET page $page"
        $response = Invoke-MgGraphRequest -Method GET -Uri $next

        foreach ($item in @($response.value)) {
            if ($null -ne $item) {
                $item
            }
        }

        $next = [string]$response.'@odata.nextLink'
    }
}
