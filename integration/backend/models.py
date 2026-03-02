"""
Modèles Django pour l'intégration de déploiement Linux
À intégrer dans: api/tacticalrmm/clients/models.py
"""
import uuid
from django.db import models
from django.utils import timezone
from datetime import timedelta


class LinuxDeployment(models.Model):
    """
    Modèle pour gérer les déploiements d'agents Linux
    """
    AGENT_TYPE_CHOICES = [
        ('server', 'Server'),
        ('workstation', 'Workstation'),
    ]

    ARCH_CHOICES = [
        ('amd64', 'AMD64/x86_64'),
        ('arm64', 'ARM64'),
        ('386', 'i386'),
    ]

    # Identifiant unique du déploiement
    uuid = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)

    # Informations client/site
    client_id = models.IntegerField()
    client_name = models.CharField(max_length=255)
    site_id = models.IntegerField()
    site_name = models.CharField(max_length=255)

    # Configuration de l'agent
    agent_type = models.CharField(max_length=20, choices=AGENT_TYPE_CHOICES, default='server')
    arch = models.CharField(max_length=20, choices=ARCH_CHOICES, default='amd64')

    # URLs et authentification
    api_url = models.URLField(help_text="URL de l'API Tactical RMM")
    mesh_url = models.URLField(help_text="URL du Mesh Agent")
    auth_key = models.CharField(max_length=255, help_text="Clé d'authentification")

    # Options d'installation
    enable_ping = models.BooleanField(default=True)
    enable_rdp = models.BooleanField(default=False)
    install_mesh = models.BooleanField(default=True)

    # Script personnalisé (optionnel)
    custom_script_url = models.URLField(
        blank=True,
        null=True,
        help_text="URL du script d'installation personnalisé"
    )

    # Métadonnées
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(
        help_text="Date d'expiration du lien de déploiement"
    )
    created_by = models.CharField(max_length=255)

    # Statistiques d'utilisation
    download_count = models.IntegerField(default=0)
    last_downloaded = models.DateTimeField(null=True, blank=True)

    # Agents installés avec ce déploiement
    agents_installed = models.IntegerField(default=0)

    class Meta:
        db_table = 'linux_deployments'
        ordering = ['-created_at']

    def __str__(self):
        return f"Linux Deployment {self.uuid} - {self.client_name}/{self.site_name}"

    def is_expired(self):
        """Vérifie si le déploiement a expiré"""
        return timezone.now() > self.expires_at

    def increment_download(self):
        """Incrémente le compteur de téléchargements"""
        self.download_count += 1
        self.last_downloaded = timezone.now()
        self.save(update_fields=['download_count', 'last_downloaded'])

    def get_install_command(self):
        """Génère la commande d'installation"""
        deployment_url = f"{self.api_url}/clients/{self.uuid}/deploy/linux/"
        return f"""wget {deployment_url} -O install-rmm-agent.sh
chmod +x install-rmm-agent.sh
sudo ./install-rmm-agent.sh"""

    def get_script_url(self):
        """Retourne l'URL du script d'installation"""
        if self.custom_script_url:
            return self.custom_script_url
        return "https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/rmmagent-linux-ameliore.sh"


class DeploymentLog(models.Model):
    """
    Logs des déploiements pour le suivi
    """
    deployment = models.ForeignKey(LinuxDeployment, on_delete=models.CASCADE, related_name='logs')
    timestamp = models.DateTimeField(auto_now_add=True)
    action = models.CharField(max_length=50)  # 'downloaded', 'installed', 'failed'
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    hostname = models.CharField(max_length=255, blank=True)
    error_message = models.TextField(blank=True)

    class Meta:
        db_table = 'deployment_logs'
        ordering = ['-timestamp']

    def __str__(self):
        return f"{self.action} - {self.deployment.uuid} - {self.timestamp}"
