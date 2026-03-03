# 🚀 Guide de Démarrage Rapide - Signing Tokens

> **Déployez le système de sécurité en 5 minutes !**

---

## ⚡ Installation Ultra-Rapide

### Étape 1 : Déployer le système (2 minutes)

```bash
# Sur votre serveur rmm.selest.info
cd ~/tactical-rmm
sudo ./deploy-signing-tokens.sh
```

**Ce script va automatiquement :**
- ✅ Vérifier les prérequis
- ✅ Sauvegarder la base de données (optionnel)
- ✅ Copier les fichiers backend
- ✅ Appliquer les migrations Django
- ✅ Redémarrer les services
- ✅ Tester l'installation

### Étape 2 : Tester l'installation (1 minute)

```bash
sudo ./test-signing-tokens-live.sh
```

**Résultat attendu :**
```
✓ TOUS LES TESTS SONT PASSÉS !
```

### Étape 3 : Créer votre premier déploiement sécurisé (2 minutes)

#### **Option A : Via l'admin Django** (recommandé)

1. Ouvrez : **https://api.selest.info/admin/**
2. Allez dans **Linux Deployments** → **Add Linux Deployment**
3. Remplissez :
   - Client ID: `1`
   - Client Name: `Mon Client`
   - Site ID: `1`
   - Site Name: `Production`
   - Agent Type: `server`
   - Architecture: `amd64`
4. Cliquez **Save**

**Les 3 tokens sont générés automatiquement !** 🎉

#### **Option B : Via Django Shell**

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell
```

```python
from linux_deployments.models import LinuxDeployment
from django.utils import timezone
from datetime import timedelta

# Créer un déploiement
deployment = LinuxDeployment.objects.create(
    client_id=1,
    client_name="Mon Client",
    site_id=1,
    site_name="Production",
    agent_type="server",
    arch="amd64",
    api_url="https://api.selest.info",
    mesh_url="https://mesh.selest.info",
    auth_key="auto-generated",
    signing_token=LinuxDeployment.generate_signing_token(),
    one_time_token=LinuxDeployment.generate_one_time_token(),
    signature_secret=LinuxDeployment.generate_signature_secret(),
    expires_at=timezone.now() + timedelta(days=30),
    created_by="admin"
)

# Obtenir l'URL signée
signed_url = deployment.get_signed_url()
print(f"URL signée: {signed_url}")

# Afficher les infos
print(f"\nDéploiement créé:")
print(f"  UUID: {deployment.uuid}")
print(f"  Signing Token: {deployment.signing_token[:30]}...")
print(f"  One-Time Token: {deployment.one_time_token[:30]}...")
print(f"  Token utilisé: {deployment.token_used}")
```

---

## 🔐 Utilisation des Déploiements Sécurisés

### Obtenir l'URL signée

**Via Django Shell :**

```python
from linux_deployments.models import LinuxDeployment

deployment = LinuxDeployment.objects.get(uuid='VOTRE-UUID')
signed_url = deployment.get_signed_url()
print(signed_url)
```

**Exemple d'URL générée :**
```
https://api.selest.info/clients/a1b2c3d4-e5f6-7890.../deploy/linux/?t=1709414500&sig=8f3a2b1...
```

### Installer sur un serveur Linux

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
- ✅ One-time token envoyé
- ✅ Marquage automatique après installation

### Vérifier l'état du déploiement

```python
from linux_deployments.models import LinuxDeployment

deployment = LinuxDeployment.objects.get(uuid='VOTRE-UUID')

print(f"Token utilisé: {deployment.token_used}")
print(f"Utilisé le: {deployment.token_used_at}")
print(f"Agents installés: {deployment.agents_installed}")
print(f"Token valide: {deployment.is_token_valid()}")
```

---

## 📊 Monitoring

### Voir tous les déploiements

```python
from linux_deployments.models import LinuxDeployment

# Tous les déploiements
for d in LinuxDeployment.objects.all():
    print(f"{d.uuid} - {d.client_name} - Utilisé: {d.token_used}")

# Déploiements avec tokens utilisés
used = LinuxDeployment.objects.filter(token_used=True)
print(f"\nTokens utilisés: {used.count()}")

# Déploiements actifs (non utilisés, non expirés)
from django.utils import timezone
active = LinuxDeployment.objects.filter(
    token_used=False,
    expires_at__gt=timezone.now()
)
print(f"Déploiements actifs: {active.count()}")
```

### Voir les logs de sécurité

```python
from linux_deployments.models import DeploymentLog

# Tentatives de signature invalide (dernières 24h)
from django.utils import timezone
from datetime import timedelta

invalid_sigs = DeploymentLog.objects.filter(
    action='invalid_signature',
    timestamp__gte=timezone.now() - timedelta(days=1)
)

for log in invalid_sigs:
    print(f"{log.timestamp} - {log.ip_address} - {log.error_message}")

# Tentatives avec token déjà utilisé
used_tokens = DeploymentLog.objects.filter(action='token_already_used')
print(f"\nTentatives avec token déjà utilisé: {used_tokens.count()}")
```

---

## 🛡️ Sécurité

### Triple Couche de Protection

| Couche | Protection | Validé où ? |
|--------|-----------|-------------|
| **1. Signature HMAC** | URLs non falsifiables | `LinuxDeploymentScriptView.get()` |
| **2. Timestamp** | URLs expirant en 1h | `LinuxDeploymentScriptView.get()` |
| **3. One-Time Token** | Installation unique | `LinuxDeploymentInstallCallbackView.post()` |

### Que se passe-t-il lors de l'installation ?

```
1. wget URL_SIGNÉE
   → Validation signature HMAC ✓
   → Validation timestamp < 1h ✓
   → Vérification expiration ✓
   → Script téléchargé

2. sudo ./install.sh
   → Installation de l'agent
   → Callback au serveur avec one_time_token

3. Callback POST /installed/
   → Validation one_time_token ✓
   → Vérification token non utilisé ✓
   → Marquage token_used = True
   → Incrément agents_installed

4. Tentatives suivantes
   → token_used = True
   → ❌ BLOQUÉ
```

---

## 🔧 Dépannage

### Problème : "Signature invalide"

**Solution :**
```python
# Générer une nouvelle URL signée
deployment = LinuxDeployment.objects.get(uuid='...')
new_url = deployment.get_signed_url()
print(new_url)
```

### Problème : "Token déjà utilisé"

**Solution 1 : Créer un nouveau déploiement** (recommandé)

**Solution 2 : Réinitialiser le token** (pour tests uniquement)
```python
deployment = LinuxDeployment.objects.get(uuid='...')
deployment.token_used = False
deployment.token_used_at = None
deployment.save()
```

### Problème : "Lien expiré (timestamp trop ancien)"

**Cause :** URL générée il y a plus d'1 heure

**Solution :** Générer une nouvelle URL signée

---

## 📝 Commandes Utiles

### Shell Django

```bash
# Accéder au shell
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell
```

### Voir les logs

```bash
# Logs du service RMM
sudo journalctl -u rmm.service -f

# Logs récents (100 lignes)
sudo journalctl -u rmm.service -n 100
```

### Redémarrer le service

```bash
sudo systemctl restart rmm.service
sudo systemctl status rmm.service
```

---

## 📚 Documentation Complète

| Document | Description |
|----------|-------------|
| **SIGNING_TOKENS_README.md** | Documentation technique complète |
| **GUIDE_UTILISATION_ADMIN_PRIVATE.md** | Guide utilisateur avec vos domaines |
| **integration/backend/migrations/README.md** | Guide des migrations |

---

## ✨ Exemple Complet

```python
from linux_deployments.models import LinuxDeployment
from django.utils import timezone
from datetime import timedelta

# 1. Créer un déploiement
deployment = LinuxDeployment.objects.create(
    client_id=1,
    client_name="Acme Corp",
    site_id=1,
    site_name="Serveurs Production",
    agent_type="server",
    arch="amd64",
    api_url="https://api.selest.info",
    mesh_url="https://mesh.selest.info",
    auth_key="generated_key",
    signing_token=LinuxDeployment.generate_signing_token(),
    one_time_token=LinuxDeployment.generate_one_time_token(),
    signature_secret=LinuxDeployment.generate_signature_secret(),
    expires_at=timezone.now() + timedelta(days=30),
    created_by="admin"
)

print(f"✓ Déploiement créé: {deployment.uuid}")

# 2. Générer l'URL signée
signed_url = deployment.get_signed_url()
print(f"✓ URL signée: {signed_url}")

# 3. Afficher les informations
print(f"\nInformations:")
print(f"  Client: {deployment.client_name}")
print(f"  Site: {deployment.site_name}")
print(f"  Expire le: {deployment.expires_at}")
print(f"  Token utilisé: {deployment.token_used}")
print(f"  Token valide: {deployment.is_token_valid()}")

# 4. Commande d'installation à exécuter sur le serveur cible
print(f"\n🚀 Commande d'installation:")
print(f'wget "{signed_url}" -O install.sh')
print(f'chmod +x install.sh')
print(f'sudo ./install.sh')
```

---

## 🎉 C'est Terminé !

Votre système de déploiement Linux est maintenant **sécurisé avec une triple couche de protection** !

**Besoin d'aide ?**
- 📖 Consultez `SIGNING_TOKENS_README.md`
- 🐛 Créez une issue sur GitHub
- 💬 Contactez le support

---

**Version :** 1.0.0
**Date :** Mars 2026
**Auteur :** fred-selest
