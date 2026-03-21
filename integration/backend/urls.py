"""
URLs Django pour l'intégration de déploiement Linux
À intégrer dans: api/tacticalrmm/urls.py
"""
from __future__ import annotations

from django.urls import path

from .views import (
    LinuxDeploymentCreateView,
    LinuxDeploymentDetailView,
    LinuxDeploymentInstallCallbackView,
    LinuxDeploymentListView,
    LinuxDeploymentScriptView,
    LinuxDeploymentStatsView,
)
from .views_export import ExportDeploymentsCSVView, ExportDeploymentsJSONView

# URLs pour l'API v3
api_v3_urlpatterns = [
    # Gestion des déploiements (authentifié)
    path('api/v3/linux-deployments/', LinuxDeploymentListView.as_view(), name='linux-deployment-list'),
    path('api/v3/linux-deployments/create/', LinuxDeploymentCreateView.as_view(), name='linux-deployment-create'),
    path('api/v3/linux-deployments/stats/', LinuxDeploymentStatsView.as_view(), name='linux-deployment-stats'),
    path('api/v3/linux-deployments/<uuid:deployment_uuid>/', LinuxDeploymentDetailView.as_view(), name='linux-deployment-detail'),

    # Export (authentifié)
    path('api/v3/linux-deployments/export/csv/', ExportDeploymentsCSVView.as_view(), name='linux-deployment-export-csv'),
    path('api/v3/linux-deployments/export/json/', ExportDeploymentsJSONView.as_view(), name='linux-deployment-export-json'),

    # Callback d'installation (non authentifié, rate-limited)
    path('api/v3/linux-deployments/<uuid:deployment_uuid>/installed/', LinuxDeploymentInstallCallbackView.as_view(), name='linux-deployment-callback'),
]

# URLs publiques pour le déploiement (non authentifiées, rate-limited)
public_urlpatterns = [
    path('clients/<uuid:deployment_uuid>/deploy/linux/', LinuxDeploymentScriptView.as_view(), name='linux-deployment-script'),
]

# Combiner toutes les URLs
urlpatterns = api_v3_urlpatterns + public_urlpatterns
