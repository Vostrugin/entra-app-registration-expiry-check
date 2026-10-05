# Azure DevOps

Runs the check every morning as a scheduled pipeline. It signs in through an Azure Resource Manager service connection that uses workload identity federation, so no secret is stored in Azure DevOps.

## Setup

### 1. Put the code in a repository

Import this repository into Azure Repos, or copy `src/` and `scripts/` into one of yours. Keep it in a project with restricted access: the pipeline log and the report list your app names.

### 2. Create the service connection

In Project settings, open Service connections and create an Azure Resource Manager connection that uses workload identity federation. Name it `entra-expiry-check`, or change `serviceConnection` in the pipeline to match.

Azure DevOps insists on an Azure scope for this kind of connection, but the check needs no Azure role at all. Keep the scope as small as you can:

- If you let Azure DevOps create the identity for you, scope the connection to an empty resource group. It assigns Contributor on whatever scope you pick.
- If you create the connection manually with your own App Registration, give that identity Reader on an empty resource group and nothing else.

### 3. Grant the Graph permission

Open the service connection, follow the link to manage its App Registration (or open the one you used), and under API permissions add the Microsoft Graph application permission `Application.Read.All`, then grant admin consent. Add `User.Read.All` if you plan to pass `-IncludeOwners`.

### 4. Create the pipeline

Create a pipeline from the existing YAML file [azure-pipelines.yml](azure-pipelines.yml) and run it once by hand. The first run asks you to permit the pipeline to use the service connection.

## What a run produces

- The "Check credentials" step log shows the summary and the table of credentials that need attention.
- The JSON and CSV reports are published as the `credential-expiry-report` artifact.
- The run fails when anything has expired or is expiring (exit code 2 or 3), or when the check itself fails (exit code 1). To fail only on expired credentials, replace the last line of the inline script with `if ($LASTEXITCODE -eq 2) { exit 0 } else { exit $LASTEXITCODE }`.

## Who gets told

Nobody requests a scheduled run, so don't count on the default build notifications reaching anyone. In Project settings, open Notifications, add a subscription for "A build fails", and filter it to this pipeline. Send it to a team or a distribution list rather than one person.

The schedule sets `always: true`. Without it, Azure DevOps skips a scheduled run when nothing has changed on the branch since the last one, which for a repository like this is most days.

Azure DevOps has no built-in alert for a pipeline that hasn't run. If the service connection is deleted, runs fail and you hear about it; if the schedule itself is removed or the pipeline is disabled, nothing happens. A heartbeat ping from the last step to an external monitor covers that case.
