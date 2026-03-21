# 🚀 Guide d'Installation - Dashboard Linux pour rmm.votre-domaine.com

> **Installation interactive du module de déploiement d'agents Linux**
> Similaire à l'interface de déploiement Windows de Tactical RMM

## 📋 Vue d'ensemble

Cette installation va ajouter à votre interface **rmm.votre-domaine.com** :

- ✅ **Interface de création de déploiements Linux** (comme pour Windows)
- ✅ **Génération d'URLs d'installation uniques** par client/site
- ✅ **Suivi des installations** et statistiques
- ✅ **Expiration automatique** des liens de déploiement
- ✅ **API REST complète** pour automatisation
- ✅ **Interface d'administration Django** pour gestion visuelle

---

## 🎯 Prérequis

Avant de commencer, assurez-vous que :

- ✅ Tactical RMM est **installé et fonctionnel** sur votre serveur
- ✅ Vous avez un **accès SSH root** au serveur
- ✅ Le domaine **api.rmm.votre-domaine.com** est accessible
- ✅ Git est installé sur le serveur

---

## 🚀 Installation rapide (5 minutes)

### Étape 1 : Se connecter au serveur

```bash
ssh root@rmm.votre-domaine.com
# ou
ssh votre-utilisateur@rmm.votre-domaine.com
sudo su -
```

### Étape 2 : Cloner le repository

```bash
cd ~
git clone https://github.com/fred-selest/tactical-rmm.git
cd tactical-rmm
```

### Étape 3 : Rendre le script exécutable

```bash
chmod +x install-interactive.sh
```

### Étape 4 : Lancer l'installation interactive

```bash
sudo ./install-interactive.sh
```

Le script va :
1. 🔍 **Vérifier** votre installation Tactical RMM
2. 💾 **Sauvegarder** vos fichiers de configuration
3. 📦 **Installer** l'application Django linux_deployments
4. 🔧 **Configurer** settings.py et urls.py automatiquement
5. 🗄️ **Créer** les tables de base de données
6. 🔄 **Redémarrer** les services
7. ✅ **Vérifier** que tout fonctionne

**Durée estimée : 2-3 minutes**

---

## ✅ Vérification de l'installation

### Test 1 : Vérifier que l'API répond

```bash
curl -I https://api.rmm.votre-domaine.com/api/v3/linux-deployments/
```

**Résultat attendu :**
```
HTTP/2 401
```

> ✅ **401 Unauthorized = PARFAIT !**
> Cela signifie que l'endpoint existe mais nécessite une authentification.

### Test 2 : Vérifier le service

```bash
systemctl status rmm.service
```

**Résultat attendu :**
```
● rmm.service - Tactical RMM
   Loaded: loaded
   Active: active (running)
```

### Test 3 : Vérifier les logs

```bash
sudo journalctl -u rmm.service -n 50
```

**Ne devrait pas contenir d'erreurs** liées à linux_deployments.

---

## 🎨 Configuration Post-Installation

### Option A : Utiliser l'Admin Django (Recommandé) 🌟

C'est la **méthode la plus simple** pour créer et gérer vos déploiements visuellement.

#### 1. Activer l'interface d'administration

```bash
sudo nano /rmm/api/tacticalrmm/tacticalrmm/local_settings.py
```

Ajoutez cette ligne :
```python
ADMIN_ENABLED = True
```

Enregistrez et quittez (`Ctrl+X`, puis `Y`, puis `Entrée`).

#### 2. Créer un compte superuser (si vous n'en avez pas)

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py createsuperuser
```

Suivez les instructions :
```
Username: admin
Email: admin@rmm.votre-domaine.com
Password: [votre mot de passe sécurisé]
Password (again): [confirmer]
```

#### 3. Redémarrer le service

```bash
sudo systemctl restart rmm.service
```

#### 4. Accéder à l'administration

Ouvrez votre navigateur et allez sur :
```
https://api.rmm.votre-domaine.com/admin/
```

Connectez-vous avec vos identifiants superuser.

#### 5. Créer un déploiement Linux

Dans l'interface d'administration :

1. **Cliquez sur "Linux Deployments"** dans le menu de gauche
2. **Cliquez sur "Add Linux Deployment"** (Ajouter un déploiement)
3. **Remplissez le formulaire :**

| Champ | Valeur exemple | Description |
|-------|----------------|-------------|
| **Client ID** | `1` | ID du client dans Tactical RMM |
| **Client Name** | `Mon Entreprise` | Nom du client |
| **Site ID** | `1` | ID du site |
| **Site Name** | `Production` | Nom du site |
| **Agent Type** | `server` | Type : `server`, `workstation`, ou `laptop` |
| **Architecture** | `amd64` | Architecture : `amd64`, `arm64`, `x86` |
| **API URL** | `https://api.rmm.votre-domaine.com` | URL de votre API |
| **Auth Key** | `[votre clé]` | Clé d'authentification Tactical RMM |
| **Mesh URL** | `https://mesh.rmm.votre-domaine.com/...` | URL MeshCentral (optionnel) |
| **Enable Ping** | ✅ | Activer le ping |
| **Install Mesh** | ✅ | Installer MeshAgent |
| **Expires At** | `2026-04-01` | Date d'expiration |
| **Created By** | `admin` | Votre nom |

4. **Cliquez sur "Save"**

5. **Copiez l'UUID généré** (affiché en haut de la page)

#### 6. Obtenir l'URL d'installation

L'URL de téléchargement sera :
```
https://api.rmm.votre-domaine.com/clients/{UUID}/deploy/linux/
```

Remplacez `{UUID}` par l'UUID copié à l'étape précédente.

---

### Option B : Utiliser le Django Shell

Pour les utilisateurs avancés qui préfèrent la ligne de commande.

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell
```

Puis dans le shell Python :

```python
from linux_deployments.models import LinuxDeployment
from datetime import timedelta
from django.utils import timezone

# Créer un déploiement
deployment = LinuxDeployment.objects.create(
    client_id=1,
    client_name="Mon Entreprise",
    site_id=1,
    site_name="Production",
    agent_type="server",
    arch="amd64",
    api_url="https://api.rmm.votre-domaine.com",
    mesh_url="https://mesh.rmm.votre-domaine.com/meshagents?id=VOTRE_MESH_ID",
    auth_key="VOTRE_AUTH_KEY_TACTICAL_RMM",
    enable_ping=True,
    install_mesh=True,
    expires_at=timezone.now() + timedelta(days=30),
    created_by="admin"
)

# Afficher l'URL d'installation
print(f"UUID: {deployment.uuid}")
print(f"URL: https://api.rmm.votre-domaine.com/clients/{deployment.uuid}/deploy/linux/")

# Quitter le shell
exit()
```

**Copiez l'URL affichée** pour l'utiliser sur vos serveurs Linux.

---

### Option C : Utiliser l'API REST

Pour automatiser via scripts ou intégrations.

#### 1. Obtenir un token API

1. Connectez-vous au dashboard Tactical RMM : `https://rmm.votre-domaine.com`
2. Allez dans **Settings → API Keys**
3. Créez une nouvelle clé API
4. **Copiez le token** (vous ne pourrez plus le voir ensuite !)

#### 2. Créer un déploiement via API

```bash
curl -X POST https://api.rmm.votre-domaine.com/api/v3/linux-deployments/create/ \
  -H "Authorization: Token VOTRE_TOKEN_API" \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": 1,
    "client_name": "Mon Entreprise",
    "site_id": 1,
    "site_name": "Production",
    "agent_type": "server",
    "arch": "amd64",
    "expires_days": 30
  }'
```

**Réponse :**
```json
{
  "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "download_url": "https://api.rmm.votre-domaine.com/clients/a1b2c3d4.../deploy/linux/",
  "expires_at": "2026-04-01T12:00:00Z",
  "created_at": "2026-03-02T12:00:00Z"
}
```

#### 3. Lister tous les déploiements

```bash
curl https://api.rmm.votre-domaine.com/api/v3/linux-deployments/ \
  -H "Authorization: Token VOTRE_TOKEN_API"
```

#### 4. Voir les statistiques

```bash
curl https://api.rmm.votre-domaine.com/api/v3/linux-deployments/stats/ \
  -H "Authorization: Token VOTRE_TOKEN_API"
```

---

## 🖥️ Installer l'agent sur un serveur Linux

Une fois que vous avez créé un déploiement et obtenu l'URL :

### Sur le serveur Linux cible :

```bash
# Télécharger le script
wget https://api.rmm.votre-domaine.com/clients/{UUID}/deploy/linux/ -O install.sh

# Rendre exécutable
chmod +x install.sh

# Installer l'agent
sudo ./install.sh
```

**L'agent apparaîtra automatiquement dans votre dashboard !** ✨

---

## 📊 Endpoints API disponibles

### Endpoints authentifiés (nécessitent un Token API)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/api/v3/linux-deployments/` | Liste tous les déploiements |
| `POST` | `/api/v3/linux-deployments/create/` | Créer un nouveau déploiement |
| `GET` | `/api/v3/linux-deployments/{uuid}/` | Détails d'un déploiement |
| `DELETE` | `/api/v3/linux-deployments/{uuid}/` | Supprimer un déploiement |
| `GET` | `/api/v3/linux-deployments/stats/` | Statistiques globales |

### Endpoints publics (sans authentification)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/clients/{uuid}/deploy/linux/` | Télécharger le script d'installation |
| `POST` | `/api/v3/linux-deployments/{uuid}/installed/` | Callback après installation |

---

## 🔐 Sécurité

- ✅ **UUID unique** non-prédictible pour chaque déploiement
- ✅ **Expiration automatique** des liens (configurable)
- ✅ **Authentification requise** pour la gestion via API
- ✅ **Logs complets** de tous les téléchargements
- ✅ **HTTPS obligatoire** (déjà configuré sur rmm.votre-domaine.com)
- ✅ **Token API** pour l'accès programmatique

---

## 📝 Systèmes Linux supportés

- ✅ **Debian** 10, 11, 12
- ✅ **Ubuntu** 18.04, 20.04, 22.04, 24.04
- ✅ **CentOS** 7, 8
- ✅ **Rocky Linux** 8, 9
- ✅ **AlmaLinux** 8, 9
- ✅ **Fedora** 30+
- ✅ **Arch Linux**
- ✅ **Synology DSM** 7.0+

Architectures supportées :
- `amd64` (x86_64)
- `arm64` (aarch64)
- `x86` (i386)

---

## 🛠️ Dépannage

### Problème : L'API retourne 404

**Solution :**
```bash
# Vérifier que le service est actif
sudo systemctl status rmm.service

# Vérifier les logs
sudo journalctl -u rmm.service -n 50

# Vérifier que l'app est dans INSTALLED_APPS
grep -A 50 'INSTALLED_APPS' /rmm/api/tacticalrmm/tacticalrmm/settings.py | grep linux_deployments

# Vérifier les URLs
grep -A 20 'urlpatterns' /rmm/api/tacticalrmm/tacticalrmm/urls.py | grep linux_deployments
```

### Problème : Erreur lors de la migration

**Solution :**
```bash
# Supprimer les migrations existantes
sudo rm -rf /rmm/api/tacticalrmm/linux_deployments/migrations/

# Recréer
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py makemigrations linux_deployments

# Appliquer
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py migrate linux_deployments
```

### Problème : Service ne démarre pas

**Solution :**
```bash
# Voir les erreurs détaillées
sudo journalctl -u rmm.service -n 100 --no-pager

# Vérifier la syntaxe Python
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py check

# Redémarrer en mode debug
sudo systemctl restart rmm.service
sudo journalctl -u rmm.service -f
```

### Problème : Réinstaller complètement

```bash
cd ~/tactical-rmm
git pull origin main
sudo ./install-interactive.sh
```

Le script est **idempotent** - vous pouvez le relancer sans problème.

---

## 📁 Structure des fichiers installés

```
/rmm/api/tacticalrmm/
├── linux_deployments/              # Nouvelle application Django
│   ├── __init__.py
│   ├── apps.py
│   ├── models.py                   # Modèle LinuxDeployment
│   ├── views.py                    # API REST endpoints
│   ├── serializers.py              # Sérialiseurs Django REST
│   ├── urls.py                     # URLs de l'app
│   ├── admin.py                    # Interface admin Django
│   └── migrations/                 # Migrations de base de données
│
├── tacticalrmm/
│   ├── settings.py                 # Modifié (INSTALLED_APPS)
│   └── urls.py                     # Modifié (urlpatterns)
```

---

## 📚 Documentation complète

- **[DASHBOARD_INTEGRATION_README.md](DASHBOARD_INTEGRATION_README.md)** - Architecture technique
- **[integration/README.md](integration/README.md)** - Guide d'intégration détaillé
- **[integration/docs/](integration/docs/)** - Documentation complète

---

## 🆘 Support et aide

### Issues GitHub
https://github.com/fred-selest/tactical-rmm/issues

### Documentation Tactical RMM
https://docs.tacticalrmm.com

### Discord Tactical RMM
https://discord.gg/uptime-kuma

---

## 🎯 Workflow complet d'utilisation

```
1. Créer un déploiement
   └─> Via Admin Django, Shell Python, ou API REST

2. Obtenir l'URL d'installation
   └─> https://api.rmm.votre-domaine.com/clients/{UUID}/deploy/linux/

3. Sur chaque serveur Linux cible
   └─> wget {URL} -O install.sh
   └─> chmod +x install.sh
   └─> sudo ./install.sh

4. L'agent apparaît dans le dashboard !
   └─> rmm.votre-domaine.com
```

---

## 📊 Exemple d'utilisation complète

### Scénario : Installer 10 agents Linux

```bash
# 1. Créer le déploiement via API
DEPLOY_UUID=$(curl -s -X POST https://api.rmm.votre-domaine.com/api/v3/linux-deployments/create/ \
  -H "Authorization: Token VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"client_id": 1, "client_name": "Production", "site_id": 1, "site_name": "Datacenter", "agent_type": "server", "arch": "amd64", "expires_days": 7}' \
  | jq -r '.uuid')

echo "UUID créé : $DEPLOY_UUID"
echo "URL : https://api.rmm.votre-domaine.com/clients/$DEPLOY_UUID/deploy/linux/"

# 2. Distribuer sur vos 10 serveurs
for SERVER in server{1..10}; do
  ssh $SERVER "wget https://api.rmm.votre-domaine.com/clients/$DEPLOY_UUID/deploy/linux/ -O /tmp/install.sh && chmod +x /tmp/install.sh && sudo /tmp/install.sh"
done

# 3. Vérifier les installations
curl https://api.rmm.votre-domaine.com/api/v3/linux-deployments/$DEPLOY_UUID/ \
  -H "Authorization: Token VOTRE_TOKEN" \
  | jq '.install_count'
```

---

## ✨ Fonctionnalités avancées

### Expiration personnalisée

```python
# Dans Django Shell
from linux_deployments.models import LinuxDeployment
from datetime import timedelta
from django.utils import timezone

# Déploiement expirant dans 1 heure (pour tests)
deployment = LinuxDeployment.objects.create(
    ...,
    expires_at=timezone.now() + timedelta(hours=1)
)

# Déploiement expirant dans 90 jours
deployment = LinuxDeployment.objects.create(
    ...,
    expires_at=timezone.now() + timedelta(days=90)
)
```

### Filtrage par client/site

```bash
# Via API
curl "https://api.rmm.votre-domaine.com/api/v3/linux-deployments/?client_id=1" \
  -H "Authorization: Token VOTRE_TOKEN"

curl "https://api.rmm.votre-domaine.com/api/v3/linux-deployments/?site_id=2" \
  -H "Authorization: Token VOTRE_TOKEN"
```

### Statistiques avancées

```bash
curl https://api.rmm.votre-domaine.com/api/v3/linux-deployments/stats/ \
  -H "Authorization: Token VOTRE_TOKEN" \
  | jq
```

**Réponse :**
```json
{
  "total_deployments": 15,
  "active_deployments": 12,
  "expired_deployments": 3,
  "total_installs": 47,
  "avg_installs_per_deployment": 3.13
}
```

---

## 🎊 Félicitations !

Vous avez maintenant une interface complète de déploiement d'agents Linux dans votre dashboard Tactical RMM !

**Développé avec ❤️ pour la communauté Tactical RMM**

---

**Auteur:** fred-selest
**Licence:** AGPL-3.0
**Date:** Mars 2026
**Version:** 1.0.0
