"""
Système de notifications pour les déploiements Linux.
Supporte: Email, Slack, Discord, Microsoft Teams, Webhooks génériques.

Configuration via les variables d'environnement :
    NOTIFICATION_EMAIL_ENABLED=true
    NOTIFICATION_EMAIL_TO=admin@example.com
    NOTIFICATION_SLACK_WEBHOOK=https://hooks.slack.com/...
    NOTIFICATION_DISCORD_WEBHOOK=https://discord.com/api/webhooks/...
    NOTIFICATION_TEAMS_WEBHOOK=https://outlook.office.com/webhook/...
    NOTIFICATION_GENERIC_WEBHOOK=https://your-service.com/webhook
"""
from __future__ import annotations

import json
import logging
import os
from typing import Any
from urllib.request import Request, urlopen
from urllib.error import URLError

logger = logging.getLogger(__name__)


class NotificationManager:
    """Gestionnaire centralisé des notifications"""

    def __init__(self) -> None:
        self.handlers: list[NotificationHandler] = []
        self._configure()

    def _configure(self) -> None:
        """Configure les handlers depuis les variables d'environnement"""
        if os.environ.get('NOTIFICATION_SLACK_WEBHOOK'):
            self.handlers.append(
                SlackNotificationHandler(os.environ['NOTIFICATION_SLACK_WEBHOOK'])
            )

        if os.environ.get('NOTIFICATION_DISCORD_WEBHOOK'):
            self.handlers.append(
                DiscordNotificationHandler(os.environ['NOTIFICATION_DISCORD_WEBHOOK'])
            )

        if os.environ.get('NOTIFICATION_TEAMS_WEBHOOK'):
            self.handlers.append(
                TeamsNotificationHandler(os.environ['NOTIFICATION_TEAMS_WEBHOOK'])
            )

        if os.environ.get('NOTIFICATION_GENERIC_WEBHOOK'):
            self.handlers.append(
                GenericWebhookHandler(os.environ['NOTIFICATION_GENERIC_WEBHOOK'])
            )

    def notify_installation_success(
        self,
        deployment_uuid: str,
        client_name: str,
        site_name: str,
        hostname: str,
        ip_address: str | None = None,
    ) -> None:
        """Notification d'installation réussie"""
        message = (
            f"Agent Linux installé avec succès\n"
            f"Client: {client_name}\n"
            f"Site: {site_name}\n"
            f"Hostname: {hostname}\n"
            f"IP: {ip_address or 'N/A'}\n"
            f"Déploiement: {deployment_uuid}"
        )
        self._send_all("installation_success", message, {
            "deployment_uuid": deployment_uuid,
            "client_name": client_name,
            "site_name": site_name,
            "hostname": hostname,
            "ip_address": ip_address,
        })

    def notify_installation_failure(
        self,
        deployment_uuid: str,
        client_name: str,
        site_name: str,
        hostname: str,
        error: str = "",
    ) -> None:
        """Notification d'échec d'installation"""
        message = (
            f"Échec d'installation de l'agent Linux\n"
            f"Client: {client_name}\n"
            f"Site: {site_name}\n"
            f"Hostname: {hostname}\n"
            f"Erreur: {error or 'Inconnue'}\n"
            f"Déploiement: {deployment_uuid}"
        )
        self._send_all("installation_failure", message, {
            "deployment_uuid": deployment_uuid,
            "client_name": client_name,
            "site_name": site_name,
            "hostname": hostname,
            "error": error,
        })

    def notify_token_expired(
        self,
        deployment_uuid: str,
        client_name: str,
        site_name: str,
    ) -> None:
        """Notification d'expiration de token"""
        message = (
            f"Token de déploiement expiré\n"
            f"Client: {client_name}\n"
            f"Site: {site_name}\n"
            f"Déploiement: {deployment_uuid}"
        )
        self._send_all("token_expired", message, {
            "deployment_uuid": deployment_uuid,
            "client_name": client_name,
            "site_name": site_name,
        })

    def _send_all(self, event_type: str, message: str, data: dict[str, Any]) -> None:
        """Envoie la notification à tous les handlers configurés"""
        for handler in self.handlers:
            try:
                handler.send(event_type, message, data)
            except Exception as e:
                logger.error(
                    "Erreur envoi notification %s via %s: %s",
                    event_type, handler.__class__.__name__, e
                )


class NotificationHandler:
    """Classe de base pour les handlers de notification"""

    def send(self, event_type: str, message: str, data: dict[str, Any]) -> None:
        raise NotImplementedError


class SlackNotificationHandler(NotificationHandler):
    """Handler pour les notifications Slack"""

    def __init__(self, webhook_url: str) -> None:
        self.webhook_url = webhook_url

    def send(self, event_type: str, message: str, data: dict[str, Any]) -> None:
        color = "#36a64f" if event_type == "installation_success" else "#dc3545"
        title = {
            "installation_success": "Installation réussie",
            "installation_failure": "Échec d'installation",
            "token_expired": "Token expiré",
        }.get(event_type, event_type)

        payload = {
            "attachments": [{
                "color": color,
                "title": f"Tactical RMM - {title}",
                "text": message,
                "footer": "Tactical RMM Linux Deployment",
            }]
        }
        self._post_json(payload)

    def _post_json(self, payload: dict) -> None:
        data = json.dumps(payload).encode('utf-8')
        req = Request(self.webhook_url, data=data, headers={'Content-Type': 'application/json'})
        try:
            urlopen(req, timeout=10)
        except URLError as e:
            logger.error("Erreur Slack webhook: %s", e)


class DiscordNotificationHandler(NotificationHandler):
    """Handler pour les notifications Discord"""

    def __init__(self, webhook_url: str) -> None:
        self.webhook_url = webhook_url

    def send(self, event_type: str, message: str, data: dict[str, Any]) -> None:
        color = 0x36A64F if event_type == "installation_success" else 0xDC3545
        title = {
            "installation_success": "Installation réussie",
            "installation_failure": "Échec d'installation",
            "token_expired": "Token expiré",
        }.get(event_type, event_type)

        payload = {
            "embeds": [{
                "title": f"Tactical RMM - {title}",
                "description": message,
                "color": color,
            }]
        }
        data_bytes = json.dumps(payload).encode('utf-8')
        req = Request(self.webhook_url, data=data_bytes, headers={'Content-Type': 'application/json'})
        try:
            urlopen(req, timeout=10)
        except URLError as e:
            logger.error("Erreur Discord webhook: %s", e)


class TeamsNotificationHandler(NotificationHandler):
    """Handler pour les notifications Microsoft Teams"""

    def __init__(self, webhook_url: str) -> None:
        self.webhook_url = webhook_url

    def send(self, event_type: str, message: str, data: dict[str, Any]) -> None:
        color = "00FF00" if event_type == "installation_success" else "FF0000"
        title = {
            "installation_success": "Installation réussie",
            "installation_failure": "Échec d'installation",
            "token_expired": "Token expiré",
        }.get(event_type, event_type)

        payload = {
            "@type": "MessageCard",
            "themeColor": color,
            "summary": f"Tactical RMM - {title}",
            "sections": [{
                "activityTitle": f"Tactical RMM - {title}",
                "text": message.replace('\n', '<br>'),
            }]
        }
        data_bytes = json.dumps(payload).encode('utf-8')
        req = Request(self.webhook_url, data=data_bytes, headers={'Content-Type': 'application/json'})
        try:
            urlopen(req, timeout=10)
        except URLError as e:
            logger.error("Erreur Teams webhook: %s", e)


class GenericWebhookHandler(NotificationHandler):
    """Handler pour les webhooks génériques"""

    def __init__(self, webhook_url: str) -> None:
        self.webhook_url = webhook_url

    def send(self, event_type: str, message: str, data: dict[str, Any]) -> None:
        payload = {
            "event": event_type,
            "message": message,
            "data": data,
            "source": "tactical-rmm-linux-deployment",
        }
        data_bytes = json.dumps(payload).encode('utf-8')
        req = Request(self.webhook_url, data=data_bytes, headers={'Content-Type': 'application/json'})
        try:
            urlopen(req, timeout=10)
        except URLError as e:
            logger.error("Erreur webhook générique: %s", e)


# Instance globale
notification_manager = NotificationManager()
