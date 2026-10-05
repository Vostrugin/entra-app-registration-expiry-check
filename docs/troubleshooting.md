# Troubleshooting

## "Insufficient privileges" or 403 Authorization_RequestDenied

The identity that signed in doesn't have `Application.Read.All`, or it has the permission without admin consent. For unattended sign-in it has to be an application permission, not a delegated one. Check the App Registration's API permissions page, or for a managed identity, its Enterprise application's Permissions page, and look for "Granted for <your tenant>".

A token issued before consent was granted doesn't pick the permission up. Sign in again, or wait for the next run to get a fresh token.

## 401 InvalidAuthenticationToken

Usually the token was issued for the wrong API. `az account get-access-token` without `--resource-type ms-graph` returns a token for Azure Resource Manager, which Microsoft Graph rejects. The other common cause is an expired token: Azure CLI tokens last roughly an hour, so request one right before the check runs, not at the start of a long pipeline.

## Get-MgApplication returns empty PasswordCredentials

This comes up when people adapt the check to the Microsoft Graph SDK. `Get-MgApplication -Property ...` returns only the properties you list, and everything else comes back empty. Include `passwordCredentials` and `keyCredentials` in `-Property`, and add `-All`, or you only get the first page of apps.

## Owners show up as object IDs

Microsoft Graph returns owners it isn't allowed to read with only their ID. Add `User.Read.All` as an application permission for unattended runs; interactive runs request `User.ReadBasic.All` automatically with `-IncludeOwners`. See [Authentication](authentication.md#owners-need-one-more-permission).

## Connect-MgGraph -Identity fails in Azure Automation

Check three things:

- The Automation account has a system-assigned managed identity turned on, or the user-assigned identity you passed with `-ManagedIdentityClientId` is attached to it.
- `Microsoft.Graph.Authentication` is imported into the runtime environment the runbook uses, for the same PowerShell version as the runbook.
- The identity has been granted the Graph permission with [Grant-GraphAppRole.ps1](../examples/azure-automation/Grant-GraphAppRole.ps1). The portal's Azure role assignments page doesn't cover Microsoft Graph permissions.

## "Could not load file or assembly" or "Assembly with same name is already loaded"

This is commonly reported when `Microsoft.Graph.Authentication` and the `Az` modules are loaded in the same PowerShell session, because each ships its own copy of shared identity libraries in different versions. Run the check in its own session, or import `Microsoft.Graph.Authentication` before any `Az` module.

## "The file is not digitally signed"

Windows blocks scripts extracted from a downloaded ZIP when the execution policy is `RemoteSigned`. Run `Get-ChildItem -Recurse | Unblock-File` in the repository folder.

## Dates look a few hours off

Every date in the console, the report, and the records is UTC. Convert with `.ToLocalTime()` if you need local time.

## A certificate has no thumbprint

The thumbprint comes from the certificate's `customKeyIdentifier`, which some tools fill with their own value. The certificate is still checked; only the thumbprint column is empty. See [How it works](how-it-works.md#certificates).

## The same expiry date shows up twice

With `-IncludeServicePrincipals`, each SAML signing certificate appears once as a certificate and once as a client secret, because Entra stores a password credential with it. Outside SAML apps, two entries with the same date are usually two separate credentials that were created together.

## The check finds nothing

Make sure you signed in to the right tenant; pass `-TenantId` if your account belongs to several. Apps your organization uses but didn't register, such as SaaS products, have their credentials in the publisher's tenant, so they won't appear at all.

## The scheduled run stopped happening

- GitHub disables scheduled workflows in public repositories after 60 days with no activity. Re-enable the workflow from the Actions tab.
- Azure DevOps skips a scheduled run when nothing changed on the branch, unless the schedule sets `always: true`.
- Azure Automation schedules can have an expiry date. Open the schedule and check it.
- In every case, check whether the check's own credential has expired.
