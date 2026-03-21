"""
Vues d'export pour les déploiements Linux.
Endpoints pour télécharger les données en CSV ou JSON.
"""
from __future__ import annotations

from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from .export import export_deployments_csv, export_deployments_json
from .models import LinuxDeployment


class ExportDeploymentsCSVView(APIView):
    """
    Exporte les déploiements en CSV
    GET /api/v3/linux-deployments/export/csv/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request) -> export_deployments_csv:
        queryset = LinuxDeployment.objects.all()

        # Filtres optionnels
        client_id = request.query_params.get('client_id')
        if client_id:
            queryset = queryset.filter(client_id=client_id)

        status_filter = request.query_params.get('status')
        if status_filter == 'active':
            from django.utils import timezone
            queryset = queryset.filter(expires_at__gt=timezone.now())
        elif status_filter == 'expired':
            from django.utils import timezone
            queryset = queryset.filter(expires_at__lte=timezone.now())

        return export_deployments_csv(queryset)


class ExportDeploymentsJSONView(APIView):
    """
    Exporte les déploiements en JSON
    GET /api/v3/linux-deployments/export/json/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request) -> export_deployments_json:
        queryset = LinuxDeployment.objects.all()

        # Filtres optionnels
        client_id = request.query_params.get('client_id')
        if client_id:
            queryset = queryset.filter(client_id=client_id)

        status_filter = request.query_params.get('status')
        if status_filter == 'active':
            from django.utils import timezone
            queryset = queryset.filter(expires_at__gt=timezone.now())
        elif status_filter == 'expired':
            from django.utils import timezone
            queryset = queryset.filter(expires_at__lte=timezone.now())

        return export_deployments_json(queryset)
