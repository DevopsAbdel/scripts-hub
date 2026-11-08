@{
    # Environnement de laboratoire : valeurs d'exemple, aucun secret en clair.
    Organization = 'Scripts-Hub Lab'
    LogLevel     = 'DEBUG'

    Inventory = @{
        IncludeVolumes = $true
        IncludeNetwork = $true
    }

    ActiveDirectory = @{
        Server    = 'dc01.lab.local'
        SearchBase = 'DC=lab,DC=local'
    }
}
