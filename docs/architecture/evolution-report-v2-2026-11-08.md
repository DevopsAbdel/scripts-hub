# Rapport d'évolution — framework de rapport v2 (dark mode)

**Date** : 2026-11-08
**Version** : 1.1.0
**Périmètre** : unification de l'interface des rapports HTML (dark mode,
KPI, recherche, tri, exports, Chart.js, impression PDF), câblage des scripts
et mise à jour de l'outillage.

---

## 1. Résumé exécutif

Le dépôt `scripts-hub` disposait de rapports HTML fonctionnels mais visuellement
hétérogènes et sans interaction. La spécification v2 impose désormais un
framework de présentation unique, hors ligne, appliqué à **tous** les rapports.

Cette évolution livre :

- un template HTML unique (`assets/templates/report.html`) ;
- un thème sombre conforme à la palette imposée (`assets/css/report.css`) ;
- des interactions complètes en JavaScript natif (`assets/js/report.js`) ;
- Chart.js 4.4.7 embarqué localement (`assets/js/chart.umd.min.js`) ;
- des cartes KPI et des graphiques dans les trois scripts métier ;
- un outil idempotent de synchronisation de l'arborescence ;
- 30 tests Pester au vert et 0 constat PSScriptAnalyzer.

Aucune ressource distante n'est référencée : les rapports s'ouvrent et
fonctionnent sans accès Internet.

---

## 2. Environnement détecté

| Élément | Valeur |
| --- | --- |
| PowerShell d'exécution | 7.6.9 (Core), x64 |
| Windows PowerShell | 5.1.26100.9711, x64 |
| Système | Windows 11 (10.0.26200), x64 |
| Git | 2.56.0.windows.4 |
| Branche | `main` (synchronisée avec `origin/main`) |
| Pester | 6.2.0 |
| PSScriptAnalyzer | 1.25.0 |
| Culture | fr-FR |

---

## 3. Actions effectuées

### 3.1 Framework de présentation

| Fichier | Rôle |
| --- | --- |
| `assets/templates/report.html` | Squelette HTML à jetons (`{{TITLE}}`, `{{KPI}}`, `{{CHARTS}}`…) |
| `assets/css/report.css` | Thème sombre, KPI, tableaux, responsive, impression |
| `assets/js/report.js` | Recherche, tri, export CSV/JSON, impression, graphiques |
| `assets/js/chart.umd.min.js` | Chart.js 4.4.7 UMD, 205 889 octets, local |

Le module `Reporting` lit ces ressources à la génération et les **inline**
dans chaque rapport. Les données du rapport et la configuration des graphiques
sont embarquées en JSON (`hub-data`, `hub-charts-config`), avec échappement
de `</` en `<\/` pour éviter toute rupture de balise `script`.

### 3.2 Palette appliquée

| Rôle | Couleur |
| --- | --- |
| Background | `#0D1117` |
| Surface | `#161B22` |
| Card | `#1F2630` |
| Primary | `#58A6FF` |
| Success | `#3FB950` |
| Warning | `#D29922` |
| Danger | `#F85149` |
| Text | `#F0F6FC` |

### 3.3 Fonctionnalités livrées

- Cartes KPI avec tonalité (primaire, succès, avertissement, danger).
- Recherche instantanée sur toutes les lignes des tableaux.
- Tri des colonnes au clic et au clavier (accessibilité `aria-sort`).
- Export CSV par tableau (respecte le filtre de recherche actif).
- Export JSON global du rapport.
- Impression / export PDF via la feuille de style `@media print`.
- Graphiques Chart.js : barres, lignes, anneaux et camemberts.
- Rendu responsive desktop.

### 3.4 Scripts enrichis

| Script | KPI | Graphiques |
| --- | --- | --- |
| `Get-SystemInventory.ps1` | machine, OS, mémoire, uptime, volumes critiques | occupation des volumes, mémoire utilisée/libre |
| `Get-SecurityPosture.ps1` | administrateurs, pare-feu, Defender, avertissements | profils pare-feu, protections Defender, types d'administrateurs |
| `Get-ADInventory.ps1` | domaine, utilisateurs, ordinateurs, groupes, OU | objets AD, comptes actifs/désactivés |
| `New-HTMLReport.ps1` | paramètres `-Kpi` / `-Charts` | idem, génériques |

### 3.5 Outillage

- `tools/maintenance/Initialize-HubStructure.ps1` : vérifie les 39 répertoires
  cibles, crée les manquants, ajoute `.gitkeep` dans les répertoires vides.
  Idempotent et compatible `-WhatIf`.
- `tools/build/Build.ps1` : nouvelle étape `[5/5]` de contrôle des ressources
  du framework (4 fichiers requis).
- `tools/maintenance/Set-FileEncoding.ps1` : normalise désormais aussi les
  fichiers `.js`.

### 3.6 Documentation

- `docs/architecture/overview.md` : composant `Reporting` et répertoire `assets/`.
- `docs/standards/powershell-standards.md` : palette, fonctionnalités et
  ressources obligatoires des rapports.
- `CHANGELOG.md` : section `Unreleased` complétée.

---

## 4. Fichiers créés

```text
assets/css/report.css
assets/js/report.js
assets/js/chart.umd.min.js
assets/templates/report.html
tools/maintenance/Initialize-HubStructure.ps1
docs/architecture/evolution-report-v2-2026-11-08.md
```

## 5. Fichiers modifiés

```text
CHANGELOG.md
docs/architecture/overview.md
docs/standards/powershell-standards.md
modules/Reporting/Reporting.psm1
src/ActiveDirectory/Get-ADInventory.ps1
src/Inventory/Get-SystemInventory.ps1
src/Reporting/New-HTMLReport.ps1
src/Security/Get-SecurityPosture.ps1
tests/unit/Reporting.Tests.ps1
tools/build/Build.ps1
tools/maintenance/Set-FileEncoding.ps1
```

## 6. Fichiers supprimés

```text
assets/images/.gitkeep   (répertoire hors structure cible v2)
```

Le répertoire `assets/images` était vide (uniquement `.gitkeep`) et ne figure
pas dans l'arborescence cible v2. Sa suppression est non destructive.

---

## 7. Vérifications

### 7.1 Build

| Contrôle | Résultat |
| --- | --- |
| Encodage UTF-8 BOM | 41 fichiers, 0 manquant |
| En-têtes d'aide | 19 fichiers, 0 incomplet |
| PSScriptAnalyzer | 0 constat |
| Tests Pester | 30 réussis / 0 échoué |
| Ressources de rapport | 4 / 4 présentes |
| Code de sortie | 0 |

### 7.2 Rapports générés

| Livrable | BOM | KPI | Graphiques | Tableaux triables | Jetons résiduels |
| --- | --- | --- | --- | --- | --- |
| `2026-11-08_System_Inventory.html` | Oui | 6 | 2 | 2 | 0 |
| `2026-11-08_Security_Posture.html` | Oui | 6 | 3 | 3 | 0 |
| `2026-11-08_System_Inventory.csv` | Oui | — | — | — | — |
| `2026-11-08_System_Inventory.json` | Oui | — | — | — | — |

### 7.3 Hors ligne

- Aucune balise `src="http…"` ou `href="http…"` dans les rapports produits.
- Chart.js, CSS et JavaScript sont inlinés.
- Le rapport s'ouvre par double-clic, sans serveur ni connexion.

### 7.4 Idempotence

- `Initialize-HubStructure.ps1` exécuté deux fois : 0 répertoire créé,
  1 seul `.gitkeep` ajouté (`reports/archive`), aucune donnée écrasée.
- Les scripts réécrivent uniquement les livrables du jour.

---

## 8. État Git

| Élément | État |
| --- | --- |
| Branche | `main` |
| Commit de référence | `c39abf2` (`feat: initialize scripts-hub automation platform`) |
| Modifications | 12 fichiers modifiés, 4 ressources ajoutées, 1 outil ajouté |
| Commit de cette évolution | à créer (`feat: add unified dark-mode report framework`) |
| Push | à effectuer après validation |

Les rapports générés restent ignorés par Git (`reports/html|csv|json/*`),
car ils contiennent des données locales d'infrastructure.

---

## 9. Erreurs rencontrées

| Erreur | Cause | Correction |
| --- | --- | --- |
| `Jeton inattendu ','` à la génération | `-replace` non parenthésé dans une valeur de table de hachage | valeur entourée de parenthèses |
| Test KPI en échec potentiel | classe réelle `kpi kpi-success` | assertion élargie à `class="kpi` |
| Aucune autre erreur | — | — |

Aucune erreur non gérée, aucun avertissement PSScriptAnalyzer.

---

## 10. Recommandations

### Court terme

1. Valider visuellement les deux rapports générés :

   ```powershell
   Invoke-Item .\reports\html\2026-11-08_System_Inventory.html
   Invoke-Item .\reports\html\2026-11-08_Security_Posture.html
   ```

2. Committer puis pousser l'évolution :

   ```text
   feat: add unified dark-mode report framework
   ```

3. Vérifier le workflow CI sur GitHub après le push.

### Moyen terme

4. Ajouter des tests d'intégration pour `Get-SecurityPosture.ps1` et
   `New-HTMLReport.ps1`.
5. Ajouter un contrôle automatique de la palette et de l'absence de ressources
   distantes dans `Build.ps1`.
6. Documenter les paramètres `-Kpi` et `-Charts` avec des exemples dans
   `docs/procedures/getting-started.md`.
7. Envisager un thème clair optionnel piloté par un paramètre `-Theme`, sans
   remettre en cause le dark mode par défaut.

### Long terme

8. Factoriser la construction des KPI et graphiques dans un module
   `Reporting` dédié (helpers publics réutilisables).
9. Étendre le framework aux futurs domaines (Azure, Microsoft 365, Hyper-V,
   VMware, Network).
10. Ajouter une signature de code aux scripts de production.

---

## 11. Risques

| Risque | Impact | Mitigation |
| --- | --- | --- |
| Taille des rapports (≈ 230 Ko à cause de Chart.js inline) | Faible | Acceptable pour un rapport local ; Chart.js peut être retiré par paramètre si besoin |
| Palette dupliquée entre CSS et JS | Faible | Centraliser dans un fichier de thème si le nombre de graphiques augmente |
| Données sensibles dans les rapports | Moyen | Sorties Git ignorées, accès local contrôlé |
| Compatibilité PowerShell 5.1 | Faible | Aucune syntaxe PS7-only ; tests exécutés sous 7.6.9 |

---

*Rapport produit par l'architecte PowerShell / DevOps de scripts-hub.*
