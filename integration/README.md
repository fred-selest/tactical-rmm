# Intégration Dashboard - Installation Agent Linux pour Tactical RMM

Cette intégration permet de déployer des agents Linux depuis le dashboard de Tactical RMM, de manière native et transparente.

## 🎯 Objectif

Offrir une expérience d'installation d'agents Linux identique à celle des agents Windows, directement depuis l'interface web de Tactical RMM.

## ✨ Fonctionnalités

- ✅ **Création de déploiements** depuis le dashboard web
- ✅ **Configuration automatique** (client, site, type d'agent, architecture)
- ✅ **Génération de commande** d'installation en une ligne
- ✅ **Suivi des déploiements** (téléchargements, installations réussies)
- ✅ **Expiration automatique** des liens de déploiement
- ✅ **Support multi-architectures** (amd64, arm64, i386)
- ✅ **Notifications** au serveur après installation
- ✅ **Statistiques** en temps réel
- ✅ **Interface d'administration** Django complète

## 📁 Structure du projet

```
integration/
├── backend/               # Code Django (API REST)
│   ├── models.py         # Modèles de base de données
│   ├── views.py          # Endpoints API
│   ├── serializers.py    # Sérialiseurs REST
│   ├── urls.py           # Configuration des routes
│   ├── admin.py          # Interface d'administration
│   └── README.md         # Documentation backend
│
├── frontend/             # Code Vue.js (Interface web)
│   ├── LinuxDeploymentManager.vue    # Modal de création
│   ├── LinuxDeploymentList.vue       # Liste des déploiements
│   └── README.md                     # Documentation frontend
│
└── docs/                 # Documentation
    ├── INTEGRATION_GUIDE.md          # Guide d'intégration complet
    ├── API_REFERENCE.md              # Référence API
    ├── USER_GUIDE.md                 # Guide utilisateur
    └── ARCHITECTURE.md               # Architecture technique
```

## 🚀 Installation rapide

### 1. Backend (Django)

```bash
# Cloner le repository
git clone https://github.com/fred-selest/tactical-rmm.git
cd tactical-rmm/integration

# Copier les fichiers backend
cp -r backend/\* /opt/tacticalrmm/api/tacticalrmm/linux_deployments/

# Créer les migrations
cd /opt/tacticalrmm/api/tacticalrmm
python manage.py makemigrations linux_deployments
python manage.py migrate
```

### 2. Frontend (Vue.js)

```bash
# Copier les composants
cp integration/frontend/LinuxDeploymentManager.vue /path/to/tacticalrmm-web/src/components/modals/agents/
cp integration/frontend/LinuxDeploymentList.vue /path/to/tacticalrmm-web/src/components/agents/

# Ajouter la route dans src/router/routes.js
# (voir documentation complète)

# Build
cd /path/to/tacticalrmm-web
npm run build
```

### 3. Script d'installation

Le script `rmmagent-linux-dashboard.sh` supporte deux modes :

**Mode 1 : Via UUID (recommandé)**
```bash
./rmmagent-linux-dashboard.sh install {uuid} {api_url}
```

**Mode 2 : Manuel (compatibilité)**
```bash
./rmmagent-linux-dashboard.sh install {mesh_url} {api_url} {client_id} {site_id} {auth_key} {agent_type}
```

## 📖 Documentation

- **[Guide d'intégration complet](docs/INTEGRATION_GUIDE.md)** - Installation pas à pas
- **[Référence API](docs/API_REFERENCE.md)** - Documentation des endpoints
- **[Guide utilisateur](docs/USER_GUIDE.md)** - Utilisation du dashboard
- **[Architecture](docs/ARCHITECTURE.md)** - Détails techniques

## 🎬 Démarrage rapide

### Pour l'administrateur

1. Connectez-vous au dashboard Tactical RMM
2. Allez dans **Agents** → **Installation Linux**
3. Cliquez sur **Nouveau déploiement**
4. Sélectionnez Client, Site, et configurez l'agent
5. Copiez la commande d'installation générée
6. Exécutez-la sur le serveur Linux cible

### Pour l'utilisateur final

```bash
# Commande fournie par l'administrateur
wget https://api.votredomaine.com/clients/{uuid}/deploy/linux/ -O install.sh
chmod +x install.sh
sudo ./install.sh
```

Ou en une seule ligne :

```bash
curl -L https://api.votredomaine.com/clients/{uuid}/deploy/linux/ | sudo bash
```

## 🔧 Configuration requise

### Backend
- Django >= 3.2
- Django REST Framework >= 3.12
- PostgreSQL >= 12
- Python >= 3.8

### Frontend
- Node.js >= 14
- npm >= 6
- Quasar Framework >= 2.0
- Vue.js >= 3.0

### Serveur Linux cible
- Systèmes supportés :
  - Debian 10+, Ubuntu 18.04+
  - CentOS 7+, Rocky Linux 8+, AlmaLinux 8+
  - Fedora 30+
  - Arch Linux
  - Synology DSM 7.0+
- Architectures :
  - amd64/x86_64
  - arm64
  - i386

## 📊 Workflow

```
┌──────────────┐
│  Dashboard   │  1. Créer déploiement
│   (Vue.js)   │─────────────────────┐
└──────────────┘                     │
                                     ▼
                            ┌─────────────────┐
                            │   API Django    │
                            │   (Backend)     │
                            └─────────────────┘
                                     │
                                     │ 2. Générer UUID
                                     │ 3. Stocker config
                                     │
                                     ▼
┌──────────────┐            ┌─────────────────┐
│   Serveur    │  4. Wget   │  Script Shell   │
│    Linux     │◀───────────│  (rmmagent.sh)  │
└──────────────┘            └─────────────────┘
        │                           │
        │ 5. Exécuter               │ 6. Récupérer config
        │                           │    via UUID
        │                           │
        │ 7. Installer              │
        │    - Go                   │
        │    - Mesh Agent           │
        │    - RMM Agent            │
        │                           │
        │ 8. Notifier succès        │
        └───────────────────────────┘
```

## 🔒 Sécurité

- ✅ Authentification requise pour les endpoints de gestion
- ✅ UUID unique et non prédictible pour chaque déploiement
- ✅ Expiration automatique des liens
- ✅ Logs complets de toutes les actions
- ✅ HTTPS obligatoire
- ✅ Aucune information sensible dans les URLs publiques

## 📈 Statistiques disponibles

Le dashboard affiche :
- Nombre total de déploiements créés
- Déploiements actifs vs expirés
- Nombre de téléchargements du script
- Nombre d'installations réussies
- Taux de succès

## 🤝 Contribution

Les contributions sont les bienvenues ! Voici comment participer :

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 🐛 Signaler un bug

Créez une issue sur GitHub avec :
- Description du problème
- Étapes pour reproduire
- Comportement attendu vs observé
- Logs pertinents
- Version de Tactical RMM

## 📝 Changelog

### Version 3.0 (Actuelle)
- ✨ Ajout du support UUID pour le déploiement
- ✨ Interface dashboard complète (Vue.js)
- ✨ API REST Django
- ✨ Notifications au serveur après installation
- ✨ Statistiques en temps réel
- ✨ Interface d'administration Django

### Version 2.0
- Support Synology amélioré
- Gestion automatique de Go
- Meilleure gestion des erreurs
- Logs détaillés

### Version 1.0
- Script d'installation de base
- Support Linux standard

## 📜 Licence

AGPL-3.0 - Même licence que Tactical RMM

## 🙏 Remerciements

- L'équipe Tactical RMM pour l'excellent projet
- La communauté pour les retours et suggestions

## 📞 Support

- **Documentation** : [docs/](docs/)
- **Issues** : [GitHub Issues](https://github.com/fred-selest/tactical-rmm/issues)
- **Discord Tactical RMM** : https://discord.gg/uptime-kuma
- **Forum** : https://forum.tacticalrmm.com

## 🔗 Liens utiles

- [Tactical RMM](https://github.com/amidaware/tacticalrmm)
- [Documentation Tactical RMM](https://docs.tacticalrmm.com)
- [MeshCentral](https://github.com/Ylianst/MeshCentral)

---

**Note** : Cette intégration est un ajout communautaire et n'est pas officiellement supportée par l'équipe Tactical RMM. Utilisez-la à vos propres risques.
