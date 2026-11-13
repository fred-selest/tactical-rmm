"""
Système de notifications pour les déploiements Linux.
Supporte: Slack, Discord, Microsoft Teams, Webhooks génériques.

Configuration via les variables d'environnement :
    NOTIFICATION_SLACK_WEBHOOK=https://hooks.slack.com/...
    NOTIFICATION_DISCORD_WEBHOOK=https://discord.com/api/webhooks/...
    NOTIFICATION_TEAMS_WEBHOOK=https://outlook.office.com/webhook/...
    NOTIFICATION_GENERIC_WEBHOOK=https://your-service.com/webhook

Les envois sont faits en arrière-plan (pool de threads), après la validation
de la transaction en cours : un webhook lent ou injoignable ne bloque jamais
la requête HTTP du script d'installation. Mettre
``LINUX_DEPLOYMENT_NOTIFICATIONS_ASYNC = False`` dans les settings pour un
envoi synchrone (tests, débogage).
"""
from __future__ import annotations

import json
import logging
import os
from concurrent.futures import ThreadPoolExecutor
from typing import Any
from urllib.request import Request, urlopen

from django.conf import settings
from django.db import transaction

logger = logging.getLogger(__name__)

WEBHOOK_TIMEOUT = 10  # secondes

EVENT_TITLES = {
    "installation_success": "Installation réussie",
    "installation_failure": "Échec d'installation",
    "token_expired": "Token expiré",
}

# Pool partagé et borné : au plus 2 envois simultanés, les autres attendent
_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix='linux-deploy-notify')


def _title(event_type: str) -> str:
    return f"Tactical RMM - {EVENT_TITLES.get(event_type, event_type)}"


def _is_success(event_type: str) -> bool:
    return event_type == "installation_success"


class NotificationHandler:
    """Classe de base : construit un payload JSON et le poste sur un webhook."""

    name = "webhook"

    def __init__(self, webhook_url: str) -> None:
        self.webhook_url = webhook_url

    def build_payload(self, event_type: str, message: str, data: dict[str, Any]) -> dict[str, Any]:
        raise NotImplementedError

    def send(self, event_type: str, message: str, data: dict[str, Any]) -> None:
        body = json.dumps(self.build_payload(event_type, message, data)).encode('utf-8')
        req = Request(self.webhook_url, data=body, headers={'Content-Type': 'application/json'})
        # Toute exception (URLError, timeout, HTTPError...) est gérée par NotificationManager
        with urlopen(req, timeout=WEBHOOK_TIMEOUT):
            pass


class SlackNotificationHandler(NotificationHandler):
    """Handler pour les notifications Slack"""

    name = "Slack"

    def build_payload(self, event_type: str, message: str, data: dict[str, Any]) -> dict[str, Any]:
        return {
            "attachments": [{
                "color": "#36a64f" if _is_success(event_type) else "#dc3545",
                "title": _title(event_type),
                "text": message,
                "footer": "Tactical RMM Linux Deployment",
            }]
        }


class DiscordNotificationHandler(NotificationHandler):
    """Handler pour les notifications Discord"""

    name = "Discord"

    def build_payload(self, event_type: str, message: str, data: dict[str, Any]) -> dict[str, Any]:
        return {
            "embeds": [{
                "title": _title(event_type),
                "description": message,
                "color": 0x36A64F if _is_success(event_type) else 0xDC3545,
            }]
        }


class TeamsNotificationHandler(NotificationHandler):
    """Handler pour les notifications Microsoft Teams"""

    name = "Teams"

    def build_payload(self, event_type: str, message: str, data: dict[str, Any]) -> dict[str, Any]:
        return {
            "@type": "MessageCard",
            "themeColor": "00FF00" if _is_success(event_type) else "FF0000",
            "summary": _title(event_type),
            "sections": [{
                "activityTitle": _title(event_type),
                "text": message.replace('\n', '<br>'),
            }]
        }


class GenericWebhookHandler(NotificationHandler):
    """Handler pour les webhooks génériques"""

    name = "générique"

    def build_payload(self, event_type: str, message: str, data: dict[str, Any]) -> dict[str, Any]:
        return {
            "event": event_type,
            "message": message,
            "data": data,
            "source": "tactical-rmm-linux-deployment",
        }


ENV_HANDLERS: dict[str, type[NotificationHandler]] = {
    'NOTIFICATION_SLACK_WEBHOOK': SlackNotificationHandler,
    'NOTIFICATION_DISCORD_WEBHOOK': DiscordNotificationHandler,
    'NOTIFICATION_TEAMS_WEBHOOK': TeamsNotificationHandler,
    'NOTIFICATION_GENERIC_WEBHOOK': GenericWebhookHandler,
}


class NotificationManager:
    """Gestionnaire centralisé des notifications"""

    def __init__(self) -> None:
        self.handlers: list[NotificationHandler] = []
        self._configure()

    def _configure(self) -> None:
        """Configure les handlers depuis les variables d'environnement"""
        for env_var, handler_cls in ENV_HANDLERS.items():
            url = os.environ.get(env_var)
            if url:
                self.handlers.append(handler_cls(url))

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
        """Envoie la notification à tous les handlers (en arrière-plan par défaut)"""
        if not self.handlers:
            return
        if getattr(settings, 'LINUX_DEPLOYMENT_NOTIFICATIONS_ASYNC', True):
            handlers = list(self.handlers)
            transaction.on_commit(
                lambda: _executor.submit(self._deliver, handlers, event_type, message, data)
            )
        else:
            self._deliver(self.handlers, event_type, message, data)

    @staticmethod
    def _deliver(
        handlers: list[NotificationHandler], event_type: str, message: str, data: dict[str, Any]
    ) -> None:
        for handler in handlers:
            try:
                handler.send(event_type, message, data)
            except Exception as e:  # noqa: BLE001 - une notification ne doit jamais faire échouer l'appelant
                logger.error(
                    "Erreur envoi notification %s via webhook %s: %s",
                    event_type, handler.name, e
                )


# Instance globale
notification_manager = NotificationManager()
