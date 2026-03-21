# Système de mise à jour automatique pour l'agent Linux Tactical RMM

Système complet de mise à jour automatique pour les agents Tactical RMM sous Linux, utilisant systemd timer.

## Vue d'ensemble

Ce système permet de :
- ✅ Vérifier automatiquement les nouvelles versions de l'agent
- ✅ Mettre à jour automatiquement pendant une fenêtre de maintenance
- ✅ Sauvegarder l'ancienne version avant mise à jour
- ✅ Rollback automatique en cas d'échec
- ✅ Envoyer des notifications par email ou webhook
- ✅ Logger toutes les opérations

## Fichiers du système

| Fichier | Emplacement | Description |
|---------|-------------|-------------|
| `tactical-agent-updater.sh` | `/usr/local/bin/` | Script principal de mise à jour |
| `auto-update.conf` | `/etc/tactical-rmm/` | Fichier de configuration |
| `tactical-agent-updater.service` | `/etc/systemd/system/` | Service systemd |
| `tactical-agent-updater.timer` | `/etc/systemd/system/` | Timer systemd (planification) |
| `tactical-rmm-updater.log` | `/var/log/` | Fichier de logs |

## Installation

### Méthode 1 : Script d'installation automatique (Recommandé)

```bash
# Télécharger les fichiers
cd /tmp
git clone https://github.com/votre-user/tactical-rmm.git
cd tactical-rmm/scripts/linux/auto-update/

# Exécuter l'installation
sudo ./install-auto-update.sh
```

### Méthode 2 : Installation manuelle

```bash
# 1. Créer les répertoires
sudo mkdir -p /etc/tactical-rmm

# 2. Copier les fichiers
sudo cp tactical-agent-updater.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/tactical-agent-updater.sh

# 3. Copier la configuration
sudo cp auto-update.conf /etc/tactical-rmm/

# 4. Installer les services systemd
sudo cp tactical-agent-updater.service /etc/systemd/system/
sudo cp tactical-agent-updater.timer /etc/systemd/system/

# 5. Activer et démarrer le timer
sudo systemctl daemon-reload
sudo systemctl enable tactical-agent-updater.timer
sudo systemctl start tactical-agent-updater.timer
```

## Configuration

Éditer le fichier `/etc/tactical-rmm/auto-update.conf` :

```bash
sudo nano /etc/tactical-rmm/auto-update.conf
```

### Options de configuration

#### Activation/Désactivation

```bash
# Activer les mises à jour automatiques
AUTO_UPDATE_ENABLED=true

# Désactiver temporairement
AUTO_UPDATE_ENABLED=false
```

#### Fenêtre de mise à jour

```bash
# Mises à jour entre 02:00 et 05:00 uniquement
UPDATE_WINDOW_START="02:00"
UPDATE_WINDOW_END="05:00"
```

#### Notifications par email

```bash
# Activer les notifications email
NOTIFICATION_EMAIL="admin@votredomaine.com"

# Prérequis: mailutils ou sendmail installé
# sudo apt-get install mailutils
```

#### Notifications par webhook (Slack, Discord, etc.)

```bash
# Slack
NOTIFICATION_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Discord
NOTIFICATION_WEBHOOK="https://discord.com/api/webhooks/YOUR/WEBHOOK"

# Teams
NOTIFICATION_WEBHOOK="https://outlook.office.com/webhook/YOUR/WEBHOOK"
```

#### Sauvegardes

```bash
# Activer les sauvegardes avant mise à jour
BACKUP_ENABLED=true
```

## Planification

Par défaut, le timer systemd vérifie les mises à jour :
- **Tous les dimanches à 03:00**
- Avec un décalage aléatoire de 0-30 minutes

### Modifier la planification

Éditer `/etc/systemd/system/tactical-agent-updater.timer` :

```bash
sudo nano /etc/systemd/system/tactical-agent-updater.timer
```

**Exemples de planification :**

```ini
# Tous les jours à 03:00
OnCalendar=*-*-* 03:00:00

# Tous les lundis à 04:00
OnCalendar=Mon *-*-* 04:00:00

# Premier dimanche du mois à 02:00
OnCalendar=Sun *-*-1..7 02:00:00

# Toutes les semaines (dimanche 03:00)
OnCalendar=Sun *-*-* 03:00:00
```

Après modification, recharger systemd :

```bash
sudo systemctl daemon-reload
sudo systemctl restart tactical-agent-updater.timer
```

## Utilisation

### Vérifier l'état du timer

```bash
# État du timer
sudo systemctl status tactical-agent-updater.timer

# Liste des timers actifs
sudo systemctl list-timers tactical-agent-updater.timer
```

**Exemple de sortie :**
```
NEXT                        LEFT          LAST                        PASSED  UNIT
Sun 2025-12-21 03:15:00 UTC 2 days left   Sun 2025-12-14 03:15:00 UTC 5 days ago tactical-agent-updater.timer
```

### Lancer une mise à jour manuelle

```bash
# Exécution immédiate (ignore la fenêtre de mise à jour)
sudo /usr/local/bin/tactical-agent-updater.sh

# Via systemd
sudo systemctl start tactical-agent-updater.service
```

### Consulter les logs

```bash
# Logs du fichier
sudo tail -f /var/log/tactical-rmm-updater.log

# Logs systemd
sudo journalctl -u tactical-agent-updater.service -n 50

# Logs en temps réel
sudo journalctl -u tactical-agent-updater.service -f
```

### Désactiver temporairement

```bash
# Arrêter le timer (les mises à jour ne seront plus automatiques)
sudo systemctl stop tactical-agent-updater.timer
sudo systemctl disable tactical-agent-updater.timer

# Réactiver
sudo systemctl enable tactical-agent-updater.timer
sudo systemctl start tactical-agent-updater.timer
```

## Fonctionnement détaillé

### Processus de mise à jour

1. **Acquisition du verrou** : Empêche les exécutions concurrentes
2. **Vérification activation** : Lit `AUTO_UPDATE_ENABLED`
3. **Fenêtre de mise à jour** : Vérifie si l'heure actuelle est dans la fenêtre
4. **Récupération des versions** :
   - Version installée : depuis `/etc/tacticalagent/.version` ou le binaire
   - Dernière version : depuis GitHub API
5. **Comparaison** : Si nouvelle version disponible → mise à jour
6. **Sauvegarde** : Backup de la configuration et du binaire
7. **Mise à jour** : Exécute `rmmagent-linux.sh update`
8. **Vérification** : Teste que le service fonctionne
9. **Notification** : Envoie un email/webhook si configuré
10. **Nettoyage** : Libère le verrou

### En cas d'échec

- Rollback automatique vers l'ancienne version
- Notification d'échec envoyée
- Service redémarré avec l'ancienne version
- Log détaillé de l'erreur

## Notifications

### Format des notifications

**Succès :**
```
Sujet: [Tactical RMM] Mise à jour réussie sur srv-web01
Message: L'agent Tactical RMM a été mis à jour vers la version 2.5.0 sur srv-web01.
```

**Échec :**
```
Sujet: [Tactical RMM] Échec de mise à jour sur srv-web01
Message: La mise à jour de l'agent Tactical RMM a échoué sur srv-web01.
         Consultez /var/log/tactical-rmm-updater.log pour plus de détails.
```

### Configuration Slack

1. Créer un Incoming Webhook dans Slack :
   - https://api.slack.com/messaging/webhooks

2. Ajouter dans `/etc/tactical-rmm/auto-update.conf` :
```bash
NOTIFICATION_WEBHOOK="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
```

### Configuration Discord

1. Créer un Webhook dans Discord :
   - Paramètres du canal > Intégrations > Webhooks

2. Ajouter dans `/etc/tactical-rmm/auto-update.conf` :
```bash
NOTIFICATION_WEBHOOK="https://discord.com/api/webhooks/123456789012345678/abcdefghijklmnopqrstuvwxyz"
```

## Déploiement sur plusieurs serveurs

### Via Tactical RMM (Recommandé)

1. **Créer un script dans Tactical RMM** :
   - Settings > Script Manager > New Script
   - Nom : `Linux - Installer Auto-Update`
   - Type : Shell
   - Coller le contenu de `install-auto-update.sh`

2. **Déployer sur tous les agents Linux** :
   - Automation > Tasks > Add Task
   - Script : Linux - Installer Auto-Update
   - Cible : Tous les agents Linux

### Via SSH en masse

```bash
#!/bin/bash
# deploy-auto-update.sh

SERVERS="server1 server2 server3 nas1"

for server in $SERVERS; do
    echo "Installation sur $server..."

    scp -r /path/to/auto-update/ root@$server:/tmp/
    ssh root@$server "cd /tmp/auto-update && ./install-auto-update.sh"

    if [ $? -eq 0 ]; then
        echo "✓ $server: OK"
    else
        echo "✗ $server: ÉCHEC"
    fi
done
```

### Via Ansible

```yaml
# playbook-tactical-auto-update.yml
---
- name: Déployer le système de mise à jour Tactical RMM
  hosts: all
  become: yes
  tasks:
    - name: Créer le répertoire de configuration
      file:
        path: /etc/tactical-rmm
        state: directory
        mode: '0755'

    - name: Copier le script de mise à jour
      copy:
        src: tactical-agent-updater.sh
        dest: /usr/local/bin/tactical-agent-updater.sh
        mode: '0755'

    - name: Copier la configuration
      copy:
        src: auto-update.conf
        dest: /etc/tactical-rmm/auto-update.conf
        mode: '0644'

    - name: Copier les fichiers systemd
      copy:
        src: "{{ item }}"
        dest: /etc/systemd/system/
      loop:
        - tactical-agent-updater.service
        - tactical-agent-updater.timer

    - name: Activer et démarrer le timer
      systemd:
        name: tactical-agent-updater.timer
        enabled: yes
        state: started
        daemon_reload: yes
```

Déployer :
```bash
ansible-playbook -i inventory.ini playbook-tactical-auto-update.yml
```

## Sécurité

### Bonnes pratiques

1. **Fenêtre de maintenance** : Limiter les mises à jour à une période creuse
2. **Décalage aléatoire** : Le timer systemd introduit un décalage de 0-30 min pour éviter la surcharge simultanée
3. **Verrou** : Un seul processus de mise à jour à la fois
4. **Sauvegardes** : Backup automatique avant chaque mise à jour
5. **Notifications** : Être alerté en cas de succès ou d'échec

### Permissions

Le script nécessite les droits root pour :
- Arrêter/démarrer le service `tacticalagent`
- Remplacer le binaire dans `/usr/local/bin/` ou `/opt/`
- Écrire dans `/var/log/`

## Dépannage

### Le timer ne se lance pas

```bash
# Vérifier l'état
sudo systemctl status tactical-agent-updater.timer

# Vérifier les logs
sudo journalctl -u tactical-agent-updater.timer

# Recharger systemd
sudo systemctl daemon-reload
sudo systemctl restart tactical-agent-updater.timer
```

### Les notifications ne fonctionnent pas

```bash
# Test email
echo "Test" | mail -s "Test Tactical RMM" votre@email.com

# Test webhook (Slack)
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H 'Content-Type: application/json' \
  -d '{"text":"Test notification Tactical RMM"}'
```

### La mise à jour échoue

```bash
# Consulter les logs détaillés
sudo cat /var/log/tactical-rmm-updater.log

# Tester manuellement
sudo /usr/local/bin/tactical-agent-updater.sh

# Vérifier la connectivité GitHub
curl -I https://api.github.com/repos/amidaware/rmmagent/releases/latest
```

### Le verrou reste bloqué

```bash
# Vérifier si un processus est actif
cat /var/run/tactical-agent-updater.lock
ps aux | grep tactical-agent-updater

# Si aucun processus actif, supprimer le verrou
sudo rm -f /var/run/tactical-agent-updater.lock
```

## Désinstallation

```bash
# Arrêter et désactiver le timer
sudo systemctl stop tactical-agent-updater.timer
sudo systemctl disable tactical-agent-updater.timer

# Supprimer les fichiers
sudo rm -f /usr/local/bin/tactical-agent-updater.sh
sudo rm -f /etc/systemd/system/tactical-agent-updater.{service,timer}
sudo rm -f /etc/tactical-rmm/auto-update.conf
sudo rm -f /var/log/tactical-rmm-updater.log

# Recharger systemd
sudo systemctl daemon-reload
```

## Exemple de logs

```
[2025-12-18 03:15:23] INFO: ==========================================
[2025-12-18 03:15:23] INFO: Tactical RMM - Vérification des mises à jour
[2025-12-18 03:15:23] INFO: Serveur: srv-web01
[2025-12-18 03:15:23] INFO: ==========================================
[2025-12-18 03:15:24] INFO: Vérification des versions...
[2025-12-18 03:15:24] INFO: Version installée: 2.4.5
[2025-12-18 03:15:25] INFO: Dernière version: 2.5.0
[2025-12-18 03:15:25] INFO: Nouvelle version disponible: 2.5.0
[2025-12-18 03:15:25] INFO: === DÉBUT DE LA MISE À JOUR ===
[2025-12-18 03:15:26] INFO: Exécution de la mise à jour...
[2025-12-18 03:17:45] SUCCESS: Mise à jour terminée avec succès
[2025-12-18 03:17:45] SUCCESS: === MISE À JOUR TERMINÉE AVEC SUCCÈS ===
[2025-12-18 03:17:46] INFO: Nettoyage terminé
```

## Roadmap

Fonctionnalités futures :
- [ ] Support de plusieurs dépôts (mirror/fallback)
- [ ] Vérification de signature GPG des binaires
- [ ] Rapport de santé post-mise à jour
- [ ] Intégration avec Grafana/Prometheus pour métriques
- [ ] Support de mise à jour par vague (canary deployment)

## Support

- Documentation Tactical RMM : https://docs.tacticalrmm.com/
- Issues GitHub : https://github.com/votre-user/tactical-rmm/issues
- systemd timers : `man systemd.timer`
