"""
Vues Django pour l'intégration de déploiement Linux
À intégrer dans: api/tacticalrmm/clients/views.py
"""
from __future__ import annotations

import uuid
from datetime import timedelta

from django.utils import timezone
from django.db.models import Sum
from django.http import HttpResponse, JsonResponse, Http404, HttpRequest
from rest_framework.views import APIView
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

from .models import LinuxDeployment, DeploymentLog
from .serializers import LinuxDeploymentSerializer
from .notifications import notification_manager
from .throttling import DeploymentDownloadThrottle, InstallCallbackThrottle


def get_client_ip(request: HttpRequest | Request) -> str | None:
    """
    Fonction utilitaire pour récupérer l'adresse IP du client.
    Gère le cas où la requête passe par un proxy (header X-Forwarded-For).
    """
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        # Prendre la première IP de la liste (IP du client original)
        ip: str = x_forwarded_for.split(',')[0].strip()
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


class LinuxDeploymentCreateView(APIView):
    """
    Crée un nouveau déploiement Linux
    POST /api/v3/linux-deployments/
    """
    permission_classes = [IsAuthenticated]

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
            "expires_days": 30,  # optionnel, défaut: 30
            "enable_ping": true,
            "enable_rdp": false,
            "install_mesh": true,
            "custom_script_url": ""  # optionnel
        }
        """
        data = request.data

        # Valider les données requises
        required_fields = ['client_id', 'client_name', 'site_id', 'site_name']
        for field in required_fields:
            if field not in data:
                return Response(
                    {'error': f'Le champ {field} est requis'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        # Calculer la date d'expiration
        expires_days = data.get('expires_days', 30)
        expires_at = timezone.now() + timedelta(days=expires_days)

        # Récupérer l'URL de l'API depuis les settings
        api_url = request.build_absolute_uri('/').rstrip('/')

        # Récupérer l'URL Mesh depuis la configuration (à adapter)
        mesh_url = data.get('mesh_url', 'https://mesh.votredomaine.com/meshagents?id=...')

        # Générer une clé d'authentification unique
        auth_key = uuid.uuid4().hex

        # Générer les tokens de sécurité
        signing_token = LinuxDeployment.generate_signing_token()
        one_time_token = LinuxDeployment.generate_one_time_token()
        signature_secret = LinuxDeployment.generate_signature_secret()

        # Créer le déploiement
        deployment = LinuxDeployment.objects.create(
            client_id=data['client_id'],
            client_name=data['client_name'],
            site_id=data['site_id'],
            site_name=data['site_name'],
            agent_type=data.get('agent_type', 'server'),
            arch=data.get('arch', 'amd64'),
            api_url=api_url,
            mesh_url=mesh_url,
            auth_key=auth_key,
            signing_token=signing_token,
            one_time_token=one_time_token,
            signature_secret=signature_secret,
            enable_ping=data.get('enable_ping', True),
            enable_rdp=data.get('enable_rdp', False),
            install_mesh=data.get('install_mesh', True),
            custom_script_url=data.get('custom_script_url', ''),
            expires_at=expires_at,
            created_by=request.user.username
        )

        # Créer un log
        DeploymentLog.objects.create(
            deployment=deployment,
            action='created',
            ip_address=get_client_ip(request),
            user_agent=request.META.get('HTTP_USER_AGENT', '')
        )

        serializer = LinuxDeploymentSerializer(deployment, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class LinuxDeploymentListView(APIView):
    """
    Liste tous les déploiements Linux
    GET /api/v3/linux-deployments/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        deployments = LinuxDeployment.objects.all()

        # Filtrage optionnel
        client_id = request.query_params.get('client_id')
        if client_id:
            deployments = deployments.filter(client_id=client_id)

        site_id = request.query_params.get('site_id')
        if site_id:
            deployments = deployments.filter(site_id=site_id)

        serializer = LinuxDeploymentSerializer(deployments, many=True, context={'request': request})
        return Response(serializer.data)


class LinuxDeploymentDetailView(APIView):
    """
    Détails d'un déploiement Linux
    GET /api/v3/linux-deployments/{uuid}/
    DELETE /api/v3/linux-deployments/{uuid}/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request: Request, deployment_uuid: str) -> Response:
        try:
            deployment = LinuxDeployment.objects.get(uuid=deployment_uuid)
            serializer = LinuxDeploymentSerializer(deployment, context={'request': request})
            return Response(serializer.data)
        except LinuxDeployment.DoesNotExist:
            raise Http404("Déploiement non trouvé")

    def delete(self, request: Request, deployment_uuid: str) -> Response:
        try:
            deployment = LinuxDeployment.objects.get(uuid=deployment_uuid)
            deployment.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except LinuxDeployment.DoesNotExist:
            raise Http404("Déploiement non trouvé")


class LinuxDeploymentScriptView(APIView):
    """
    Télécharge le script d'installation Linux pré-configuré
    GET /clients/{uuid}/deploy/linux/

    Cette URL est publique (pas d'authentification) car utilisée pour le déploiement
    """
    permission_classes = []  # Pas d'authentification requise
    throttle_classes = [DeploymentDownloadThrottle]

    def get(self, request: Request, deployment_uuid: str) -> HttpResponse:
        try:
            deployment = LinuxDeployment.objects.get(uuid=deployment_uuid)
        except LinuxDeployment.DoesNotExist:
            return HttpResponse("Déploiement non trouvé ou expiré", status=404)

        # Vérifier l'expiration
        if deployment.is_expired():
            return HttpResponse("Ce lien de déploiement a expiré", status=410)

        # Validation de la signature HMAC (si fournie)
        timestamp = request.GET.get('t')
        signature = request.GET.get('sig')

        if timestamp and signature:
            # Vérifier la signature HMAC
            data_to_sign = f"{deployment_uuid}:{timestamp}"
            if not deployment.validate_signature(data_to_sign, signature):
                DeploymentLog.objects.create(
                    deployment=deployment,
                    action='invalid_signature',
                    ip_address=get_client_ip(request),
                    user_agent=request.META.get('HTTP_USER_AGENT', ''),
                    error_message=f"Signature HMAC invalide: {signature}"
                )
                return HttpResponse("Signature invalide", status=403)

            # Vérifier que le timestamp n'est pas trop ancien (max 1 heure)
            from datetime import datetime
            try:
                ts = int(timestamp)
                request_time = datetime.fromtimestamp(ts, tz=timezone.get_current_timezone())
                age = (timezone.now() - request_time).total_seconds()

                if age > 3600:  # 1 heure
                    return HttpResponse("Lien expiré (timestamp trop ancien)", status=410)
            except (ValueError, OSError):
                return HttpResponse("Timestamp invalide", status=400)

        # Incrémenter le compteur de téléchargements
        deployment.increment_download()

        # Logger le téléchargement
        DeploymentLog.objects.create(
            deployment=deployment,
            action='downloaded',
            ip_address=get_client_ip(request),
            user_agent=request.META.get('HTTP_USER_AGENT', '')
        )

        # Générer le script
        script = self._generate_install_script(deployment)

        # Retourner le script
        response = HttpResponse(script, content_type='text/x-shellscript')
        response['Content-Disposition'] = f'attachment; filename="install-rmm-agent-{deployment.uuid}.sh"'
        return response

    def _generate_install_script(self, deployment: LinuxDeployment) -> str:
        """Génère le script d'installation avec les paramètres pré-configurés"""

        # URL du script de base
        base_script_url = deployment.get_script_url()

        script = f"""#!/bin/bash
#
# Script d'installation automatique de l'agent Tactical RMM pour Linux
# Généré automatiquement - Ne pas modifier
#
# Client: {deployment.client_name}
# Site: {deployment.site_name}
# Type: {deployment.agent_type}
# Architecture: {deployment.arch}
# Date d'expiration: {deployment.expires_at.strftime('%Y-%m-%d %H:%M:%S')}
#

set -e

# Couleurs pour les messages
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m' # No Color

echo -e "${{GREEN}}========================================${{NC}}"
echo -e "${{GREEN}}Installation de l'agent Tactical RMM${{NC}}"
echo -e "${{GREEN}}========================================${{NC}}"
echo ""
echo "Client: {deployment.client_name}"
echo "Site: {deployment.site_name}"
echo "Type: {deployment.agent_type}"
echo ""

# Vérifier les privilèges root
if [ "$EUID" -ne 0 ]; then
    echo -e "${{RED}}Ce script doit être exécuté en tant que root${{NC}}"
    echo "Utilisez: sudo $0"
    exit 1
fi

# Télécharger le script d'installation de base
echo -e "${{YELLOW}}Téléchargement du script d'installation...${{NC}}"
wget -q "{base_script_url}" -O /tmp/rmmagent-install.sh

if [ ! -f /tmp/rmmagent-install.sh ]; then
    echo -e "${{RED}}Erreur: Impossible de télécharger le script d'installation${{NC}}"
    exit 1
fi

chmod +x /tmp/rmmagent-install.sh

# Exécuter l'installation avec les paramètres pré-configurés
echo -e "${{YELLOW}}Installation de l'agent...${{NC}}"

/tmp/rmmagent-install.sh install \\
    "{deployment.mesh_url}" \\
    "{deployment.api_url}" \\
    {deployment.client_id} \\
    {deployment.site_id} \\
    "{deployment.auth_key}" \\
    "{deployment.agent_type}"

INSTALL_STATUS=$?

# Notifier le serveur du résultat
if [ $INSTALL_STATUS -eq 0 ]; then
    echo -e "${{GREEN}}Installation terminée avec succès !${{NC}}"

    # Envoyer une notification de succès au serveur avec one-time token
    HOSTNAME=$(hostname)
    curl -s -X POST "{deployment.api_url}/api/v3/linux-deployments/{deployment.uuid}/installed/" \\
        -H "Content-Type: application/json" \\
        -d '{{"hostname": "'$HOSTNAME'", "status": "success", "one_time_token": "{deployment.one_time_token}"}}' || true

    echo ""
    echo "L'agent devrait apparaître dans le dashboard dans quelques instants."
    echo "Vérifiez dans: {deployment.client_name} > {deployment.site_name}"
else
    echo -e "${{RED}}Erreur lors de l'installation${{NC}}"

    # Envoyer une notification d'erreur au serveur avec one-time token
    HOSTNAME=$(hostname)
    curl -s -X POST "{deployment.api_url}/api/v3/linux-deployments/{deployment.uuid}/installed/" \\
        -H "Content-Type: application/json" \\
        -d '{{"hostname": "'$HOSTNAME'", "status": "failed", "one_time_token": "{deployment.one_time_token}"}}' || true

    exit 1
fi

# Nettoyage
rm -f /tmp/rmmagent-install.sh

echo ""
echo -e "${{GREEN}}========================================${{NC}}"
echo -e "${{GREEN}}Installation terminée${{NC}}"
echo -e "${{GREEN}}========================================${{NC}}"
"""
        return script


class LinuxDeploymentInstallCallbackView(APIView):
    """
    Callback appelé par le script d'installation pour notifier le résultat
    POST /api/v3/linux-deployments/{uuid}/installed/
    """
    permission_classes = []  # Pas d'authentification requise
    throttle_classes = [InstallCallbackThrottle]

    def post(self, request: Request, deployment_uuid: str) -> Response:
        try:
            deployment = LinuxDeployment.objects.get(uuid=deployment_uuid)
        except LinuxDeployment.DoesNotExist:
            return Response({'error': 'Déploiement non trouvé'}, status=404)

        data = request.data
        hostname = data.get('hostname', 'unknown')
        install_status = data.get('status', 'unknown')
        one_time_token = data.get('one_time_token', '')

        # Vérifier le one-time token si fourni (pour installations sécurisées)
        if one_time_token:
            # Vérifier que le token correspond
            if one_time_token != deployment.one_time_token:
                DeploymentLog.objects.create(
                    deployment=deployment,
                    action='invalid_token',
                    ip_address=get_client_ip(request),
                    hostname=hostname,
                    error_message=f"One-time token invalide: {one_time_token[:10]}..."
                )
                return Response({'error': 'Token invalide'}, status=403)

            # Vérifier que le token n'a pas déjà été utilisé
            if deployment.token_used:
                DeploymentLog.objects.create(
                    deployment=deployment,
                    action='token_already_used',
                    ip_address=get_client_ip(request),
                    hostname=hostname,
                    error_message=f"Token déjà utilisé le {deployment.token_used_at}"
                )
                return Response({'error': 'Ce token a déjà été utilisé'}, status=410)

            # Marquer le token comme utilisé (seulement si installation réussie)
            if install_status == 'success':
                try:
                    deployment.use_one_time_token()
                except ValueError as e:
                    # Token déjà utilisé (condition de concurrence possible)
                    return Response({'error': str(e)}, status=410)

        # Incrémenter le compteur d'installations si succès
        if install_status == 'success':
            deployment.agents_installed += 1
            deployment.save(update_fields=['agents_installed'])

        # Logger l'installation
        DeploymentLog.objects.create(
            deployment=deployment,
            action=f'installed_{install_status}',
            ip_address=get_client_ip(request),
            hostname=hostname,
            error_message=data.get('error', '')
        )

        # Envoyer les notifications
        if install_status == 'success':
            notification_manager.notify_installation_success(
                deployment_uuid=str(deployment.uuid),
                client_name=deployment.client_name,
                site_name=deployment.site_name,
                hostname=hostname,
                ip_address=get_client_ip(request),
            )
        elif install_status == 'failed':
            notification_manager.notify_installation_failure(
                deployment_uuid=str(deployment.uuid),
                client_name=deployment.client_name,
                site_name=deployment.site_name,
                hostname=hostname,
                error=data.get('error', ''),
            )

        return Response({'status': 'logged'})


class LinuxDeploymentStatsView(APIView):
    """
    Statistiques des déploiements Linux
    GET /api/v3/linux-deployments/stats/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        total_deployments: int = LinuxDeployment.objects.count()
        active_deployments: int = LinuxDeployment.objects.filter(expires_at__gt=timezone.now()).count()
        expired_deployments: int = LinuxDeployment.objects.filter(expires_at__lte=timezone.now()).count()
        total_downloads: int = LinuxDeployment.objects.aggregate(Sum('download_count'))['download_count__sum'] or 0
        total_installations: int = LinuxDeployment.objects.aggregate(Sum('agents_installed'))['agents_installed__sum'] or 0

        return Response({
            'total_deployments': total_deployments,
            'active_deployments': active_deployments,
            'expired_deployments': expired_deployments,
            'total_downloads': total_downloads,
            'total_installations': total_installations,
            'success_rate': round((total_installations / total_downloads * 100) if total_downloads > 0 else 0, 2)
        })
