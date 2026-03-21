# Integration Package - Linux Deployments

Package d'integration Django pour les deploiements d'agents Linux avec securite avancee (HMAC-SHA256, one-time tokens).

## Structure

```
integration/
├── backend/
│   ├── models.py          # Modele LinuxDeployment + DeploymentLog
│   ├── views.py           # API views (CRUD + script download + callback)
│   ├── views_export.py    # Export CSV/JSON
│   ├── serializers.py     # Serializers DRF avec validation
│   ├── urls.py            # Routes API v3
│   ├── admin.py           # Interface admin Django
│   ├── throttling.py      # Rate limiting endpoints publics
│   ├── notifications.py   # Notifications Slack/Discord/Teams/Webhook
│   ├── export.py          # Export CSV et JSON
│   ├── apps.py            # Configuration Django app
│   ├── management/commands/
│   │   └── cleanup_expired_deployments.py
│   ├── migrations/
│   │   ├── 0001_initial.py
│   │   └── 0002_add_signing_tokens.py
│   └── tests: test_signing_tokens.py, test_api_integration.py,
│              test_export.py, test_notifications.py
│
└── frontend/
    ├── LinuxDeploymentManager.vue   # Modal creation deploiement
    ├── LinuxDeploymentList.vue      # Liste avec filtres et stats
    └── __tests__/                   # Tests Vitest
```

## Installation

```bash
# Methode automatisee (recommandee)
sudo ./deploy-signing-tokens.sh

# Methode manuelle
cp -r integration/backend/* /rmm/api/tacticalrmm/linux_deployments/
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py migrate linux_deployments
sudo systemctl restart rmm.service
```

## Documentation

- [SIGNING_TOKENS_README.md](../SIGNING_TOKENS_README.md) - Documentation technique securite
- [INSTALLATION_GUIDE.md](../INSTALLATION_GUIDE.md) - Guide d'installation complet
- [TEST_GUIDE.md](../TEST_GUIDE.md) - Guide de verification

## Prerequis

- Django >= 3.2, DRF >= 3.12, PostgreSQL >= 12, Python >= 3.8
- Frontend : Vue.js 3+, Quasar 2+
