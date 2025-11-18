# Scripts Veeam pour Tactical RMM

Scripts PowerShell pour surveiller Veeam Backup & Replication.

## Scripts disponibles

| Script | Description |
|--------|-------------|
| `veeam_check_backups.ps1` | Surveillance complète des jobs Veeam |

## Fonctionnalités

Le script vérifie :

- **État général** : Serveur, licence, expiration
- **Jobs de sauvegarde** : Statut, dernière exécution, durée
- **Jobs de réplication** : État des réplicas
- **Repositories** : Espace disponible
- **Sessions en cours** : Progression des sauvegardes actives
- **Tapes** : Jobs de sauvegarde sur bande (si configuré)
- **Alertes système** : Alertes Veeam actives

## Prérequis

- Veeam Backup & Replication installé
- PowerShell Snapin Veeam (`VeeamPSSnapin`)
- Droits d'administration Veeam

## Installation dans Tactical RMM

1. **Settings** > **Script Manager** > **New Script**
2. Nom : `Veeam - Surveillance backups`
3. Type : **PowerShell**
4. Coller le contenu du script
5. Sauvegarder

## Paramètres

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| `-WarningHours` | Alerte si backup > X heures | 24 |
| `-CriticalHours` | Critique si backup > X heures | 48 |

## Utilisation

### Surveillance quotidienne

```powershell
# Paramètres par défaut (24h warning, 48h critical)
.\veeam_check_backups.ps1

# Paramètres personnalisés
.\veeam_check_backups.ps1 -WarningHours 12 -CriticalHours 24
```

### Tâche planifiée Tactical RMM

1. **Automation** > **Tasks** > **Add Task**
2. Script : Veeam - Surveillance backups
3. Schedule : Tous les jours à 8h
4. Action : Email au support

### Check automatisé

1. **Automation** > **Checks** > **Add Check**
2. Type : Script Check
3. Script : Veeam - Surveillance backups
4. Condition : Code de sortie ≠ 0
5. Alerte : Email + SMS

## Codes de sortie

| Code | Signification |
|------|---------------|
| 0 | Tous les jobs OK |
| 1 | Au moins un job en échec |

## Exemple de sortie

```
==========================================
SURVEILLANCE VEEAM BACKUP
Serveur: SRV-BACKUP
==========================================

--- ETAT GENERAL ---
Serveur Veeam: SRV-BACKUP
Licence: Enterprise Plus
Expiration: 2026-01-15

--- JOBS DE SAUVEGARDE ---
[OK] Backup-DC
   Statut: Success
   Dernière exécution: 2025-11-18 02:00
   Durée: 1h 23m
   Il y a: 12.5 heures

[ERREUR] Backup-SQL
   Statut: Failed
   Dernière exécution: 2025-11-17 22:00
   Il y a: 16.5 heures

--- REPOSITORIES ---
[OK] Repo-Local
   Espace: 2.5/10 TB (25%)
   Libre: 7.5 TB

[ATTENTION] Repo-NAS
   Espace: 8.5/10 TB (85%)
   Libre: 1.5 TB

--- RESUME ---
Jobs totaux: 5
Succès: 4
Échecs: 1
[ALERTE] 1 job(s) en échec!
```

## Dépannage

### Erreur : Snapin non disponible

```powershell
# Vérifier l'installation
Get-PSSnapin -Registered | Where-Object { $_.Name -like "*Veeam*" }

# Charger manuellement
Add-PSSnapin VeeamPSSnapin
```

### Erreur : Accès refusé

L'agent Tactical RMM doit être configuré pour utiliser un compte avec droits Veeam :

```powershell
sc.exe config "tacticalagent" obj= "DOMAIN\svc-tactical" password= "Password"
```

## Alertes recommandées

| Condition | Sévérité | Action |
|-----------|----------|--------|
| Job en échec | Critique | Email + SMS |
| Repository > 90% | Critique | Email |
| Licence < 30 jours | Attention | Email admin |
| Job > 48h | Critique | Email |
