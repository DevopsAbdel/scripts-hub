@{
    RootModule        = 'Reporting.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'f1d7a6e5-8192-4da4-bee2-5a6b7c8d9ea4'
    Author            = 'Scripts-Hub'
    CompanyName       = 'Scripts-Hub'
    Copyright         = '(c) 2026 Scripts-Hub. MIT License.'
    Description       = 'Rapports HTML autonomes et exports CSV / JSON en UTF-8 avec BOM.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'New-HubHtmlReport'
        'Export-HubCsv'
        'Export-HubJson'
        'Export-HubReport'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Scripts-Hub', 'Reporting', 'HTML', 'CSV', 'JSON')
            ProjectUri = 'https://github.com/DevopsAbdel/scripts-hub'
            LicenseUri = 'https://github.com/DevopsAbdel/scripts-hub/blob/main/LICENSE'
        }
    }
}
