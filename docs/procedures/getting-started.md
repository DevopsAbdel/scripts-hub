# Prise en main

## 1. Prérequis

- Windows 10/11 ou Windows Server 2019+
- PowerShell 7.2+ (**environnement par défaut**) et Windows PowerShell 5.1
- Git 2.30+
- Accès en lecture au dépôt

## 2. Récupération du dépôt

```powershell
git clone https://github.com/DevopsAbdel/scripts-hub.git
Set-Location .\scripts-hub
```

## 3. Ouverture dans VS Code

Ouvrir `scripts-hub.code-workspace`. Le terminal intégré démarre en
PowerShell 7, avec les tâches `build`, `test` et `environment-audit`.

## 4. Dépendances de développement

```powershell
.\tools\deployment\Install-HubModules.ps1
```

Installe Pester 5+ et PSScriptAnalyzer dans la portée utilisateur.
Utiliser `-Scope AllUsers` pour une installation machine (administrateur).

## 5. Vérification de l'environnement

```powershell
.\tools\maintenance\Test-Environment.ps1
```

Contrôle : versions PowerShell, architecture x64, assemblys .NET, Git,
modules de développement.

## 6. Premier rapport

```powershell
.\src\Inventory\Get-SystemInventory.ps1
```

Livrables :

```text
reports/html/2026-11-08_System_Inventory.html
reports/csv/2026-11-08_System_Inventory.csv
reports/json/2026-11-08_System_Inventory.json
logs/2026-11-08_System_Inventory.log
```

## 7. Audit de sécurité

```powershell
.\src\Security\Get-SecurityPosture.ps1
```

## 8. Inventaire Active Directory

Prérequis : RSAT (`ActiveDirectory`), compte autorisé, connectivité au DC.

```powershell
.\src\ActiveDirectory\Get-ADInventory.ps1 -Server dc01.contoso.com
```

## 9. Qualité

```powershell
# Tout : conformité, analyse statique, tests
.\tools\build\Build.ps1

# Tests seuls
Invoke-Pester -Path .\tests -Output Detailed
```

## 10. Ajouter un script

1. Créer la branche : `git switch -c feature/mon-script develop`.
2. Créer `src\<Domaine>\Verbe-Nom.ps1` avec l'en-tête standard.
3. Extraire la logique réutilisable dans un module.
4. Ajouter les tests dans `tests/unit/`.
5. Mettre à jour la documentation et le `CHANGELOG.md`.
6. Lancer `.\tools\build\Build.ps1`.
7. Ouvrir une Pull Request vers `develop`.

## 11. Normaliser l'encodage

```powershell
.\tools\maintenance\Set-FileEncoding.ps1
```

Réécrit les fichiers texte en UTF-8 BOM / CRLF. Idempotent.

## 12. Purger les anciens rapports

```powershell
.\tools\maintenance\Clear-OldReports.ps1 -Days 90 -WhatIf
.\tools\maintenance\Clear-OldReports.ps1 -Days 90
```

## Dépannage

| Symptôme | Cause probable | Action |
| --- | --- | --- |
| `Get-ADDomain` introuvable | RSAT absent | Installer `RSAT-AD-PowerShell` |
| `Get-MpComputerStatus` introuvable | Module Defender absent | Audit partiel, voir avertissements |
| Fonctions non reconnues | Module non importé | Vérifier le chemin `$PSScriptRoot` |
| Caractères accentués incorrects | Fichier sans BOM | `Set-FileEncoding.ps1` |
| Pester 3 détecté | Ancienne version système | `Install-HubModules.ps1` |
