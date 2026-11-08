# Contributing

Merci de contribuer à `scripts-hub`. Ce document décrit le workflow, les
conventions de code et les règles de revue.

## 1. Workflow Git

Convention GitFlow simplifiée :

```text
main        -> état stable, protégé, livrable
develop     -> intégration continue des travaux
feature/*   -> nouvelle fonctionnalité
fix/*       -> correction de défaut
chore/*     -> maintenance, outillage, documentation
hotfix/*    -> correctif urgent depuis main
```

Processus :

1. Créer une branche depuis `develop` :
   `git switch -c feature/ad-inventory develop`
2. Committer par lots cohérents avec la convention ci-dessous.
3. Ouvrir une Pull Request vers `develop`.
4. Vérifier que `tools/build/Build.ps1` passe.
5. Fusionner après revue ; `develop` est fusionnée dans `main` à chaque release.

### Convention de commits

```text
<type>: <description à l'impératif, minuscule, sans point final>
```

| Type | Usage |
| --- | --- |
| `feat` | nouvelle fonctionnalité ou script |
| `fix` | correction de défaut |
| `docs` | documentation uniquement |
| `refactor` | restructuration sans changement de comportement |
| `test` | ajout ou correction de tests |
| `build` | outillage, CI, dépendances |
| `chore` | tâche de maintenance diverse |

Exemples :

```text
feat: add active directory inventory module
fix: correct html report encoding
docs: update deployment guide
refactor: split reporting module
test: add pester unit tests
```

## 2. Conventions de code

### Nommage

- Scripts : `Verbe-Nom.ps1` avec un verbe approuvé (`Get-Verb`).
- Fonctions : `Verbe-Nom` au singulier, en PascalCase.
- Modules : un dossier par module, `<Nom>.psm1` + `<Nom>.psd1`.
- Variables : `$camelCase` pour les locales, `$PascalCase` pour les paramètres.
- Paramètres : PascalCase, explicites (`-OutputDirectory`, pas `-Out`).

### Structure d'un script

1. `#Requires -Version 5.1`
2. Bloc d'aide complet (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES`)
3. `[CmdletBinding()]` et `param()`
4. `Set-StrictMode -Version Latest` et `$ErrorActionPreference = 'Stop'`
5. Import des modules
6. `try / catch / finally`
7. Sortie d'un objet de synthèse (`-PassThru`)

### Compatibilité

Le code de `src/` et `modules/` doit fonctionner sous Windows PowerShell 5.1 :

- pas d'opérateur ternaire, pas de `??`, pas de `-Parallel` ;
- `Join-Path` imbriqué plutôt que `-AdditionalChildPath` ;
- pas de `using namespace` non disponible en 5.1.

### Encodage

Tous les fichiers texte sont en **UTF-8 avec BOM**, fins de ligne CRLF.
`tools/maintenance/Set-FileEncoding.ps1` applique cette normalisation.

## 3. Qualité

- Aucune erreur PSScriptAnalyzer (règles par défaut).
- Tests Pester pour toute nouvelle fonction exportée.
- Gestion explicite des erreurs, pas de `catch { }` vide.
- Pas de secret, jeton ou mot de passe dans le dépôt.

## 4. Revue de code

Checklist du relecteur :

- [ ] Le nom respecte les verbes approuvés.
- [ ] L'en-tête d'aide est complet et exact.
- [ ] Les erreurs sont gérées et journalisées.
- [ ] Le script est idempotent.
- [ ] Les sorties respectent `YYYY-MM-DD_Type_Rapport.ext`.
- [ ] Les tests couvrent le comportement nominal et les cas d'erreur.
- [ ] La documentation est mise à jour.
- [ ] `Build.ps1` passe localement.

## 5. Sécurité

Signaler toute vulnérabilité en privé à l'équipe `scripts-hub` plutôt que via une
issue publique. Ne jamais committer de données d'infrastructure sensibles :
utiliser `config/environments/` avec des valeurs d'exemple.
