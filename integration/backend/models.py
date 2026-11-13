"""
Modèles Django pour l'intégration de déploiement Linux
À intégrer dans: api/tacticalrmm/clients/models.py
"""
from __future__ import annotations

import hashlib
import hmac
import secrets
import shlex
import uuid
from datetime import datetime

from django.db import models
from django.db.models import F
from django.utils import timezone


class LinuxDeploymentQuerySet(models.QuerySet):
    """Filtres réutilisables (vues, exports, statistiques, commande de nettoyage)."""

    def active(self) -> LinuxDeploymentQuerySet:
        return self.filter(expires_at__gt=timezone.now())

    def expired(self) -> LinuxDeploymentQuerySet:
        return self.filter(expires_at__lte=timezone.now())

    def expired_before(self, cutoff: datetime) -> LinuxDeploymentQuerySet:
        return self.filter(expires_at__lt=cutoff)

    def for_client(self, client_id: int | str) -> LinuxDeploymentQuerySet:
        return self.filter(client_id=client_id)

    def for_site(self, site_id: int | str) -> LinuxDeploymentQuerySet:
        return self.filter(site_id=site_id)

    def with_status(self, status: str | None) -> LinuxDeploymentQuerySet:
        """``'active'`` / ``'expired'`` ; toute autre valeur ne filtre pas."""
        if status == 'active':
            return self.active()
        if status == 'expired':
            return self.expired()
        return self


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

    objects = LinuxDeploymentQuerySet.as_manager()

    class Meta:
        db_table = 'linux_deployments'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['expires_at'], name='linux_deploy_expires_idx'),
            models.Index(fields=['client_id', 'site_id'], name='linux_deploy_client_site_idx'),
        ]

    def __str__(self) -> str:
        return f"Linux Deployment {self.uuid} - {self.client_name}/{self.site_name}"

    def is_expired(self) -> bool:
        """Vérifie si le déploiement a expiré"""
        return timezone.now() > self.expires_at

    def increment_download(self) -> None:
        """Incrémente le compteur de téléchargements (atomique)"""
        now = timezone.now()
        LinuxDeployment.objects.filter(pk=self.pk).update(
            download_count=F('download_count') + 1,
            last_downloaded=now,
        )
        self.refresh_from_db(fields=['download_count', 'last_downloaded'])

    def increment_installed(self) -> None:
        """Incrémente le compteur d'agents installés (atomique)"""
        LinuxDeployment.objects.filter(pk=self.pk).update(agents_installed=F('agents_installed') + 1)
        self.refresh_from_db(fields=['agents_installed'])

    def get_install_command(self) -> str:
        """Génère la commande d'installation (URL signée, correctement échappée)"""
        deployment_url = shlex.quote(self.get_signed_url())
        return f"""wget {deployment_url} -O install-rmm-agent.sh
chmod +x install-rmm-agent.sh
sudo ./install-rmm-agent.sh"""

    def get_script_url(self) -> str:
        """Retourne l'URL du script d'installation"""
        if self.custom_script_url:
            return self.custom_script_url
        return "https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/rmmagent-linux.sh"

    @staticmethod
    def generate_signing_token() -> str:
        """Génère un token de signature aléatoire sécurisé"""
        return secrets.token_hex(32)  # 64 caractères hexadécimaux

    @staticmethod
    def generate_one_time_token() -> str:
        """Génère un token unique à usage unique"""
        return secrets.token_urlsafe(48)

    @staticmethod
    def generate_signature_secret() -> str:
        """Génère un secret pour les signatures HMAC"""
        return secrets.token_hex(64)  # 128 caractères hexadécimaux

    def generate_signature(self, data_to_sign: str) -> str:
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

    def validate_signature(self, data_to_sign: str, signature: str) -> bool:
        """
        Valide une signature HMAC

        Args:
            data_to_sign: Données signées
            signature: Signature à valider

        Returns:
            True si la signature est valide
        """
        expected_signature = self.generate_signature(data_to_sign)
        return hmac.compare_digest(expected_signature.encode(), str(signature).encode())

    def signature_payload(self, timestamp: int | str) -> str:
        """Chaîne signée pour l'URL de téléchargement : ``<uuid>:<timestamp>``"""
        return f"{self.uuid}:{timestamp}"

    def get_signed_url(self) -> str:
        """
        Génère une URL signée pour le téléchargement du script.

        Le paramètre ``t`` est le timestamp Unix d'expiration du déploiement ;
        la signature couvre ``<uuid>:<t>``, ce qui empêche de prolonger le lien.

        Returns:
            URL complète avec signature HMAC
        """
        base_url = f"{self.api_url.rstrip('/')}/clients/{self.uuid}/deploy/linux/"
        timestamp = int(self.expires_at.timestamp())
        signature = self.generate_signature(self.signature_payload(timestamp))
        return f"{base_url}?t={timestamp}&sig={signature}"

    def check_signed_request(self, timestamp: str | None, signature: str | None) -> tuple[bool, int, str]:
        """
        Valide les paramètres ``t`` et ``sig`` d'une URL de téléchargement.

        Returns:
            (valide, code HTTP en cas d'échec, message)
        """
        if not timestamp or not signature:
            return False, 403, "Signature manquante"
        if not self.validate_signature(self.signature_payload(timestamp), signature):
            return False, 403, "Signature invalide"
        try:
            ts = int(timestamp)
        except ValueError:
            return False, 400, "Timestamp invalide"
        if ts < int(timezone.now().timestamp()):
            return False, 410, "Lien expiré"
        return True, 200, "OK"

    def use_one_time_token(self) -> None:
        """Marque le one-time token comme utilisé (atomique, sans condition de course)"""
        now = timezone.now()
        updated = LinuxDeployment.objects.filter(pk=self.pk, token_used=False).update(
            token_used=True,
            token_used_at=now,
        )
        if not updated:
            raise ValueError("Ce token a déjà été utilisé")
        self.token_used = True
        self.token_used_at = now

    def check_one_time_token(self, provided: str | None) -> bool:
        """Compare le one-time token fourni en temps constant"""
        if not provided or not self.one_time_token:
            return False
        return hmac.compare_digest(str(provided).encode(), self.one_time_token.encode())

    def is_token_valid(self) -> bool:
        """Vérifie si le one-time token est toujours valide"""
        if self.token_used:
            return False
        if self.is_expired():
            return False
        return True

    def can_be_used(self) -> tuple[bool, str]:
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

    def __str__(self) -> str:
        return f"{self.action} - {self.deployment.uuid} - {self.timestamp}"
