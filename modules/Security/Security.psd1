@{
    RootModule        = 'Security.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'e0c6f5d4-7081-4c93-add1-4f5a6b7c8d93'
    Author            = 'Scripts-Hub'
    CompanyName       = 'Scripts-Hub'
    Copyright         = '(c) 2026 Scripts-Hub. MIT License.'
    Description       = 'Audit en lecture seule des administrateurs locaux, du pare-feu Windows et de Microsoft Defender.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-LocalAdministratorAudit'
        'Get-FirewallProfileStatus'
        'Get-DefenderStatus'
        'Get-SecurityPosture'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Scripts-Hub', 'Security', 'Audit')
            ProjectUri = 'https://github.com/DevopsAbdel/scripts-hub'
            LicenseUri = 'https://github.com/DevopsAbdel/scripts-hub/blob/main/LICENSE'
        }
    }
}
