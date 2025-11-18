# Tactical RMM - Scripts et documentation

Dépôt contenant des scripts de surveillance et documentation pour Tactical RMM.

## Documentation

| Fichier | Description |
|---------|-------------|
| [LINUX_AGENT_INSTALL.md](LINUX_AGENT_INSTALL.md) | Installation de l'agent sur Linux |
| [SYNOLOGY_AGENT_INSTALL.md](SYNOLOGY_AGENT_INSTALL.md) | Installation de l'agent sur NAS Synology |
| [ALERTES_TACTICALRMM.md](ALERTES_TACTICALRMM.md) | Configuration des alertes automatiques |
| [scripts/README.md](scripts/README.md) | Scripts de surveillance Plesk et Synology |

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
│   ├── plesk/              # Scripts surveillance serveur Plesk
│   └── synology/           # Scripts surveillance NAS Synology
├── rmmagent-synology/      # Agent modifié pour Synology
├── LINUX_AGENT_INSTALL.md
├── SYNOLOGY_AGENT_INSTALL.md
└── ALERTES_TACTICALRMM.md
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

## Licence

MIT License - Copyright (c) 2025
