# Intégration Backend Django - Déploiement Agent Linux

Ce dossier contient les fichiers backend Django à intégrer dans le projet principal de Tactical RMM.

## Structure des fichiers

```
backend/
├── models.py          # Modèles de base de données
├── views.py           # Vues API REST
├── serializers.py     # Serializers REST Framework
├── urls.py            # Configuration des URLs
├── admin.py           # Interface d'administration Django
└── README.md          # Ce fichier
```

## Installation dans Tactical RMM

### 1. Cloner le repository principal de Tactical RMM

```bash
git clone https://github.com/amidaware/tacticalrmm.git
cd tacticalrmm
```

### 2. Intégration des modèles

Ajouter le contenu de `models.py` dans :
```
api/tacticalrmm/clients/models.py
```

Ou créer une nouvelle app Django :
```bash
cd api/tacticalrmm
python manage.py startapp linux_deployments
```

Puis copier les fichiers dans cette nouvelle app.

### 3. Intégration des vues

Copier le contenu de `views.py` dans :
```
api/tacticalrmm/clients/views.py
```

Ou dans la nouvelle app `linux_deployments/views.py`

### 4. Intégration des serializers

Copier le contenu de `serializers.py` dans :
```
api/tacticalrmm/clients/serializers.py
```

Ou dans `linux_deployments/serializers.py`

### 5. Configuration des URLs

Ajouter les URLs dans le fichier principal :
```python
# api/tacticalrmm/urls.py

from django.urls import path, include

urlpatterns = [
    # ... autres URLs existantes ...

    # Ajouter les URLs de déploiement Linux
    path('', include('tacticalrmm.clients.urls_linux')),
]
```

### 6. Configuration de Django

Ajouter l'app dans `settings.py` si vous avez créé une nouvelle app :

```python
# api/tacticalrmm/tacticalrmm/settings.py

INSTALLED_APPS = [
    # ... apps existantes ...
    'tacticalrmm.linux_deployments',
]
```

### 7. Migrations de base de données

Créer et appliquer les migrations :

```bash
cd api/tacticalrmm
python manage.py makemigrations
python manage.py migrate
```

### 8. Configuration de l'admin Django (optionnel)

Copier le contenu de `admin.py` dans votre app pour avoir une interface d'administration.

## Endpoints API disponibles

### Authentifiés (nécessitent un token API)

- `POST /api/v3/linux-deployments/create/` - Créer un nouveau déploiement
- `GET /api/v3/linux-deployments/` - Lister tous les déploiements
- `GET /api/v3/linux-deployments/{uuid}/` - Détails d'un déploiement
- `DELETE /api/v3/linux-deployments/{uuid}/` - Supprimer un déploiement
- `GET /api/v3/linux-deployments/stats/` - Statistiques globales

### Publics (pas d'authentification)

- `GET /clients/{uuid}/deploy/linux/` - Télécharger le script d'installation
- `POST /api/v3/linux-deployments/{uuid}/installed/` - Callback d'installation

## Exemples d'utilisation

### Créer un déploiement

```bash
curl -X POST https://api.votredomaine.com/api/v3/linux-deployments/create/ \
  -H "Authorization: Token YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": 123,
    "client_name": "Ma Société",
    "site_id": 456,
    "site_name": "Serveurs Production",
    "agent_type": "server",
    "arch": "amd64",
    "expires_days": 30
  }'
```

Réponse :
```json
{
  "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "deployment_url": "https://api.votredomaine.com/clients/a1b2c3d4-e5f6-7890-abcd-ef1234567890/deploy/linux/",
  "install_command": "wget https://api.votredomaine.com/clients/a1b2c3d4-.../deploy/linux/ -O install.sh\nchmod +x install.sh\nsudo ./install.sh",
  "expires_at": "2026-02-16T10:30:00Z",
  ...
}
```

### Télécharger le script d'installation

```bash
wget https://api.votredomaine.com/clients/{uuid}/deploy/linux/ -O install-rmm.sh
chmod +x install-rmm.sh
sudo ./install-rmm.sh
```

### Lister les déploiements

```bash
curl -X GET https://api.votredomaine.com/api/v3/linux-deployments/ \
  -H "Authorization: Token YOUR_API_TOKEN"
```

### Obtenir les statistiques

```bash
curl -X GET https://api.votredomaine.com/api/v3/linux-deployments/stats/ \
  -H "Authorization: Token YOUR_API_TOKEN"
```

## Sécurité

1. **Authentification** : Les endpoints de gestion nécessitent une authentification
2. **UUID unique** : Chaque déploiement a un UUID unique pour éviter les collisions
3. **Expiration** : Les liens de déploiement expirent après la durée configurée
4. **Logs** : Tous les téléchargements et installations sont loggés
5. **Clé d'authentification** : Chaque déploiement a sa propre clé d'auth

## Tests

Pour tester l'intégration :

```bash
cd api/tacticalrmm
python manage.py test linux_deployments
```

## Dépendances

- Django >= 3.2
- Django REST Framework >= 3.12
- PostgreSQL >= 12

## Support

Pour toute question ou problème, créer une issue sur GitHub.
