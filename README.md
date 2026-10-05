# entra-app-registration-expiry-check
PowerShell tool that finds expired and expiring client secrets and certificates on Microsoft Entra ID (Azure AD) app registrations. One read-only Microsoft Graph query (Application.Read.All), JSON/CSV reports, exit codes for pipelines. Runs in Azure Automation, GitHub Actions or Azure DevOps with managed identity or workload identity federation.
