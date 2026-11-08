# Standards PowerShell

Ce document est normatif pour l'ensemble du dépôt.

## 1. Environnement

| Élément | Standard |
| --- | --- |
| Environnement par défaut | PowerShell 7.2+ (validé sur 7.6.9) |
| Compatibilité minimale | Windows PowerShell 5.1 |
| Architecture | x64 |
| Encodage | UTF-8 avec BOM |
| Fins de ligne | CRLF |

Le workspace VS Code pointe le terminal par défaut sur `pwsh.exe`.
Le code de `src/` et `modules/` ne doit utiliser aucune syntaxe propre à
PowerShell 7 (ternaire, `??`, `-Parallel`, `-AdditionalChildPath`).

## 2. En-tête obligatoire

Chaque script (`.ps1`) et module (`.psm1`) commence par un bloc d'aide :

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Description courte.

.DESCRIPTION
    Description détaillée du comportement et des effets de bord.

.PARAMETER Nom
    Description du paramètre.

.EXAMPLE
    PS> .\src\Domaine\Verbe-Nom.ps1

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>
```

> **Écart assumé par rapport au modèle initial** : PowerShell ne reconnaît pas
> `.AUTHOR` comme mot-clé d'aide ; sa présence invalide le bloc et `Get-Help`
> ne restitue plus le synopsis. L'auteur, la version et la date sont donc
> portés par `.NOTES`, ce qui préserve un `Get-Help` fonctionnel.

## 3. Structure d'un script

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Parametre
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$hubRoot = Split-Path -Path (Split-Path -Path $scriptDirectory -Parent) -Parent

Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Common\Common.psd1') -Force

try {
    # traitement
}
catch {
    Write-HubLog -Level ERROR -Message $_.Exception.Message -Path $logPath
    throw
}
finally {
    # nettoyage et journalisation de fin
}
```

## 4. Nommage

| Élément | Convention | Exemple |
| --- | --- | --- |
| Script | `Verbe-Nom.ps1` | `Get-ADInventory.ps1` |
| Fonction | `Verbe-Nom` | `Get-SystemInventory` |
| Module | PascalCase | `Inventory.psm1` |
| Paramètre | PascalCase | `-OutputDirectory` |
| Variable locale | camelCase | `$reportPath` |
| Constante de module | `script:` | `$script:HubRoot` |
| Rapport | `YYYY-MM-DD_Type_Rapport.ext` | `2026-11-08_AD_Inventory.html` |

Verbes autorisés uniquement (`Get-Verb`). Contrôle automatique possible via
`Test-HubApprovedVerb`.

## 5. Gestion des erreurs

- `$ErrorActionPreference = 'Stop'` au niveau du script ou du module.
- `Set-StrictMode -Version Latest` pour détecter les variables non définies.
- `try / catch / finally` systématique autour du traitement principal.
- Interdiction des `catch { }` vides.
- Journalisation de l'erreur avant `throw`.
- Messages d'erreur actionnables : cause, remède attendu.

## 6. Journalisation

- Utiliser `Write-HubLog` du module `Common`.
- Un fichier de journal par exécution : `logs/YYYY-MM-DD_Nom.log`.
- Niveaux : `DEBUG`, `INFO`, `WARNING`, `ERROR`.
- Ne jamais journaliser de secret, jeton ou mot de passe.
- Toujours journaliser : démarrage, contexte, chemins produits, fin et durée.

## 7. Rapports

- HTML : document autonome, aucune ressource distante, utilisable hors ligne.
- Framework unique : `assets/templates/report.html`, `assets/css/report.css`
  et `assets/js/report.js` sont inlinés à la génération.
- Dark mode par défaut, palette imposée :
  `#0D1117` (fond), `#161B22` (surface), `#1F2630` (carte),
  `#58A6FF` (primaire), `#3FB950` (succès), `#D29922` (avertissement),
  `#F85149` (danger), `#F0F6FC` (texte).
- Fonctionnalités obligatoires : cartes KPI, recherche instantanée, tri des
  colonnes, export CSV par tableau, export JSON global, graphiques Chart.js,
  impression PDF.
- CSV : séparateur `;`, UTF-8 BOM, en-tête explicite.
- JSON : UTF-8 BOM, profondeur explicite, structure stable.
- Échappement HTML obligatoire de toute valeur dynamique.
- Les fichiers de `reports/` ne sont jamais édités manuellement.

## 8. Idempotence

Une ré-exécution :

- ne duplique pas les données ;
- écrase les livrables du jour ;
- ne crée pas de répertoire en double ;
- ne dépend pas d'un état résiduel.

## 9. Sécurité

- Aucun secret dans le dépôt ni dans les journaux.
- `Get-Credential` ou coffre pour les identités alternatives.
- Scripts d'audit en lecture seule par défaut.
- Toute opération destructive expose `-WhatIf` / `-Confirm`.
- Principe du moindre privilège : ne pas exiger d'élévation inutile.

## 10. Tests

- Pester 5+.
- Un fichier de test par module dans `tests/unit/`.
- Les tests d'intégration de scripts vont dans `tests/integration/`.
- Chaque fonction exportée possède au moins un test nominal.
- Les tests utilisent `$TestDrive` pour les sorties.
- Aucun test ne dépend d'une donnée réelle de production.
