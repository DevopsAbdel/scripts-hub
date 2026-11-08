@{
    # Modèle de configuration d'environnement.
    # Copier vers config/environments/<nom>.psd1 puis adapter.
    # Ne jamais stocker de secret dans ce fichier.
    Organization = 'Organisation'
    LogLevel     = 'INFO'

    Reports = @{
        RetainDays = 90
    }

    ActiveDirectory = @{
        Server     = 'dc01.example.local'
        SearchBase = 'DC=example,DC=local'
    }
}
