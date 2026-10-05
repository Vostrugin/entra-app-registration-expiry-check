@{
    RootModule           = 'EntraAppRegExpiryCheck.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'bcbe2660-9727-49bc-826a-b214a7f4b03c'
    Author               = 'Maksym Vostruhin'
    CompanyName          = 'Token Watch'
    Copyright            = '(c) 2026 Maksym Vostruhin. Released under the MIT License.'
    Description          = 'Finds expired and expiring client secrets and certificates on Microsoft Entra ID App Registrations with a read-only Microsoft Graph query.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport    = @(
        'Get-AppCredentialExpiry'
        'Measure-AppCredentialExpiry'
        'Export-AppCredentialExpiryReport'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags                       = @('Entra', 'EntraID', 'AzureAD', 'AppRegistration', 'ClientSecret', 'Certificate', 'Expiry', 'MicrosoftGraph')
            ExternalModuleDependencies = @('Microsoft.Graph.Authentication')
        }
    }
}
