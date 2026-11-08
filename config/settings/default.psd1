@{
    Organization = 'Scripts-Hub'
    LogLevel     = 'INFO'

    Reports = @{
        RetainDays = 90
        Culture    = 'fr-FR'
    }

    Inventory = @{
        IncludeVolumes = $true
        IncludeNetwork = $false
    }

    Paths = @{
        Logs    = 'logs'
        Reports = 'reports'
    }
}
