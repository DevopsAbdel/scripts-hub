@{
    RootModule        = 'Dashboard.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b6c2d3f4-5a70-4c18-9d2e-7f3a8b1c6e52'
    Author            = 'Scripts-Hub'
    CompanyName       = 'Scripts-Hub'
    Copyright         = '(c) 2026 Scripts-Hub. MIT License.'
    Description       = 'Dashboard web local : index des rapports, exécution contrôlée des scripts et journaux.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-HubDashboardAction'
        'Get-HubDashboardReportIndex'
        'Get-HubDashboardLogIndex'
        'Resolve-HubDashboardReportPath'
        'Get-HubDashboardLogContent'
        'Get-HubDashboardState'
        'New-HubDashboardPage'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Scripts-Hub', 'Dashboard', 'Web', 'Reporting')
            ProjectUri = 'https://github.com/DevopsAbdel/scripts-hub'
            LicenseUri = 'https://github.com/DevopsAbdel/scripts-hub/blob/main/LICENSE'
        }
    }
}
