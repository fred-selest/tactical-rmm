# Changelog - Intégration Dashboard Linux

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

## [3.0.0] - 2026-01-21

### 🎉 Nouvelle Fonctionnalité Majeure : Intégration Dashboard

**Installation d'agents Linux directement depuis le dashboard Tactical RMM**

#### Ajouté

**Backend Django :**
- ✅ Modèles de base de données (`LinuxDeployment`, `DeploymentLog`)
- ✅ API REST complète (7 endpoints)
- ✅ Interface d'administration Django
- ✅ Système de suivi des téléchargements et installations
- ✅ Gestion automatique des expirations
- ✅ Statistiques en temps réel

**Scripts :**
- ✅ `install-backend.sh` - Installation automatique en 1 commande
- ✅ `create-deployment.sh` - Helper interactif pour créer des déploiements
- ✅ `rmmagent-linux.sh` - Script d'installation avec support UUID (v3.0)

**Documentation :**
- ✅ `TEST_GUIDE.md` - Guide de test complet
- ✅ `DASHBOARD_INTEGRATION_README.md` - Documentation complète
- ✅ `integration/README.md` - Vue d'ensemble du projet
- ✅ `integration/docs/INTEGRATION_GUIDE.md` - Guide d'intégration détaillé
- ✅ `integration/backend/README.md` - Documentation backend
- ✅ `integration/frontend/README.md` - Documentation frontend

**Composants Frontend Vue.js :**
- ✅ `LinuxDeploymentManager.vue` - Modal de création de déploiement
- ✅ `LinuxDeploymentList.vue` - Liste et gestion des déploiements

#### Fonctionnalités

- **Création de déploiements** depuis le dashboard ou API
- **URL unique** générée automatiquement pour chaque déploiement
- **Installation en une ligne** sur les serveurs Linux
- **Suivi complet** : téléchargements, installations, erreurs
- **Expiration automatique** des liens de déploiement
- **Support multi-architectures** : amd64, arm64, i386
- **Callbacks** : notification au serveur après installation
- **Statistiques** : taux de succès, total d'installations, etc.

#### Endpoints API

| Endpoint | Méthode | Auth | Description |
|----------|---------|------|-------------|
| `/api/v3/linux-deployments/` | GET | ✅ | Liste |
| `/api/v3/linux-deployments/create/` | POST | ✅ | Créer |
| `/api/v3/linux-deployments/{uuid}/` | GET | ✅ | Détails |
| `/api/v3/linux-deployments/{uuid}/` | DELETE | ✅ | Supprimer |
| `/api/v3/linux-deployments/stats/` | GET | ✅ | Stats |
| `/clients/{uuid}/deploy/linux/` | GET | ❌ | Script (public) |
| `/api/v3/linux-deployments/{uuid}/installed/` | POST | ❌ | Callback |

#### Amélioration

- Script d'installation Linux amélioré avec support UUID
- Compatibilité totale avec l'ancienne méthode (rétrocompatible)
- Détection automatique de l'architecture et du système
- Gestion améliorée des erreurs
- Logs détaillés

---

## [2.0.0] - 2025-01-14

### Script d'Installation Linux Amélioré

#### Ajouté

- Support Synology optimisé
- Détection automatique du système
- Gestion automatique de Go
- Logs détaillés dans `/var/log/tacticalrmm-install.log`
- Commande `status` pour vérifier l'état de l'agent
- Commande `update` pour mettre à jour l'agent

#### Modifié

- Amélioration de la gestion des erreurs
- Meilleure détection d'architecture
- Support des systèmes sans systemd (Synology DSM < 7)

#### Fichiers

- `rmmagent-linux.sh` - Script principal
- `SCRIPT_LINUX_AMELIORE_README.md` - Documentation
- `AMELIORATIONS_SCRIPT_LINUX.md` - Notes d'amélioration

---

## [1.0.0] - 2025-08-07

### Version Initiale

#### Ajouté

**Scripts de Surveillance :**
- Scripts Plesk (surveillance complète)
- Scripts Synology (surveillance NAS)

**Agent Synology Modifié :**
- Détection correcte du modèle NAS
- Numéro de série
- Informations des disques
- Version DSM

**Documentation :**
- `LINUX_AGENT_INSTALL.md` - Installation agent Linux
- `SYNOLOGY_AGENT_INSTALL.md` - Installation agent Synology
- `ALERTES_TACTICALRMM.md` - Configuration des alertes

**Structure :**
```
tactical-rmm/
├── scripts/
│   ├── plesk/
│   └── synology/
├── rmmagent-synology/
└── docs/
```

---

## Roadmap

### Version 3.1.0 (À venir)

- [ ] Interface Vue.js complète dans le dashboard
- [ ] Authentification OAuth2 pour les callbacks
- [ ] Webhook personnalisables
- [ ] Notifications Slack/Discord après installation
- [ ] Templates de scripts personnalisables
- [ ] Multi-langue (français, anglais)

### Version 3.2.0 (Futur)

- [ ] API GraphQL
- [ ] Export des statistiques (CSV, JSON)
- [ ] Planification d'installation (cron jobs)
- [ ] Intégration Ansible
- [ ] Support Kubernetes

---

## Notes de Version

### Migration 2.0 → 3.0

**Aucune action requise pour les utilisateurs existants.**

La version 3.0 ajoute l'intégration dashboard sans modifier les scripts existants.
Les deux méthodes (manuelle et dashboard) sont supportées.

### Installation Propre

Pour une nouvelle installation, utilisez :
```bash
git clone https://github.com/fred-selest/tactical-rmm.git
cd tactical-rmm
sudo ./install-backend.sh
```

---

## Support

- **GitHub** : https://github.com/fred-selest/tactical-rmm
- **Issues** : https://github.com/fred-selest/tactical-rmm/issues
- **Documentation** : Voir fichiers `*.md` dans le repository

---

## License

AGPL-3.0 - Voir fichier LICENSE

---

**Développé par fred-selest** | **Janvier 2026**
