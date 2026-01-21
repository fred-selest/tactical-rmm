# Installation Rapide - Dashboard Linux pour Tactical RMM

Guide d'installation en **5 minutes** pour intégrer l'installation d'agents Linux dans votre dashboard Tactical RMM.

## 🚀 Installation Ultra-Rapide

```bash
# 1. Cloner le repository
cd ~
git clone https://github.com/fred-selest/tactical-rmm.git
cd tactical-rmm

# 2. Rendre le script exécutable
chmod +x install-backend.sh

# 3. Lancer l'installation
sudo ./install-backend.sh
```

**C'est tout ! 🎉**

Le script installe automatiquement :
- ✅ Les modèles Django
- ✅ Les endpoints API REST
- ✅ Les migrations de base de données
- ✅ Les URLs
- ✅ Redémarre les services

## 📋 Prérequis

- Tactical RMM déjà installé et fonctionnel
- Accès root au serveur
- Git installé

## ✅ Vérification

Après l'installation, testez :

```bash
# Trouver votre domaine API
grep "server_name" /etc/nginx/sites-enabled/rmm.conf | grep api

# Tester l'API (doit retourner 401 Unauthorized)
curl -I https://api.votre-domaine.com/api/v3/linux-deployments/
```

Si vous obtenez **401 Unauthorized**, l'API fonctionne parfaitement ! ✅

## 🎯 Utilisation Rapide

### Option 1 : Via Django Shell

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell
```

```python
from linux_deployments.models import LinuxDeployment
from datetime import timedelta
from django.utils import timezone

# Créer un déploiement
deployment = LinuxDeployment.objects.create(
    client_id=1,
    client_name="Mon Client",
    site_id=1,
    site_name="Production",
    agent_type="server",
    arch="amd64",
    api_url="https://api.votre-domaine.com",
    mesh_url="https://mesh.votre-domaine.com/meshagents?id=...",
    auth_key="votre-auth-key",
    enable_ping=True,
    install_mesh=True,
    expires_at=timezone.now() + timedelta(days=30),
    created_by="admin"
)

print(f"UUID: {deployment.uuid}")
print(f"URL: https://api.votre-domaine.com/clients/{deployment.uuid}/deploy/linux/")
```

### Option 2 : Activer l'Admin Django (Recommandé)

```bash
# 1. Éditer local_settings.py
sudo nano /rmm/api/tacticalrmm/tacticalrmm/local_settings.py
```

Ajoutez :
```python
ADMIN_ENABLED = True
```

```bash
# 2. Créer un superuser (si nécessaire)
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py createsuperuser

# 3. Redémarrer
sudo systemctl restart rmm.service

# 4. Accéder à l'admin
# Ouvrir : https://api.votre-domaine.com/admin/
```

Dans l'admin, allez dans **Linux Deployments** pour créer et gérer vos déploiements visuellement.

### Option 3 : Via API REST

```bash
# Obtenir un token depuis le dashboard : Settings → API Keys

# Créer un déploiement
curl -X POST https://api.votre-domaine.com/api/v3/linux-deployments/create/ \
  -H "Authorization: Token VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": 1,
    "client_name": "Mon Client",
    "site_id": 1,
    "site_name": "Production",
    "agent_type": "server",
    "arch": "amd64",
    "expires_days": 30
  }'
```

## 🖥️ Installation sur un serveur Linux

Une fois le déploiement créé, sur le serveur Linux cible :

```bash
wget https://api.votre-domaine.com/clients/{UUID}/deploy/linux/ -O install.sh
chmod +x install.sh
sudo ./install.sh
```

L'agent apparaîtra automatiquement dans le dashboard ! ✨

## 📊 Endpoints API Disponibles

| Endpoint | Méthode | Auth | Description |
|----------|---------|------|-------------|
| `/api/v3/linux-deployments/` | GET | ✅ | Liste des déploiements |
| `/api/v3/linux-deployments/create/` | POST | ✅ | Créer un déploiement |
| `/api/v3/linux-deployments/{uuid}/` | GET | ✅ | Détails d'un déploiement |
| `/api/v3/linux-deployments/{uuid}/` | DELETE | ✅ | Supprimer un déploiement |
| `/api/v3/linux-deployments/stats/` | GET | ✅ | Statistiques globales |
| `/clients/{uuid}/deploy/linux/` | GET | ❌ | Télécharger le script (public) |
| `/api/v3/linux-deployments/{uuid}/installed/` | POST | ❌ | Callback installation |

## 🛠️ Dépannage

### Le script d'installation retourne 404

```bash
# Vérifier que les services sont actifs
systemctl status rmm.service

# Vérifier les logs
sudo journalctl -u rmm.service -n 50
```

### L'API retourne 401

C'est **normal** ! 401 signifie que l'endpoint existe mais nécessite une authentification.

### Réinstaller

```bash
cd ~/tactical-rmm
sudo ./install-backend.sh
```

Le script est **idempotent** - vous pouvez le relancer sans problème.

## 📚 Documentation Complète

- **Guide d'intégration** : [integration/docs/INTEGRATION_GUIDE.md](integration/docs/INTEGRATION_GUIDE.md)
- **README complet** : [integration/README.md](integration/README.md)
- **Architecture** : [DASHBOARD_INTEGRATION_README.md](DASHBOARD_INTEGRATION_README.md)

## 🆘 Support

- **Issues GitHub** : https://github.com/fred-selest/tactical-rmm/issues
- **Documentation Tactical RMM** : https://docs.tacticalrmm.com
- **Discord Tactical RMM** : https://discord.gg/uptime-kuma

## 📝 Systèmes Linux Supportés

- ✅ Debian 10+, Ubuntu 18.04+
- ✅ CentOS 7+, Rocky Linux 8+, AlmaLinux 8+
- ✅ Fedora 30+
- ✅ Arch Linux
- ✅ Synology DSM 7.0+

## 🔐 Sécurité

- UUID unique et non-prédictible pour chaque déploiement
- Expiration automatique des liens
- Authentification requise pour la gestion
- Logs complets de tous les téléchargements
- HTTPS obligatoire

---

**Développé par fred-selest** | **License AGPL-3.0** | **Janvier 2026**
