# 🎨 Guide d'Utilisation - Interface Admin Django pour Linux Deployments

> **Guide complet pour créer et gérer vos déploiements d'agents Linux via l'interface d'administration Django**

## 📋 Table des matières

1. [Activer l'interface d'administration](#1-activer-linterface-dadministration)
2. [Accéder à l'admin Django](#2-accéder-à-ladmin-django)
3. [Créer votre premier déploiement](#3-créer-votre-premier-déploiement)
4. [Obtenir les informations nécessaires](#4-obtenir-les-informations-nécessaires)
5. [Utiliser le déploiement](#5-utiliser-le-déploiement)
6. [Gérer les déploiements existants](#6-gérer-les-déploiements-existants)
7. [Statistiques et suivi](#7-statistiques-et-suivi)

---

## 1. Activer l'interface d'administration

### Étape 1.1 : Se connecter au serveur

```bash
ssh root@rmm.selest.info
```

### Étape 1.2 : Éditer le fichier de configuration

```bash
sudo nano /rmm/api/tacticalrmm/tacticalrmm/local_settings.py
```

### Étape 1.3 : Ajouter la ligne d'activation

Ajoutez cette ligne au fichier :

```python
ADMIN_ENABLED = True
```

**Exemple de fichier complet :**
```python
# /rmm/api/tacticalrmm/tacticalrmm/local_settings.py

DEBUG = False
ADMIN_ENABLED = True

# Autres configurations...
```

Enregistrez et quittez :
- `Ctrl+X` pour quitter
- `Y` pour confirmer
- `Entrée` pour valider

### Étape 1.4 : Créer un superuser (si nécessaire)

Si vous n'avez pas encore de compte superuser Django :

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py createsuperuser
```

**Suivez les instructions :**
```
Username (leave blank to use 'tactical'): admin
Email address: admin@rmm.selest.info
Password: [entrez un mot de passe fort]
Password (again): [confirmez]
Superuser created successfully.
```

> ⚠️ **Important :** Notez bien ces identifiants !

### Étape 1.5 : Redémarrer le service

```bash
sudo systemctl restart rmm.service
```

### Étape 1.6 : Vérifier que le service est actif

```bash
sudo systemctl status rmm.service
```

Vous devriez voir :
```
● rmm.service - Tactical RMM
   Active: active (running)
```

---

## 2. Accéder à l'admin Django

### Étape 2.1 : Ouvrir votre navigateur

Allez sur : **https://api.rmm.selest.info/admin/**

### Étape 2.2 : Se connecter

Utilisez les identifiants créés à l'étape 1.4 :
- **Username:** `admin`
- **Password:** `[votre mot de passe]`

### Étape 2.3 : Interface d'administration

Vous devriez voir l'interface Django Admin avec plusieurs sections, dont :

```
Django administration
├─ AUTHENTICATION AND AUTHORIZATION
│  ├─ Groups
│  └─ Users
│
├─ LINUX DEPLOYMENTS         ← Section ajoutée !
│  └─ Linux Deployments
│
└─ [autres sections]
```

---

## 3. Créer votre premier déploiement

### Étape 3.1 : Accéder à Linux Deployments

1. Dans l'interface admin, cliquez sur **"Linux Deployments"** dans la section `LINUX DEPLOYMENTS`
2. Cliquez sur le bouton **"Add Linux Deployment"** en haut à droite

### Étape 3.2 : Remplir le formulaire

Vous allez voir un formulaire avec plusieurs champs. Voici comment les remplir :

#### **Section 1 : Informations client/site**

| Champ | Description | Exemple |
|-------|-------------|---------|
| **Client ID** | ID numérique du client dans Tactical RMM | `1` |
| **Client Name** | Nom du client | `Mon Entreprise` |
| **Site ID** | ID numérique du site | `1` |
| **Site Name** | Nom du site/emplacement | `Serveurs Production` |

> 💡 **Comment trouver ces infos ?** Voir section [4. Obtenir les informations nécessaires](#4-obtenir-les-informations-nécessaires)

#### **Section 2 : Configuration de l'agent**

| Champ | Options | Recommandation |
|-------|---------|----------------|
| **Agent Type** | `server`, `workstation`, `laptop` | `server` pour serveurs, `workstation` pour postes de travail |
| **Architecture** | `amd64`, `arm64`, `386` | `amd64` (le plus courant pour serveurs Linux) |

#### **Section 3 : URLs et authentification**

| Champ | Valeur pour rmm.selest.info |
|-------|------------------------------|
| **API URL** | `https://api.rmm.selest.info` |
| **Mesh URL** | Voir section 4.2 |
| **Auth Key** | Voir section 4.3 |

#### **Section 4 : Options d'installation**

| Champ | Valeur recommandée | Description |
|-------|-------------------|-------------|
| **Enable Ping** | ✅ Coché | Activer le monitoring ping |
| **Enable RDP** | ❌ Non coché | RDP (pour Windows uniquement) |
| **Install Mesh** | ✅ Coché | Installer MeshCentral pour accès à distance |

#### **Section 5 : Expiration et métadonnées**

| Champ | Valeur recommandée | Description |
|-------|-------------------|-------------|
| **Expires At** | `2026-04-01 00:00:00` | Date d'expiration du lien (30 jours par défaut) |
| **Created By** | `admin` | Votre nom d'utilisateur |

### Étape 3.3 : Enregistrer

Cliquez sur le bouton **"Save"** en bas du formulaire.

### Étape 3.4 : Récupérer l'UUID

Après l'enregistrement, vous serez redirigé vers la page de détails du déploiement.

**En haut de la page, vous verrez :**
```
Linux Deployment: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**Copiez cet UUID !** Vous en aurez besoin pour télécharger le script d'installation.

---

## 4. Obtenir les informations nécessaires

### 4.1 : Client ID et Site ID

#### **Option A : Via l'interface web Tactical RMM**

1. Connectez-vous au dashboard : **https://rmm.selest.info**
2. Allez dans **Clients** dans le menu de gauche
3. Cliquez sur le client souhaité
4. Dans l'URL, vous verrez : `https://rmm.selest.info/clients/{CLIENT_ID}/sites/{SITE_ID}`
   - Notez le `CLIENT_ID`
   - Notez le `SITE_ID`

#### **Option B : Via l'API**

```bash
# Lister tous les clients
curl -H "Authorization: Token VOTRE_TOKEN" \
  https://api.rmm.selest.info/api/v3/clients/

# Lister les sites d'un client
curl -H "Authorization: Token VOTRE_TOKEN" \
  https://api.rmm.selest.info/api/v3/clients/{CLIENT_ID}/sites/
```

#### **Option C : Via Django Shell**

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell
```

```python
from clients.models import Client, Site

# Lister tous les clients
for client in Client.objects.all():
    print(f"ID: {client.id} - Nom: {client.name}")

# Lister tous les sites
for site in Site.objects.all():
    print(f"ID: {site.id} - Nom: {site.name} - Client: {site.client.name}")

exit()
```

### 4.2 : Mesh URL

#### **Trouver votre Mesh URL**

1. Connectez-vous au dashboard Tactical RMM : **https://rmm.selest.info**
2. Allez dans **Settings → Global Settings**
3. Cherchez la section **MeshCentral**
4. L'URL sera du format :
   ```
   https://mesh.rmm.selest.info/meshagents?id=XXXXXXXXXXXXXXXXXXXXXXX...
   ```

#### **Alternative : Via la ligne de commande**

```bash
# Chercher dans la configuration
sudo grep -r "mesh" /rmm/api/tacticalrmm/tacticalrmm/local_settings.py

# Ou dans les variables d'environnement
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell
```

```python
from django.conf import settings
print(settings.MESH_URL)
exit()
```

### 4.3 : Auth Key (Clé d'authentification)

Cette clé est utilisée pour authentifier l'agent auprès du serveur Tactical RMM.

#### **Option A : Via Django Shell**

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell
```

```python
from core.models import CoreSettings
core = CoreSettings.objects.first()
print(f"Auth Key: {core.agent_auto_update_token}")
exit()
```

#### **Option B : Via les fichiers de configuration**

```bash
sudo grep -r "agent_auto_update_token" /rmm/api/tacticalrmm/
```

---

## 5. Utiliser le déploiement

### Étape 5.1 : Construire l'URL d'installation

L'URL sera :
```
https://api.rmm.selest.info/clients/{UUID}/deploy/linux/
```

**Exemple avec l'UUID de l'étape 3.4 :**
```
https://api.rmm.selest.info/clients/a1b2c3d4-e5f6-7890-abcd-ef1234567890/deploy/linux/
```

### Étape 5.2 : Sur le serveur Linux cible

```bash
# Télécharger le script
wget https://api.rmm.selest.info/clients/a1b2c3d4-e5f6-7890-abcd-ef1234567890/deploy/linux/ -O install-rmm.sh

# Vérifier que le script a été téléchargé
ls -lh install-rmm.sh

# Rendre exécutable
chmod +x install-rmm.sh

# Voir le contenu (optionnel)
less install-rmm.sh

# Installer l'agent
sudo ./install-rmm.sh
```

### Étape 5.3 : Vérifier l'installation

#### **Sur le serveur Linux :**

```bash
# Vérifier que le service est actif
sudo systemctl status tacticalagent

# Voir les logs
sudo journalctl -u tacticalagent -n 50
```

#### **Dans le dashboard Tactical RMM :**

1. Allez sur **https://rmm.selest.info**
2. Naviguez vers **Clients → [Votre client] → [Votre site]**
3. Vous devriez voir le nouvel agent apparaître dans la liste !

---

## 6. Gérer les déploiements existants

### 6.1 : Lister tous les déploiements

1. Dans l'admin Django : **https://api.rmm.selest.info/admin/**
2. Cliquez sur **"Linux Deployments"**
3. Vous verrez la liste de tous les déploiements

**Colonnes affichées :**
- **UUID** : Identifiant unique
- **Client Name** : Nom du client
- **Site Name** : Nom du site
- **Agent Type** : Type d'agent (server/workstation)
- **Created At** : Date de création
- **Expires At** : Date d'expiration
- **Install Count** : Nombre d'installations effectuées

### 6.2 : Filtrer les déploiements

Utilisez les filtres sur la droite pour :
- Filtrer par type d'agent
- Filtrer par architecture
- Filtrer par statut (actif/expiré)
- Filtrer par date de création

### 6.3 : Modifier un déploiement

1. Cliquez sur le déploiement que vous souhaitez modifier
2. Modifiez les champs nécessaires
3. Cliquez sur **"Save"**

> ⚠️ **Attention :** Modifier un déploiement ne change pas les agents déjà installés !

### 6.4 : Supprimer un déploiement

1. Cliquez sur le déploiement à supprimer
2. En bas de la page, cliquez sur **"Delete"**
3. Confirmez la suppression

> ⚠️ **Attention :** La suppression est définitive !

### 6.5 : Supprimer plusieurs déploiements

1. Dans la liste des déploiements, cochez les cases des déploiements à supprimer
2. Dans le menu déroulant en haut : sélectionnez **"Delete selected Linux Deployments"**
3. Cliquez sur **"Go"**
4. Confirmez la suppression

---

## 7. Statistiques et suivi

### 7.1 : Voir les statistiques d'un déploiement

Dans la page de détails d'un déploiement, vous verrez :

```
┌─────────────────────────────────────────────┐
│ Linux Deployment Details                   │
├─────────────────────────────────────────────┤
│ UUID: a1b2c3d4-e5f6-7890-abcd-ef1234567890 │
│ Client: Mon Entreprise                      │
│ Site: Production                            │
│ Type: server (amd64)                        │
│                                             │
│ 📊 Statistics:                              │
│   • Created: 2026-03-02 10:30:00           │
│   • Expires: 2026-04-01 10:30:00           │
│   • Installations: 5                        │
│   • Last download: 2026-03-02 15:45:00     │
│                                             │
│ 🔗 Download URL:                            │
│   https://api.rmm.selest.info/clients/...  │
└─────────────────────────────────────────────┘
```

### 7.2 : Voir les statistiques globales via API

```bash
curl -H "Authorization: Token VOTRE_TOKEN" \
  https://api.rmm.selest.info/api/v3/linux-deployments/stats/ | jq
```

**Réponse :**
```json
{
  "total_deployments": 15,
  "active_deployments": 12,
  "expired_deployments": 3,
  "total_installs": 47,
  "avg_installs_per_deployment": 3.13,
  "by_agent_type": {
    "server": 10,
    "workstation": 5
  },
  "by_architecture": {
    "amd64": 13,
    "arm64": 2
  }
}
```

---

## 📊 Cas d'utilisation pratiques

### Cas 1 : Déployer 10 serveurs identiques

1. **Créer un seul déploiement** avec expiration de 7 jours
2. **Copier l'URL** d'installation
3. **Utiliser l'URL sur tous les serveurs**
4. **Vérifier** que `install_count` passe à 10

### Cas 2 : Déploiement par client

1. **Créer un déploiement par client**
2. **Nommer clairement** : `client_name = "Client A - Production"`
3. **Définir une expiration longue** (90 jours)
4. **Archiver le lien** dans votre documentation client

### Cas 3 : Déploiement temporaire pour tests

1. **Créer un déploiement** avec expiration de 1 heure
2. **Tester l'installation** sur un serveur de test
3. **Le lien expire automatiquement** après 1 heure
4. **Supprimer le déploiement** si le test est OK

### Cas 4 : Déploiement avec script personnalisé

1. **Héberger votre script** sur un serveur accessible
2. **Ajouter l'URL** dans le champ `custom_script_url`
3. **Le script sera exécuté** après l'installation de l'agent

---

## 🔒 Bonnes pratiques de sécurité

### ✅ À FAIRE

- ✅ Utiliser des **expirations courtes** (7-30 jours) pour les déploiements
- ✅ **Supprimer les déploiements** une fois terminés
- ✅ Utiliser des **noms descriptifs** pour faciliter la gestion
- ✅ **Vérifier l'install_count** pour détecter des installations non autorisées
- ✅ Activer **HTTPS** (déjà fait sur rmm.selest.info)
- ✅ **Limiter les accès** à l'admin Django aux administrateurs de confiance

### ❌ À ÉVITER

- ❌ Ne pas créer de déploiements **sans expiration**
- ❌ Ne pas **partager publiquement** les URLs de déploiement
- ❌ Ne pas utiliser le **même déploiement** pour tous les clients
- ❌ Ne pas laisser des **déploiements expirés** dans la base
- ❌ Ne pas utiliser des **mots de passe faibles** pour le superuser

---

## 🛠️ Dépannage

### Problème : Impossible d'accéder à /admin/

**Solution :**
```bash
# Vérifier que ADMIN_ENABLED est bien à True
grep ADMIN_ENABLED /rmm/api/tacticalrmm/tacticalrmm/local_settings.py

# Vérifier que le service est actif
sudo systemctl status rmm.service

# Redémarrer le service
sudo systemctl restart rmm.service
```

### Problème : "Invalid password" lors de la connexion

**Solution :**
```bash
# Réinitialiser le mot de passe du superuser
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py changepassword admin
```

### Problème : "Linux Deployments" n'apparaît pas dans l'admin

**Solution :**
```bash
# Vérifier que l'app est installée
grep -A 50 'INSTALLED_APPS' /rmm/api/tacticalrmm/tacticalrmm/settings.py | grep linux_deployments

# Relancer l'installation si nécessaire
cd ~/tactical-rmm
sudo ./install-interactive.sh
```

---

## 📚 Ressources complémentaires

- **Installation complète :** [INSTALLATION_RMM_SELEST_INFO.md](INSTALLATION_RMM_SELEST_INFO.md)
- **Installation rapide :** [QUICK_INSTALL.md](QUICK_INSTALL.md)
- **Architecture :** [DASHBOARD_INTEGRATION_README.md](DASHBOARD_INTEGRATION_README.md)
- **API REST :** [integration/README.md](integration/README.md)

---

## ✨ Félicitations !

Vous maîtrisez maintenant l'interface d'administration Django pour gérer vos déploiements d'agents Linux !

**Bon déploiement ! 🚀**

---

**Auteur:** fred-selest
**Version:** 1.0.0
**Date:** Mars 2026
