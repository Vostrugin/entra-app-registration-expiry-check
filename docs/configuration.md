# Configuration

Everything is set with parameters. There's no configuration file apart from the optional exclusions file.

## Script parameters

`scripts/Invoke-ExpiryCheck.ps1` takes one set of sign-in parameters (see [Authentication](authentication.md)) plus these:

| Parameter | Default | What it does |
| --------- | ------- | ------------ |
| `-ThresholdDays` | `30` | How many days ahead a credential counts as Expiring. 0 to 3650. |
| `-IncludeOwners` | off | Reads each app's owners and adds an Owners column. Interactive sign-in also requests `User.ReadBasic.All`. |
| `-IncludeServicePrincipals` | off | Also reports credentials added directly to service principals, such as SAML signing certificates. See [How it works](how-it-works.md#service-principals). |
| `-ExclusionPath` | none | Path to an exclusions file, described below. |
| `-OutputPath` | none | Folder for the reports. Nothing is written when it's empty. |
| `-Format` | `Json, Csv` | Which reports to write. |
| `-PassThru` | off | Also sends the credential records down the pipeline. |

### Choosing a threshold

The threshold has to cover two things: the gap between runs, and the time your team needs to rotate a credential once someone notices. A daily run with a team that can swap a secret in an afternoon is fine at 14 days. If rotating means a change request and a release window, 45 or 60 days is safer. A run that only happens weekly needs at least a week more than whatever you'd pick for a daily one.

## Module parameters

The module functions take the same names, so anything above works the same way in your own scripts:

| Function | Parameters |
| -------- | ---------- |
| `Get-AppCredentialExpiry` | `-ThresholdDays`, `-IncludeOwners`, `-IncludeServicePrincipals`, `-ExclusionPath`, `-AsOf` |
| `Measure-AppCredentialExpiry` | `-InputObject` (records, from the pipeline or as an array) |
| `Export-AppCredentialExpiryReport` | `-InputObject`, `-Path`, `-Format`, `-BaseName`, `-ThresholdDays` |

`-AsOf` evaluates expiry against a moment other than now. It's useful in tests, and for questions like "what will have expired by the end of the quarter?":

```powershell
Get-AppCredentialExpiry -AsOf '2026-12-31T23:59:59Z' -ThresholdDays 0 | Where-Object Status -eq 'Expired'
```

## Exclusions

An exclusions file lists credentials and whole apps that the check should report but not count. It's JSON with two optional arrays:

```json
{
  "applications": [
    {
      "appId": "a0000000-0000-4000-8000-000000000003",
      "reason": "Decommissioned; registration deletion pending change approval"
    }
  ],
  "credentials": [
    {
      "keyId": "5ec0f3a1-0000-4000-8000-000000000003",
      "reason": "Old secret kept until the November release rolls back cleanly",
      "until": "2026-11-30"
    }
  ]
}
```

| Field | Required | Notes |
| ----- | -------- | ----- |
| `appId` | yes, in `applications` | The Application (client) ID. Excludes every credential on that app. |
| `keyId` | yes, in `credentials` | The credential's key ID, shown in the report and in the Entra admin center as the Secret ID or Certificate ID. |
| `reason` | no, but use it | Copied into the report as `ExclusionReason`. |
| `until` | no | A date. After it passes, the entry is ignored and the credential counts again. |

IDs are matched without regard to case. A credential excluded by its key ID and by its app shows the key ID's reason.

A few habits that keep the file useful:

- Exclude single credentials rather than whole apps when you can. An app-level exclusion also hides the next secret someone adds to that app.
- Put an `until` date on anything temporary. Exclusions without one tend to outlive the reason they were added.
- Keep the file in source control. Every change then has an author, a date, and a review, which is the closest this tool gets to an audit trail.

[examples/exclusions.sample.json](../examples/exclusions.sample.json) is a starting point.
