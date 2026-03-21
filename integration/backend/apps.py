"""Configuration de l'application Django pour les déploiements Linux."""
from __future__ import annotations

from django.apps import AppConfig


class LinuxDeploymentsConfig(AppConfig):
    """Configuration de l'application linux_deployments"""
    default_auto_field = 'django.db.models.AutoField'
    name = 'linux_deployments'
    verbose_name = 'Déploiements Linux'
