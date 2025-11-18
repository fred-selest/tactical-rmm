# Scripts de surveillance pour Tactical RMM

Scripts Bash pour surveiller des serveurs Plesk et NAS Synology via Tactical RMM.

## Scripts Plesk

| Script | Description |
|--------|-------------|
| `plesk_check_all.sh` | Exécute toutes les vérifications Plesk |
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
| `synology_check_all.sh` | Exécute toutes les vérifications Synology |
| `synology_check_system.sh` | CPU, RAM, température, ventilateurs, UPS |
| `synology_check_disks.sh` | État SMART, température des disques |
| `synology_check_raid.sh` | Volumes RAID, pools de stockage |
| `synology_check_services.sh` | Paquets installés, Docker, connexions |
| `synology_check_backup.sh` | Hyper Backup, Snapshot Replication |
| `synology_check_security.sh` | Blocages IP, connexions, mises à jour DSM |

## Installation dans Tactical RMM

### Méthode 1 : Script individuel

1. Dans Tactical RMM → **Settings** → **Script Manager**
2. Cliquez sur **New**
3. Nom : `Plesk - Vérification SSL` (par exemple)
4. Type : `Shell`
5. Collez le contenu du script
6. Enregistrez

### Méthode 2 : Télécharger tous les scripts

#### Sur un serveur Plesk

```bash
mkdir -p /opt/tacticalrmm/scripts
cd /opt/tacticalrmm/scripts
for script in plesk_check_all plesk_check_services plesk_check_disk plesk_check_ssl plesk_check_mail plesk_check_backup plesk_check_security plesk_check_docker plesk_check_docker_compose; do
  wget "https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/${script}.sh"
done
chmod +x *.sh
```

#### Sur un NAS Synology

```bash
mkdir -p /opt/tacticalrmm/scripts
cd /opt/tacticalrmm/scripts
for script in synology_check_all synology_check_system synology_check_disks synology_check_raid synology_check_services synology_check_backup synology_check_security; do
  wget "https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/${script}.sh"
done
chmod +x *.sh
```

## Configuration des alertes

### Créer une tâche automatisée

1. Dans Tactical RMM → Sélectionnez l'agent
2. **Tasks** → **Add Task**
3. Configurez :
   - Nom : `Surveillance Plesk` ou `Surveillance Synology`
   - Type : `Script`
   - Script : Sélectionnez votre script
   - Planification : Toutes les heures (ou selon besoin)

### Configurer les alertes

1. **Settings** → **Automation Manager**
2. **Policies** → Créez une nouvelle politique
3. Ajoutez une condition sur le code de retour du script
4. Si code ≠ 0 → Envoyer une alerte

## Codes de retour

- `0` : Tout est OK
- `1` : Alerte détectée (vérifiez la sortie)

## Personnalisation

### Seuils Plesk

```bash
# plesk_check_ssl.sh
JOURS_ALERTE=30    # Alerte si certificat expire dans moins de X jours

# plesk_check_disk.sh
SEUIL=80           # Alerte si utilisation disque > X%

# plesk_check_mail.sh
SEUIL=100          # Alerte si file email > X messages

# plesk_check_backup.sh
JOURS_MAX=7        # Alerte si sauvegarde > X jours
```

### Seuils Synology

```bash
# synology_check_disks.sh
TEMP_MAX=50        # Température max des disques en °C

# synology_check_raid.sh
SEUIL=85           # Alerte si volume > X%

# synology_check_backup.sh
JOURS_MAX=7        # Alerte si sauvegarde > X jours
```

## Exemples de sortie

### Plesk - Services OK
```
[OK] Plesk (psa)
[OK] Nginx (nginx)
[OK] MariaDB (mariadb)
[OK] PHP-FPM (45 processus)
```

### Synology - Disques OK
```
Disque: sda
  Modèle: WDC WD40EFRX
  [OK] Santé SMART: PASSED
  [OK] Température: 35°C

Disque: sdb
  Modèle: WDC WD40EFRX
  [OK] Santé SMART: PASSED
  [OK] Température: 36°C
```

### Synology - Alerte RAID
```
Volume: md2 (raid1)
  Disques: 1/2 actifs
  [ALERTE] État: degraded (volume dégradé)
  [ALERTE] 1 disque(s) en échec
```

## Installation agent sur Synology

Pour installer l'agent Tactical RMM sur un NAS Synology :

1. Activez SSH dans DSM : **Panneau de configuration** → **Terminal & SNMP** → **Activer SSH**
2. Connectez-vous en SSH
3. Utilisez le script d'installation Linux (voir LINUX_AGENT_INSTALL.md)

**Note** : Sur DSM 7+, certaines limitations peuvent s'appliquer. Utilisez un compte admin.

## Dépannage

### Plesk

```bash
# Tester manuellement
bash -x /opt/tacticalrmm/scripts/plesk_check_services.sh

# Vérifier les permissions
chmod +x /opt/tacticalrmm/scripts/*.sh

# Vérifier l'accès Plesk
plesk bin --help
```

### Synology

```bash
# Tester manuellement
bash -x /opt/tacticalrmm/scripts/synology_check_system.sh

# Vérifier les permissions
chmod +x /opt/tacticalrmm/scripts/*.sh

# Vérifier qu'on est sur Synology
cat /etc/synoinfo.conf
```
