# Diagrams

Each diagram is a [Mermaid](https://mermaid.js.org/) source file in this folder. GitHub only renders Mermaid written inline in a Markdown file, so every diagram is also pasted into the pages that use it, right after a marker comment such as `<!-- diagram: how-it-works.mmd -->`. `tests/Docs.Tests.ps1` fails when a pasted copy no longer matches its source, so edit the `.mmd` file first and then update each copy.

To export a diagram as SVG or PNG, paste the source into the [Mermaid Live Editor](https://mermaid.live/), or use the Mermaid CLI: `npx @mermaid-js/mermaid-cli -i how-it-works.mmd -o how-it-works.svg`.

| Source | Shows | Used in |
| ------ | ----- | ------- |
| [how-it-works.mmd](how-it-works.mmd) | The whole run, from scheduler to exit code | [README](../../README.md) |
| [authentication-options.mmd](authentication-options.mmd) | Which sign-in method fits where the check runs | [Authentication](../authentication.md) |
| [credential-classification.mmd](credential-classification.mmd) | How a credential becomes Expired, Expiring, or Healthy, and what exclusion changes | [How it works](../how-it-works.md#classification) |
| [github-actions-run.mmd](github-actions-run.mmd) | One scheduled GitHub Actions run, step by step | [Scheduling](../scheduling.md), [GitHub Actions example](../../examples/github-actions/README.md) |
| [production-gaps.mmd](production-gaps.mmd) | What the script does, next to what a production setup still needs | [What this doesn't solve](../production-gaps.md) |
