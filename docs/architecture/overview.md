# Architecture

## Vue d'ensemble

`scripts-hub` est une plateforme d'automatisation PowerShell organisée en
couches. Chaque couche a une responsabilité unique et ne dépend que des
couches inférieures.

```text
scripts (src/)
    │  orchestration : paramètres, journalisation, rapports
    ▼
modules métier (Inventory, Security)
    │  collecte et logique de domaine
    ▼
modules socle (Common, Utilities)
    │  chemins, logs, configuration, helpers
    ▼
Reporting
    │  restitution HTML / CSV / JSON
    ▼
reports/ + logs/
```

## Règles de dépendance

| Couche | Peut dépendre de | Ne doit pas dépendre de |
| --- | --- | --- |
| `src/` | tous les modules | autre script de `src/` |
| `Inventory`, `Security` | `Common`, `Utilities` | `Reporting` |
| `Reporting` | `Common` | modules métier |
| `Common`, `Utilities` | bibliothèque standard | autres modules du hub |
| `tools/` | tous les modules | logique métier propre |

Règles complémentaires :

- Un script ne contient pas de logique réutilisable : elle appartient à un module.
- Un module ne produit pas de sortie console : il retourne des objets.
- Seuls les scripts écrivent dans `reports/` et `logs/`.
- Aucune dépendance circulaire entre modules.

## Composants

### `modules/Common`

Socle du hub :

- résolution de la racine du dépôt (`Get-HubRoot`) ;
- horodatage invariant (`Get-HubTimestamp`) ;
- journalisation console + fichier (`Write-HubLog`) ;
- création idempotente de répertoires (`New-HubDirectory`) ;
- chemins de rapports normalisés (`Get-HubReportPath`) ;
- configuration par environnement (`Get-HubConfig`) ;
- contexte d'exécution (`Get-HubRunContext`) ;
- audit d'environnement (`Test-HubEnvironment`).

### `modules/Utilities`

Fonctions sans état, testables isolément : disponibilité de commandes,
formatage de tailles, normalisation de noms, validation de verbes.

### `modules/Inventory`

Collecte système (CIM) et Active Directory (RSAT). Les fonctions AD échouent
avec un message explicite si le module est absent.

### `modules/Security`

Audit en lecture seule : administrateurs locaux, profils de pare-feu,
Microsoft Defender. Chaque source est isolée : une indisponibilité produit un
avertissement, pas un échec global.

### `modules/Reporting`

Restitution :

- `New-HubHtmlReport` : document HTML5 autonome, CSS embarqué, échappement strict ;
- `Export-HubCsv` : CSV `;` UTF-8 BOM, compatible Excel FR ;
- `Export-HubJson` : JSON UTF-8 BOM, profondeur contrôlée ;
- `Export-HubReport` : orchestrateur multi-format.

## Flux d'exécution d'un script

```text
paramètres
  → import des modules (chemins $PSScriptRoot)
  → Get-HubRunContext (RunId, journal, chemins datés)
  → collecte (module métier)
  → restitution (module Reporting)
  → journal de fin (durée, chemins, erreurs)
  → objet de synthèse ou données avec -PassThru
```

## Gestion des erreurs

- `$ErrorActionPreference = 'Stop'` et `Set-StrictMode -Version Latest`.
- `try / catch / finally` autour du traitement principal.
- Erreur journalisée puis relancée (`throw`) pour préserver le code de sortie.
- Le bloc `finally` journalise toujours la durée d'exécution.

## Configuration

Ordre de fusion :

1. `config/settings/default.psd1`
2. `config/environments/<environnement>.psd1` (surcharge récursive)

Aucun secret dans les fichiers de configuration : utiliser un coffre
(Windows Credential Manager, Azure Key Vault, variable protégée CI).

## Conventions de nommage des livrables

```text
reports/html/YYYY-MM-DD_Type_Rapport.html
reports/csv/YYYY-MM-DD_Type_Rapport.csv
reports/json/YYYY-MM-DD_Type_Rapport.json
logs/YYYY-MM-DD_Nom_Execution.log
```

## Extensibilité

Ajouter un domaine :

1. créer `src/<Domaine>/` ;
2. ajouter un module dédié si la logique est réutilisable ;
3. ajouter les tests unitaires correspondants ;
4. documenter le domaine dans ce fichier.
