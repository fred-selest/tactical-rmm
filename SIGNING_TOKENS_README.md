# 🔐 Signing Tokens - Documentation Technique

## 📋 Vue d'ensemble

Cette implémentation ajoute **trois couches de sécurité** au système de déploiement Linux de Tactical RMM :

1. **Signing Token** - Signature HMAC des URLs
2. **One-Time Token** - Token unique à usage unique
3. **Signature Secret** - Secret cryptographique pour HMAC

## 🎯 Objectifs de sécurité

| Menace | Protection | Comment |
|--------|-----------|---------|
| Falsification d'URL | ✅ | Signature HMAC-SHA256 |
| Rejeu d'URL | ✅ | Timestamp avec expiration (1h) |
| Installation multiple | ✅ | One-time token |
| Attaque par force brute | ✅ | Tokens cryptographiquement sécurisés (48-96 bytes) |
| Audit | ✅ | Logs complets avec `token_used_at` |

## 🏗️ Architecture

### Nouveaux champs du modèle `LinuxDeployment`

```python
class LinuxDeployment(models.Model):
    # ... champs existants ...

    # Tokens de sécurité
    signing_token = models.CharField(max_length=64, unique=True)
    one_time_token = models.CharField(max_length=64, unique=True)
    signature_secret = models.CharField(max_length=128)
    token_used = models.BooleanField(default=False)
    token_used_at = models.DateTimeField(null=True, blank=True)
```

### Nouvelles méthodes

| Méthode | Description | Retour |
|---------|-------------|--------|
| `generate_signing_token()` | Génère un signing token | str (64 chars) |
| `generate_one_time_token()` | Génère un one-time token | str (64 chars) |
| `generate_signature_secret()` | Génère un secret HMAC | str (128 chars) |
| `generate_signature(data)` | Génère une signature HMAC | str (hex) |
| `validate_signature(data, sig)` | Valide une signature | bool |
| `get_signed_url()` | Génère une URL signée | str (URL) |
| `use_one_time_token()` | Marque le token comme utilisé | None |
| `is_token_valid()` | Vérifie si le token est valide | bool |

## 🔄 Flux de sécurité

### 1. Création d'un déploiement

```python
# Dans LinuxDeploymentCreateView.post()
deployment = LinuxDeployment.objects.create(
    # ... autres champs ...
    signing_token=LinuxDeployment.generate_signing_token(),
    one_time_token=LinuxDeployment.generate_one_time_token(),
    signature_secret=LinuxDeployment.generate_signature_secret(),
)
```

**Génère :**
- `signing_token` : Token public pour identifier le déploiement
- `one_time_token` : Token secret envoyé lors de l'installation
- `signature_secret` : Secret pour signer les URLs (jamais exposé)

### 2. Génération d'URL signée

```python
# deployment.get_signed_url()
timestamp = str(int(timezone.now().timestamp()))
data_to_sign = f"{deployment.uuid}:{timestamp}"
signature = deployment.generate_signature(data_to_sign)

url = f"{api_url}/clients/{uuid}/deploy/linux/?t={timestamp}&sig={signature}"
```

**Exemple d'URL :**
```
https://api.selest.info/clients/a1b2c3d4-e5f6-7890-abcd-ef1234567890/deploy/linux/
?t=1709414500
&sig=8f3a2b1c9d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a
```

### 3. Validation lors du téléchargement

```python
# Dans LinuxDeploymentScriptView.get()

# Vérifier la signature
timestamp = request.GET.get('t')
signature = request.GET.get('sig')
data_to_sign = f"{deployment_uuid}:{timestamp}"

if not deployment.validate_signature(data_to_sign, signature):
    return HttpResponse("Signature invalide", status=403)

# Vérifier le timestamp (max 1 heure)
ts = int(timestamp)
age = (timezone.now() - datetime.fromtimestamp(ts)).total_seconds()
if age > 3600:
    return HttpResponse("Lien expiré", status=410)
```

### 4. Installation et callback

```bash
# Dans le script d'installation généré
curl -X POST "$API_URL/api/v3/linux-deployments/$UUID/installed/" \
  -H "Content-Type: application/json" \
  -d '{"hostname": "'$HOSTNAME'", "status": "success", "one_time_token": "'$ONE_TIME_TOKEN'"}'
```

### 5. Validation du one-time token

```python
# Dans LinuxDeploymentInstallCallbackView.post()

# Vérifier que le token correspond
if one_time_token != deployment.one_time_token:
    return Response({'error': 'Token invalide'}, status=403)

# Vérifier qu'il n'a pas déjà été utilisé
if deployment.token_used:
    return Response({'error': 'Token déjà utilisé'}, status=410)

# Marquer comme utilisé
if install_status == 'success':
    deployment.use_one_time_token()
```

## 📊 Diagramme de séquence

```
┌─────────┐         ┌─────────┐         ┌──────────┐         ┌────────┐
│  Admin  │         │  Django │         │  Script  │         │ Server │
│  (Web)  │         │   API   │         │ Install  │         │ Linux  │
└────┬────┘         └────┬────┘         └────┬─────┘         └───┬────┘
     │                   │                   │                    │
     │ 1. Create Deployment                  │                    │
     ├──────────────────>│                   │                    │
     │                   │ Generate 3 tokens │                    │
     │                   │ (signing, onetime, secret)             │
     │                   │                   │                    │
     │ 2. Get Signed URL │                   │                    │
     ├──────────────────>│                   │                    │
     │<──────────────────┤                   │                    │
     │  URL + t + sig    │                   │                    │
     │                   │                   │                    │
     │ 3. wget URL       │                   │                    │
     │─────────────────────────────────────>│                    │
     │                   │                   │                    │
     │                   │ 4. Validate sig   │                    │
     │                   │<──────────────────┤                    │
     │                   │ Check timestamp   │                    │
     │                   │ Check expiration  │                    │
     │                   │                   │                    │
     │                   │ 5. Return script  │                    │
     │                   ├──────────────────>│                    │
     │                   │                   │                    │
     │                   │                   │ 6. Run script      │
     │                   │                   ├───────────────────>│
     │                   │                   │                    │
     │                   │ 7. Callback + one_time_token           │
     │                   │<───────────────────────────────────────│
     │                   │ Validate token    │                    │
     │                   │ Mark as used      │                    │
     │                   │                   │                    │
     │                   │ 8. Success        │                    │
     │                   ├────────────────────────────────────────>│
     │                   │                   │                    │
```

## 🧪 Tests

### Exécuter les tests unitaires

```bash
cd integration/backend
python test_signing_tokens.py
```

### Tests couverts

- ✅ Génération des tokens (signing, onetime, secret)
- ✅ Génération de signatures HMAC
- ✅ Validation de signatures valides
- ✅ Détection de signatures invalides
- ✅ Génération d'URLs signées
- ✅ Validation de tokens frais
- ✅ Détection de tokens utilisés
- ✅ Détection de tokens expirés
- ✅ Utilisation de one-time tokens
- ✅ Protection contre double utilisation
- ✅ Unicité des tokens

## 📦 Migration

### Appliquer la migration

```bash
# Copier les fichiers de migration
sudo cp -r integration/backend/migrations /rmm/api/tacticalrmm/linux_deployments/

# Appliquer la migration
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py migrate linux_deployments

# Redémarrer le service
sudo systemctl restart rmm.service
```

### Contenu de la migration `0002_add_signing_tokens`

1. Ajoute les 5 nouveaux champs
2. Génère automatiquement des tokens pour les déploiements existants
3. Applique les contraintes `unique=True`

**⚠️ Important :** Sauvegardez votre base de données avant d'appliquer cette migration !

## 🔒 Bonnes pratiques de sécurité

### ✅ À FAIRE

1. **Utiliser HTTPS uniquement** - Les tokens ne doivent jamais transiter en clair
2. **Configurer l'expiration** - Définir `expires_at` raisonnablement (7-30 jours)
3. **Surveiller les logs** - Vérifier régulièrement les tentatives d'accès invalides
4. **Nettoyer les déploiements expirés** - Supprimer les anciens déploiements
5. **Limiter les permissions** - Seuls les admins peuvent créer des déploiements

### ❌ À ÉVITER

1. **Ne jamais exposer `signature_secret`** - Ce secret doit rester côté serveur
2. **Ne pas réutiliser les one-time tokens** - Créer un nouveau déploiement par installation
3. **Ne pas désactiver la validation HMAC** - Critique pour la sécurité
4. **Ne pas prolonger indéfiniment `expires_at`** - Limite les fenêtres d'attaque

## 📈 Monitoring et audit

### Logs disponibles

Tous les événements sont loggés dans `DeploymentLog` :

| Action | Description |
|--------|-------------|
| `downloaded` | Script téléchargé avec succès |
| `invalid_signature` | Tentative avec signature invalide |
| `installed_success` | Installation réussie |
| `installed_failed` | Installation échouée |
| `invalid_token` | One-time token invalide |
| `token_already_used` | Tentative avec token déjà utilisé |

### Requêtes utiles

```python
from linux_deployments.models import LinuxDeployment, DeploymentLog

# Déploiements avec tokens utilisés
LinuxDeployment.objects.filter(token_used=True)

# Tentatives d'accès invalides (dernières 24h)
DeploymentLog.objects.filter(
    action='invalid_signature',
    timestamp__gte=timezone.now() - timedelta(days=1)
)

# Installations multiples suspectes
LinuxDeployment.objects.filter(agents_installed__gt=1)
```

## 🐛 Dépannage

### Problème : "Signature invalide"

**Cause possible :**
- URL modifiée manuellement
- Timestamp expiré (> 1h)
- Mauvais `signature_secret`

**Solution :**
1. Générer une nouvelle URL signée via `deployment.get_signed_url()`
2. Vérifier que l'heure du serveur est correcte

### Problème : "Token déjà utilisé"

**Cause :**
- Tentative d'installation multiple avec le même déploiement

**Solution :**
1. Créer un nouveau déploiement pour chaque serveur
2. Ou réinitialiser manuellement :
   ```python
   deployment.token_used = False
   deployment.token_used_at = None
   deployment.save()
   ```

### Problème : "Lien expiré (timestamp trop ancien)"

**Cause :**
- URL générée il y a plus de 1 heure

**Solution :**
- Générer une nouvelle URL signée

## 📚 Références

- **HMAC-SHA256** : https://en.wikipedia.org/wiki/HMAC
- **Django Migrations** : https://docs.djangoproject.com/en/stable/topics/migrations/
- **Secrets module** : https://docs.python.org/3/library/secrets.html

## 🎉 Conclusion

Cette implémentation fournit une **sécurité de niveau entreprise** pour les déploiements d'agents Linux :

- ✅ **Intégrité** : Signatures HMAC
- ✅ **Fraîcheur** : Timestamps
- ✅ **Unicité** : One-time tokens
- ✅ **Traçabilité** : Logs complets
- ✅ **Révocabilité** : Expiration individuelle

**Version :** 1.0.0
**Date :** Mars 2026
**Auteur :** fred-selest
