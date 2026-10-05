# Load private helpers first so public functions can use them, then export only the public functions.
$privateFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$publicFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

foreach ($file in @($privateFiles + $publicFiles)) {
    . $file.FullName
}

Export-ModuleMember -Function $publicFiles.BaseName
