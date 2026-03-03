# 📦 Integration Package - Signing Tokens System

> **Système de sécurité avancé pour les déploiements Linux de Tactical RMM**
> **Prêt à intégrer dans votre installation**

## 🎯 Objectif

Sécuriser les déploiements d'agents Linux avec une **triple couche de protection** :

1. **🔐 Signature HMAC-SHA256** - URLs non falsifiables
2. **⏱️ Timestamps** - URLs expirant en 1 heure
3. **🎫 One-Time Tokens** - Installation unique par déploiement

## ✨ Fonctionnalités de Sécurité

- ✅ **Signing Tokens** - HMAC-SHA256 pour URLs signées
- ✅ **One-Time Tokens** - Prévention de réutilisation
- ✅ **Signature Secrets** - Secrets serveur sécurisés
- ✅ **Validation Timestamp** - Liens expirant en 1h
- ✅ **Expiration Automatique** - Contrôle de durée de vie
- ✅ **Logs d'Audit** - Traçabilité complète
- ✅ **Protection Anti-Falsification** - Détection de modification
- ✅ **Callback Sécurisé** - Validation après installation
- ✅ **Interface Admin** - Gestion simplifiée

## 📁 Structure du Package

```
integration/
├── README.md                          # Ce fichier
│
├── backend/                           # Code backend Django
│   ├── models.py                      # Modèle LinuxDeployment avec sécurité
│   ├── views.py                       # Views pour script + callback
│   ├── serializers.py                 # Serializers API REST
│   ├── urls.py                        # Routes URL
│   ├── admin.py                       # Interface admin Django
│   └── migrations/                    # Migrations de base de données
│       ├── __init__.py
│       ├── 0001_initial.py           # Migration initiale
│       ├── 0002_add_signing_tokens.py # Ajout signing tokens
│       ├── 0003_add_deployment_log.py # Ajout logs de sécurité
│       └── README.md                  # Guide des migrations
│
└── frontend/                          # Code frontend (React)
    ├── components/
    │   └── LinuxDeploymentButton.tsx  # Bouton "Create Linux Deployment"
    └── README.md                       # Guide d'intégration frontend
```

## 🚀 Installation Rapide

### Méthode 1 : Script Automatisé ⚡ (Recommandé)

```bash
# Sur votre serveur Tactical RMM
cd ~/tactical-rmm
sudo ./deploy-signing-tokens.sh
```

**Ce script fait tout automatiquement :**
- ✅ Vérification des prérequis
- ✅ Sauvegarde de la base de données
- ✅ Copie des fichiers backend
- ✅ Application des migrations Django
- ✅ Vérification de l'installation
- ✅ Redémarrage des services
- ✅ Tests de validation

### Méthode 2 : Installation Manuelle

#### Étape 1 : Copier les fichiers backend

```bash
# Se placer à la racine de Tactical RMM
cd /rmm/api/tacticalrmm

# Créer le répertoire linux_deployments
mkdir -p linux_deployments

# Copier les fichiers depuis integration/backend/
cp ~/tactical-rmm/integration/backend/models.py linux_deployments/
cp ~/tactical-rmm/integration/backend/views.py linux_deployments/
cp ~/tactical-rmm/integration/backend/serializers.py linux_deployments/
cp ~/tactical-rmm/integration/backend/urls.py linux_deployments/
cp ~/tactical-rmm/integration/backend/admin.py linux_deployments/

# Copier les migrations
cp -r ~/tactical-rmm/integration/backend/migrations linux_deployments/

# Corriger les permissions
chown -R tactical:tactical linux_deployments/
```

#### Étape 2 : Appliquer les migrations

```bash
# En tant qu'utilisateur tactical
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py makemigrations linux_deployments
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py migrate linux_deployments
```

#### Étape 3 : Vérifier l'installation

```bash
sudo ./test-signing-tokens-live.sh
```

#### Étape 4 : Redémarrer le service

```bash
sudo systemctl restart rmm.service
```

## 📖 Documentation

### Documentation Technique
- **[SIGNING_TOKENS_README.md](../SIGNING_TOKENS_README.md)** - Documentation complète du système
- **[backend/migrations/README.md](backend/migrations/README.md)** - Guide des migrations Django

### Guides Utilisateur
- **[QUICK_START_SIGNING_TOKENS.md](../QUICK_START_SIGNING_TOKENS.md)** - Démarrage rapide (5 min)
- **[GUIDE_UTILISATION_ADMIN_PRIVATE.md](../GUIDE_UTILISATION_ADMIN_PRIVATE.md)** - Guide admin complet

### Scripts
- **[deploy-signing-tokens.sh](../deploy-signing-tokens.sh)** - Script de déploiement automatisé
- **[test-signing-tokens-live.sh](../test-signing-tokens-live.sh)** - Suite de tests complète

## 🎬 Démarrage Rapide

### 1. Installer le système (2 minutes)

```bash
cd ~/tactical-rmm
sudo ./deploy-signing-tokens.sh
```

### 2. Créer un déploiement

**Option A : Via Admin Django** (recommandé)

1. Ouvrez https://api.selest.info/admin/
2. Allez dans **Linux Deployments** → **Add Linux Deployment**
3. Remplissez les champs (Client, Site, Agent Type, etc.)
4. Cliquez **Save**

✨ **Les 3 tokens sont générés automatiquement !**

**Option B : Via Django Shell**

```python
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell

from linux_deployments.models import LinuxDeployment
from django.utils import timezone
from datetime import timedelta

deployment = LinuxDeployment.objects.create(
    client_id=1,
    client_name="Mon Client",
    site_id=1,
    site_name="Production",
    agent_type="server",
    arch="amd64",
    api_url="https://api.selest.info",
    mesh_url="https://mesh.selest.info",
    auth_key="auto_key",
    signing_token=LinuxDeployment.generate_signing_token(),
    one_time_token=LinuxDeployment.generate_one_time_token(),
    signature_secret=LinuxDeployment.generate_signature_secret(),
    expires_at=timezone.now() + timedelta(days=30),
    created_by="admin"
)

# Obtenir l'URL signée
signed_url = deployment.get_signed_url()
print(signed_url)
```

### 3. Installer sur un serveur Linux

```bash
# Sur le serveur cible
wget "URL_SIGNÉE" -O install.sh
chmod +x install.sh
sudo ./install.sh
```

**Sécurité automatique :**
- ✅ Vérification signature HMAC
- ✅ Validation timestamp (< 1h)
- ✅ Vérification expiration
- ✅ One-time token envoyé au callback
- ✅ Marquage automatique après installation

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

## 📊 Workflow de Sécurité

```
┌─────────────────────────────────────────────────────────────────┐
│  1. CRÉATION DU DÉPLOIEMENT                                     │
├─────────────────────────────────────────────────────────────────┤
│  Admin Django / Django Shell                                    │
│  → Génération automatique des 3 tokens:                         │
│     • signing_token (128 chars)                                 │
│     • one_time_token (128 chars)                                │
│     • signature_secret (256 chars)                              │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. GÉNÉRATION URL SIGNÉE                                       │
├─────────────────────────────────────────────────────────────────┤
│  deployment.get_signed_url()                                    │
│  → Timestamp actuel                                             │
│  → Data = f"{uuid}:{timestamp}"                                 │
│  → Signature = HMAC-SHA256(data, signature_secret)              │
│  → URL avec ?t=timestamp&sig=signature                          │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. TÉLÉCHARGEMENT DU SCRIPT                                    │
├─────────────────────────────────────────────────────────────────┤
│  wget URL_SIGNÉE -O install.sh                                  │
│  → LinuxDeploymentScriptView.get()                              │
│     ✓ Validation signature HMAC                                 │
│     ✓ Validation timestamp < 1h                                 │
│     ✓ Vérification expires_at                                   │
│     ✓ Log de l'événement                                        │
│  → Script retourné avec one_time_token intégré                  │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│  4. INSTALLATION                                                │
├─────────────────────────────────────────────────────────────────┤
│  sudo ./install.sh                                              │
│  → Installation Go, Mesh Agent, RMM Agent                       │
│  → Envoi callback POST /installed/ avec one_time_token          │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│  5. CALLBACK ET VALIDATION                                      │
├─────────────────────────────────────────────────────────────────┤
│  LinuxDeploymentInstallCallbackView.post()                      │
│  → Validation one_time_token                                    │
│  → Vérification token_used == False                             │
│  → Marquage token_used = True                                   │
│  → Incrément agents_installed                                   │
│  → Log de succès                                                │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│  6. TENTATIVES SUIVANTES                                        │
├─────────────────────────────────────────────────────────────────┤
│  → token_used == True                                           │
│  → ❌ BLOQUÉ (HTTP 400 "Token déjà utilisé")                    │
│  → Log de la tentative d'utilisation                            │
└─────────────────────────────────────────────────────────────────┘
```

## 🔒 Triple Couche de Sécurité

### Couche 1 : Signature HMAC-SHA256

**Protection :** URLs non falsifiables

```python
# Génération
data = f"{uuid}:{timestamp}"
signature = hmac.new(
    signature_secret.encode(),
    data.encode(),
    hashlib.sha256
).hexdigest()

# Validation dans LinuxDeploymentScriptView.get()
if not deployment.validate_signature(data, signature):
    return HTTP 403 "Signature invalide"
```

### Couche 2 : Timestamps

**Protection :** URLs expirant en 1 heure

```python
# Validation dans LinuxDeploymentScriptView.get()
timestamp_age = int(time.time()) - int(timestamp)
if timestamp_age > 3600:  # 1 heure
    return HTTP 400 "Lien expiré"
```

### Couche 3 : One-Time Tokens

**Protection :** Installation unique par déploiement

```python
# Validation dans LinuxDeploymentInstallCallbackView.post()
if deployment.token_used:
    return HTTP 400 "Token déjà utilisé"

# Marquage après succès
deployment.use_one_time_token()  # token_used = True
```

### Protection Supplémentaires

- ✅ **Expiration automatique** - Champ `expires_at`
- ✅ **Logs d'audit** - Table `DeploymentLog`
- ✅ **HTTPS obligatoire** - Configuration serveur
- ✅ **Secrets serveur** - `signature_secret` jamais exposé
- ✅ **UUID non prédictibles** - UUID4 random
- ✅ **Rate limiting** - Protection DoS (à configurer)

### Comparaison avec l'Ancien Système

| Fonctionnalité | Ancien | Nouveau |
|----------------|--------|---------|
| URLs signées | ❌ Non | ✅ HMAC-SHA256 |
| Timestamps | ❌ Non | ✅ < 1h |
| One-time tokens | ❌ Non | ✅ Oui |
| Logs d'audit | ⚠️ Limités | ✅ Complets |
| Protection replay | ❌ Non | ✅ Oui |
| URLs falsifiables | ❌ Oui | ✅ Non |

## 📈 Monitoring et Statistiques

### Via Django Admin

**URL :** https://api.selest.info/admin/linux_deployments/linuxdeployment/

**Informations disponibles :**
- Liste de tous les déploiements
- Statut (token_used, expiré, actif)
- Nombre d'agents installés
- Date d'utilisation du token
- Logs d'audit

### Via Django Shell

```python
from linux_deployments.models import LinuxDeployment, DeploymentLog
from django.utils import timezone

# Déploiements actifs (non utilisés, non expirés)
active = LinuxDeployment.objects.filter(
    token_used=False,
    expires_at__gt=timezone.now()
)
print(f"Déploiements actifs: {active.count()}")

# Tokens utilisés
used = LinuxDeployment.objects.filter(token_used=True)
print(f"Tokens utilisés: {used.count()}")

# Tentatives de signature invalide (dernières 24h)
from datetime import timedelta
invalid_sigs = DeploymentLog.objects.filter(
    action='invalid_signature',
    timestamp__gte=timezone.now() - timedelta(days=1)
)
print(f"Tentatives de signature invalide: {invalid_sigs.count()}")

# Tentatives avec token déjà utilisé
used_attempts = DeploymentLog.objects.filter(
    action='token_already_used'
)
print(f"Tentatives avec token déjà utilisé: {used_attempts.count()}")
```

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

### Version 4.0 - Signing Tokens (Mars 2026) 🔐

**Nouveautés majeures :**
- ✨ Signature HMAC-SHA256 pour URLs non falsifiables
- ✨ Timestamps avec expiration en 1 heure
- ✨ One-Time Tokens pour installation unique
- ✨ Signature Secrets côté serveur
- ✨ Logs d'audit complets (DeploymentLog)
- ✨ Scripts de déploiement automatisés
- ✨ Suite de tests complète

**Sécurité :**
- 🔒 Triple couche de protection
- 🔒 Protection anti-replay
- 🔒 Protection anti-falsification
- 🔒 Validation multi-niveaux

**Outils :**
- 🚀 deploy-signing-tokens.sh - Déploiement auto
- 🧪 test-signing-tokens-live.sh - Tests complets
- 📖 Documentation technique complète

**Migrations :**
- 0001_initial.py - Table de base
- 0002_add_signing_tokens.py - Ajout 3 tokens
- 0003_add_deployment_log.py - Table de logs

### Version 3.0
- ✨ Support UUID pour déploiement
- ✨ Interface dashboard
- ✨ API REST Django
- ✨ Notifications post-installation

### Version 2.0
- Support Synology amélioré
- Gestion automatique de Go

### Version 1.0
- Script d'installation de base

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

## 🎉 Quick Start

```bash
# 1. Déployer le système (2 min)
sudo ./deploy-signing-tokens.sh

# 2. Tester l'installation (1 min)
sudo ./test-signing-tokens-live.sh

# 3. Créer un déploiement
# → Via https://api.selest.info/admin/
# → Ou via Django shell

# 4. Installer sur un serveur Linux
wget "URL_SIGNÉE" -O install.sh && chmod +x install.sh && sudo ./install.sh
```

**Prochaine étape :** Consultez [QUICK_START_SIGNING_TOKENS.md](../QUICK_START_SIGNING_TOKENS.md) ! 🚀

---

**Version :** 4.0.0 (Signing Tokens)
**Date :** Mars 2026
**Auteur :** fred-selest
**License :** AGPL-3.0 (même que Tactical RMM)

**Note :** Cette intégration est un ajout communautaire et n'est pas officiellement supportée par l'équipe Tactical RMM. Elle a été développée pour renforcer la sécurité des déploiements Linux.
