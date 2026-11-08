@{
    RootModule        = 'Common.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b7f3c2a1-4d5e-4f60-9a8b-1c2d3e4f5a60'
    Author            = 'Scripts-Hub'
    CompanyName       = 'Scripts-Hub'
    Copyright         = '(c) 2026 Scripts-Hub. MIT License.'
    Description       = 'Fonctions transverses : racine, journalisation, configuration, contexte et audit d''environnement.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-HubRoot'
        'Get-HubTimestamp'
        'New-HubDirectory'
        'Write-HubLog'
        'Get-HubReportPath'
        'Get-HubConfig'
        'Get-HubRunContext'
        'Test-HubEnvironment'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Scripts-Hub', 'Automation', 'Common')
            ProjectUri = 'https://github.com/DevopsAbdel/scripts-hub'
            LicenseUri = 'https://github.com/DevopsAbdel/scripts-hub/blob/main/LICENSE'
        }
    }
}
