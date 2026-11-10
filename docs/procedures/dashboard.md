# Dashboard web local

Le dashboard est une interface de pilotage locale, servie uniquement sur
l'interface de bouclage (`http://localhost:<port>`). Elle ne remplace pas les
scripts : elle les lance, affiche l'état du hub et donne accès aux livrables.

## Démarrage

```powershell
# Depuis la racine du dépôt
.\src\Dashboard\Start-HubDashboard.ps1

# Port personnalisé, sans ouverture automatique du navigateur
.\src\Dashboard\Start-HubDashboard.ps1 -Port 8090 -NoBrowser
```

Le navigateur par défaut s'ouvre sur `http://localhost:8080`. Le serveur
s'arrête avec `Ctrl+C` ou le bouton **Arrêter** de la page.

Dans VS Code, la tâche `dashboard` du workspace lance le serveur.

## Fonctionnalités

| Zone | Contenu |
| --- | --- |
| KPI | Nombre de rapports HTML, CSV, JSON, scripts prêts et journaux. |
| Scripts disponibles | Inventaire système, posture de sécurité, inventaire Active Directory. |
| Exécution | Lancement en arrière-plan, sortie console en direct, liens vers les livrables. |
| Rapports générés | Filtre instantané, tri des colonnes, ouverture HTML, téléchargement CSV/JSON. |
| Journaux récents | Consultation des 25 derniers fichiers de `logs/` dans une visionneuse. |

L'exécution est protégée par une **liste blanche** définie dans
`modules/Dashboard/Dashboard.psm1` : aucune commande arbitraire ne peut être
envoyée au serveur. Un seul script peut s'exécuter à la fois ; la durée est
limitée par `-RunTimeoutSeconds` (300 s par défaut).

## API locale

| Méthode | Route | Rôle |
| --- | --- | --- |
| `GET` | `/` | Page du dashboard (CSS et JS embarqués). |
| `GET` | `/api/state` | Environnement, rapports, actions et journaux. |
| `POST` | `/api/run` | Démarre une action (`{"id":"inventory"}`). |
| `GET` | `/api/run/status` | État, sortie et livrables de l'exécution courante. |
| `GET` | `/api/log?name=...` | Dernières lignes d'un journal (200 max). |
| `GET` | `/reports/<type>/<fichier>` | Sert un rapport HTML ou télécharge un export. |
| `POST` | `/api/shutdown` | Arrête proprement le serveur. |

## Sécurité

- Écoute limitée à `localhost` : aucun accès depuis le réseau.
- Aucune ressource Internet : pas de CDN, pas de police distante, pas de
  télémétrie. La page fonctionne hors ligne.
- Chemins de fichiers validés : type `html|csv|json`, nom de fichier filtré et
  vérification que le chemin résolu reste sous `reports/`.
- Noms de journaux validés et confinement sous `logs/`.
- Livrables servis en lecture seule ; le dashboard ne modifie aucun rapport.

## Dépannage

| Symptôme | Cause probable | Action |
| --- | --- | --- |
| `Impossible de démarrer le dashboard` | Port déjà utilisé | Relancer avec `-Port 8090`. |
| Page blanche | JavaScript désactivé ou page obsolète | Recharger avec `Ctrl+F5`. |
| Action « Indisponible » | Script absent ou module RSAT manquant | Lire la note sous la carte, installer le prérequis. |
| Aucun rapport | Aucun script exécuté aujourd'hui | Lancer une action ou un script en console. |
| Sortie figée | Script long | Attendre la fin ou consulter `logs/`. |
