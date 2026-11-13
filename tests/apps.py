"""AppConfig de test : charge integration/backend sous le label 'linux_deployments'."""
from django.apps import AppConfig


class LinuxDeploymentsTestConfig(AppConfig):
    name = 'integration.backend'
    label = 'linux_deployments'
    default_auto_field = 'django.db.models.AutoField'
