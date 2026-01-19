# Guide d'intégration - Installation Agent Linux via Dashboard

Ce guide explique comment intégrer l'installation de l'agent Linux nativement dans le dashboard de Tactical RMM.

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Installation Backend](#installation-backend)
4. [Installation Frontend](#installation-frontend)
5. [Configuration](#configuration)
6. [Utilisation](#utilisation)
7. [Dépannage](#dépannage)

## Vue d'ensemble

Cette intégration permet aux administrateurs de Tactical RMM de déployer des agents Linux depuis le dashboard web, de la même manière que pour les agents Windows.

### Fonctionnalités

- ✅ Création de liens de déploiement depuis le dashboard
- ✅ Configuration automatique (client, site, type d'agent)
- ✅ Génération de commande d'installation en une ligne
- ✅ Suivi des déploiements (téléchargements, installations)
- ✅ Expiration automatique des liens
- ✅ Support de multiples architectures (amd64, arm64, i386)
- ✅ Notifications au serveur après installation

### Workflow

```
┌─────────────┐        ┌──────────────┐        ┌───────────────┐
│  Dashboard  │───────▶│  API Django  │───────▶│ Script Shell  │
│   (Vue.js)  │        │  (Backend)   │        │ (rmmagent.sh) │
└─────────────┘        └──────────────┘        └───────────────┘
      │                       │                        │
      │ 1. Créer déploiement  │                        │
      │────────────────────▶  │                        │
      │                       │                        │
      │ 2. Récupérer URL      │                        │
      │◀────────────────────  │                        │
      │                       │                        │
      │                       │ 3. Télécharger script  │
      │                       │◀───────────────────────│
      │                       │                        │
      │                       │ 4. Récupérer config    │
      │                       │◀───────────────────────│
      │                       │                        │
      │                       │ 5. Notifier succès     │
      │                       │◀───────────────────────│
```

## Architecture

### Composants

#### 1. Backend Django

**Fichiers** :
- `integration/backend/models.py` - Modèles de base de données
- `integration/backend/views.py` - Endpoints API REST
- `integration/backend/serializers.py` - Sérialiseurs
- `integration/backend/urls.py` - Configuration des routes
- `integration/backend/admin.py` - Interface d'administration

**Modèles** :
- `LinuxDeployment` - Stocke les déploiements
- `DeploymentLog` - Logs des téléchargements et installations

**Endpoints** :
- `POST /api/v3/linux-deployments/create/` - Créer un déploiement
- `GET /api/v3/linux-deployments/` - Lister les déploiements
- `GET /api/v3/linux-deployments/{uuid}/` - Détails d'un déploiement
- `DELETE /api/v3/linux-deployments/{uuid}/` - Supprimer
- `GET /api/v3/linux-deployments/stats/` - Statistiques
- `GET /clients/{uuid}/deploy/linux/` - Télécharger le script (public)
- `POST /api/v3/linux-deployments/{uuid}/installed/` - Callback installation

#### 2. Frontend Vue.js

**Fichiers** :
- `integration/frontend/LinuxDeploymentManager.vue` - Modal de création
- `integration/frontend/LinuxDeploymentList.vue` - Liste des déploiements

**Composants** :
- Interface en 3 étapes (Client/Site → Config → Instructions)
- Statistiques en temps réel
- Filtres et recherche
- Copie automatique des commandes

#### 3. Script d'installation

**Fichiers** :
- `rmmagent-linux-dashboard.sh` - Script avec support UUID
- `rmmagent-linux-ameliore.sh` - Script original (compatibilité)

**Modes d'installation** :
1. **Via UUID** (recommandé) : `./script.sh install {uuid} {api_url}`
2. **Manuel** (ancien) : `./script.sh install {mesh_url} {api_url} {client_id} ...`

## Installation Backend

### 1. Prérequis

- Tactical RMM déjà installé et fonctionnel
- Django >= 3.2
- Django REST Framework >= 3.12
- PostgreSQL >= 12

### 2. Copier les fichiers

```bash
cd /opt/tacticalrmm
git clone https://github.com/fred-selest/tactical-rmm.git integration-files
cd integration-files
```

### 3. Intégrer les modèles

**Option A : Créer une nouvelle app Django**

```bash
cd /opt/tacticalrmm/api/tacticalrmm
python manage.py startapp linux_deployments
```

Copier les fichiers :

```bash
cp /path/to/integration/backend/models.py linux_deployments/
cp /path/to/integration/backend/views.py linux_deployments/
cp /path/to/integration/backend/serializers.py linux_deployments/
cp /path/to/integration/backend/urls.py linux_deployments/
cp /path/to/integration/backend/admin.py linux_deployments/
```

Ajouter l'app dans `settings.py` :

```python
INSTALLED_APPS = [
    # ... apps existantes ...
    'tacticalrmm.linux_deployments',
]
```

**Option B : Intégrer dans l'app clients existante**

Copier le contenu des fichiers dans les fichiers correspondants de `api/tacticalrmm/clients/`.

### 4. Configurer les URLs

Dans `api/tacticalrmm/tacticalrmm/urls.py` :

```python
from django.urls import path, include

urlpatterns = [
    # ... URLs existantes ...

    # Linux Deployments
    path('', include('tacticalrmm.linux_deployments.urls')),
]
```

### 5. Créer les migrations

```bash
cd /opt/tacticalrmm/api/tacticalrmm
python manage.py makemigrations linux_deployments
python manage.py migrate
```

### 6. Créer un superuser (si nécessaire)

```bash
python manage.py createsuperuser
```

### 7. Tester l'API

```bash
# Démarrer le serveur de développement
python manage.py runserver

# Dans un autre terminal, tester l'endpoint
curl -X GET http://localhost:8000/api/v3/linux-deployments/ \
  -H "Authorization: Token YOUR_API_TOKEN"
```

## Installation Frontend

### 1. Prérequis

- Node.js >= 14
- npm >= 6
- Quasar CLI

### 2. Cloner le frontend de Tactical RMM

```bash
git clone https://github.com/amidaware/tacticalrmm-web.git
cd tacticalrmm-web
```

### 3. Copier les composants

```bash
cp /path/to/integration/frontend/LinuxDeploymentManager.vue src/components/modals/agents/
cp /path/to/integration/frontend/LinuxDeploymentList.vue src/components/agents/
```

### 4. Ajouter la route

Dans `src/router/routes.js` :

```javascript
{
  path: '/agents/linux-deployments',
  name: 'linux-deployments',
  component: () => import('components/agents/LinuxDeploymentList.vue'),
  meta: {
    requiresAuth: true,
    title: 'Déploiements Linux'
  }
}
```

### 5. Ajouter au menu

Dans `src/layouts/MainLayout.vue` :

```javascript
{
  label: 'Agents',
  icon: 'computer',
  children: [
    // ... éléments existants ...
    {
      label: 'Installation Linux',
      icon: 'terminal',
      to: '/agents/linux-deployments'
    }
  ]
}
```

### 6. Configurer Quasar

Dans `quasar.conf.js`, vérifier que ces plugins sont activés :

```javascript
framework: {
  plugins: [
    'Notify',
    'Dialog',
    'copyToClipboard'
  ]
}
```

### 7. Build et déploiement

```bash
# Développement
npm run dev

# Production
npm run build

# Copier les fichiers vers le serveur
scp -r dist/* user@server:/var/www/tacticalrmm/
```

## Configuration

### 1. Configuration Django

Dans `settings.py`, ajouter/vérifier :

```python
# CORS (si frontend et backend sur des domaines différents)
CORS_ALLOWED_ORIGINS = [
    "https://votre-domaine.com",
]

# URL de base pour les scripts
SCRIPT_BASE_URL = "https://raw.githubusercontent.com/fred-selest/tactical-rmm/main"
```

### 2. Configuration Mesh

Assurez-vous que MeshCentral est correctement configuré et accessible.

### 3. Configuration Nginx

Ajouter la configuration pour servir le script :

```nginx
# /etc/nginx/sites-available/rmm.conf

server {
    listen 443 ssl;
    server_name api.votredomaine.com;

    # ... configuration SSL existante ...

    # Scripts publics
    location /clients/ {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # API
    location /api/ {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Recharger Nginx :

```bash
nginx -t
systemctl reload nginx
```

## Utilisation

### Pour l'administrateur

#### 1. Créer un déploiement

1. Connectez-vous au dashboard
2. Allez dans **Agents** → **Installation Linux**
3. Cliquez sur **Nouveau déploiement**
4. Sélectionnez le **Client** et le **Site**
5. Configurez l'agent :
   - Type : Server ou Workstation
   - Architecture : amd64, arm64, ou i386
   - Expiration : nombre de jours
6. Cliquez sur **Créer le déploiement**
7. Copiez l'URL ou la commande d'installation
8. Envoyez-la au client ou utilisez-la directement

#### 2. Gérer les déploiements

- **Voir les statistiques** : En haut de la page
- **Filtrer** : Par statut, type d'agent, ou recherche
- **Copier l'URL** : Bouton dans la colonne Actions
- **Supprimer** : Si le déploiement n'est plus nécessaire

### Pour le client/technicien

#### Méthode 1 : Commande en une ligne (recommandé)

```bash
wget https://api.votredomaine.com/clients/{uuid}/deploy/linux/ -O install-rmm.sh && chmod +x install-rmm.sh && sudo ./install-rmm.sh
```

Ou avec curl :

```bash
curl -L https://api.votredomaine.com/clients/{uuid}/deploy/linux/ | sudo bash
```

#### Méthode 2 : Téléchargement puis exécution

```bash
# Télécharger
wget https://api.votredomaine.com/clients/{uuid}/deploy/linux/ -O install-rmm.sh

# Rendre exécutable
chmod +x install-rmm.sh

# Exécuter en tant que root
sudo ./install-rmm.sh
```

### Vérification de l'installation

Après quelques minutes, l'agent devrait apparaître dans le dashboard sous :
**Clients** → **{Votre Client}** → **{Votre Site}**

## Dépannage

### Problème : L'agent n'apparaît pas dans le dashboard

**Vérifications** :

1. Le service est-il actif ?
   ```bash
   systemctl status tacticalagent
   ```

2. Y a-t-il des erreurs dans les logs ?
   ```bash
   journalctl -u tacticalagent -n 50
   ```

3. La configuration est-elle correcte ?
   ```bash
   cat /etc/tacticalagent
   ```

4. Le serveur API est-il accessible ?
   ```bash
   curl -v https://api.votredomaine.com
   ```

### Problème : Erreur lors du téléchargement du script

**Vérifications** :

1. L'UUID est-il correct ?
2. Le déploiement a-t-il expiré ?
3. Le serveur API est-il accessible ?

**Solution** :

Vérifier dans le dashboard si le déploiement existe et est actif.

### Problème : Erreur de compilation

**Vérifications** :

1. Go est-il installé correctement ?
   ```bash
   go version
   ```

2. Y a-t-il assez d'espace disque ?
   ```bash
   df -h
   ```

3. Les dépendances sont-elles installées ?
   ```bash
   which wget tar curl jq
   ```

**Solution** :

Installer les dépendances manquantes :

```bash
# Debian/Ubuntu
apt-get install wget tar curl jq

# CentOS/RHEL
yum install wget tar curl jq

# Fedora
dnf install wget tar curl jq
```

### Problème : Mesh Agent ne s'installe pas

**Vérifications** :

1. L'URL Mesh est-elle correcte ?
2. Le serveur Mesh est-il accessible ?
3. Le fichier téléchargé est-il valide ?

**Solution** :

Tester manuellement l'installation Mesh :

```bash
wget "https://mesh.votredomaine.com/meshagents?id=..." -O meshagent
chmod +x meshagent
./meshagent -install
```

### Logs et débogage

**Logs du script d'installation** :

```bash
tail -f /var/log/tacticalrmm-install.log
```

**Logs de l'agent** :

```bash
journalctl -u tacticalagent -f
```

**Logs du backend Django** :

```bash
tail -f /var/log/tacticalrmm/django.log
```

## Sécurité

### Bonnes pratiques

1. **Expiration des liens** : Définir une durée d'expiration raisonnable (7-30 jours)
2. **HTTPS uniquement** : Toujours utiliser HTTPS pour l'API
3. **Authentification** : Les endpoints de gestion nécessitent une authentification
4. **Audit** : Tous les téléchargements et installations sont loggés
5. **Nettoyage** : Supprimer les déploiements expirés régulièrement

### Nettoyage automatique

Créer un cron job pour supprimer les déploiements expirés :

```bash
# /etc/cron.daily/cleanup-deployments
#!/bin/bash
cd /opt/tacticalrmm/api/tacticalrmm
python manage.py shell << EOF
from tacticalrmm.linux_deployments.models import LinuxDeployment
from django.utils import timezone
LinuxDeployment.objects.filter(expires_at__lt=timezone.now()).delete()
EOF
```

## Support

- **Documentation Tactical RMM** : https://docs.tacticalrmm.com
- **GitHub Issues** : https://github.com/fred-selest/tactical-rmm/issues
- **Discord Tactical RMM** : https://discord.gg/uptime-kuma

## Licence

AGPL-3.0 (même licence que Tactical RMM)
