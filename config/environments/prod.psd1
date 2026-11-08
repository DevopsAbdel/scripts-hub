@{
    # Environnement de production : surcharger uniquement les valeurs utiles.
    # Les identifiants doivent provenir d'un coffre, jamais de ce fichier.
    LogLevel = 'INFO'

    Reports = @{
        RetainDays = 365
    }
}
