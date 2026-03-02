# Tactical RMM - Scripts et documentation

Dépôt complet pour l'installation, la surveillance et la gestion de Tactical RMM sur Linux, Windows, Synology et Plesk.

## 🚀 Installation rapide (Nouveau !)

### Installation universelle (Linux/Windows)

```bash
# Installation interactive (recommandé)
sudo bash <(curl -sSL https://raw.githubusercontent.com/votre-user/tactical-rmm/main/install.sh)

# Installation non-interactive
curl -sSL https://raw.githubusercontent.com/votre-user/tactical-rmm/main/install.sh | \
  sudo bash -s -- \
  --api-url "https://api.votredomaine.com" \
  --client-id 1 \
  --site-id 2 \
  --auth-key "votre-auth-key" \
  --agent-type workstation
```

Le script **`install.sh`** détecte automatiquement votre système et installe l'agent approprié.

## 📚 Documentation

| Fichier | Description |
|---------|-------------|
| **INSTALLATION** ||
| [install.sh](install.sh) | 🆕 Script d'installation universel (auto-détection) |
| [LINUX_AGENT_INSTALL.md](LINUX_AGENT_INSTALL.md) | Installation de l'agent sur Linux |
| [SYNOLOGY_AGENT_INSTALL.md](SYNOLOGY_AGENT_INSTALL.md) | Installation de l'agent sur NAS Synology |
| [scripts/windows/install/](scripts/windows/install/) | Installation Windows (5 scripts PowerShell) |
| **MISE À JOUR** ||
| [scripts/linux/auto-update/](scripts/linux/auto-update/) | 🆕 Système de mise à jour automatique Linux |
| **SURVEILLANCE** ||
| [scripts/README.md](scripts/README.md) | Index de tous les scripts de surveillance |
| [scripts/synology/](scripts/synology/) | Scripts surveillance Synology (9 scripts) |
| [scripts/plesk/](scripts/plesk/) | Scripts surveillance Plesk (10 scripts) |
| [scripts/windows/](scripts/windows/) | Scripts surveillance Windows |
| **AUTRES** ||
| [ALERTES_TACTICALRMM.md](ALERTES_TACTICALRMM.md) | Configuration des alertes automatiques |
| [ANALYSE_DEPOT.md](ANALYSE_DEPOT.md) | 🆕 Analyse complète du dépôt et plan d'amélioration |

## Agent Synology modifié

L'agent rmmagent standard ne détecte pas correctement les informations matérielles sur Synology. Une version modifiée est disponible dans `rmmagent-synology/` avec :

- Détection du modèle NAS et version DSM
- Numéro de série correct
- Informations des disques (modèle, S/N, type HDD/SSD)
- Détection des adresses IP

Voir [rmmagent-synology/README.md](rmmagent-synology/README.md) pour l'installation.

## 📁 Structure du dépôt

```
tactical-rmm/
├── install.sh                        # 🆕 Script d'installation universel
├── rmmagent-linux-ameliore.sh        # Script Linux amélioré (support Synology optimisé)
│
├── scripts/
│   ├── linux/
│   │   └── auto-update/              # 🆕 Système de mise à jour automatique
│   │       ├── tactical-agent-updater.sh
│   │       ├── install-auto-update.sh
│   │       ├── auto-update.conf
│   │       └── systemd timers/services
│   │
│   ├── windows/
│   │   ├── install/                  # 🆕 Scripts d'installation Windows
│   │   │   ├── windows_agent_install.ps1
│   │   │   ├── windows_agent_update.ps1
│   │   │   ├── windows_agent_check.ps1
│   │   │   ├── windows_agent_deploy_gpo.ps1
│   │   │   └── windows_agent_uninstall.ps1
│   │   └── windows_surveillance_complete.ps1
│   │
│   ├── synology/                     # Scripts surveillance Synology (9 scripts)
│   ├── plesk/                        # Scripts surveillance Plesk (10 scripts)
│   ├── activedirectory/              # Scripts gestion AD (9 scripts)
│   ├── eset/                         # Scripts ESET antivirus (3 scripts)
│   ├── veeam/                        # Scripts Veeam Backup (1 script)
│   └── omada/                        # Scripts TP-Link Omada (3 scripts)
│
├── rmmagent-synology/                # Agent modifié pour Synology
│
└── Documentation (*.md)
    ├── ANALYSE_DEPOT.md              # 🆕 Analyse complète et recommandations
    ├── LINUX_AGENT_INSTALL.md
    ├── SYNOLOGY_AGENT_INSTALL.md
    └── ALERTES_TACTICALRMM.md
```

## ✨ Nouveautés (v2.0)

### 🆕 Script d'installation universel
- Détection automatique du système (Linux, Windows, Synology)
- Installation en une commande
- Support mode interactif et non-interactif
- Installation automatique du système de mise à jour

### 🆕 Système de mise à jour automatique Linux
- Vérification automatique des nouvelles versions
- Mise à jour pendant fenêtre de maintenance configurable
- Sauvegarde et rollback automatique
- Notifications (email, Slack, Discord, Teams)
- Timer systemd (hebdomadaire avec décalage aléatoire)

### 🆕 Scripts Windows complets
- Installation, mise à jour, diagnostic, désinstallation
- Déploiement via GPO (Active Directory)
- Gestion d'erreurs robuste avec rollback

### 🆕 Documentation complète
- README pour chaque catégorie de scripts
- Analyse du dépôt avec plan d'amélioration
- Exemples et guides de dépannage

## 🎯 Cas d'usage

### Installation sur Linux/Synology
```bash
# Méthode 1: Script universel (recommandé)
sudo bash <(curl -sSL https://raw.githubusercontent.com/votre-user/tactical-rmm/main/install.sh)

# Méthode 2: Script Linux amélioré
wget https://raw.githubusercontent.com/votre-user/tactical-rmm/main/rmmagent-linux-ameliore.sh
chmod +x rmmagent-linux-ameliore.sh
sudo ./rmmagent-linux-ameliore.sh install "MESH_URL" "API_URL" CLIENT_ID SITE_ID "AUTH_KEY" "server"
```

### Installation sur Windows
```powershell
# Télécharger et installer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/votre-user/tactical-rmm/main/scripts/windows/install/windows_agent_install.ps1" -OutFile "install.ps1"
.\install.ps1 -ApiUrl "https://api.votredomaine.com" -ClientId 1 -SiteId 2 -AuthKey "key" -AgentType "server"
```

### Déploiement GPO (Active Directory)
Voir [scripts/windows/install/README.md](scripts/windows/install/README.md)

### Mise à jour automatique (Linux)
```bash
# Installer le système de mise à jour automatique
cd scripts/linux/auto-update/
sudo ./install-auto-update.sh

# Les mises à jour seront automatiques chaque dimanche à 03:00
```

## 🔧 Prérequis

- Instance Tactical RMM fonctionnelle
- MeshCentral configuré
- Accès SSH aux machines cibles (Linux)
- Droits administrateur (Windows)

## 📊 Scripts de surveillance

### Synology (9 scripts)
- Surveillance complète, disques, RAID, Hyper Backup, services, sécurité
- Voir [scripts/synology/README.md](scripts/synology/README.md)

### Plesk (10 scripts)
- Surveillance complète, backup, SSL, mail, Docker, security
- Voir [scripts/plesk/README.md](scripts/plesk/README.md)

### Windows
- Surveillance serveur complète
- Voir [scripts/windows/README.md](scripts/windows/README.md)

### Active Directory (9 scripts)
- Gestion utilisateurs, groupes, inventaire AD
- Voir [scripts/activedirectory/README.md](scripts/activedirectory/README.md)

### Autres intégrations
- **ESET** : Antivirus monitoring (3 scripts)
- **Veeam** : Backup monitoring (1 script)
- **Omada** : TP-Link network monitoring (3 scripts)

## Licence

MIT License - Copyright (c) 2025
