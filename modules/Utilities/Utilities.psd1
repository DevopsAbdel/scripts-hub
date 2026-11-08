@{
    RootModule        = 'Utilities.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'd9b5e4c3-6f70-4b82-9cad-3e4f5a6b7c82'
    Author            = 'Scripts-Hub'
    CompanyName       = 'Scripts-Hub'
    Copyright         = '(c) 2026 Scripts-Hub. MIT License.'
    Description       = 'Helpers sans état : disponibilité de commandes, formatage de tailles, nommage sûr, verbes approuvés.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Test-HubCommand'
        'Format-HubByteSize'
        'ConvertTo-HubSafeName'
        'Test-HubApprovedVerb'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Scripts-Hub', 'Utilities')
            ProjectUri = 'https://github.com/DevopsAbdel/scripts-hub'
            LicenseUri = 'https://github.com/DevopsAbdel/scripts-hub/blob/main/LICENSE'
        }
    }
}
