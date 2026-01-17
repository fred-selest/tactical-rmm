"""
URLs Django pour l'intégration de déploiement Linux
À intégrer dans: api/tacticalrmm/urls.py
"""
from django.urls import path
from .views import (
    LinuxDeploymentCreateView,
    LinuxDeploymentListView,
    LinuxDeploymentDetailView,
    LinuxDeploymentScriptView,
    LinuxDeploymentInstallCallbackView,
    LinuxDeploymentStatsView,
)

# URLs pour l'API v3
api_v3_urlpatterns = [
    # Gestion des déploiements (authentifié)
    path('api/v3/linux-deployments/', LinuxDeploymentListView.as_view(), name='linux-deployment-list'),
    path('api/v3/linux-deployments/create/', LinuxDeploymentCreateView.as_view(), name='linux-deployment-create'),
    path('api/v3/linux-deployments/stats/', LinuxDeploymentStatsView.as_view(), name='linux-deployment-stats'),
    path('api/v3/linux-deployments/<uuid:deployment_uuid>/', LinuxDeploymentDetailView.as_view(), name='linux-deployment-detail'),

    # Callback d'installation (non authentifié)
    path('api/v3/linux-deployments/<uuid:deployment_uuid>/installed/', LinuxDeploymentInstallCallbackView.as_view(), name='linux-deployment-callback'),
]

# URLs publiques pour le déploiement (non authentifiées)
public_urlpatterns = [
    # URL de téléchargement du script (publique, avec UUID)
    path('clients/<uuid:deployment_uuid>/deploy/linux/', LinuxDeploymentScriptView.as_view(), name='linux-deployment-script'),
]

# Combiner toutes les URLs
urlpatterns = api_v3_urlpatterns + public_urlpatterns
