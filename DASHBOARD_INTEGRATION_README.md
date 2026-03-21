# Intégration de l'installation de l'agent Linux dans le Dashboard Tactical RMM

Ce document explique comment intégrer l'installation de l'agent Linux nativement dans le dashboard de Tactical RMM.

## 🎯 Objectif

Permettre aux administrateurs de déployer des agents Linux depuis le dashboard web, exactement comme pour les agents Windows.

## 📦 Contenu de cette intégration

Ce repository contient maintenant :

### 1. Code Backend (Django)

**Dossier** : `integration/backend/`

- `models.py` - Modèles pour stocker les déploiements
- `views.py` - Endpoints API REST
- `serializers.py` - Sérialiseurs pour l'API
- `urls.py` - Configuration des routes
- `admin.py` - Interface d'administration Django

### 2. Code Frontend (Vue.js)

**Dossier** : `integration/frontend/`

- `LinuxDeploymentManager.vue` - Modal de création de déploiement
- `LinuxDeploymentList.vue` - Page de gestion des déploiements

### 3. Script d'installation amélioré

**Fichier** : `rmmagent-linux.sh`

Nouveau script qui supporte :
- Installation via UUID de déploiement (mode dashboard)
- Installation manuelle (mode classique, compatible avec l'ancien script)

### 4. Documentation complète

**Dossier** : `integration/docs/`

- Guide d'intégration complet
- Documentation de l'API
- Guide utilisateur

## 🚀 Comment ça fonctionne

### Workflow complet

```
┌─────────────────────────────────────────────────────────────┐
│                     DASHBOARD WEB                           │
│  1. Admin crée un déploiement pour Client X / Site Y       │
│  2. Système génère un UUID unique                           │
│  3. Dashboard affiche la commande d'installation            │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Commande générée:
                            │ wget https://api.domain.com/clients/{uuid}/deploy/linux/ | sudo bash
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   SERVEUR LINUX CIBLE                       │
│  4. Télécharge le script pré-configuré                      │
│  5. Script récupère la config via l'API (avec UUID)         │
│  6. Installe Go, Mesh Agent, RMM Agent                      │
│  7. Démarre le service                                      │
│  8. Notifie le serveur du succès                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Agent apparaît dans
                            │ le dashboard
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                DASHBOARD - Liste des agents                 │
│  Client X > Site Y > nouveau-serveur (online)               │
└─────────────────────────────────────────────────────────────┘
```

## 🎨 Captures d'écran (concept)

### 1. Page de gestion des déploiements

```
╔════════════════════════════════════════════════════════════════╗
║  Déploiements Linux                         [Nouveau déploiem]║
║                                                                ║
║  📊 Statistiques                                               ║
║  ┌──────────────┬──────────────┬──────────────┬──────────────┐║
║  │ Total: 25    │ Actifs: 18   │ Téléch: 42   │ Install: 38  │║
║  └──────────────┴──────────────┴──────────────┴──────────────┘║
║                                                                ║
║  🔍 Recherche: [________] Statut: [Tous ▼] Type: [Tous ▼]     ║
║                                                                ║
║  Statut │ Client/Site    │ Config    │ Stats      │ Actions   ║
║  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ║
║  🟢Actif│ ACME Corp      │ server    │ DL: 2      │ [⋮]      ║
║         │ Prod Servers   │ amd64     │ Install: 2 │           ║
║  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ║
║  🔴Exp. │ TechCo         │ workst.   │ DL: 5      │ [⋮]      ║
║         │ Office         │ amd64     │ Install: 3 │           ║
╚════════════════════════════════════════════════════════════════╝
```

### 2. Modal de création

```
╔════════════════════════════════════════════════════════════════╗
║  Installation de l'agent Linux                           [X]  ║
║════════════════════════════════════════════════════════════════║
║                                                                ║
║  ① Sélection Client/Site                                      ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │ Client:  [ACME Corporation          ▼]                   │ ║
║  │ Site:    [Production Servers        ▼]                   │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                        [Suivant >]            ║
║                                                                ║
║  ② Configuration de l'agent                                   ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │ Type:         [Server              ▼]                    │ ║
║  │ Architecture: [AMD64/x86_64        ▼]                    │ ║
║  │ Expiration:   [30] jours                                 │ ║
║  │ ☑ Activer ping                                           │ ║
║  │ ☑ Installer Mesh Agent                                   │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                [< Retour] [Créer déploiement] ║
║                                                                ║
║  ③ Instructions d'installation                                ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │ ✓ Déploiement créé avec succès !                         │ ║
║  │                                                           │ ║
║  │ Commande d'installation:                                 │ ║
║  │ ┌───────────────────────────────────────────────────┐    │ ║
║  │ │ wget https://api.example.com/clients/{uuid}/...   │📋  │ ║
║  │ │ chmod +x install-rmm-agent.sh                     │    │ ║
║  │ │ sudo ./install-rmm-agent.sh                       │    │ ║
║  │ └───────────────────────────────────────────────────┘    │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                [Créer un autre] [Fermer]      ║
╚════════════════════════════════════════════════════════════════╝
```

## 📋 Prérequis

### Pour Tactical RMM

- Tactical RMM déjà installé et fonctionnel
- Accès au serveur backend (Django)
- Accès au code source frontend (Vue.js)
- PostgreSQL pour stocker les déploiements

### Pour les serveurs Linux cibles

- Un des systèmes supportés :
  - Debian 10+, Ubuntu 18.04+
  - CentOS 7+, Rocky Linux 8+, AlmaLinux 8+
  - Fedora 30+
  - Arch Linux
  - Synology DSM 7.0+
- Architecture : amd64, arm64, ou i386
- Accès root ou sudo
- Connexion Internet

## 🔧 Installation

Voir le guide complet : [integration/docs/INTEGRATION_GUIDE.md](integration/docs/INTEGRATION_GUIDE.md)

### Résumé

1. **Backend** : Copier les fichiers Django et créer les migrations
2. **Frontend** : Copier les composants Vue.js et configurer les routes
3. **Script** : Déployer `rmmagent-linux.sh` sur votre CDN/serveur
4. **Configuration** : Configurer les URLs dans Django settings

## 💡 Utilisation

### Créer un déploiement

1. Dashboard → Agents → Installation Linux
2. Cliquer "Nouveau déploiement"
3. Sélectionner Client et Site
4. Configurer (type, architecture, expiration)
5. Copier la commande générée

### Installer l'agent

Sur le serveur Linux cible :

```bash
# Copier-coller la commande fournie par le dashboard
wget https://api.votredomaine.com/clients/a1b2c3d4.../deploy/linux/ -O install.sh
chmod +x install.sh
sudo ./install.sh
```

L'agent apparaîtra automatiquement dans le dashboard.

## 🔐 Sécurité

- ✅ UUID unique et non-prédictible
- ✅ Expiration automatique des liens
- ✅ Authentification pour la création de déploiements
- ✅ Logs de tous les téléchargements et installations
- ✅ HTTPS obligatoire
- ✅ Pas de secrets dans les URLs publiques

## 📊 Statistiques et Suivi

Le dashboard affiche :
- Nombre de déploiements créés
- Déploiements actifs vs expirés
- Téléchargements du script
- Installations réussies
- Taux de succès

Logs détaillés :
- Qui a créé le déploiement
- Quand
- Combien de fois téléchargé
- Hostname des serveurs installés
- Erreurs éventuelles

## 🆚 Comparaison avec l'ancienne méthode

### Ancienne méthode (manuelle)

```bash
# Admin doit fournir 6 paramètres
./rmmagent-linux.sh install \
  "https://mesh.example.com/meshagents?id=abc123..." \
  "https://api.example.com" \
  123 \
  456 \
  "auth-key-xyz-secret" \
  "server"
```

❌ Paramètres à copier manuellement
❌ Risque d'erreur de saisie
❌ Auth key visible en clair
❌ Pas de suivi
❌ Pas d'expiration

### Nouvelle méthode (dashboard)

```bash
# Une seule ligne
wget https://api.example.com/clients/a1b2.../deploy/linux/ | sudo bash
```

✅ Une seule commande
✅ Configuration automatique
✅ Auth key sécurisée
✅ Suivi complet
✅ Expiration automatique

## 🔄 Rétrocompatibilité

Le nouveau script `rmmagent-linux.sh` est **100% rétrocompatible**.

Il supporte toujours l'ancienne méthode :

```bash
./rmmagent-linux.sh install \
  "https://mesh..." \
  "https://api..." \
  123 456 "auth" "server"
```

## 🛠️ Maintenance

### Nettoyer les déploiements expirés

```bash
# Créer un cron job quotidien
cat > /etc/cron.daily/cleanup-deployments << 'EOF'
#!/bin/bash
cd /opt/tacticalrmm/api/tacticalrmm
python manage.py shell << PYTHON
from linux_deployments.models import LinuxDeployment
from django.utils import timezone
deleted = LinuxDeployment.objects.filter(expires_at__lt=timezone.now()).delete()
print(f"Supprimé {deleted[0]} déploiements expirés")
PYTHON
EOF
chmod +x /etc/cron.daily/cleanup-deployments
```

## 📚 Documentation complète

Voir le dossier `integration/docs/` pour :

- **INTEGRATION_GUIDE.md** - Guide d'intégration pas à pas
- **API_REFERENCE.md** - Documentation de l'API (à créer)
- **USER_GUIDE.md** - Guide utilisateur (à créer)
- **ARCHITECTURE.md** - Architecture technique (à créer)

## ❓ FAQ

**Q: Est-ce compatible avec Tactical RMM v0.x ?**
R: Compatible avec les versions récentes. Testez en dev d'abord.

**Q: Peut-on personnaliser le script d'installation ?**
R: Oui, via le champ `custom_script_url` dans l'API.

**Q: Les déploiements peuvent-ils être réutilisés ?**
R: Oui, tant qu'ils ne sont pas expirés.

**Q: Comment changer la durée d'expiration par défaut ?**
R: Dans le modèle Django ou lors de la création via l'API.

**Q: L'installation fonctionne-t-elle hors ligne ?**
R: Non, une connexion Internet est nécessaire pour télécharger Go et l'agent.

## 🤝 Contribution

Ce projet est open-source. Les contributions sont bienvenues :

1. Fork le repository
2. Créer une branche feature
3. Commit les changements
4. Push et créer une PR

## 📞 Support

- **Issues** : https://github.com/fred-selest/tactical-rmm/issues
- **Discord Tactical RMM** : https://discord.gg/uptime-kuma

## 📝 Licence

AGPL-3.0 (même licence que Tactical RMM)

---

**Créé par** : fred-selest
**Date** : Janvier 2026
**Version** : 3.0
