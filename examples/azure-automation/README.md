# Azure Automation

Runs the check daily as a runbook, signed in with the Automation account's managed identity, so there's no credential to store or rotate. A failed job is the alert.

| File | What it is |
| ---- | ---------- |
| [CredentialExpiryCheck.ps1](CredentialExpiryCheck.ps1) | The runbook. |
| [Grant-GraphAppRole.ps1](Grant-GraphAppRole.ps1) | One-off script that grants the managed identity its Microsoft Graph permission. |

## Setup

### 1. Turn on the managed identity

In the Automation account, open Identity, switch the system-assigned identity on, and copy its Object (principal) ID.

### 2. Grant the Graph permission

From your own machine, signed in as a Privileged Role Administrator or Global Administrator:

```powershell
./examples/azure-automation/Grant-GraphAppRole.ps1 -PrincipalObjectId <object-id>
```

Add `-Permission Application.Read.All, User.Read.All` if you'll run with owners and want their names. The portal can't do this step for a managed identity; that's why the script exists.

### 3. Add the modules

The runbook needs two modules in the runtime environment it runs on (PowerShell 7.2 or later):

- `Microsoft.Graph.Authentication`, from the PowerShell Gallery.
- `EntraAppRegExpiryCheck`, from this repository. Zip the module folder so the zip contains a folder named `EntraAppRegExpiryCheck`, then upload the zip as a custom module:

```powershell
Compress-Archive -Path ./src/EntraAppRegExpiryCheck -DestinationPath ./EntraAppRegExpiryCheck.zip
```

### 4. Create the runbook

Create a PowerShell runbook named `CredentialExpiryCheck` on the same runtime, paste in [CredentialExpiryCheck.ps1](CredentialExpiryCheck.ps1), and publish it. Start it once by hand and read the job output before you schedule it.

### 5. Optional: exclusions

Create a string variable in the Automation account, for example `ExpiryCheckExclusions`, paste the JSON from your exclusions file into it, and set the runbook's `ExclusionVariableName` parameter to that name. Variables don't keep history, so keep the original file in source control too.

### 6. Schedule it

Link the runbook to a daily schedule. Leave the schedule's expiry unset: a schedule that expires stops the check without any error.

## Parameters

| Parameter | Default | Notes |
| --------- | ------- | ----- |
| `ThresholdDays` | `30` | How many days ahead a credential counts as expiring. |
| `IncludeOwners` | `false` | Reads app owners into the job output. |
| `FailOnExpiring` | `true` | Fails the job for expiring credentials, not only expired ones. |
| `ManagedIdentityClientId` | empty | Set it to use a user-assigned identity instead of the system-assigned one. |
| `ExclusionVariableName` | empty | Name of the Automation variable holding the exclusions JSON. |

## Getting alerted

The runbook throws when something needs attention, which marks the job as Failed. Two alerts cover the rest:

- Failed jobs. In Azure Monitor, create an alert rule on the Automation account's `Total Jobs` metric, filtered to `Runbook name = CredentialExpiryCheck` and `Status = Failed`, with an action group that emails or messages your team. The job output says whether a credential expired or the check itself broke.
- No job at all. A schedule that stops firing produces no failed job, so the first alert stays quiet. If you send the account's job logs to a Log Analytics workspace (Diagnostic settings, category `JobLogs`), a log alert on this query catches it:

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.AUTOMATION" and Category == "JobLogs"
| where RunbookName_s == "CredentialExpiryCheck" and ResultType in ("Completed", "Failed")
| where TimeGenerated > ago(26h)
| count
```

Set the alert to fire when the count is 0. It counts failed jobs too, because this runbook fails on purpose whenever it finds something; what matters here is whether it ran.
