# Migrations Django pour Linux Deployments

## 📦 Fichiers de migration

- **`0002_add_signing_tokens.py`** : Ajoute les champs de sécurité (signing_token, one_time_token, etc.)

## 🚀 Comment appliquer les migrations

### Sur votre serveur Tactical RMM :

```bash
# 1. Copier les fichiers de migration
sudo cp -r integration/backend/migrations /rmm/api/tacticalrmm/linux_deployments/

# 2. Appliquer les migrations
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py migrate linux_deployments

# 3. Vérifier que la migration est appliquée
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py showmigrations linux_deployments

# 4. Redémarrer le service
sudo systemctl restart rmm.service
```

## 🔍 Que fait la migration `0002_add_signing_tokens` ?

Cette migration ajoute les champs suivants au modèle `LinuxDeployment` :

1. **`signing_token`** (CharField, 64 chars, unique)
   - Token HMAC pour signer les URLs de déploiement
   - Génère automatiquement un token unique pour chaque déploiement

2. **`one_time_token`** (CharField, 64 chars, unique)
   - Token unique qui expire après la première installation
   - Empêche les réutilisations non autorisées

3. **`signature_secret`** (CharField, 128 chars)
   - Secret cryptographique pour générer et valider les signatures HMAC
   - Unique par déploiement

4. **`token_used`** (BooleanField, default=False)
   - Indique si le one-time token a été utilisé
   - Permet de bloquer les installations multiples

5. **`token_used_at`** (DateTimeField, nullable)
   - Timestamp de l'utilisation du token
   - Utile pour l'audit et le débogage

## ⚙️ Fonctionnement

La migration :

1. Ajoute les nouveaux champs (sans contrainte unique temporairement)
2. Génère automatiquement des tokens pour tous les déploiements existants
3. Applique ensuite la contrainte `unique=True` sur `signing_token` et `one_time_token`

Cela évite les erreurs de contrainte unique lors de la migration de déploiements existants.

## 🔐 Sécurité

Les tokens générés utilisent :
- `secrets.token_urlsafe()` : Génération cryptographiquement sécurisée
- Taille suffisante (48-96 bytes) pour éviter les collisions
- Unique par déploiement

## 📝 Notes importantes

- ⚠️ **Sauvegardez votre base de données avant d'appliquer cette migration**
- ✅ Cette migration est **réversible** (avec `migrate linux_deployments 0001`)
- 🔄 Les déploiements existants recevront automatiquement des tokens
- 📊 Pas de perte de données

## 🆘 En cas de problème

### Erreur : "no such table: linux_deployments_linuxdeployment"

```bash
# Créer d'abord la table initiale
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py migrate linux_deployments 0001_initial
```

### Erreur : "duplicate key value violates unique constraint"

Cela ne devrait pas arriver grâce à la génération automatique des tokens, mais si c'est le cas :

```bash
# Rollback
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py migrate linux_deployments 0001

# Vérifier les doublons manuellement
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell
```

```python
from linux_deployments.models import LinuxDeployment
import secrets

# Vérifier les doublons
for d in LinuxDeployment.objects.all():
    if not d.signing_token:
        d.signing_token = secrets.token_urlsafe(48)
        d.one_time_token = secrets.token_urlsafe(48)
        d.signature_secret = secrets.token_urlsafe(96)
        d.save()
```

### Vérifier l'état des migrations

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py showmigrations linux_deployments
```

Résultat attendu :
```
linux_deployments
 [X] 0001_initial
 [X] 0002_add_signing_tokens
```

## 📖 Plus d'informations

Consultez la documentation Django sur les migrations :
- https://docs.djangoproject.com/en/stable/topics/migrations/
- https://docs.djangoproject.com/en/stable/ref/migration-operations/
