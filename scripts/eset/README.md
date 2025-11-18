# Scripts ESET Endpoint pour Tactical RMM

Scripts PowerShell pour surveiller et gérer ESET Endpoint Security/Antivirus.

## Scripts disponibles

| Script | Description |
|--------|-------------|
| `eset_check_status.ps1` | Surveillance complète de l'état ESET |
| `eset_force_update.ps1` | Forcer la mise à jour des signatures |
| `eset_run_scan.ps1` | Lancer une analyse antivirus |

## Fonctionnalités de surveillance

Le script `eset_check_status.ps1` vérifie :

- **Produit** : Version, édition
- **Modules** : État des composants (temps réel, firewall, etc.)
- **Protection** : Statut de la protection temps réel
- **Mises à jour** : Date de la dernière mise à jour
- **Menaces** : Détections des 30 derniers jours
- **Analyses** : Historique des scans récents
- **Licence** : Expiration

## Prérequis

- ESET Endpoint Security ou ESET Endpoint Antivirus installé
- Droits administrateur local

## Installation dans Tactical RMM

### Importer les scripts

1. **Settings** > **Script Manager** > **New Script**
2. Pour chaque script :
   - Nom : `ESET - [Description]`
   - Type : **PowerShell**
   - Coller le contenu

### Scripts à créer

| Nom | Script |
|-----|--------|
| ESET - État protection | `eset_check_status.ps1` |
| ESET - Forcer mise à jour | `eset_force_update.ps1` |
| ESET - Analyse rapide | `eset_run_scan.ps1` |

## Utilisation

### Vérifier l'état de protection

```powershell
# Pas de paramètres
.\eset_check_status.ps1
```

### Forcer une mise à jour

```powershell
.\eset_force_update.ps1
```

### Lancer une analyse

```powershell
# Analyse rapide
.\eset_run_scan.ps1 -ScanType Quick

# Analyse complète
.\eset_run_scan.ps1 -ScanType Full

# Analyse d'un dossier spécifique
.\eset_run_scan.ps1 -ScanType Custom -CustomPath "D:\Data"
```

## Paramètres

### eset_run_scan.ps1

| Paramètre | Description | Valeurs |
|-----------|-------------|---------|
| `-ScanType` | Type d'analyse | Quick, Full, Custom |
| `-CustomPath` | Chemin pour analyse personnalisée | Chemin Windows |

## Automatisation recommandée

### Surveillance quotidienne

1. **Automation** > **Checks** > **Add Check**
2. Script : ESET - État protection
3. Schedule : Toutes les 4 heures
4. Condition : Si sortie contient `[ERREUR]`
5. Alerte : Email

### Mise à jour automatique

1. **Automation** > **Tasks** > **Add Task**
2. Script : ESET - Forcer mise à jour
3. Schedule : Tous les jours à 12h
4. Cible : Tous les postes avec ESET

### Analyse hebdomadaire

1. **Automation** > **Tasks** > **Add Task**
2. Script : ESET - Analyse rapide
3. Arguments : `-ScanType Quick`
4. Schedule : Tous les dimanches à 2h

## Exemple de sortie

### État de protection

```
==========================================
SURVEILLANCE ESET ENDPOINT
Poste: PC-COMPTA01
==========================================

--- INFORMATIONS PRODUIT ---
Produit: ESET Endpoint Security
Version: 10.0.2045.0

--- ETAT DES MODULES ---
[OK] ESET Service
[OK] Personal Firewall

--- ETAT DE LA PROTECTION ---
[OK] Protection temps réel active
[OK] Pare-feu actif

--- MISES A JOUR ---
[OK] Base de signatures: 2025-11-18

--- MENACES DETECTEES (30 derniers jours) ---
[OK] Aucune menace détectée

--- LICENCE ---
[OK] Expire le: 2026-06-15 (209 jours restants)

--- RESUME ---
[OK] Protection ESET fonctionnelle
==========================================
```

### Menaces détectées

```
--- MENACES DETECTEES (30 derniers jours) ---
Menaces détectées: 2

[2025-11-15 14:32] Win32/Adware.Agent
   Fichier: C:\Users\User\Downloads\setup.exe
   Action: Cleaned

[2025-11-10 09:15] JS/TrojanDownloader
   Fichier: C:\Temp\script.js
   Action: Deleted
```

## Seuils d'alerte

| Condition | Sévérité | Action recommandée |
|-----------|----------|-------------------|
| Protection temps réel inactive | Critique | Email + SMS |
| Menace détectée | Attention | Email |
| Mise à jour > 7 jours | Attention | Forcer update |
| Licence < 30 jours | Attention | Email admin |
| Licence expirée | Critique | Email + intervention |

## Intégration ESET PROTECT

Si vous utilisez ESET PROTECT (console centralisée), ces scripts peuvent compléter la surveillance en fournissant :

- Alertes en temps réel dans Tactical RMM
- Actions correctives automatiques
- Rapports consolidés multi-clients

## Dépannage

### ESET non détecté

Vérifier l'installation :

```powershell
# Vérifier le service
Get-Service -Name "ekrn"

# Vérifier le registre
Get-ItemProperty "HKLM:\SOFTWARE\ESET\ESET Security\CurrentVersion\Info"
```

### ecmd.exe non trouvé

Chercher l'emplacement :

```powershell
Get-ChildItem -Path "${env:ProgramFiles}" -Recurse -Filter "ecmd.exe" -ErrorAction SilentlyContinue
```

### Erreur WMI

Vérifier l'espace de noms ESET :

```powershell
Get-WmiObject -Namespace "root\ESET" -List
```

## Ressources

- [Documentation ESET](https://help.eset.com/)
- [ESET Command Line](https://help.eset.com/ees/10/en-US/idh_command_line.html)
- [ESET WMI Provider](https://help.eset.com/protect_admin/10/en-US/wmi_provider.html)
