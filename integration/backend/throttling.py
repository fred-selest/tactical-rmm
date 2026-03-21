"""
Throttling pour les endpoints publics de déploiement Linux
"""
from __future__ import annotations

from rest_framework.throttling import AnonRateThrottle


class DeploymentDownloadThrottle(AnonRateThrottle):
    """Limite les téléchargements de scripts à 10/minute par IP"""
    rate = '10/minute'
    scope = 'deployment_download'


class InstallCallbackThrottle(AnonRateThrottle):
    """Limite les callbacks d'installation à 5/minute par IP"""
    rate = '5/minute'
    scope = 'install_callback'
