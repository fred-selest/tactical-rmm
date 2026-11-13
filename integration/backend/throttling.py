"""
Throttling pour les endpoints publics de déploiement Linux
"""
from __future__ import annotations

from rest_framework.throttling import AnonRateThrottle

from .security import get_client_ip


class _TrustedIPThrottle(AnonRateThrottle):
    """
    Identifie le client par son IP fiable.

    Le ``get_ident`` par défaut de DRF utilise l'en-tête X-Forwarded-For brut
    lorsque ``NUM_PROXIES`` n'est pas défini : un attaquant pourrait alors
    contourner la limite en changeant cet en-tête à chaque requête.
    """

    def get_ident(self, request):  # type: ignore[override]
        return get_client_ip(request) or 'unknown'


class DeploymentDownloadThrottle(_TrustedIPThrottle):
    """Limite les téléchargements de scripts à 10/minute par IP"""
    rate = '10/minute'
    scope = 'deployment_download'


class InstallCallbackThrottle(_TrustedIPThrottle):
    """Limite les callbacks d'installation à 5/minute par IP"""
    rate = '5/minute'
    scope = 'install_callback'
