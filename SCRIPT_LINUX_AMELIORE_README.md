# Script d'installation Linux amélioré pour Tactical RMM

## Vue d'ensemble

Version améliorée du script d'installation `rmmagent-linux.sh` avec support optimisé pour Synology et nombreuses améliorations de sécurité et fiabilité.

## Nouvelles fonctionnalités

### ✨ Améliorations majeures

| Fonctionnalité | Description |
|----------------|-------------|
| 🔧 **Support Synology optimisé** | Installation automatique dans `/volume1/@appstore/` pour éviter de remplir la partition système |
| 🧹 **Nettoyage automatique de Go** | Go est supprimé après compilation s'il n'était pas déjà installé (économise 244 MB) |
| 💾 **Sauvegarde avant mise à jour** | L'ancien agent est sauvegardé avant chaque mise à jour |
| 📊 **Commande status** | Nouvelle commande pour vérifier l'état de l'agent |
| 📝 **Logging complet** | Tous les événements sont enregistrés dans `/var/log/tacticalrmm-install.log` |
| ✅ **Vérification des dépendances** | Installation automatique des paquets manquants |
| 🌍 **Support multilingue** | Français et anglais (via variable `TACTICAL_LANG`) |
| 🔍 **Détection de distribution** | Reconnaissance automatique de Synology, Debian, Ubuntu, CentOS, Alpine, etc. |
| 🛡️ **Gestion d'erreurs robuste** | Vérifications à chaque étape avec messages explicites |
| 🔗 **Chemins d'installation flexibles** | `/opt/tacticalrmm` pour Linux standard, `/volume1/@appstore/tactical-rmm` pour Synology |

## Installation

### Téléchargement

```bash
wget https://raw.githubusercontent.com/votre-repo/tactical-rmm/main/rmmagent-linux-ameliore.sh
chmod +x rmmagent-linux-ameliore.sh
```

### Utilisation

#### 1. Installation complète

```bash
sudo ./rmmagent-linux-ameliore.sh install \
  "https://mesh.votredomaine.com/meshagents?id=XXXXX" \
  "https://api.votredomaine.com" \
  "123" \
  "456" \
  "votre-auth-key" \
  "server"
```

**Arguments :**
1. URL Mesh Agent (obtenue depuis l'interface Tactical RMM)
2. URL de l'API Tactical RMM
3. Client ID
4. Site ID
5. Auth Key
6. Type d'agent : `server` ou `workstation`

#### 2. Mise à jour de l'agent

```bash
sudo ./rmmagent-linux-ameliore.sh update
```

Cette commande :
- Télécharge la dernière version du code source
- Recompile l'agent
- Sauvegarde l'ancien binaire
- Installe la nouvelle version
- Redémarre le service

#### 3. Vérifier l'état

```bash
sudo ./rmmagent-linux-ameliore.sh status
```

Affiche :
- État du service systemd
- Emplacement et taille du binaire
- Présence de la configuration
- État de Mesh Agent
- Derniers logs

**Exemple de sortie :**
```
===========================================
STATUT DE L'AGENT TACTICAL RMM
===========================================

✓ Service: ACTIF
  Démarré: Mon 2025-12-18 10:30:45 CET
✓ Binaire: /opt/tacticalrmm/bin/rmmagent (25M)
✓ Configuration: /etc/tacticalagent
✓ Mesh Agent: INSTALLÉ

--- Logs récents (5 dernières lignes) ---
Dec 18 10:30:45 server systemd[1]: Started Tactical RMM Linux Agent.
Dec 18 10:30:46 server rmmagent[1234]: Agent started successfully
...
===========================================
```

#### 4. Désinstallation

```bash
sudo ./rmmagent-linux-ameliore.sh uninstall \
  "mesh.votredomaine.com" \
  "votre-mesh-agent-id"
```

**Arguments :**
1. FQDN du serveur Mesh
2. ID de l'agent Mesh (entre guillemets)

#### 5. Aide

```bash
./rmmagent-linux-ameliore.sh help
```

## Architectures supportées

| Architecture | Support | Notes |
|--------------|---------|-------|
| x86_64 (amd64) | ✅ | Serveurs et PC standard |
| x86 (32-bit) | ✅ | Anciennes machines |
| ARM64 (aarch64) | ✅ | Raspberry Pi 3/4/5, serveurs ARM |
| ARMv6 | ✅ | Raspberry Pi 1/Zero |

## Distributions testées

| Distribution | Version | Support | Notes |
|--------------|---------|---------|-------|
| Synology DSM | 7.x | ✅ Optimisé | Installation dans `/volume1/@appstore/` |
| Ubuntu | 20.04+ | ✅ | |
| Debian | 10+ | ✅ | |
| CentOS | 7+ | ✅ | |
| Rocky Linux | 8+ | ✅ | |
| Alpine Linux | 3.x | ✅ | |
| Raspberry Pi OS | Bullseye+ | ✅ | |

## Particularités Synology

Le script détecte automatiquement Synology et :

1. **Installe dans `/volume1/@appstore/tactical-rmm/`** au lieu de `/usr/local/` pour ne pas remplir la partition système
2. **Installe Go dans le même répertoire** (`/volume1/@appstore/tactical-rmm/go`)
3. **Adapte le service systemd** avec `After=syno-volume.target` pour attendre le montage des volumes
4. **Détecte le modèle et la version DSM** pour les afficher dans l'interface

### Espace disque Synology

| Partition | Taille | Usage agent |
|-----------|--------|-------------|
| `/dev/md0` (système) | 2.3 GB | **0 MB** ✅ (rien n'est installé ici) |
| `/volume1` (données) | Variable | ~30 MB (agent + config) |

## Variables d'environnement

### TACTICAL_LANG

Définit la langue des messages :

```bash
# Français (par défaut)
export TACTICAL_LANG=fr_FR
sudo ./rmmagent-linux-ameliore.sh install ...

# Anglais
export TACTICAL_LANG=en_US
sudo ./rmmagent-linux-ameliore.sh install ...
```

## Fichiers installés

### Linux standard

```
/opt/tacticalrmm/
├── bin/
│   └── rmmagent                    # Binaire de l'agent
/usr/local/bin/
└── rmmagent                        # Lien symbolique vers /opt/tacticalrmm/bin/rmmagent
/etc/tacticalagent/                 # Configuration
/etc/systemd/system/
└── tacticalagent.service           # Service systemd
/opt/tacticalmesh/                  # Mesh Agent
/var/log/
└── tacticalrmm-install.log         # Log d'installation
```

### Synology

```
/volume1/@appstore/tactical-rmm/
├── rmmagent                        # Binaire de l'agent
└── go/                             # Go (temporaire, supprimé après compilation)
/etc/tacticalagent/                 # Configuration
/etc/systemd/system/
└── tacticalagent.service           # Service systemd
/opt/tacticalmesh/                  # Mesh Agent
/var/log/
└── tacticalrmm-install.log         # Log d'installation
```

## Dépannage

### Le script échoue avec "Permission denied"

```bash
# S'assurer d'exécuter en tant que root
sudo ./rmmagent-linux-ameliore.sh install ...
```

### "ERREUR: Dépendances manquantes"

Le script installe automatiquement les dépendances, mais si cela échoue :

```bash
# Debian/Ubuntu
sudo apt-get install wget tar

# CentOS/Rocky
sudo yum install wget tar

# Alpine
sudo apk add wget tar

# Synology
# Via Package Center : installer "Command Line Tools"
```

### L'agent ne démarre pas

```bash
# Vérifier le status
sudo ./rmmagent-linux-ameliore.sh status

# Consulter les logs
sudo journalctl -u tacticalagent -n 50

# Ou directement le fichier log
sudo tail -f /var/log/tacticalrmm-install.log
```

### Partition système pleine (Synology)

Si vous avez utilisé l'ancien script et que `/dev/md0` est plein :

```bash
# 1. Désinstaller avec l'ancien script
sudo ./rmmagent-linux.sh uninstall mesh.votredomaine.com mesh-id

# 2. Nettoyer Go et fichiers temporaires
sudo rm -rf /usr/local/go/
sudo rm -rf /tmp/rmmagent*

# 3. Réinstaller avec le nouveau script
sudo ./rmmagent-linux-ameliore.sh install ...
```

### Go déjà installé globalement

Le script détecte si Go est déjà installé et ne le télécharge pas. Après compilation, il ne supprime que les installations qu'il a effectuées lui-même.

### Erreur de compilation

```bash
# Vérifier les logs
cat /var/log/tacticalrmm-install.log

# Essayer avec plus de verbosité
sudo bash -x ./rmmagent-linux-ameliore.sh install ...
```

## Logs

### Emplacement

`/var/log/tacticalrmm-install.log`

### Format

```
[2025-12-18 10:30:45] === Tactical RMM Installation Script v2.0 ===
[2025-12-18 10:30:45] Détection du système...
[2025-12-18 10:30:45] Architecture: amd64
[2025-12-18 10:30:45] Système détecté: Synology DSM
[2025-12-18 10:30:45] Version DSM: 7.2
[2025-12-18 10:30:46] Vérification des dépendances...
[2025-12-18 10:30:46] Toutes les dépendances sont présentes
...
```

### Consulter les logs

```bash
# Tout le log
sudo cat /var/log/tacticalrmm-install.log

# Dernières lignes
sudo tail -f /var/log/tacticalrmm-install.log

# Filtrer les erreurs
sudo grep "ERREUR" /var/log/tacticalrmm-install.log
```

## Comparaison avec le script original

| Fonctionnalité | Script original | Script amélioré |
|----------------|-----------------|-----------------|
| Installation path | `/usr/local/` (fixe) | `/opt/` ou `/volume1/@appstore/` (intelligent) |
| Nettoyage Go | ❌ | ✅ |
| Sauvegarde avant update | ❌ | ✅ |
| Commande status | ❌ | ✅ |
| Logging | Minimal | Complet avec fichier log |
| Vérification dépendances | ❌ | ✅ Auto-install |
| Support multilingue | ❌ | ✅ |
| Détection distribution | Basique | Avancée |
| Gestion d'erreurs | Basique | Robuste avec rollback |
| Support Synology | Standard | Optimisé |

## Sécurité

### Bonnes pratiques implémentées

1. ✅ Vérification de l'intégrité des téléchargements (taille non nulle)
2. ✅ Sauvegarde avant modification
3. ✅ Nettoyage automatique des fichiers temporaires
4. ✅ Exécution en root uniquement
5. ✅ Logging de toutes les actions
6. ✅ Rollback automatique en cas d'échec

### Recommandations

- Toujours vérifier les URLs avant installation
- Conserver les logs pour audit
- Tester d'abord dans un environnement de développement
- Sauvegarder la configuration avant désinstallation

## Automatisation

### Déploiement sur plusieurs serveurs

```bash
#!/bin/bash
# deploy-tactical.sh

SERVERS="server1 server2 server3"
MESH_URL="https://mesh.votredomaine.com/meshagents?id=XXX"
API_URL="https://api.votredomaine.com"
CLIENT_ID="123"
SITE_ID="456"
AUTH_KEY="votre-key"

for server in $SERVERS; do
    echo "Déploiement sur $server..."
    ssh root@$server 'bash -s' < rmmagent-linux-ameliore.sh install \
        "$MESH_URL" "$API_URL" "$CLIENT_ID" "$SITE_ID" "$AUTH_KEY" "server"
done
```

### Mise à jour automatique via cron

```bash
# /etc/cron.weekly/update-tactical-agent
#!/bin/bash
/opt/scripts/rmmagent-linux-ameliore.sh update >> /var/log/tactical-auto-update.log 2>&1
```

## Support et contributions

### Signaler un problème

1. Vérifier les logs : `/var/log/tacticalrmm-install.log`
2. Exécuter `sudo ./rmmagent-linux-ameliore.sh status`
3. Créer une issue avec :
   - Distribution et version (`cat /etc/os-release`)
   - Architecture (`uname -m`)
   - Logs pertinents

### Contribuer

Les contributions sont bienvenues ! Domaines d'amélioration :

- Support de nouvelles distributions
- Optimisations supplémentaires
- Traductions (espagnol, allemand, etc.)
- Tests automatisés

## Licence

Ce script est basé sur le travail de la communauté Tactical RMM et est fourni tel quel, sans garantie.

## Ressources

- [Tactical RMM](https://github.com/amidaware/tacticalrmm)
- [Documentation officielle](https://docs.tacticalrmm.com/)
- [Script original](https://github.com/netvolt/LinuxRMM-Script)

## Changelog

### Version 2.0 (2025-12-18)

- ✨ Installation intelligente selon la distribution (Synology optimisé)
- ✨ Nettoyage automatique de Go après compilation
- ✨ Commande `status` pour diagnostic
- ✨ Logging complet dans `/var/log/tacticalrmm-install.log`
- ✨ Sauvegarde automatique avant mise à jour
- ✨ Vérification et installation automatique des dépendances
- ✨ Support multilingue (français/anglais)
- ✨ Détection avancée de distribution
- ✨ Gestion d'erreurs robuste avec rollback
- 🐛 Correction : partition système pleine sur Synology
- 🐛 Correction : pas de vérification des téléchargements
- 🐛 Correction : compilation échouant sans message clair
- 📚 Documentation complète en français

### Version 1.0 (Script original)

- Installation de base sur Linux
- Support amd64, x86, arm64, armv6
- Compilation depuis les sources GitHub
