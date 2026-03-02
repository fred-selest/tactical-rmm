# Scripts de surveillance Plesk pour Tactical RMM

Scripts Bash pour surveiller des serveurs Plesk (hébergement web).

## Scripts disponibles

| Script | Description |
|--------|-------------|
| `plesk_surveillance_complete.sh` | Surveillance complète du serveur Plesk |
| `plesk_check_all.sh` | Vérification rapide de tous les composants |
| `plesk_check_backup.sh` | État des sauvegardes Plesk |
| `plesk_check_disk.sh` | Espace disque et quotas |
| `plesk_check_docker.sh` | Containers Docker gérés par Plesk |
| `plesk_check_docker_compose.sh` | Docker Compose via Plesk |
| `plesk_check_mail.sh` | Services mail (Postfix, Dovecot, queues) |
| `plesk_check_security.sh` | Configuration sécurité et fail2ban |
| `plesk_check_services.sh` | Services critiques Plesk |
| `plesk_check_ssl.sh` | Certificats SSL et expiration |

## Prérequis

- Plesk Obsidian 18.0+ ou Plesk Onyx
- Accès root ou administrateur Plesk
- Agent Tactical RMM installé
- Outils : `plesk`, `mysql`, `postfix`, `fail2ban`

## Installation dans Tactical RMM

### 1. Importer les scripts

1. **Settings** > **Script Manager** > **New Script**
2. Pour chaque script :
   - Nom : `Plesk - <Nom du script>`
   - Type : **Shell**
   - Coller le contenu du script
   - Catégorie : `Plesk`

### 2. Créer des checks automatisés

1. **Automation** > **Checks** > **Add Check**
2. Type : **Script Check**
3. Script : `Plesk - Surveillance complète`
4. Intervalle : **Toutes les heures**
5. Alerte si sortie contient : `[ERREUR]` ou `[CRITIQUE]`

## Utilisation

### Surveillance complète

```bash
# Exécution manuelle
bash plesk_surveillance_complete.sh

# Via Tactical RMM
# Agents > Sélectionner serveur Plesk > Run Script > Plesk - Surveillance complète
```

### Vérifications spécifiques

```bash
# Sauvegardes
bash plesk_check_backup.sh

# Certificats SSL
bash plesk_check_ssl.sh

# Services mail
bash plesk_check_mail.sh

# Docker
bash plesk_check_docker.sh
```

## Fonctionnalités de surveillance

### plesk_surveillance_complete.sh

Vérifie l'ensemble du serveur :
- **Système** : OS, uptime, charge, mémoire
- **Disques** : Espace disponible sur toutes les partitions
- **Services** : Apache/Nginx, MySQL, Postfix, Dovecot, Plesk Panel
- **Mail** : Queue mail, connexions SMTP/IMAP
- **SSL** : Certificats expirés ou proches de l'expiration
- **Sauvegardes** : Dernière sauvegarde Plesk
- **Sécurité** : fail2ban, pare-feu
- **Docker** : Containers actifs

### plesk_check_backup.sh

État des sauvegardes :
- Dernière sauvegarde réussie
- Taille des sauvegardes
- Espace disponible pour les backups
- Vérification de la configuration Backup Manager

**Exemple de sortie :**
```
=== SAUVEGARDES PLESK ===
[OK] Dernière sauvegarde : 2025-12-18 02:00 (il y a 12h)
[OK] Taille : 45 GB
[OK] Espace backup : 250 GB disponibles
[OK] Backup Manager : actif
```

### plesk_check_ssl.sh

Certificats SSL :
- Liste tous les certificats gérés par Plesk
- Détecte les certificats expirés
- Alerte si expiration < 30 jours
- Vérifie le renouvellement automatique Let's Encrypt

**Exemple de sortie :**
```
=== CERTIFICATS SSL ===
[OK] exemple.com : valide jusqu'au 2026-03-15 (13 jours)
[ATTENTION] vieux-site.com : expire dans 5 jours !
[ERREUR] test.com : EXPIRÉ depuis 2 jours
```

### plesk_check_mail.sh

Services mail :
- État Postfix et Dovecot
- Taille de la queue mail
- Connexions actives SMTP/IMAP
- Logs d'erreurs récentes
- Blacklists (optionnel)

**Seuils d'alerte :**
- Queue mail > 100 messages : ATTENTION
- Queue mail > 500 messages : CRITIQUE
- Service arrêté : CRITIQUE

### plesk_check_docker.sh

Containers Docker :
- Liste des containers actifs
- État de chaque container
- Utilisation CPU/RAM
- Volumes et réseaux

### plesk_check_security.sh

Sécurité :
- État fail2ban
- Bans actifs
- Pare-feu (firewalld/iptables)
- Mises à jour disponibles
- Permissions fichiers critiques

## Configuration

### Personnaliser les seuils

Modifier les variables en début de script :

```bash
# plesk_check_disk.sh
WARN_THRESHOLD=80  # Alerte si disque > 80%
CRIT_THRESHOLD=90  # Critique si disque > 90%

# plesk_check_mail.sh
QUEUE_WARN=100     # Alerte si queue > 100 messages
QUEUE_CRIT=500     # Critique si queue > 500 messages

# plesk_check_ssl.sh
SSL_WARN_DAYS=30   # Alerte si expire dans < 30 jours
SSL_CRIT_DAYS=7    # Critique si expire dans < 7 jours
```

### Notifications par email

Utiliser les alertes Tactical RMM ou ajouter dans le script :

```bash
# Envoyer un email en cas d'erreur
if [[ $ERROR_COUNT -gt 0 ]]; then
    echo "Erreurs détectées sur $HOSTNAME" | \
    mail -s "[ALERTE] Plesk $HOSTNAME" admin@votredomaine.com
fi
```

## Tâches planifiées recommandées

| Script | Fréquence | Alerte si |
|--------|-----------|-----------|
| surveillance_complete | Toutes les heures | Contient `[ERREUR]` ou `[CRITIQUE]` |
| check_backup | Quotidien (03:00) | Dernière sauvegarde > 36h |
| check_ssl | Quotidien (09:00) | Certificat expire < 30 jours |
| check_mail | Toutes les 30 min | Queue > 100 ou service arrêté |
| check_security | Quotidien (04:00) | Mises à jour disponibles |

## Services surveillés

| Service | Description | Port |
|---------|-------------|------|
| `psa` | Plesk Panel | 8443 |
| `httpd` / `nginx` | Serveur web | 80, 443 |
| `mysqld` / `mariadb` | Base de données | 3306 |
| `postfix` | SMTP sortant | 25, 587 |
| `dovecot` | IMAP/POP3 | 143, 993, 110, 995 |
| `named` | DNS (si activé) | 53 |
| `fail2ban` | Protection intrusions | - |

## Dépannage

### Script ne trouve pas la commande `plesk`

```bash
# Ajouter le chemin Plesk au PATH
export PATH=$PATH:/usr/local/psa/bin

# Ou utiliser le chemin complet
/usr/local/psa/bin/plesk version
```

### Erreur "Permission denied"

```bash
# Exécuter en root
sudo bash plesk_check_all.sh

# Ou donner les permissions à l'agent Tactical
# (dans /etc/sudoers ou via Plesk)
```

### Les sauvegardes ne sont pas détectées

Vérifier le répertoire de sauvegarde Plesk :

```bash
# Afficher la config backup
/usr/local/psa/bin/pleskebackup --list

# Vérifier le dossier
ls -lh /var/lib/psa/dumps/
```

## Intégration avec Plesk API

Pour des fonctionnalités avancées, utiliser l'API XML Plesk :

```bash
# Exemple: Lister tous les domaines
curl -k -H "HTTP_AUTH_LOGIN: admin" \
     -H "HTTP_AUTH_PASSWD: password" \
     -d '<packet><webspace><get><filter/></get></webspace></packet>' \
     https://localhost:8443/enterprise/control/agent.php
```

## Exemple de sortie complète

```
==========================================
SURVEILLANCE PLESK
Serveur: srv-web01.votredomaine.com
Date: 2025-12-18 14:30:00
==========================================

--- SYSTÈME ---
[OK] OS: Ubuntu 22.04 LTS
[OK] Uptime: 45 jours
[OK] Charge: 1.2 (4 CPUs)
[OK] RAM: 12/32 GB (37%)

--- PLESK ---
[OK] Version: Plesk Obsidian 18.0.58
[OK] Panel: actif (port 8443)
[OK] Licence: valide jusqu'au 2026-06-01

--- SERVICES ---
[OK] Apache: actif
[OK] MySQL: actif
[OK] Postfix: actif
[OK] Dovecot: actif
[OK] fail2ban: actif

--- DISQUES ---
[OK] / : 45/100 GB (45%)
[OK] /var : 120/500 GB (24%)
[ATTENTION] /var/lib/psa/dumps : 180/200 GB (90%)

--- MAIL ---
[OK] Queue: 12 messages
[OK] Connexions SMTP: 3 actives
[OK] Connexions IMAP: 15 actives

--- SSL ---
[OK] exemple.com: expire dans 45 jours
[OK] shop.exemple.com: expire dans 67 jours
[ATTENTION] test.exemple.com: expire dans 12 jours

--- SAUVEGARDES ---
[OK] Dernière sauvegarde: 18/12/2025 02:00 (12h)
[OK] Taille: 45 GB

==========================================
RÉSULTAT: 1 ATTENTION, 0 ERREUR
==========================================
```

## Ressources

- [Documentation Plesk](https://docs.plesk.com/)
- [Plesk CLI Reference](https://docs.plesk.com/en-US/obsidian/cli-linux/)
- [Tactical RMM Documentation](https://docs.tacticalrmm.com/)
