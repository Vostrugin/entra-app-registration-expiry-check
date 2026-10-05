# Changelog

All notable changes to this project are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-05

### Added

- `EntraAppRegExpiryCheck` module with `Get-AppCredentialExpiry`, `Measure-AppCredentialExpiry`, and `Export-AppCredentialExpiryReport`.
- `scripts/Invoke-ExpiryCheck.ps1` with interactive, managed identity, access token, certificate, and existing-connection sign-in, and exit codes 0 to 3.
- Exclusions file with reasons and optional `until` dates.
- Optional owners (`-IncludeOwners`) and service principal credentials (`-IncludeServicePrincipals`).
- JSON and CSV reports.
- Examples for Azure Automation, GitHub Actions, and Azure DevOps.
- Pester tests and a CI workflow for Windows PowerShell 5.1 and PowerShell 7.
