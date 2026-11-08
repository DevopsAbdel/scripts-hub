# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le
versionnement suit [Semantic Versioning](https://semver.org/lang/fr/).

## [Unreleased]

### Added

- Framework de rapport unifié dans `assets/` : template HTML, thème sombre,
  interactions JavaScript et Chart.js 4.4.7 embarqué (hors ligne).
- Rapports HTML : cartes KPI, recherche instantanée, tri des colonnes,
  export CSV par tableau, export JSON global, impression PDF.
- Cartes KPI et graphiques dans les scripts d'inventaire système, de posture
  de sécurité et d'inventaire Active Directory.
- `tools/maintenance/Initialize-HubStructure.ps1` : synchronisation idempotente
  de l'arborescence cible.

### Changed

- `New-HubHtmlReport` consomme désormais `assets/templates/report.html` et
  inline CSS, JavaScript, Chart.js et les données JSON.
- `Build.ps1` vérifie la présence des ressources du framework de rapport.
- `Set-FileEncoding.ps1` normalise également les fichiers `.js`.

### Planned

- Inventaire Active Directory et Microsoft 365 enrichis.
- Collecte Azure et rapports consolidés multi-sources.
- Planification via le Planificateur de tâches Windows.

## [1.0.0] - 2026-11-08

### Added

- Structure de dépôt complète `src/`, `modules/`, `config/`, `reports/`, `logs/`,
  `docs/`, `tests/`, `tools/`, `assets/`, `archive/` et `.github/workflows/`.
- Module `Common` : racine du dépôt, journalisation, contexte d'exécution,
  configuration, audit d'environnement.
- Module `Inventory` : inventaire système local et inventaire Active Directory.
- Module `Reporting` : rapports HTML autonomes, export CSV et JSON.
- Module `Security` : audit des administrateurs locaux, du pare-feu et de Defender.
- Module `Utilities` : helpers de disponibilité, de formatage et de nommage.
- Scripts `Get-SystemInventory`, `Get-SecurityPosture`, `Get-ADInventory`
  et `New-HTMLReport`.
- Outillage `Build.ps1`, `Test-Environment.ps1`, `Set-FileEncoding.ps1`
  et `Install-HubModules.ps1`.
- Tests unitaires Pester et workflow GitHub Actions.
- Documentation d'architecture, standards, procédures et runbook.
- Fichiers `README.md`, `CONTRIBUTING.md`, `LICENSE`, `.editorconfig`,
  `.gitignore` et `scripts-hub.code-workspace`.

[Unreleased]: https://github.com/DevopsAbdel/scripts-hub/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/DevopsAbdel/scripts-hub/releases/tag/v1.0.0
