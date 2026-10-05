<#
.SYNOPSIS
Grants Microsoft Graph application permissions to a managed identity or any other service principal.

.DESCRIPTION
The Entra admin center can't grant Microsoft Graph application permissions to a managed identity,
so this script creates the app role assignments through Microsoft Graph instead. Run it once,
interactively, as a Privileged Role Administrator or Global Administrator.

Permissions that are already granted are left alone, so running it twice is safe.

.PARAMETER PrincipalObjectId
The object (principal) ID of the managed identity. In the Azure portal it's on the resource's
Identity page; for a user-assigned identity, on the identity's Overview page.

.PARAMETER Permission
Microsoft Graph application permissions to grant. Application.Read.All is all the check needs.
Add User.Read.All if you run it with -IncludeOwners and want owner names and email addresses.

.PARAMETER TenantId
The tenant to sign in to, if your account belongs to more than one.

.EXAMPLE
./Grant-GraphAppRole.ps1 -PrincipalObjectId 11111111-2222-3333-4444-555555555555

.EXAMPLE
./Grant-GraphAppRole.ps1 -PrincipalObjectId 11111111-2222-3333-4444-555555555555 -Permission Application.Read.All, User.Read.All -WhatIf
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive, one-off admin script.')]
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string] $PrincipalObjectId,

    [string[]] $Permission = @('Application.Read.All'),

    [string] $TenantId
)

$ErrorActionPreference = 'Stop'
$graphAppId = '00000003-0000-0000-c000-000000000000'
$graphRoot = 'https://graph.microsoft.com/v1.0'

$connect = @{ Scopes = @('Application.Read.All', 'AppRoleAssignment.ReadWrite.All'); NoWelcome = $true }
if ($TenantId) {
    $connect.TenantId = $TenantId
}
Connect-MgGraph @connect

$graph = @((Invoke-MgGraphRequest -Method GET -Uri "$graphRoot/servicePrincipals?`$filter=appId eq '$graphAppId'&`$select=id,appRoles").value)[0]
if (-not $graph) {
    throw 'Could not find the Microsoft Graph service principal in this tenant.'
}

$principal = Invoke-MgGraphRequest -Method GET -Uri "$graphRoot/servicePrincipals/$PrincipalObjectId`?`$select=id,displayName,servicePrincipalType"
Write-Host ('Granting to {0} ({1}, {2})' -f $principal.displayName, $principal.servicePrincipalType, $principal.id)

$existing = @((Invoke-MgGraphRequest -Method GET -Uri "$graphRoot/servicePrincipals/$PrincipalObjectId/appRoleAssignments").value |
        Where-Object { $_.resourceId -eq $graph.id } |
        ForEach-Object { $_.appRoleId })

foreach ($name in $Permission) {
    $role = @($graph.appRoles | Where-Object { $_.value -eq $name -and $_.allowedMemberTypes -contains 'Application' })[0]
    if (-not $role) {
        throw "Microsoft Graph has no application permission called '$name'."
    }

    if ($existing -contains $role.id) {
        Write-Host "  $name is already granted."
        continue
    }

    if ($PSCmdlet.ShouldProcess($principal.displayName, "Grant Microsoft Graph application permission $name")) {
        $body = @{
            principalId = $PrincipalObjectId
            resourceId  = $graph.id
            appRoleId   = $role.id
        }
        $null = Invoke-MgGraphRequest -Method POST -Uri "$graphRoot/servicePrincipals/$PrincipalObjectId/appRoleAssignments" -Body $body
        Write-Host "  $name granted."
    }
}
