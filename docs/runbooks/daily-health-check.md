# Runbook : contrôle de santé quotidien

## Objectif

Produire chaque jour un état consolidé du poste ou du serveur : inventaire,
volumes, posture de sécurité, puis archiver les rapports.

## Fréquence

Quotidienne, en début de journée. Durée attendue : moins de deux minutes.

## Prérequis

- PowerShell 7 (`pwsh`)
- Modules `Common`, `Inventory`, `Security`, `Reporting`
- Droits de lecture sur les sources auditées

## Procédure

### 1. Vérifier l'environnement

```powershell
pwsh -NoProfile -File .\tools\maintenance\Test-Environment.ps1
```

Attendu : PowerShell 7.x, x64, Git détecté, Pester et PSScriptAnalyzer présents.

### 2. Inventaire système

```powershell
pwsh -NoProfile -File .\src\Inventory\Get-SystemInventory.ps1 -Format All
```

Contrôles :

- le rapport HTML s'ouvre sans erreur ;
- chaque volume affiche un `Health` différent de `Critique` ;
- le JSON contient `ComputerName` et `Volumes`.

### 3. Posture de sécurité

```powershell
pwsh -NoProfile -File .\src\Security\Get-SecurityPosture.ps1 -Format All
```

Contrôles :

- pare-feu activé sur les trois profils ;
- Defender actif si le poste est managé ;
- administrateurs locaux limités aux comptes attendus.

### 4. Vérifier les journaux

```powershell
Get-Content .\logs\$(Get-Date -Format 'yyyy-MM-dd')_Security_Posture.log -Tail 20
```

Aucune ligne `[ERROR]` ne doit apparaître.

### 5. Archiver

Copier les rapports du jour dans `reports/archive/` si une conservation
hors ligne est requise, puis purger selon la rétention :

```powershell
.\tools\maintenance\Clear-OldReports.ps1 -Days 90 -WhatIf
```

## Critères de succès

- [ ] Les trois livrables HTML/CSV/JSON existent pour chaque script exécuté.
- [ ] Le journal ne contient ni `ERROR` ni exception non gérée.
- [ ] Aucun volume en `Critique`.
- [ ] Pare-feu actif sur tous les profils.
- [ ] Durée totale inférieure à cinq minutes.

## Escalade

| Constat | Gravité | Action |
| --- | --- | --- |
| Volume `Critique` (> 90 %) | Haute | Libérer de l'espace, ouvrir un ticket |
| Pare-feu désactivé | Haute | Vérifier GPO, réactiver après validation |
| Defender désactivé | Haute | Vérifier politique de sécurité |
| Compte admin inconnu | Moyenne | Vérifier avec l'équipe sécurité |
| Échec de collecte CIM | Moyenne | Vérifier le service WMI |
| Module absent | Basse | Installer la dépendance |

## Automatisation

Planifier via le Planificateur de tâches :

```powershell
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -File "D:\scripts-hub\src\Inventory\Get-SystemInventory.ps1" -Format All'
$trigger = New-ScheduledTaskTrigger -Daily -At '07:00'
Register-ScheduledTask -TaskName 'ScriptsHub-DailyHealth' -Action $action -Trigger $trigger -Description 'Contrôle de santé quotidien scripts-hub'
```

La tâche doit s'exécuter avec un compte disposant des droits de lecture requis,
sans élévation inutile.
