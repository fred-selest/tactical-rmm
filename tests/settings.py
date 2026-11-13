"""
Settings Django minimaux pour tester l'intégration hors de Tactical RMM.

Base SQLite en mémoire par défaut ; définir DATABASE_URL
(postgres://user:pass@host:port/db) pour tester sur PostgreSQL.
"""
import os
from urllib.parse import unquote, urlparse

SECRET_KEY = 'tests-only-not-secret'
DEBUG = False
USE_TZ = True
TIME_ZONE = 'UTC'
ALLOWED_HOSTS = ['testserver']

INSTALLED_APPS = [
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'rest_framework',
    'tests.apps.LinuxDeploymentsTestConfig',
]


def _database_from_url(url: str) -> dict:
    parsed = urlparse(url)
    if parsed.scheme not in ('postgres', 'postgresql'):
        raise ValueError(f"DATABASE_URL non supportée : {parsed.scheme}")
    return {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': parsed.path.lstrip('/'),
        'USER': unquote(parsed.username or ''),
        'PASSWORD': unquote(parsed.password or ''),
        'HOST': parsed.hostname or 'localhost',
        'PORT': str(parsed.port or 5432),
    }


if os.environ.get('DATABASE_URL'):
    DATABASES = {'default': _database_from_url(os.environ['DATABASE_URL'])}
else:
    DATABASES = {'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': ':memory:'}}
ROOT_URLCONF = 'integration.backend.urls'
CACHES = {'default': {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'}}

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': ['rest_framework.authentication.SessionAuthentication'],
}

LINUX_DEPLOYMENT_API_URL = 'https://api.example.test'
LINUX_DEPLOYMENT_MESH_URL = 'https://mesh.example.test/meshagents?id=abc'
LINUX_DEPLOYMENT_TRUSTED_PROXY_COUNT = 0
