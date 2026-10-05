# Contributing

Bug reports, fixes, and improvements are welcome. For anything larger than a small fix, open an issue first so we can agree on the approach before you spend time on it.

## Running the tests

The tests use [Pester](https://pester.dev/) 5.5 or later and never call Microsoft Graph; they replay the responses in `tests/fixtures`.

```powershell
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force

Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path ./tests
```

CI runs the same commands on Windows PowerShell 5.1 and on PowerShell 7 for Windows and Linux.

## Guidelines

- Keep it read-only. The check must never need more than `Application.Read.All` (plus `User.Read.All` for owner names), and must never write to the tenant.
- Keep it compatible with Windows PowerShell 5.1: no ternary operators, null-coalescing operators, or other PowerShell 7-only syntax, and keep `.ps1` files ASCII so 5.1 reads them correctly.
- Put new logic in a function under `src/EntraAppRegExpiryCheck/Private` or `Public`, and cover it with a test. Add a fixture under `tests/fixtures` when a test needs a new Graph response.
- If you change a diagram, edit the `.mmd` file in `docs/diagrams` and update every page that embeds it. `tests/Docs.Tests.ps1` checks that they match.
- Add a line to the Unreleased section of [CHANGELOG.md](CHANGELOG.md).

## Pull requests

Describe what changed and why, and how you tested it. If it changes output, exit codes, or parameters, update the docs in the same pull request.
