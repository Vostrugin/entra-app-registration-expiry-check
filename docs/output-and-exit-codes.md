# Output and exit codes

## Exit codes

| Code | Meaning |
| ---- | ------- |
| 0 | Nothing needs attention. |
| 1 | The check itself failed: sign-in, permissions, an unreadable exclusions file, or a Microsoft Graph error. |
| 2 | At least one credential expires within the threshold. None have expired. |
| 3 | At least one credential has expired. |

Excluded credentials never affect the code. Treat 1 differently from 2 and 3 wherever you can: it means you don't know the state of the tenant, which is a different problem from knowing that something is about to expire.

## Credential records

`Get-AppCredentialExpiry` returns one object per credential, and `-PassThru` sends the same objects out of the script:

| Property | Example | Notes |
| -------- | ------- | ----- |
| `ObjectType` | `Application` | `ServicePrincipal` for credentials found with `-IncludeServicePrincipals`. |
| `ObjectId` | `0a1b2c3d-...` | The object ID of the App Registration or service principal. |
| `AppId` | `a0000000-...` | The Application (client) ID. |
| `AppDisplayName` | `billing-api` | |
| `CredentialType` | `ClientSecret` | Or `Certificate`. |
| `CredentialName` | `prod-2025` | The description given when the credential was added. Often empty. |
| `KeyId` | `5ec0f3a1-...` | Shown in the Entra admin center as the Secret ID or Certificate ID. Use it in exclusions. |
| `Thumbprint` | `3F2A9C4E...` | Certificates only, when Graph has one. |
| `KeyUsage` | `Verify` | Certificates only. |
| `SecretHint` | `x7Q` | Client secrets only: the first characters of the secret value, as shown in the portal. |
| `StartDateTime`, `EndDateTime` | `2026-09-23 10:00:00` | UTC `DateTime` values. |
| `DaysRemaining` | `-12` | Whole days, rounded down. Negative once expired. |
| `Status` | `Expired` | `Expired`, `Expiring`, `Healthy`, or `Unknown` (no end date). |
| `Excluded` | `False` | True when an exclusions entry matched. |
| `ExclusionReason` | | The reason from the exclusions file. |
| `Owners` | | Owner objects (`Id`, `Type`, `DisplayName`, `UserPrincipalName`, `Mail`, `Contact`), with `-IncludeOwners`. |
| `OwnerContacts` | `ana.ruiz@contoso.com` | One string, owners separated by `; `. Each is the mail address, user principal name, display name, or object ID, whichever is available first. |

## JSON report

`credential-expiry.json` has the run's settings, the totals, and every credential sorted by end date. Dates are ISO 8601 strings in UTC.

```json
{
  "generatedAt": "2026-10-05T06:00:12Z",
  "thresholdDays": 30,
  "summary": {
    "applications": 27,
    "credentials": 41,
    "expired": 1,
    "expiring": 2,
    "healthy": 36,
    "unknown": 0,
    "excluded": 2
  },
  "credentials": [
    {
      "objectType": "Application",
      "objectId": "0a1b2c3d-0000-4000-8000-000000000001",
      "appId": "a0000000-0000-4000-8000-000000000001",
      "appDisplayName": "billing-api",
      "credentialType": "ClientSecret",
      "credentialName": "prod-2025",
      "keyId": "5ec0f3a1-0000-4000-8000-000000000001",
      "thumbprint": null,
      "keyUsage": null,
      "secretHint": "x7Q",
      "startDateTime": "2025-03-23T10:00:00Z",
      "endDateTime": "2026-09-23T10:00:00Z",
      "daysRemaining": -12,
      "status": "Expired",
      "excluded": false,
      "exclusionReason": null,
      "owners": [
        {
          "id": "0bbe0000-0000-4000-8000-000000000001",
          "type": "user",
          "displayName": "Ana Ruiz",
          "userPrincipalName": "ana.ruiz@contoso.com",
          "mail": "ana.ruiz@contoso.com"
        }
      ]
    }
  ]
}
```

`summary.applications` counts apps that have at least one credential. Apps with none don't appear anywhere in the report.

## CSV report

`credential-expiry.csv` has one row per credential with these columns: `ObjectType`, `AppDisplayName`, `AppId`, `ObjectId`, `CredentialType`, `CredentialName`, `KeyId`, `Thumbprint`, `SecretHint`, `StartDateTime`, `EndDateTime`, `DaysRemaining`, `Status`, `Excluded`, `ExclusionReason`, `OwnerContacts`.

It's written as UTF-8 with a byte order mark so Excel reads non-ASCII app names correctly. When there are no credentials at all, the file still has its header row.

## Reading the report from other tools

PowerShell:

```powershell
$report = Get-Content ./report/credential-expiry.json -Raw | ConvertFrom-Json
$report.credentials | Where-Object { $_.status -ne 'Healthy' -and -not $_.excluded }
```

jq:

```bash
jq -r '.credentials[] | select(.status != "Healthy" and (.excluded | not))
       | [.status, .appDisplayName, .credentialName, .endDateTime] | @tsv' report/credential-expiry.json
```
