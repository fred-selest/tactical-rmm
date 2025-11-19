# Scripts de surveillance pour Tactical RMM

Scripts pour surveiller et gérer des serveurs via Tactical RMM.

## Structure

```
scripts/
├── plesk/           # Scripts Bash pour serveurs Plesk
├── synology/        # Scripts Bash pour NAS Synology
├── windows/         # Scripts PowerShell pour Windows Server
├── activedirectory/ # Scripts PowerShell pour Active Directory
├── veeam/           # Scripts PowerShell pour Veeam Backup
├── eset/            # Scripts PowerShell pour ESET Endpoint
├── omada/           # Scripts PowerShell pour TP-Link Omada
└── README.md
```

## Scripts TP-Link Omada

Scripts PowerShell pour surveiller et gérer les équipements Omada (WiFi, Switches, Gateways).

| Script | Description |
|--------|-------------|
| `omada_check_status.ps1` | Surveillance complète du réseau |
| `omada_list_clients.ps1` | Liste des clients connectés |
| `omada_reboot_device.ps1` | Redémarrer un équipement |

Voir [omada/README.md](omada/README.md) pour la documentation complète.

## Scripts Windows Server

Scripts PowerShell pour surveiller les serveurs Windows.

| Script | Description |
|--------|-------------|
| `windows_surveillance_complete.ps1` | Surveillance complète (CPU, RAM, disques, services, événements, certificats) |

Voir [windows/README.md](windows/README.md) pour la documentation complète.

## Scripts Veeam Backup

Scripts PowerShell pour surveiller Veeam Backup & Replication.

| Script | Description |
|--------|-------------|
| `veeam_check_backups.ps1` | État des jobs, repositories, sessions |

Voir [veeam/README.md](veeam/README.md) pour la documentation complète.

## Scripts ESET Endpoint

Scripts PowerShell pour ESET Endpoint Security/Antivirus.

| Script | Description |
|--------|-------------|
| `eset_check_status.ps1` | État de protection, mises à jour, menaces |
| `eset_force_update.ps1` | Forcer la mise à jour des signatures |
| `eset_run_scan.ps1` | Lancer une analyse (rapide, complète, personnalisée) |

Voir [eset/README.md](eset/README.md) pour la documentation complète.

## Scripts Active Directory

Scripts PowerShell pour gérer Active Directory depuis le contrôleur de domaine.

| Script | Description |
|--------|-------------|
| `ad_create_user.ps1` | Créer un utilisateur |
| `ad_disable_user.ps1` | Désactiver un compte |
| `ad_reset_password.ps1` | Réinitialiser un mot de passe |
| `ad_unlock_account.ps1` | Déverrouiller un compte |
| `ad_delete_user.ps1` | Supprimer un utilisateur |
| `ad_list_users.ps1` | Lister les utilisateurs |
| `ad_add_to_group.ps1` | Ajouter à un groupe |
| `ad_create_group.ps1` | Créer un groupe |
| `ad_inventory.ps1` | Inventaire complet AD |

Voir [activedirectory/README.md](activedirectory/README.md) pour la documentation complète.

## Scripts Plesk

| Script | Description |
|--------|-------------|
| `plesk_surveillance_complete.sh` | **Script autonome** - Toutes les vérifications |
| `plesk_check_all.sh` | Exécute tous les scripts modulaires |
| `plesk_check_services.sh` | État des services (Apache, MySQL, etc.) |
| `plesk_check_disk.sh` | Espace disque par abonnement |
| `plesk_check_ssl.sh` | Expiration des certificats SSL |
| `plesk_check_mail.sh` | File d'attente email |
| `plesk_check_backup.sh` | État des sauvegardes |
| `plesk_check_security.sh` | Fail2ban, tentatives connexion |
| `plesk_check_docker.sh` | Conteneurs Docker, ressources, santé |
| `plesk_check_docker_compose.sh` | Stacks Docker Compose |

## Scripts Synology NAS

| Script | Description |
|--------|-------------|
| `synology_surveillance_complete.sh` | **Script autonome** - Toutes les vérifications |
| `synology_check_all.sh` | Exécute tous les scripts modulaires |
| `synology_check_system.sh` | CPU, RAM, température, ventilateurs, UPS |
| `synology_check_disks.sh` | État SMART, température des disques |
| `synology_check_raid.sh` | Volumes RAID, pools de stockage |
| `synology_check_services.sh` | Paquets installés, Docker, connexions |
| `synology_check_backup.sh` | Hyper Backup, Snapshot Replication |
| `synology_check_security.sh` | Blocages IP, connexions, mises à jour DSM |
| `synology_check_hyperbackup.sh` | **Nouveau** - Surveillance détaillée Hyper Backup |

## Installation dans Tactical RMM

### Méthode recommandée : Scripts autonomes

Utilisez les scripts `*_surveillance_complete.sh` qui sont autonomes et peuvent être copiés directement dans **Script Manager**.

1. Dans Tactical RMM → **Settings** → **Script Manager** → **New**
2. **Name** : `Synology - Surveillance complète` ou `Plesk - Surveillance complète`
3. **Shell** : `Shell`
4. **Timeout** : `120`
5. Copiez le contenu du script autonome
6. **Save**

### Téléchargement sur le serveur

#### Sur un serveur Plesk

```bash
mkdir -p /opt/tacticalrmm/scripts
cd /opt/tacticalrmm/scripts
wget https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/plesk/plesk_surveillance_complete.sh
chmod +x *.sh
```

#### Sur un NAS Synology

```bash
mkdir -p /opt/tacticalrmm/scripts
cd /opt/tacticalrmm/scripts
wget https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/synology/synology_surveillance_complete.sh
chmod +x *.sh
```

## Configuration des alertes

### Créer une tâche automatisée

1. Dans Tactical RMM → Sélectionnez l'agent
2. **Tasks** → **Add Task**
3. Configurez :
   - **Name** : `Surveillance Synology horaire`
   - **Script** : Sélectionnez votre script
   - **Schedule** : Daily, every 1 hour
   - **Alert on failure** : Coché
4. **Save**

## Codes de retour

- `0` : Tout est OK
- `1` : Alerte détectée (vérifiez la sortie)

## Personnalisation des seuils

### Plesk

```bash
SEUIL=80           # Alerte si utilisation disque > X%
JOURS_ALERTE=30    # Alerte si certificat expire dans moins de X jours
SEUIL_MAIL=100     # Alerte si file email > X messages
JOURS_MAX=7        # Alerte si sauvegarde > X jours
```

### Synology

```bash
TEMP_MAX=50        # Température max des disques en °C
SEUIL_DISK=85      # Alerte si volume > X%
```

## Exemples de sortie

### Synology - Surveillance complète

```
========================================
  SURVEILLANCE NAS SYNOLOGY
  2025-11-18 01:27:02
========================================

=== Informations système ===

Modèle: DS218+
DSM: 7.2.2 (build 72806)
Uptime: up 14 weeks, 6 days, 5 hours, 47 minutes

--- Ressources ---
[OK] CPU: 1.4%
[OK] RAM: 21% (2075Mo / 9796Mo)

=== État RAID / Volumes ===

Volume: md0 (raid1)
  Disques: 2/2 actifs
  [OK] État: clean

--- Utilisation des volumes ---
[OK] volume1: 41% utilisé (5.0T / 13T)

=== Services ===

[OK] Serveur Web
[OK] SSH
[OK] Samba/CIFS
[OK] Docker: 5/7 conteneurs actifs

=== Sécurité ===

IPs bloquées: 2

--- Liste des IPs bloquées ---
  - 192.168.10.16
  - plesk.votredomaine.com

========================================
RÉSULTAT: Tout est OK
========================================
```

## Installation agent sur Synology

Voir le fichier `SYNOLOGY_AGENT_INSTALL.md` pour les instructions détaillées.

## Dépannage

### Plesk

```bash
# Tester manuellement
bash -x /opt/tacticalrmm/scripts/plesk_surveillance_complete.sh
```

### Synology

```bash
# Tester manuellement
bash -x /opt/tacticalrmm/scripts/synology_surveillance_complete.sh

# Vérifier qu'on est sur Synology
cat /etc/synoinfo.conf
```
