"""
Module d'export des données de déploiement en CSV et JSON.

Usage dans les vues:
    from .export import export_deployments_csv, export_deployments_json
"""
from __future__ import annotations

import csv
import io
import json
from datetime import datetime
from typing import Any

from django.http import HttpResponse, JsonResponse

from .models import LinuxDeployment


def export_deployments_csv(queryset: Any | None = None) -> HttpResponse:
    """
    Exporte les déploiements en CSV.

    Args:
        queryset: QuerySet de déploiements (optionnel, tous par défaut)

    Returns:
        HttpResponse avec le fichier CSV
    """
    if queryset is None:
        queryset = LinuxDeployment.objects.all()

    output = io.StringIO()
    writer = csv.writer(output, delimiter=';', quoting=csv.QUOTE_MINIMAL)

    # En-têtes
    writer.writerow([
        'UUID',
        'Client',
        'Site',
        'Type Agent',
        'Architecture',
        'Statut',
        'Téléchargements',
        'Installations',
        'Créé le',
        'Expire le',
        'Créé par',
    ])

    # Données
    for deployment in queryset:
        writer.writerow([
            str(deployment.uuid),
            deployment.client_name,
            deployment.site_name,
            deployment.agent_type,
            deployment.arch,
            'Expiré' if deployment.is_expired() else 'Actif',
            deployment.download_count,
            deployment.agents_installed,
            deployment.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            deployment.expires_at.strftime('%Y-%m-%d %H:%M:%S'),
            deployment.created_by,
        ])

    response = HttpResponse(output.getvalue(), content_type='text/csv; charset=utf-8')
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    response['Content-Disposition'] = f'attachment; filename="deployments_{timestamp}.csv"'
    return response


def export_deployments_json(queryset: Any | None = None) -> JsonResponse:
    """
    Exporte les déploiements en JSON.

    Args:
        queryset: QuerySet de déploiements (optionnel, tous par défaut)

    Returns:
        JsonResponse avec les données JSON
    """
    if queryset is None:
        queryset = LinuxDeployment.objects.all()

    deployments_data = []
    for deployment in queryset:
        deployments_data.append({
            'uuid': str(deployment.uuid),
            'client_id': deployment.client_id,
            'client_name': deployment.client_name,
            'site_id': deployment.site_id,
            'site_name': deployment.site_name,
            'agent_type': deployment.agent_type,
            'arch': deployment.arch,
            'status': 'expired' if deployment.is_expired() else 'active',
            'download_count': deployment.download_count,
            'agents_installed': deployment.agents_installed,
            'created_at': deployment.created_at.isoformat(),
            'expires_at': deployment.expires_at.isoformat(),
            'created_by': deployment.created_by,
            'enable_ping': deployment.enable_ping,
            'enable_rdp': deployment.enable_rdp,
            'install_mesh': deployment.install_mesh,
        })

    export_data = {
        'export_date': datetime.now().isoformat(),
        'total_count': len(deployments_data),
        'deployments': deployments_data,
    }

    response = JsonResponse(export_data, json_dumps_params={'indent': 2, 'ensure_ascii': False})
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    response['Content-Disposition'] = f'attachment; filename="deployments_{timestamp}.json"'
    return response
