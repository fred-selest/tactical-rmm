"""
Vues d'export pour les déploiements Linux.
Endpoints pour télécharger les données en CSV ou JSON.
"""
from __future__ import annotations

from django.http import HttpResponse
from django.utils import timezone
from rest_framework.request import Request
from rest_framework.views import APIView

from .export import export_deployments_csv, export_deployments_json
from .models import LinuxDeployment
from .security import LinuxDeploymentPermission, filter_deployments_for_user


def _filtered_queryset(request: Request):
    queryset = filter_deployments_for_user(LinuxDeployment.objects.all(), request.user)

    client_id = request.query_params.get('client_id')
    if client_id and client_id.isdigit():
        queryset = queryset.filter(client_id=client_id)

    status_filter = request.query_params.get('status')
    if status_filter == 'active':
        queryset = queryset.filter(expires_at__gt=timezone.now())
    elif status_filter == 'expired':
        queryset = queryset.filter(expires_at__lte=timezone.now())

    return queryset


class ExportDeploymentsCSVView(APIView):
    """
    Exporte les déploiements en CSV
    GET /api/v3/linux-deployments/export/csv/
    """
    permission_classes = [LinuxDeploymentPermission]

    def get(self, request: Request) -> HttpResponse:
        return export_deployments_csv(_filtered_queryset(request))


class ExportDeploymentsJSONView(APIView):
    """
    Exporte les déploiements en JSON
    GET /api/v3/linux-deployments/export/json/
    """
    permission_classes = [LinuxDeploymentPermission]

    def get(self, request: Request) -> HttpResponse:
        return export_deployments_json(_filtered_queryset(request))
