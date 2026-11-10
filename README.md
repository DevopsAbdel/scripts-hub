# scripts-hub

Plateforme centralisée d'automatisation PowerShell pour l'inventaire, l'audit et
l'exploitation des infrastructures Windows, Active Directory, Microsoft 365 et Azure.

Le dépôt fournit des scripts prêts pour la production, des modules réutilisables,
des rapports HTML/CSV/JSON et une base de tests automatisés.

---

## Sommaire

- [Présentation](#présentation)
- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Interface locale](#interface-locale)
- [Exemples](#exemples)
- [Standards](#standards)
- [Conventions Git](#conventions-git)
- [Tests et qualité](#tests-et-qualité)
- [Roadmap](#roadmap)
- [Documentation](#documentation)

---

## Présentation

`scripts-hub` répond à quatre objectifs :

1. **Centraliser** les scripts d'exploitation et d'audit dans un dépôt unique.
2. **Mutualiser** la logique commune dans des modules PowerShell versionnés.
3. **Standardiser** la sortie : journalisation systématique et rapports
   HTML / CSV / JSON horodatés.
4. **Industrialiser** la qualité : analyse statique, tests Pester et intégration
   continue GitHub Actions.

## Architecture

```text
scripts-hub/
├── src/                  # Scripts métier par domaine
│   ├── ActiveDirectory/
│   ├── Azure/
│   ├── Microsoft365/
│   ├── HyperV/
│   ├── VMware/
│   ├── Network/
│   ├── Security/
│   ├── Inventory/
│   ├── Dashboard/
│   └── Reporting/
├── modules/              # Modules PowerShell réutilisables
│   ├── Common/
│   ├── Inventory/
│   ├── Reporting/
│   ├── Security/
│   ├── Dashboard/
│   └── Utilities/
├── config/               # Configuration par environnement
│   ├── environments/
│   ├── templates/
│   └── settings/
├── reports/              # Sorties générées (html, csv, json, archive)
├── logs/                 # Journaux d'exécution
├── docs/                 # Architecture, procédures, standards, runbooks
├── tests/                # Tests Pester (unit, integration, data)
├── tools/                # Outillage build, déploiement, maintenance
├── assets/               # Ressources statiques des rapports
├── archive/              # Scripts et artefacts obsolètes
└── .github/workflows/    # Intégration continue
```

| Dossier | Rôle |
| --- | --- |
| `src/` | Scripts exécutables, un domaine par dossier. |
| `modules/` | Code réutilisable, importé par les scripts et les tests. |
| `config/` | Paramétrage versionné (pas de secret en clair). |
| `reports/` | Livrables générés, jamais édités à la main. |
| `logs/` | Traces d'exécution, ignorées par Git. |
| `docs/` | Documentation de référence du projet. |
| `tests/` | Tests unitaires et d'intégration Pester. |
| `tools/` | Scripts d'outillage du dépôt, pas de logique métier. |

## Prérequis

| Composant | Version minimale | Remarque |
| --- | --- | --- |
| PowerShell | **7.2+** | **Environnement d'exécution par défaut** (validé sur 7.6.9). |
| Windows PowerShell | 5.1 | Compatibilité obligatoire de tous les scripts. |
| Git | 2.30+ | Convention GitFlow simplifiée. |
| Pester | 5.x | Tests unitaires et d'intégration. |
| PSScriptAnalyzer | 1.21+ | Analyse statique. |

Le shell par défaut du dépôt est **PowerShell 7** : le workspace VS Code
(`scripts-hub.code-workspace`) pointe `terminal.integrated.defaultProfile.windows`
sur `pwsh.exe`, et les tâches `build` / `test` invoquent explicitement `pwsh`.
Les scripts restent toutefois compatibles Windows PowerShell 5.1.

Dépendances optionnelles, chargées uniquement si le module correspondant est présent :

- `ActiveDirectory` (RSAT) pour `src/ActiveDirectory`.
- `Microsoft.Graph` pour `src/Microsoft365`.
- `Az.Accounts` / `Az.Resources` pour `src/Azure`.
- `Hyper-V` et `VMware.PowerCLI` pour les scripts de virtualisation.

## Installation

```powershell
git clone https://github.com/DevopsAbdel/scripts-hub.git
Set-Location .\scripts-hub

# Dépendances de développement (portée utilisateur)
.\tools\deployment\Install-HubModules.ps1

# Vérification de l'environnement
.\tools\maintenance\Test-Environment.ps1
```

Aucun module métier n'est installé automatiquement : les scripts détectent les
dépendances absentes et s'arrêtent avec un message explicite.

## Utilisation

```powershell
# Inventaire système local + rapports HTML, CSV et JSON
.\src\Inventory\Get-SystemInventory.ps1

# Audit de la posture de sécurité locale
.\src\Security\Get-SecurityPosture.ps1

# Inventaire Active Directory (poste joint au domaine + module RSAT)
.\src\ActiveDirectory\Get-ADInventory.ps1 -Server dc01.contoso.com

# Génération d'un rapport HTML autonome
.\src\Reporting\New-HTMLReport.ps1 -Title 'Inventaire' -InputObject (.\src\Inventory\Get-SystemInventory.ps1 -PassThru)
```

Chaque script expose `Get-Help <script>.ps1 -Full`.

## Interface locale

Le dépôt inclut un dashboard web local pour piloter l'exécution et consulter
les livrables sans ligne de commande :

```powershell
.\src\Dashboard\Start-HubDashboard.ps1
# Navigateur : http://localhost:8080
```

Le serveur écoute uniquement sur `localhost`, fonctionne hors ligne et propose :

- des KPI sur les rapports et les scripts disponibles ;
- le lancement contrôlé des scripts par liste blanche, avec sortie en direct ;
- le filtre et le tri des rapports, l'ouverture HTML et le téléchargement
  CSV/JSON ;
- la consultation des journaux récents ;
- l'arrêt propre du serveur depuis la page.

Options : `-Port 8090`, `-NoBrowser`, `-RunTimeoutSeconds 300`.
Guide complet : [`docs/procedures/dashboard.md`](docs/procedures/dashboard.md).

## Exemples

Sorties générées :

```text
reports/html/2026-11-08_System_Inventory.html
reports/csv/2026-11-08_System_Inventory.csv
reports/json/2026-11-08_System_Inventory.json
logs/2026-11-08_Get-SystemInventory.log
```

Convention de nommage : `YYYY-MM-DD_Type_Rapport.ext`.

## Standards

- **Encodage** : UTF-8 avec BOM sur tous les fichiers générés.
- **Compatibilité** : PowerShell 5.1 et 7+ (aucune syntaxe 7-only dans `src/` et `modules/`).
- **En-tête obligatoire** : `.SYNOPSIS`, `.DESCRIPTION`, `.AUTHOR`, `.VERSION`, `.DATE`.
- **Erreurs** : `$ErrorActionPreference = 'Stop'` et blocs `try / catch / finally`.
- **Verbes** : verbes approuvés Microsoft (`Get-Verb`), nommage `Verbe-Nom.ps1`.
- **Idempotence** : une ré-exécution ne doit ni dupliquer ni corrompre les sorties.

Détail complet : [`docs/standards/powershell-standards.md`](docs/standards/powershell-standards.md).

## Conventions Git

Branches : `main` (stable), `develop` (intégration), `feature/*`, `fix/*`, `chore/*`.

Format des commits (Conventional Commits) :

```text
feat: add active directory inventory module
fix: correct html report encoding
docs: update deployment guide
refactor: split reporting module
test: add pester unit tests
build: update ci workflow
chore: refresh editorconfig
```

Voir [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Tests et qualité

```powershell
# Analyse statique + tests unitaires + contrôles de conformité
.\tools\build\Build.ps1

# Tests seuls
Invoke-Pester .\tests -Output Detailed
```

## Roadmap

| Version | Contenu |
| --- | --- |
| `1.0.0` | Structure du dépôt, modules de base, outillage et CI. |
| `1.1.0` | Inventaire Active Directory et Microsoft 365 enrichis. |
| `1.2.0` | Collecte Azure et rapports consolidés multi-sources. |
| `1.3.0` | Planification (Task Scheduler) et rétention des rapports. |
| `2.0.0` | Publication des modules et exécution distante. |

## Documentation

- [Architecture](docs/architecture/overview.md)
- [Standards PowerShell](docs/standards/powershell-standards.md)
- [Prise en main](docs/procedures/getting-started.md)
- [Dashboard web local](docs/procedures/dashboard.md)
- [Runbook : contrôle de santé quotidien](docs/runbooks/daily-health-check.md)

## Licence

MIT — voir [`LICENSE`](LICENSE).
