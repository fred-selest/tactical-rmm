# Tactical RMM - Scripts et documentation

Dépôt contenant des scripts de surveillance et documentation pour Tactical RMM.

## Documentation

| Fichier | Description |
|---------|-------------|
| [LINUX_AGENT_INSTALL.md](LINUX_AGENT_INSTALL.md) | Installation de l'agent sur Linux |
| [SYNOLOGY_AGENT_INSTALL.md](SYNOLOGY_AGENT_INSTALL.md) | Installation de l'agent sur NAS Synology |
| [ALERTES_TACTICALRMM.md](ALERTES_TACTICALRMM.md) | Configuration des alertes automatiques |
| [scripts/README.md](scripts/README.md) | Scripts de surveillance Plesk et Synology |
| [AGENTS.md](AGENTS.md) | Guide de développement pour agents IA |

## Nouvelles Fonctionnalités

### 🤖 Installation Automatisée
- **`install-automated.sh`** : Script d'installation entièrement automatisé avec détection automatique des paramètres
- **`test-automated-install.sh`** : Script de test pour valider l'installation automatisée

### 📊 Surveillance Avancée
- **Surveillance Système** : CPU, mémoire, disque, réseau avec seuils configurables
- **Surveillance Docker** : État des conteneurs, utilisation espace, éléments orphelins
- **Surveillance Bases de Données** : MySQL/MariaDB et PostgreSQL avec détection automatique

### 🧪 Tests Complets
- **`test-advanced-monitoring.sh`** : Suite de tests complète pour la surveillance avancée
- **Validation automatique** de tous les composants

## Agent Synology modifié

L'agent rmmagent standard ne détecte pas correctement les informations matérielles sur Synology. Une version modifiée est disponible dans `rmmagent-synology/` avec :

- Détection du modèle NAS et version DSM
- Numéro de série correct
- Informations des disques (modèle, S/N, type HDD/SSD)
- Détection des adresses IP

Voir [rmmagent-synology/README.md](rmmagent-synology/README.md) pour l'installation.

## Structure du dépôt

```
tactical-rmm/
├── scripts/
│   ├── system/             # Scripts surveillance système (CPU, mémoire, disque, réseau)
│   ├── docker/             # Scripts surveillance Docker
│   ├── database/           # Scripts surveillance bases de données (MySQL, PostgreSQL)
│   ├── plesk/              # Scripts surveillance serveur Plesk
│   └── synology/           # Scripts surveillance NAS Synology
├── rmmagent-synology/      # Agent modifié pour Synology
├── integration/            # Composants d'intégration Django
├── *.sh                    # Scripts principaux d'installation et utilitaires
└── *.md                    # Documentation (français/anglais)
```

## Prérequis

- Instance Tactical RMM fonctionnelle
- MeshCentral configuré
- Accès SSH aux machines cibles

## Installation rapide

### Linux (sans token de signature)

```bash
wget https://raw.githubusercontent.com/netvolt/LinuxRMM-Script/main/rmmagent-linux.sh
chmod +x rmmagent-linux.sh
./rmmagent-linux.sh install 'MESH_URL' 'API_URL' 'CLIENT_ID' 'SITE_ID' 'AUTH_KEY' 'TYPE'
```

### Synology NAS

Voir [SYNOLOGY_AGENT_INSTALL.md](SYNOLOGY_AGENT_INSTALL.md) pour les instructions complètes.

## 🔁 Mise à Jour

### Mise à jour manuelle
```bash
cd /home/debian/tactical-rmm
sudo ./update-tactical-rmm.sh
```

### Mise à jour automatique
```bash
# Mise à jour quotidienne
sudo ./setup-auto-update.sh --daily

# Mise à jour hebdomadaire  
sudo ./setup-auto-update.sh --weekly
```

Voir [UPDATE.md](UPDATE.md) pour la documentation complète du système de mise à jour.

## Licence

MIT License - Copyright (c) 2025
