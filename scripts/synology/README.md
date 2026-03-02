# Scripts de surveillance Synology pour Tactical RMM

Scripts Bash optimisés pour surveiller les NAS Synology sous DSM 7.x.

## Scripts disponibles

| Script | Description |
|--------|-------------|
| `synology_surveillance_complete.sh` | Surveillance complète du NAS |
| `synology_check_all.sh` | Vérification rapide de tous les composants |
| `synology_check_system.sh` | Informations système (modèle, DSM, température) |
| `synology_check_disks.sh` | État des disques (santé SMART, températures) |
| `synology_check_raid.sh` | État du RAID/SHR et volumes |
| `synology_check_services.sh` | Services critiques Synology |
| `synology_check_backup.sh` | Sauvegardes Hyper Backup et Cloud Sync |
| `synology_check_hyperbackup.sh` | Détails Hyper Backup (tâches, rotation) |
| `synology_check_security.sh` | Sécurité et pare-feu |

## Prérequis

- Synology NAS avec DSM 7.0 ou supérieur
- SSH activé (**Panneau de configuration** > **Terminal & SNMP** > **Activer le service SSH**)
- Agent Tactical RMM installé (voir `/SYNOLOGY_AGENT_INSTALL.md`)
- Accès root ou compte admin avec privilèges sudo

## Installation de l'agent

Voir la documentation : [SYNOLOGY_AGENT_INSTALL.md](/SYNOLOGY_AGENT_INSTALL.md)

```bash
# Installation rapide
wget https://raw.githubusercontent.com/votre-user/tactical-rmm/main/rmmagent-linux-ameliore.sh
chmod +x rmmagent-linux-ameliore.sh
sudo ./rmmagent-linux-ameliore.sh install \
  "https://mesh.votredomaine.com/meshagents?id=XXX" \
  "https://api.votredomaine.com" \
  "123" "456" "auth-key" "server"
```

## Installation des scripts dans Tactical RMM

### Méthode 1 : Script par script

1. **Settings** > **Script Manager** > **New Script**
2. Pour chaque script :
   - Nom : `Synology - <Nom du script>`
   - Type : **Shell**
   - Coller le contenu du script
   - Catégorie : `Synology`
   - Save

### Méthode 2 : Import en masse (recommandé)

```bash
# Sur votre poste de travail, cloner le dépôt
git clone https://github.com/votre-user/tactical-rmm.git
cd tactical-rmm/scripts/synology

# Puis importer via l'interface Tactical RMM
# Settings > Script Manager > Import
```

## Utilisation

### Surveillance complète (recommandé)

```bash
# Exécution manuelle sur le NAS
bash synology_surveillance_complete.sh

# Via Tactical RMM
# Agents > Sélectionner le NAS > Run Script > Synology - Surveillance complète
```

### Vérifications spécifiques

```bash
# État des disques
bash synology_check_disks.sh

# État du RAID
bash synology_check_raid.sh

# Sauvegardes Hyper Backup
bash synology_check_hyperbackup.sh

# Température et système
bash synology_check_system.sh
```

## Fonctionnalités de surveillance

### synology_surveillance_complete.sh

Vérifie l'ensemble du NAS :
- **Système** : Modèle, numéro de série, version DSM, uptime
- **Températures** : CPU, disques, système
- **Disques** : Santé SMART, erreurs, température
- **RAID** : État du RAID/SHR, volumes, expansion
- **Mémoire** : RAM utilisée, swap
- **Services** : Services critiques DSM
- **Réseau** : Interfaces, LAN, adresses IP
- **Sauvegardes** : Hyper Backup, Cloud Sync
- **Sécurité** : Pare-feu, tentatives de connexion échouées
- **Mises à jour** : Disponibilité de mises à jour DSM

**Exemple de sortie :**
```
==========================================
SURVEILLANCE SYNOLOGY NAS
Modèle: DS920+
Série: 20C0PDN123456
==========================================

--- SYSTÈME ---
[OK] DSM 7.2.1-69057 Update 5
[OK] Uptime: 45 jours 12 heures
[OK] Température CPU: 42°C
[OK] Température système: 38°C

--- DISQUES ---
[OK] Disk 1 (WD Red 4TB): Healthy, 35°C
[OK] Disk 2 (WD Red 4TB): Healthy, 36°C
[OK] Disk 3 (WD Red 4TB): Healthy, 34°C
[OK] Disk 4 (WD Red 4TB): Healthy, 37°C

--- RAID ---
[OK] Volume 1 (SHR): Normal, 10.9 TB / 14.5 TB (75%)
[OK] RAID Status: Healthy
[OK] Parity Check: OK (18/12/2025)

--- SERVICES ---
[OK] DSM Portal: actif
[OK] SSH: actif
[OK] AFP/SMB: actif
[OK] Docker: actif (12 containers)

--- SAUVEGARDES ---
[OK] Hyper Backup: dernière 18/12/2025 02:00
[OK] Cloud Sync: synchronisé il y a 15 min

==========================================
RÉSULTAT: SYSTÈME SAIN
==========================================
```

### synology_check_disks.sh

Surveillance détaillée des disques :
- État de santé SMART (Healthy, Warning, Critical)
- Température de chaque disque
- Nombre de secteurs réalloués
- Heures de fonctionnement
- Erreurs de lecture/écriture
- Modèle et capacité

**Seuils d'alerte :**
- Température > 50°C : ATTENTION
- Température > 60°C : CRITIQUE
- État SMART != Healthy : CRITIQUE
- Secteurs réalloués > 0 : ATTENTION

### synology_check_raid.sh

État du RAID/SHR :
- Type de RAID (RAID 1, RAID 5, SHR, SHR-2)
- État global (Normal, Degraded, Crashed)
- Progression de reconstruction/expansion
- Espace utilisé/disponible
- Date du dernier Parity Check

**Alertes critiques :**
- RAID Degraded : disque défaillant
- RAID Crashed : perte de données imminente
- Reconstruction en cours : performances dégradées

### synology_check_hyperbackup.sh

Sauvegardes Hyper Backup :
- Liste de toutes les tâches
- État de chaque tâche (succès/échec)
- Date et heure de la dernière sauvegarde
- Taille de la sauvegarde
- Destination (locale, rsync, cloud)
- Rotation et rétention

**Alertes :**
- Dernière sauvegarde > 24h : ATTENTION
- Dernière sauvegarde > 48h : CRITIQUE
- Échec de sauvegarde : CRITIQUE

### synology_check_services.sh

Services critiques DSM :
- `synoschedtask` : Tâches planifiées
- `synonetd` : Réseau
- `smbd` : Partages Windows (SMB)
- `dockerd` : Docker (si installé)
- `PostgreSQL` : Base de données (si installée)
- Paquets installés et leur version

### synology_check_security.sh

Sécurité :
- État du pare-feu
- Règles de pare-feu actives
- Tentatives de connexion SSH échouées (fail2ban)
- Protection contre les ransomwares
- Blocages IP
- Comptes administrateurs

## Configuration

### Personnaliser les seuils

Modifier les variables en début des scripts :

```bash
# synology_check_disks.sh
TEMP_WARN=50  # Alerte si température disque > 50°C
TEMP_CRIT=60  # Critique si > 60°C

# synology_check_raid.sh
VOLUME_WARN=80  # Alerte si volume > 80% plein
VOLUME_CRIT=90  # Critique si > 90% plein

# synology_check_hyperbackup.sh
BACKUP_WARN_HOURS=24  # Alerte si dernière sauvegarde > 24h
BACKUP_CRIT_HOURS=48  # Critique si > 48h
```

### Notifications

Les scripts utilisent les codes de sortie standard :
- `0` : OK
- `1` : WARNING
- `2` : CRITICAL

Configurer les alertes dans Tactical RMM :
1. **Automation** > **Checks** > **Add Check**
2. Type : **Script Check**
3. Alerte si : Code de retour != 0 OU sortie contient `[ERREUR]`

## Tâches planifiées recommandées

| Script | Fréquence | Alerte si |
|--------|-----------|-----------|
| surveillance_complete | Toutes les heures | Contient `[ERREUR]` ou `[CRITIQUE]` |
| check_disks | Toutes les 4 heures | Température > 50°C ou état != Healthy |
| check_raid | Toutes les heures | État != Normal |
| check_hyperbackup | Quotidien (08:00) | Dernière sauvegarde > 24h |
| check_services | Toutes les 30 min | Service critique arrêté |
| check_security | Quotidien (09:00) | Tentatives de connexion échouées > 10 |

## Commandes Synology utiles

```bash
# Informations système
synoinfo --model          # Modèle du NAS
synoinfo --serial         # Numéro de série
synoinfo --version        # Version DSM

# Disques
synodisk --list           # Liste des disques
synodisk --smart-test-schedule --show  # Tests SMART programmés

# RAID
synoraid --get-pd-status  # État des disques physiques
synoraid --get-volume-status  # État des volumes

# Services
synosystemctl list        # Liste de tous les services
synosystemctl status <service>  # État d'un service

# Réseau
synonet --list            # Interfaces réseau
synonet --show eth0       # Détails d'une interface

# Mise à jour
synopkg list              # Paquets installés
synonet --check-update    # Vérifier les MAJ DSM
```

## Intégration avec Synology API

Pour des fonctionnalités avancées, utiliser l'API Synology :

```bash
# Exemple: Obtenir les infos système via API
curl -k "https://nas.votredomaine.com:5001/webapi/entry.cgi" \
  -d "api=SYNO.API.Info&version=1&method=query"
```

## Dépannage

### "Command not found" pour les commandes syno*

Les commandes Synology sont dans `/usr/syno/bin/` :

```bash
# Ajouter au PATH
export PATH=$PATH:/usr/syno/bin:/usr/syno/sbin

# Ou utiliser le chemin complet
/usr/syno/bin/synoinfo --model
```

### Permission denied

```bash
# Exécuter en root
sudo bash synology_check_all.sh

# Ou ajouter l'utilisateur au groupe administrators
sudo synogroup --member administrators <username>
```

### Agent Tactical RMM ne démarre pas

```bash
# Vérifier le service
sudo systemctl status tacticalagent

# Vérifier les logs
sudo journalctl -u tacticalagent -n 50

# Redémarrer
sudo systemctl restart tacticalagent
```

### Partition système pleine (/dev/md0)

L'agent doit être installé dans `/volume1/@appstore/` et non dans `/usr/local/` :

```bash
# Utiliser le script amélioré qui installe automatiquement au bon endroit
./rmmagent-linux-ameliore.sh install ...
```

## Spécificités Synology

### Structure des disques

```
/dev/md0     → Partition système (2.3 GB, NE PAS REMPLIR!)
/dev/md1     → Partition swap
/volume1     → Volume de stockage principal (vos données)
/volume2     → Volume additionnel (si configuré)
```

### Services critiques DSM

| Service | Description |
|---------|-------------|
| `synoschedtask` | Tâches planifiées |
| `synonetd` | Services réseau |
| `smbd` | Partages SMB/CIFS |
| `afpd` | Partages AFP (macOS) |
| `nfsd` | Partages NFS |
| `sshd` | SSH |
| `nginx` | Interface web DSM |

### Emplacements importants

```
/var/log/                      → Logs système
/var/services/homes/           → Dossiers utilisateurs
/volume1/@appstore/            → Applications installées
/volume1/@database/            → Bases de données
/volume1/docker/               → Docker containers et volumes
/usr/syno/etc/certificate/     → Certificats SSL
```

## Exemples d'utilisation avancée

### Surveillance avec Grafana

Exporter les métriques vers InfluxDB pour visualisation :

```bash
# Dans le script
TEMP=$(synodisktemp --enum | grep Disk | awk '{print $5}')
curl -i -XPOST 'http://influxdb:8086/write?db=synology' \
  --data-binary "temperature,host=nas value=$TEMP"
```

### Alerte Slack/Discord

```bash
# Envoyer une notification en cas d'erreur
if [[ $ERROR_COUNT -gt 0 ]]; then
    curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
      -H 'Content-Type: application/json' \
      -d '{"text":"⚠️ Alerte NAS: '"$ERROR_MSG"'"}'
fi
```

## Ressources

- [Documentation Synology DSM](https://kb.synology.com/)
- [Synology API Guide](https://global.download.synology.com/download/Document/Software/DeveloperGuide/)
- [Agent Tactical RMM pour Synology](../../SYNOLOGY_AGENT_INSTALL.md)
- [Tactical RMM Documentation](https://docs.tacticalrmm.com/)
