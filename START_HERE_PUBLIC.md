# 🚀 DÉMARRAGE RAPIDE - Dashboard Linux pour rmm.votre-domaine.com

> **Bienvenue ! Ce guide vous aidera à installer l'interface de déploiement d'agents Linux sur votre serveur Tactical RMM.**

## 🎯 Qu'est-ce que c'est ?

Cette intégration ajoute à votre dashboard Tactical RMM (**rmm.votre-domaine.com**) la possibilité de :

- ✅ **Créer des déploiements d'agents Linux** comme vous le faites pour Windows
- ✅ **Générer des URLs d'installation uniques** par client/site
- ✅ **Suivre les installations** et voir les statistiques
- ✅ **Gérer visuellement** via l'interface d'administration Django
- ✅ **Automatiser** via une API REST complète

---

## ⚡ Installation Ultra-Rapide (5 minutes)

### Sur votre serveur rmm.votre-domaine.com :

```bash
# 1. Cloner le dépôt
cd ~
git clone https://github.com/fred-selest/tactical-rmm.git
cd tactical-rmm

# 2. Lancer l'installation interactive
sudo ./install-interactive.sh
```

**C'est tout !** 🎉

Le script installe automatiquement tout ce qui est nécessaire et redémarre les services.

---

## 📚 Documentation disponible

Voici tous les guides à votre disposition :

### 🟢 Pour commencer (vous êtes ici !)

| Fichier | Description | Durée |
|---------|-------------|-------|
| **[START_HERE.md](START_HERE.md)** | 👈 Vous êtes ici - Guide de démarrage | 2 min |

### 🔧 Installation

| Fichier | Description | Quand l'utiliser |
|---------|-------------|------------------|
| **[install-interactive.sh](install-interactive.sh)** | 🚀 Script d'installation interactif | **LANCER EN PREMIER** |
| **[INSTALLATION_RMM_SELEST_INFO.md](INSTALLATION_RMM_SELEST_INFO.md)** | 📖 Guide complet d'installation | Pour comprendre chaque étape |
| **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** | ⚡ Guide d'installation complet | Installation pas à pas |

### 🎨 Utilisation

| Fichier | Description | Quand l'utiliser |
|---------|-------------|------------------|
| **[GUIDE_UTILISATION_ADMIN.md](GUIDE_UTILISATION_ADMIN.md)** | 🎨 Guide complet Admin Django | **Créer vos déploiements** |
| **[integration/README.md](integration/README.md)** | 📖 README de l'intégration | Vue d'ensemble technique |

### 🧪 Tests et vérification

| Fichier | Description | Quand l'utiliser |
|---------|-------------|------------------|
| **[test-installation.sh](test-installation.sh)** | 🧪 Tests automatiques | Vérifier l'installation |

### 🏗️ Architecture et développement

| Fichier | Description | Pour qui |
|---------|-------------|----------|
| **[DASHBOARD_INTEGRATION_README.md](DASHBOARD_INTEGRATION_README.md)** | 🏗️ Architecture technique | Développeurs |
| **[integration/docs/](integration/docs/)** | 📚 Docs complètes | Développeurs |

---

## 🎯 Workflow recommandé

### 1️⃣ Installation (5 minutes)

```bash
# Sur votre serveur rmm.votre-domaine.com
ssh root@rmm.votre-domaine.com
cd ~
git clone https://github.com/fred-selest/tactical-rmm.git
cd tactical-rmm
sudo ./install-interactive.sh
```

### 2️⃣ Vérification (1 minute)

```bash
# Lancer les tests
./test-installation.sh
```

**Résultat attendu :** Tous les tests en vert ✅

### 3️⃣ Activation de l'interface Admin (2 minutes)

```bash
# Activer l'admin Django
sudo nano /rmm/api/tacticalrmm/tacticalrmm/local_settings.py
```

Ajoutez :
```python
ADMIN_ENABLED = True
```

```bash
# Créer un superuser
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py createsuperuser

# Redémarrer
sudo systemctl restart rmm.service
```

### 4️⃣ Créer votre premier déploiement

Ouvrez : **https://api.rmm.votre-domaine.com/admin/**

Suivez le guide : **[GUIDE_UTILISATION_ADMIN.md](GUIDE_UTILISATION_ADMIN.md)**

### 5️⃣ Installer l'agent sur un serveur Linux

```bash
# Sur le serveur Linux cible
wget https://api.rmm.votre-domaine.com/clients/{UUID}/deploy/linux/ -O install.sh
chmod +x install.sh
sudo ./install.sh
```

**L'agent apparaît dans votre dashboard !** ✨

---

## 🆘 Besoin d'aide ?

### Guide par cas d'usage

#### "Je veux installer le module"
→ Lancez `sudo ./install-interactive.sh`
→ Lisez [INSTALLATION_RMM_SELEST_INFO.md](INSTALLATION_RMM_SELEST_INFO.md)

#### "Je veux créer mon premier déploiement"
→ Lisez [GUIDE_UTILISATION_ADMIN.md](GUIDE_UTILISATION_ADMIN.md)

#### "Je veux vérifier que tout fonctionne"
→ Lancez `./test-installation.sh`

#### "Je veux automatiser via API"
→ Lisez [integration/README.md](integration/README.md) section API

#### "Je veux comprendre l'architecture"
→ Lisez [DASHBOARD_INTEGRATION_README.md](DASHBOARD_INTEGRATION_README.md)

#### "J'ai une erreur"
→ Consultez les sections Dépannage dans les guides
→ Lancez `sudo journalctl -u rmm.service -n 100`
→ Créez une issue sur GitHub

---

## 📊 Vue d'ensemble de l'architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   rmm.votre-domaine.com                           │
│                (Dashboard Tactical RMM)                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Nouvelles fonctionnalités
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              linux_deployments (Django App)                 │
│                                                             │
│  • Modèle LinuxDeployment (base de données)                │
│  • API REST (création, liste, stats)                       │
│  • Interface Admin Django (gestion visuelle)               │
│  • Génération de scripts d'installation                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Génère des URLs
                            ▼
┌─────────────────────────────────────────────────────────────┐
│     https://api.rmm.votre-domaine.com/clients/{UUID}/deploy/...  │
│                                                             │
│  Script d'installation téléchargeable depuis n'importe      │
│  quel serveur Linux                                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ wget + sudo ./install.sh
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Serveurs Linux (clients)                       │
│                                                             │
│  • Ubuntu, Debian, CentOS, Rocky, etc.                     │
│  • Agent installé automatiquement                          │
│  • Apparaît dans le dashboard                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎁 Ce qui est inclus

### Scripts d'installation

- ✅ `install-interactive.sh` - Installation guidée étape par étape
- ✅ `install-backend.sh` - Installation automatique (legacy)
- ✅ `test-installation.sh` - Suite de tests automatiques

### Fichiers backend (Django)

- ✅ `integration/backend/models.py` - Modèle de données
- ✅ `integration/backend/views.py` - API REST endpoints
- ✅ `integration/backend/serializers.py` - Sérialiseurs Django REST
- ✅ `integration/backend/urls.py` - Configuration des URLs
- ✅ `integration/backend/admin.py` - Interface d'administration

### Documentation

- ✅ `START_HERE.md` - Ce fichier (démarrage rapide)
- ✅ `INSTALLATION_RMM_SELEST_INFO.md` - Guide d'installation complet
- ✅ `GUIDE_UTILISATION_ADMIN.md` - Guide d'utilisation de l'interface admin
- ✅ `DASHBOARD_INTEGRATION_README.md` - Architecture technique

---

## ⚡ Commandes utiles

### Installation et tests

```bash
# Installer
sudo ./install-interactive.sh

# Tester
./test-installation.sh

# Voir les logs
sudo journalctl -u rmm.service -f
```

### Gestion du service

```bash
# Redémarrer
sudo systemctl restart rmm.service

# Statut
sudo systemctl status rmm.service

# Vérifier Django
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py check
```

### Gestion des déploiements (Django Shell)

```bash
# Ouvrir le shell
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell
```

```python
# Dans le shell
from linux_deployments.models import LinuxDeployment

# Lister tous les déploiements
for d in LinuxDeployment.objects.all():
    print(f"{d.uuid} - {d.client_name}/{d.site_name}")

# Compter les installations
LinuxDeployment.objects.aggregate(total=Sum('install_count'))

# Supprimer les déploiements expirés
from django.utils import timezone
LinuxDeployment.objects.filter(expires_at__lt=timezone.now()).delete()
```

### API REST (avec curl)

```bash
# Obtenir un token depuis : Settings → API Keys

# Lister les déploiements
curl -H "Authorization: Token VOTRE_TOKEN" \
  https://api.rmm.votre-domaine.com/api/v3/linux-deployments/

# Créer un déploiement
curl -X POST \
  -H "Authorization: Token VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"client_id":1,"client_name":"Test","site_id":1,"site_name":"Prod","agent_type":"server","arch":"amd64","expires_days":30}' \
  https://api.rmm.votre-domaine.com/api/v3/linux-deployments/create/

# Voir les stats
curl -H "Authorization: Token VOTRE_TOKEN" \
  https://api.rmm.votre-domaine.com/api/v3/linux-deployments/stats/
```

---

## 🔐 Sécurité

- ✅ **UUID unique** non-prédictible pour chaque déploiement
- ✅ **Expiration automatique** des liens (configurable)
- ✅ **Authentification requise** pour la gestion
- ✅ **Logs complets** de tous les téléchargements
- ✅ **HTTPS obligatoire** (déjà configuré)
- ✅ **Token API** pour automatisation sécurisée

---

## 📝 Systèmes Linux supportés

- ✅ Debian 10, 11, 12
- ✅ Ubuntu 18.04, 20.04, 22.04, 24.04
- ✅ CentOS 7, 8
- ✅ Rocky Linux 8, 9
- ✅ AlmaLinux 8, 9
- ✅ Fedora 30+
- ✅ Arch Linux
- ✅ Synology DSM 7.0+

Architectures : `amd64`, `arm64`, `x86`

---

## 🎊 Prêt à commencer ?

### Option 1 : Installation express (recommandée)

```bash
ssh root@rmm.votre-domaine.com
cd ~ && git clone https://github.com/fred-selest/tactical-rmm.git && cd tactical-rmm
sudo ./install-interactive.sh
```

### Option 2 : Installation guidée

Suivez le guide complet : **[INSTALLATION_RMM_SELEST_INFO.md](INSTALLATION_RMM_SELEST_INFO.md)**

---

## 📞 Support

- 🐛 **Issues GitHub :** https://github.com/fred-selest/tactical-rmm/issues
- 📖 **Documentation Tactical RMM :** https://docs.tacticalrmm.com
- 💬 **Discord Tactical RMM :** https://discord.gg/uptime-kuma

---

## 🌟 Fonctionnalités principales

| Fonctionnalité | Description | Statut |
|----------------|-------------|--------|
| **Création de déploiements** | Via Admin Django, Shell, ou API | ✅ |
| **Expiration automatique** | Les liens expirent après X jours | ✅ |
| **Suivi des installations** | Compteur install_count | ✅ |
| **Statistiques globales** | Dashboard des stats | ✅ |
| **Multi-architecture** | amd64, arm64, x86 | ✅ |
| **Interface d'administration** | Django Admin intégré | ✅ |
| **API REST complète** | Automatisation possible | ✅ |
| **Scripts personnalisés** | Post-installation custom | ✅ |

---

## 🚀 Après l'installation

### Vous aurez accès à :

1. **Interface d'administration Django**
   - https://api.rmm.votre-domaine.com/admin/
   - Section "Linux Deployments"

2. **API REST**
   - `GET /api/v3/linux-deployments/` - Liste
   - `POST /api/v3/linux-deployments/create/` - Créer
   - `GET /api/v3/linux-deployments/stats/` - Statistiques

3. **URLs publiques de déploiement**
   - `https://api.rmm.votre-domaine.com/clients/{UUID}/deploy/linux/`

---

## 📈 Roadmap

- [x] Installation automatique via script
- [x] Interface Admin Django
- [x] API REST complète
- [x] Support multi-architecture
- [x] Expiration automatique
- [x] Scripts personnalisés
- [ ] Interface web intégrée au dashboard (prochainement)
- [ ] Webhooks post-installation (prochainement)
- [ ] Support de scripts pré-installation (prochainement)

---

## 👏 Crédits

**Développé avec ❤️ pour la communauté Tactical RMM**

- **Auteur :** fred-selest
- **Licence :** AGPL-3.0
- **Version :** 1.0.0
- **Date :** Mars 2026

---

## ✨ Bon déploiement !

Vous êtes maintenant prêt à déployer des agents Linux aussi facilement que des agents Windows !

**Questions ? → [Créer une issue](https://github.com/fred-selest/tactical-rmm/issues)**

---

*Ce projet est basé sur [Tactical RMM](https://github.com/amidaware/tacticalrmm) - Merci à toute l'équipe Tactical RMM !*
