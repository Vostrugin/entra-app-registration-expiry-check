# Security policy

## Reporting a vulnerability

Please don't open a public issue for a security problem. Report it privately through GitHub's "Report a vulnerability" button on this repository's Security tab, or by email to contact@aztokenwatch.com with "Security" in the subject.

You'll get an acknowledgement within two business days. Include what you found, how to reproduce it, and what an attacker could do with it.

## What this tool can and can't access

- It reads App Registration and service principal metadata through Microsoft Graph with `Application.Read.All`, and owner details with `User.Read.All` or `User.ReadBasic.All` when you ask for them.
- It only sends GET requests. Nothing in the module or the script writes to the tenant. `examples/azure-automation/Grant-GraphAppRole.ps1` is the one exception: it's a separate admin script that grants the permission above, and you run it by hand.
- It never receives secret values or private keys. Microsoft Graph doesn't return them.
- Reports contain app names, IDs, credential names and dates, and owner contact details. Treat them as internal data, and keep pipelines that publish them in private repositories or restricted projects.
