"""
Vues Django pour l'intégration de déploiement Linux
À intégrer dans: api/tacticalrmm/clients/views.py
"""
from __future__ import annotations

import re
import shlex
import uuid
from datetime import timedelta

from django.conf import settings
from django.db.models import Count, Q, Sum
from django.http import Http404, HttpResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import DeploymentLog, LinuxDeployment
from .notifications import notification_manager
from .security import (
    LinuxDeploymentPermission,
    filter_deployments_for_user,
    get_client_ip,
    user_can_access_client,
)
from .serializers import LinuxDeploymentCreateSerializer, LinuxDeploymentSerializer
from .throttling import DeploymentDownloadThrottle, InstallCallbackThrottle

# Compatibilité : get_client_ip était auparavant défini dans ce module
__all__ = ['get_client_ip']

INSTALL_STATUSES = ('success', 'failed')
_CONTROL_CHARS = re.compile(r'[\x00-\x1f\x7f]')


def _clean_text(value: object, max_length: int = 255) -> str:
    """Supprime les caractères de contrôle et tronque une valeur fournie par un client."""
    return _CONTROL_CHARS.sub('', str(value or ''))[:max_length]


class LinuxDeploymentCreateView(APIView):
    """
    Crée un nouveau déploiement Linux
    POST /api/v3/linux-deployments/create/
    """
    permission_classes = [LinuxDeploymentPermission]

    def post(self, request: Request) -> Response:
        """
        Crée un nouveau lien de déploiement Linux

        Body:
        {
            "client_id": 123,
            "client_name": "Nom Client",
            "site_id": 456,
            "site_name": "Nom Site",
            "agent_type": "server",  # ou "workstation"
            "arch": "amd64",  # ou "arm64", "386"
            "expires_days": 30,  # optionnel, défaut: 30 (1 à 365)
            "enable_ping": true,
            "enable_rdp": false,
            "install_mesh": true,
            "mesh_url": "https://...",  # optionnel si LINUX_DEPLOYMENT_MESH_URL est défini
            "custom_script_url": ""  # optionnel, https:// uniquement
        }
        """
        serializer = LinuxDeploymentCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'error': 'Données invalides', 'details': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )
        data = serializer.validated_data

        if not user_can_access_client(request.user, data['client_id']):
            return Response(
                {'error': "Vous n'avez pas accès à ce client"},
                status=status.HTTP_403_FORBIDDEN,
            )

        mesh_url = data.get('mesh_url') or getattr(settings, 'LINUX_DEPLOYMENT_MESH_URL', '')
        if data['install_mesh'] and not mesh_url:
            return Response(
                {'error': "mesh_url est requis (ou définir LINUX_DEPLOYMENT_MESH_URL dans les settings)"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # URL de l'API : configurée explicitement de préférence (évite de dépendre de l'en-tête Host)
        api_url = getattr(settings, 'LINUX_DEPLOYMENT_API_URL', '') or request.build_absolute_uri('/')
        api_url = api_url.rstrip('/')

        deployment = LinuxDeployment.objects.create(
            client_id=data['client_id'],
            client_name=data['client_name'],
            site_id=data['site_id'],
            site_name=data['site_name'],
            agent_type=data['agent_type'],
            arch=data['arch'],
            api_url=api_url,
            mesh_url=mesh_url,
            auth_key=uuid.uuid4().hex,
            signing_token=LinuxDeployment.generate_signing_token(),
            one_time_token=LinuxDeployment.generate_one_time_token(),
            signature_secret=LinuxDeployment.generate_signature_secret(),
            enable_ping=data['enable_ping'],
            enable_rdp=data['enable_rdp'],
            install_mesh=data['install_mesh'],
            custom_script_url=data.get('custom_script_url') or '',
            expires_at=timezone.now() + timedelta(days=data['expires_days']),
            created_by=request.user.username,
        )

        DeploymentLog.objects.create(
            deployment=deployment,
            action='created',
            ip_address=get_client_ip(request),
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
        )

        serializer = LinuxDeploymentSerializer(deployment, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class LinuxDeploymentListView(APIView):
    """
    Liste les déploiements Linux accessibles par l'utilisateur
    GET /api/v3/linux-deployments/
    """
    permission_classes = [LinuxDeploymentPermission]

    def get(self, request: Request) -> Response:
        deployments = filter_deployments_for_user(LinuxDeployment.objects.all(), request.user)

        client_id = request.query_params.get('client_id')
        if client_id:
            if not client_id.isdigit():
                return Response({'error': 'client_id invalide'}, status=status.HTTP_400_BAD_REQUEST)
            deployments = deployments.filter(client_id=client_id)

        site_id = request.query_params.get('site_id')
        if site_id:
            if not site_id.isdigit():
                return Response({'error': 'site_id invalide'}, status=status.HTTP_400_BAD_REQUEST)
            deployments = deployments.filter(site_id=site_id)

        serializer = LinuxDeploymentSerializer(deployments, many=True, context={'request': request})
        return Response(serializer.data)


class LinuxDeploymentDetailView(APIView):
    """
    Détails d'un déploiement Linux
    GET /api/v3/linux-deployments/{uuid}/
    DELETE /api/v3/linux-deployments/{uuid}/
    """
    permission_classes = [LinuxDeploymentPermission]

    def _get_deployment(self, request: Request, deployment_uuid: str) -> LinuxDeployment:
        deployment = get_object_or_404(LinuxDeployment, uuid=deployment_uuid)
        # 404 plutôt que 403 : ne pas révéler l'existence du déploiement
        if not user_can_access_client(request.user, deployment.client_id):
            raise Http404("Déploiement non trouvé")
        return deployment

    def get(self, request: Request, deployment_uuid: str) -> Response:
        deployment = self._get_deployment(request, deployment_uuid)
        serializer = LinuxDeploymentSerializer(deployment, context={'request': request})
        return Response(serializer.data)

    def delete(self, request: Request, deployment_uuid: str) -> Response:
        deployment = self._get_deployment(request, deployment_uuid)
        deployment.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class LinuxDeploymentScriptView(APIView):
    """
    Télécharge le script d'installation Linux pré-configuré
    GET /clients/{uuid}/deploy/linux/?t=<timestamp>&sig=<signature>

    URL publique (pas d'authentification) mais obligatoirement signée (HMAC) :
    connaître l'UUID ne suffit pas pour obtenir le script et la clé d'agent.
    """
    authentication_classes = []
    permission_classes = []
    throttle_classes = [DeploymentDownloadThrottle]

    def get(self, request: Request, deployment_uuid: str) -> HttpResponse:
        try:
            deployment = LinuxDeployment.objects.get(uuid=deployment_uuid)
        except LinuxDeployment.DoesNotExist:
            return HttpResponse("Déploiement non trouvé ou expiré", status=404)

        if deployment.is_expired():
            return HttpResponse("Ce lien de déploiement a expiré", status=410)

        ok, error_status, message = deployment.check_signed_request(
            request.GET.get('t'), request.GET.get('sig')
        )
        if not ok:
            DeploymentLog.objects.create(
                deployment=deployment,
                action='invalid_signature',
                ip_address=get_client_ip(request),
                user_agent=request.META.get('HTTP_USER_AGENT', ''),
                error_message=message,
            )
            return HttpResponse(message, status=error_status)

        deployment.increment_download()

        DeploymentLog.objects.create(
            deployment=deployment,
            action='downloaded',
            ip_address=get_client_ip(request),
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
        )

        script = generate_install_script(deployment)

        response = HttpResponse(script, content_type='text/x-shellscript')
        response['Content-Disposition'] = f'attachment; filename="install-rmm-agent-{deployment.uuid}.sh"'
        response['Cache-Control'] = 'no-store'
        return response


def generate_install_script(deployment: LinuxDeployment) -> str:
    """
    Génère le script d'installation avec les paramètres pré-configurés.

    Toutes les valeurs dynamiques sont échappées avec ``shlex.quote`` et
    assignées à des variables en tête de script : aucune donnée utilisateur
    n'est interprétée par le shell.
    """
    q = shlex.quote
    callback_url = f"{deployment.api_url.rstrip('/')}/api/v3/linux-deployments/{deployment.uuid}/installed/"

    def comment(value: object) -> str:
        return _clean_text(value)

    return f"""#!/bin/bash
#
# Script d'installation automatique de l'agent Tactical RMM pour Linux
# Généré automatiquement - Ne pas modifier
#
# Client: {comment(deployment.client_name)}
# Site: {comment(deployment.site_name)}
# Type: {comment(deployment.agent_type)}
# Architecture: {comment(deployment.arch)}
# Date d'expiration: {deployment.expires_at.strftime('%Y-%m-%d %H:%M:%S')}
#

set -euo pipefail

CLIENT_NAME={q(deployment.client_name)}
SITE_NAME={q(deployment.site_name)}
AGENT_TYPE={q(deployment.agent_type)}
BASE_SCRIPT_URL={q(deployment.get_script_url())}
MESH_URL={q(deployment.mesh_url or '')}
API_URL={q(deployment.api_url)}
CLIENT_ID={int(deployment.client_id)}
SITE_ID={int(deployment.site_id)}
AUTH_KEY={q(deployment.auth_key)}
CALLBACK_URL={q(callback_url)}
ONE_TIME_TOKEN={q(deployment.one_time_token)}

RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

printf '%b\\n' "${{GREEN}}========================================${{NC}}"
printf '%b\\n' "${{GREEN}}Installation de l'agent Tactical RMM${{NC}}"
printf '%b\\n' "${{GREEN}}========================================${{NC}}"
printf '\\nClient: %s\\nSite: %s\\nType: %s\\n\\n' "$CLIENT_NAME" "$SITE_NAME" "$AGENT_TYPE"

if [ "$EUID" -ne 0 ]; then
    printf '%b\\n' "${{RED}}Ce script doit être exécuté en tant que root${{NC}}"
    echo "Utilisez: sudo $0"
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
INSTALLER="$WORKDIR/rmmagent-install.sh"

notify() {{
    curl -fsS -X POST "$CALLBACK_URL" \\
        --data-urlencode "hostname=$(hostname)" \\
        --data-urlencode "status=$1" \\
        --data-urlencode "one_time_token=$ONE_TIME_TOKEN" >/dev/null || true
}}

printf '%b\\n' "${{YELLOW}}Téléchargement du script d'installation...${{NC}}"
if ! wget -q "$BASE_SCRIPT_URL" -O "$INSTALLER"; then
    printf '%b\\n' "${{RED}}Erreur: Impossible de télécharger le script d'installation${{NC}}"
    notify failed
    exit 1
fi
chmod 700 "$INSTALLER"

printf '%b\\n' "${{YELLOW}}Installation de l'agent...${{NC}}"
if "$INSTALLER" install "$MESH_URL" "$API_URL" "$CLIENT_ID" "$SITE_ID" "$AUTH_KEY" "$AGENT_TYPE"; then
    printf '%b\\n' "${{GREEN}}Installation terminée avec succès !${{NC}}"
    notify success
    echo ""
    echo "L'agent devrait apparaître dans le dashboard dans quelques instants."
    printf 'Vérifiez dans: %s > %s\\n' "$CLIENT_NAME" "$SITE_NAME"
else
    printf '%b\\n' "${{RED}}Erreur lors de l'installation${{NC}}"
    notify failed
    exit 1
fi

echo ""
printf '%b\\n' "${{GREEN}}========================================${{NC}}"
printf '%b\\n' "${{GREEN}}Installation terminée${{NC}}"
printf '%b\\n' "${{GREEN}}========================================${{NC}}"
"""


class LinuxDeploymentInstallCallbackView(APIView):
    """
    Callback appelé par le script d'installation pour notifier le résultat
    POST /api/v3/linux-deployments/{uuid}/installed/

    Le one-time token est obligatoire. Un succès consomme le token ; après
    consommation, plus aucun callback n'est accepté.
    """
    authentication_classes = []
    permission_classes = []
    throttle_classes = [InstallCallbackThrottle]

    def post(self, request: Request, deployment_uuid: str) -> Response:
        try:
            deployment = LinuxDeployment.objects.get(uuid=deployment_uuid)
        except LinuxDeployment.DoesNotExist:
            return Response({'error': 'Déploiement non trouvé'}, status=404)

        data = request.data
        hostname = _clean_text(data.get('hostname') or 'unknown')
        install_status = str(data.get('status', ''))
        error_detail = _clean_text(data.get('error', ''), max_length=2000)
        ip_address = get_client_ip(request)

        if not deployment.check_one_time_token(data.get('one_time_token')):
            DeploymentLog.objects.create(
                deployment=deployment,
                action='invalid_token',
                ip_address=ip_address,
                hostname=hostname,
                error_message="One-time token manquant ou invalide",
            )
            return Response({'error': 'Token invalide'}, status=403)

        if install_status not in INSTALL_STATUSES:
            return Response({'error': 'Statut invalide'}, status=400)

        if deployment.token_used:
            DeploymentLog.objects.create(
                deployment=deployment,
                action='token_already_used',
                ip_address=ip_address,
                hostname=hostname,
                error_message=f"Token déjà utilisé le {deployment.token_used_at}",
            )
            return Response({'error': 'Ce token a déjà été utilisé'}, status=410)

        if install_status == 'success':
            try:
                deployment.use_one_time_token()
            except ValueError as e:
                # Un autre callback concurrent a consommé le token entre-temps
                return Response({'error': str(e)}, status=410)
            deployment.increment_installed()

        DeploymentLog.objects.create(
            deployment=deployment,
            action=f'installed_{install_status}',
            ip_address=ip_address,
            hostname=hostname,
            error_message=error_detail,
        )

        if install_status == 'success':
            notification_manager.notify_installation_success(
                deployment_uuid=str(deployment.uuid),
                client_name=deployment.client_name,
                site_name=deployment.site_name,
                hostname=hostname,
                ip_address=ip_address,
            )
        else:
            notification_manager.notify_installation_failure(
                deployment_uuid=str(deployment.uuid),
                client_name=deployment.client_name,
                site_name=deployment.site_name,
                hostname=hostname,
                error=error_detail,
            )

        return Response({'status': 'logged'})


class LinuxDeploymentStatsView(APIView):
    """
    Statistiques des déploiements Linux accessibles par l'utilisateur
    GET /api/v3/linux-deployments/stats/
    """
    permission_classes = [LinuxDeploymentPermission]

    def get(self, request: Request) -> Response:
        now = timezone.now()
        qs = filter_deployments_for_user(LinuxDeployment.objects.all(), request.user)
        agg = qs.aggregate(
            total_deployments=Count('id'),
            active_deployments=Count('id', filter=Q(expires_at__gt=now)),
            expired_deployments=Count('id', filter=Q(expires_at__lte=now)),
            total_downloads=Sum('download_count'),
            total_installations=Sum('agents_installed'),
        )
        total_downloads = agg['total_downloads'] or 0
        total_installations = agg['total_installations'] or 0

        return Response({
            'total_deployments': agg['total_deployments'],
            'active_deployments': agg['active_deployments'],
            'expired_deployments': agg['expired_deployments'],
            'total_downloads': total_downloads,
            'total_installations': total_installations,
            'success_rate': round((total_installations / total_downloads * 100) if total_downloads > 0 else 0, 2),
        })
