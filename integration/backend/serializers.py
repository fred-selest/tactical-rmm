"""
Serializers Django REST Framework pour l'intégration de déploiement Linux
À intégrer dans: api/tacticalrmm/clients/serializers.py
"""
from rest_framework import serializers
from .models import LinuxDeployment, DeploymentLog


class LinuxDeploymentSerializer(serializers.ModelSerializer):
    """
    Serializer pour le modèle LinuxDeployment
    """
    is_expired = serializers.BooleanField(read_only=True)
    install_command = serializers.SerializerMethodField()
    deployment_url = serializers.SerializerMethodField()
    script_download_url = serializers.SerializerMethodField()

    class Meta:
        model = LinuxDeployment
        fields = [
            'uuid',
            'client_id',
            'client_name',
            'site_id',
            'site_name',
            'agent_type',
            'arch',
            'api_url',
            'mesh_url',
            'auth_key',
            'enable_ping',
            'enable_rdp',
            'install_mesh',
            'custom_script_url',
            'created_at',
            'expires_at',
            'created_by',
            'download_count',
            'last_downloaded',
            'agents_installed',
            'is_expired',
            'install_command',
            'deployment_url',
            'script_download_url',
        ]
        read_only_fields = [
            'uuid',
            'created_at',
            'download_count',
            'last_downloaded',
            'agents_installed',
        ]

    def get_install_command(self, obj):
        """Retourne la commande d'installation complète"""
        return obj.get_install_command()

    def get_deployment_url(self, obj):
        """Retourne l'URL de déploiement complète"""
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(f'/clients/{obj.uuid}/deploy/linux/')
        return f"/clients/{obj.uuid}/deploy/linux/"

    def get_script_download_url(self, obj):
        """Retourne l'URL de téléchargement du script"""
        return obj.get_script_url()


class DeploymentLogSerializer(serializers.ModelSerializer):
    """
    Serializer pour le modèle DeploymentLog
    """
    deployment_uuid = serializers.UUIDField(source='deployment.uuid', read_only=True)

    class Meta:
        model = DeploymentLog
        fields = [
            'id',
            'deployment_uuid',
            'timestamp',
            'action',
            'ip_address',
            'user_agent',
            'hostname',
            'error_message',
        ]
        read_only_fields = ['id', 'timestamp']


class LinuxDeploymentCreateSerializer(serializers.Serializer):
    """
    Serializer pour la création d'un déploiement Linux
    """
    client_id = serializers.IntegerField(required=True)
    client_name = serializers.CharField(max_length=255, required=True)
    site_id = serializers.IntegerField(required=True)
    site_name = serializers.CharField(max_length=255, required=True)
    agent_type = serializers.ChoiceField(
        choices=['server', 'workstation'],
        default='server'
    )
    arch = serializers.ChoiceField(
        choices=['amd64', 'arm64', '386'],
        default='amd64'
    )
    expires_days = serializers.IntegerField(default=30, min_value=1, max_value=365)
    enable_ping = serializers.BooleanField(default=True)
    enable_rdp = serializers.BooleanField(default=False)
    install_mesh = serializers.BooleanField(default=True)
    custom_script_url = serializers.URLField(required=False, allow_blank=True)
    mesh_url = serializers.URLField(required=False)


class DeploymentStatsSerializer(serializers.Serializer):
    """
    Serializer pour les statistiques de déploiement
    """
    total_deployments = serializers.IntegerField()
    active_deployments = serializers.IntegerField()
    expired_deployments = serializers.IntegerField()
    total_downloads = serializers.IntegerField()
    total_installations = serializers.IntegerField()
    success_rate = serializers.FloatField()
