@{
    RootModule        = 'Inventory.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'c8a4d3b2-5e6f-4a71-8b9c-2d3e4f5a6b71'
    Author            = 'Scripts-Hub'
    CompanyName       = 'Scripts-Hub'
    Copyright         = '(c) 2026 Scripts-Hub. MIT License.'
    Description       = 'Inventaire système local et inventaire de synthèse Active Directory.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-SystemVolume'
        'Get-SystemInventory'
        'Get-ADInventory'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    RequiredModules   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Scripts-Hub', 'Inventory', 'ActiveDirectory')
            ProjectUri = 'https://github.com/DevopsAbdel/scripts-hub'
            LicenseUri = 'https://github.com/DevopsAbdel/scripts-hub/blob/main/LICENSE'
        }
    }
}
