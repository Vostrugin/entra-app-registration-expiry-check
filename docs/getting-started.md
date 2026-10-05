# Getting started

This walks through one interactive run on your own machine. Running it on a schedule comes after that, in [Scheduling](scheduling.md).

## What you need

- Windows PowerShell 5.1, or PowerShell 7.2 or later. Either works; PowerShell 7 is what the scheduled examples use.
- The `Microsoft.Graph.Authentication` module. The tool talks to Microsoft Graph through `Invoke-MgGraphRequest`, which lives in that module, so you don't need the full Microsoft Graph SDK.
- An account in the tenant you want to check, and consent for the Microsoft Graph Command Line Tools app to use the `Application.Read.All` permission on your behalf. That permission needs admin consent, so the first run in a tenant has to be approved by an administrator.

Install the module once:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

## 1. Get the code

Clone the repository, or download it as a ZIP and extract it. On Windows, files extracted from a downloaded ZIP are marked as coming from the internet, and an execution policy of `RemoteSigned` will refuse to run them. Clear the mark from the repository folder:

```powershell
Get-ChildItem -Recurse | Unblock-File
```

## 2. Run the check

From the repository folder:

```powershell
./scripts/Invoke-ExpiryCheck.ps1 -ThresholdDays 30 -IncludeOwners -OutputPath ./report
```

A browser window opens for you to sign in. If nobody has consented to `Application.Read.All` for Microsoft Graph Command Line Tools yet, Entra shows a consent screen. An administrator can approve it for the whole tenant; anyone else can only request it.

`-IncludeOwners` also asks for `User.ReadBasic.All`, so owners show up with names and email addresses instead of bare object IDs. Leave it off if you only want the credentials.

## 3. Read the result

The first two lines are the totals:

```text
Checked 41 credentials across 27 apps. Threshold: 30 days.
Expired: 1   Expiring: 2   Healthy: 36   Excluded: 2
```

A table of everything Expired or Expiring follows, soonest first. `Days` is the number of whole days left, so `0` means "expires within the next 24 hours" and a negative number means it has already expired.

The exit code is in `$LASTEXITCODE`:

```powershell
$LASTEXITCODE   # 0 nothing to do, 1 the check failed, 2 something is expiring, 3 something has expired
```

## 4. Open the report

`./report/credential-expiry.json` has the totals and every credential, including owners. `./report/credential-expiry.csv` has the same credentials as one row each, which is easier to open in Excel or hand to someone. [Output and exit codes](output-and-exit-codes.md) describes every field.

## 5. Exclude what you've decided to leave alone

Most tenants have a few credentials nobody is going to rotate: an app that's being decommissioned, a secret kept for one more release. Copy the sample exclusions file and add them:

```powershell
Copy-Item ./examples/exclusions.sample.json ./exclusions.json
```

Each entry needs an ID and should have a reason. Add an `until` date when the exclusion is temporary; after that date the credential counts again. Then run with the file:

```powershell
./scripts/Invoke-ExpiryCheck.ps1 -ExclusionPath ./exclusions.json -OutputPath ./report
```

Excluded credentials still appear in the report, marked as excluded with their reason, but they no longer affect the exit code. [Configuration](configuration.md#exclusions) has the full format.

## Next steps

- Choose how the check signs in when nobody is at the keyboard: [Authentication](authentication.md).
- Put it on a schedule and decide how you'll hear about failures: [Scheduling](scheduling.md).
- Read what the script leaves to you before you rely on it: [What this doesn't solve](production-gaps.md).
