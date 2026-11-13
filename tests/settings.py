"""Settings Django minimaux pour tester l'intégration hors de Tactical RMM."""
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

DATABASES = {'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': ':memory:'}}
ROOT_URLCONF = 'integration.backend.urls'
CACHES = {'default': {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'}}

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': ['rest_framework.authentication.SessionAuthentication'],
}

LINUX_DEPLOYMENT_API_URL = 'https://api.example.test'
LINUX_DEPLOYMENT_MESH_URL = 'https://mesh.example.test/meshagents?id=abc'
LINUX_DEPLOYMENT_TRUSTED_PROXY_COUNT = 0
