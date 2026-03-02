"""
Modèles Django pour l'intégration de déploiement Linux
À intégrer dans: api/tacticalrmm/clients/models.py
"""
import uuid
import hmac
import hashlib
import secrets
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

    # Tokens de sécurité
    signing_token = models.CharField(
        max_length=64,
        unique=True,
        help_text="Token HMAC pour signer les URLs de déploiement"
    )
    one_time_token = models.CharField(
        max_length=64,
        unique=True,
        help_text="Token unique qui expire après la première installation"
    )
    signature_secret = models.CharField(
        max_length=128,
        help_text="Secret pour générer et valider les signatures HMAC"
    )
    token_used = models.BooleanField(
        default=False,
        help_text="Indique si le one-time token a déjà été utilisé"
    )
    token_used_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Date et heure d'utilisation du token"
    )

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

    @staticmethod
    def generate_signing_token():
        """Génère un token de signature unique"""
        return secrets.token_urlsafe(48)

    @staticmethod
    def generate_one_time_token():
        """Génère un token unique à usage unique"""
        return secrets.token_urlsafe(48)

    @staticmethod
    def generate_signature_secret():
        """Génère un secret pour les signatures HMAC"""
        return secrets.token_urlsafe(96)

    def generate_signature(self, data_to_sign):
        """
        Génère une signature HMAC pour les données fournies

        Args:
            data_to_sign: str - Données à signer (ex: uuid + timestamp)

        Returns:
            str - Signature HMAC en hexadécimal
        """
        return hmac.new(
            self.signature_secret.encode('utf-8'),
            data_to_sign.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

    def validate_signature(self, data_to_sign, signature):
        """
        Valide une signature HMAC

        Args:
            data_to_sign: str - Données signées
            signature: str - Signature à valider

        Returns:
            bool - True si la signature est valide
        """
        expected_signature = self.generate_signature(data_to_sign)
        return hmac.compare_digest(expected_signature, signature)

    def get_signed_url(self):
        """
        Génère une URL signée pour le téléchargement du script

        Returns:
            str - URL complète avec signature HMAC
        """
        timestamp = str(int(timezone.now().timestamp()))
        data_to_sign = f"{self.uuid}:{timestamp}"
        signature = self.generate_signature(data_to_sign)

        return f"{self.api_url}/clients/{self.uuid}/deploy/linux/?t={timestamp}&sig={signature}"

    def use_one_time_token(self):
        """Marque le one-time token comme utilisé"""
        if self.token_used:
            raise ValueError("Ce token a déjà été utilisé")

        self.token_used = True
        self.token_used_at = timezone.now()
        self.save(update_fields=['token_used', 'token_used_at'])

    def is_token_valid(self):
        """Vérifie si le one-time token est toujours valide"""
        if self.token_used:
            return False
        if self.is_expired():
            return False
        return True

    @staticmethod
    def generate_signing_token():
        """Génère un token de signature aléatoire sécurisé"""
        return secrets.token_hex(32)  # 64 caractères hexadécimaux

    @staticmethod
    def generate_signature_secret():
        """Génère un secret pour les signatures HMAC"""
        return secrets.token_hex(64)  # 128 caractères hexadécimaux

    def generate_signature(self, data_to_sign):
        """
        Génère une signature HMAC pour les données fournies

        Args:
            data_to_sign: Chaîne de caractères à signer

        Returns:
            Signature HMAC en hexadécimal
        """
        signature = hmac.new(
            self.signature_secret.encode('utf-8'),
            data_to_sign.encode('utf-8'),
            hashlib.sha256
        )
        return signature.hexdigest()

    def verify_signature(self, data_to_verify, provided_signature):
        """
        Vérifie une signature HMAC

        Args:
            data_to_verify: Données originales
            provided_signature: Signature fournie à vérifier

        Returns:
            True si la signature est valide, False sinon
        """
        expected_signature = self.generate_signature(data_to_verify)
        return hmac.compare_digest(expected_signature, provided_signature)

    def get_signed_url(self):
        """
        Génère une URL signée pour le téléchargement du script

        Returns:
            URL complète avec signature HMAC
        """
        base_url = f"{self.api_url}/clients/{self.uuid}/deploy/linux/"

        # Données à signer : uuid + signing_token + timestamp de création
        data_to_sign = f"{self.uuid}{self.signing_token}{self.created_at.isoformat()}"
        signature = self.generate_signature(data_to_sign)

        return f"{base_url}?token={self.signing_token}&sig={signature}"

    def use_one_time_token(self):
        """Marque le one-time token comme utilisé"""
        if self.token_used:
            raise ValueError("Ce token a déjà été utilisé")

        self.token_used = True
        self.token_used_at = timezone.now()
        self.save(update_fields=['token_used', 'token_used_at'])

    def can_be_used(self):
        """
        Vérifie si le déploiement peut être utilisé

        Returns:
            tuple (bool, str): (peut_être_utilisé, message_erreur)
        """
        if self.is_expired():
            return False, "Ce lien de déploiement a expiré"

        if self.token_used:
            return False, "Ce token a déjà été utilisé"

        return True, "OK"


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
