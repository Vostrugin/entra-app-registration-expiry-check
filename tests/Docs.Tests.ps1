#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

# Mermaid diagrams live as source files in docs/diagrams/*.mmd. GitHub only renders a diagram that is
# written inline in a Markdown file, so each one is also pasted into the pages that use it, right after
# a marker comment:
#
#   <!-- diagram: how-it-works.mmd -->
#   ```mermaid
#   ...
#   ```
#
# These tests fail when a pasted copy drifts from its source, or when a source isn't used anywhere.

BeforeDiscovery {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $diagramFolder = Join-Path (Join-Path $repoRoot 'docs') 'diagrams'
    $diagrams = @(Get-ChildItem -Path $diagramFolder -Filter '*.mmd' -File | ForEach-Object {
            @{ Name = $_.Name; Path = $_.FullName }
        })
}

Describe 'Diagram <Name>' -ForEach $diagrams {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $source = ((Get-Content -LiteralPath $Path -Raw -Encoding UTF8) -replace "`r`n", "`n").Trim()

        $pattern = '<!-- diagram: ' + [regex]::Escape($Name) + ' -->\s*```mermaid\n(.*?)\n```'
        $copies = @(
            foreach ($page in (Get-ChildItem -Path $repoRoot -Filter '*.md' -File -Recurse)) {
                $text = (Get-Content -LiteralPath $page.FullName -Raw -Encoding UTF8) -replace "`r`n", "`n"
                foreach ($match in [regex]::Matches($text, $pattern, [Text.RegularExpressions.RegexOptions]::Singleline)) {
                    [pscustomobject]@{ Page = $page.FullName; Body = $match.Groups[1].Value.Trim() }
                }
            }
        )
    }

    It 'is embedded in at least one page' {
        $copies.Count | Should -BeGreaterThan 0
    }

    It 'matches its source in every page that embeds it' {
        foreach ($copy in $copies) {
            $copy.Body | Should -BeExactly $source -Because "the copy in $($copy.Page) should match docs/diagrams/$Name"
        }
    }
}
