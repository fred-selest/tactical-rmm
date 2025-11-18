# Scripts Windows Server pour Tactical RMM

Scripts PowerShell pour surveiller les serveurs Windows.

## Scripts disponibles

| Script | Description |
|--------|-------------|
| `windows_surveillance_complete.ps1` | Surveillance complète du serveur |

## Fonctionnalités de surveillance

Le script `windows_surveillance_complete.ps1` vérifie :

- **Système** : OS, uptime, domaine
- **CPU** : Utilisation actuelle
- **Mémoire** : RAM utilisée/libre
- **Disques** : Espace par volume
- **Services critiques** : État des services Windows importants
- **Événements** : Erreurs système/application des 24h
- **Mises à jour** : Windows Updates en attente
- **Réseau** : Connexions établies
- **Certificats** : Expiration SSL
- **Tâches planifiées** : Tâches en erreur

## Installation dans Tactical RMM

1. **Settings** > **Script Manager** > **New Script**
2. Nom : `Windows - Surveillance complète`
3. Type : **PowerShell**
4. Coller le contenu du script
5. Sauvegarder

## Utilisation

### Surveillance manuelle

1. Sélectionner l'agent Windows Server
2. **Run Script** > **Windows - Surveillance complète**
3. Pas de paramètres requis

### Tâche planifiée

1. **Automation** > **Tasks** > **Add Task**
2. Script : Windows - Surveillance complète
3. Schedule : Toutes les heures ou selon besoin
4. Action : Email si erreur

### Check automatisé

1. **Automation** > **Checks** > **Add Check**
2. Type : Script Check
3. Script : Windows - Surveillance complète
4. Condition : Si sortie contient `[ALERTE]` ou `[ERREUR]`

## Services surveillés

Le script vérifie automatiquement ces services s'ils sont installés :

| Service | Description |
|---------|-------------|
| W32Time | Temps Windows |
| Dnscache | Client DNS |
| EventLog | Journal d'événements |
| WinRM | Gestion à distance |
| LanmanServer | Partages réseau |
| MSSQLSERVER | SQL Server |
| W3SVC | IIS |
| NTDS | AD DS (DC) |
| DNS | Serveur DNS (DC) |
| Netlogon | Netlogon (DC) |

## Seuils d'alerte

| Métrique | Attention | Critique |
|----------|-----------|----------|
| CPU | > 70% | > 90% |
| RAM | > 80% | > 90% |
| Disque | > 80% | > 90% |
| Certificat | < 30 jours | Expiré |
| Mises à jour | Importantes | Critiques |

## Exemple de sortie

```
==========================================
SURVEILLANCE WINDOWS SERVER
Serveur: SRV-DC01
Date: 2025-11-18 14:30:00
==========================================

--- CPU ---
Utilisation: 45%
[OK] Charge CPU normale

--- MEMOIRE ---
Utilisé: 12.5 GB (78%)
[OK] Mémoire normale

--- DISQUES ---
C: [OK] 85/200 GB (42%) - Libre: 115 GB
D: [ATTENTION] 450/500 GB (90%) - Libre: 50 GB

--- SERVICES CRITIQUES ---
[OK] Windows Time
[OK] DNS Client
[ERREUR] Print Spooler - Stopped
```

## Personnalisation

### Ajouter des services à surveiller

Modifier la liste `$CriticalServices` dans le script :

```powershell
$CriticalServices = @(
    "W32Time",
    "VotreService",
    # ...
)
```

### Modifier les seuils

Modifier les valeurs dans les conditions :

```powershell
if ($CPULoad -gt 90) {  # Critique
if ($CPULoad -gt 70) {  # Attention
```
