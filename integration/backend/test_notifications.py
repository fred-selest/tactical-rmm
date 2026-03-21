"""
Tests unitaires pour le système de notifications.

Usage:
    python -m pytest test_notifications.py -v
"""
from __future__ import annotations

import json
import unittest
from unittest.mock import MagicMock, patch

from notifications import (
    DiscordNotificationHandler,
    GenericWebhookHandler,
    NotificationManager,
    SlackNotificationHandler,
    TeamsNotificationHandler,
)


class TestNotificationManager(unittest.TestCase):
    """Tests pour le gestionnaire de notifications"""

    def test_manager_initializes_empty_without_env(self) -> None:
        """Test initialisation sans variables d'environnement"""
        with patch.dict('os.environ', {}, clear=True):
            manager = NotificationManager()
            self.assertEqual(len(manager.handlers), 0)

    @patch.dict('os.environ', {'NOTIFICATION_SLACK_WEBHOOK': 'https://hooks.slack.com/test'})
    def test_manager_configures_slack(self) -> None:
        """Test configuration Slack depuis l'environnement"""
        manager = NotificationManager()
        slack_handlers = [h for h in manager.handlers if isinstance(h, SlackNotificationHandler)]
        self.assertEqual(len(slack_handlers), 1)

    @patch.dict('os.environ', {'NOTIFICATION_DISCORD_WEBHOOK': 'https://discord.com/api/webhooks/test'})
    def test_manager_configures_discord(self) -> None:
        """Test configuration Discord depuis l'environnement"""
        manager = NotificationManager()
        discord_handlers = [h for h in manager.handlers if isinstance(h, DiscordNotificationHandler)]
        self.assertEqual(len(discord_handlers), 1)


class TestSlackNotificationHandler(unittest.TestCase):
    """Tests pour le handler Slack"""

    def setUp(self) -> None:
        self.handler = SlackNotificationHandler('https://hooks.slack.com/test')

    @patch('notifications.urlopen')
    def test_send_success_notification(self, mock_urlopen) -> None:
        """Test envoi de notification de succès"""
        mock_urlopen.return_value = MagicMock()
        self.handler.send(
            'installation_success',
            'Agent installé',
            {'hostname': 'test-server'},
        )
        mock_urlopen.assert_called_once()

    @patch('notifications.urlopen')
    def test_send_failure_notification(self, mock_urlopen) -> None:
        """Test envoi de notification d'échec"""
        mock_urlopen.return_value = MagicMock()
        self.handler.send(
            'installation_failure',
            'Échec installation',
            {'hostname': 'test-server', 'error': 'timeout'},
        )
        mock_urlopen.assert_called_once()


class TestDiscordNotificationHandler(unittest.TestCase):
    """Tests pour le handler Discord"""

    def setUp(self) -> None:
        self.handler = DiscordNotificationHandler('https://discord.com/api/webhooks/test')

    @patch('notifications.urlopen')
    def test_send_notification(self, mock_urlopen) -> None:
        """Test envoi de notification Discord"""
        mock_urlopen.return_value = MagicMock()
        self.handler.send(
            'installation_success',
            'Agent installé',
            {'hostname': 'test-server'},
        )
        mock_urlopen.assert_called_once()


class TestTeamsNotificationHandler(unittest.TestCase):
    """Tests pour le handler Teams"""

    def setUp(self) -> None:
        self.handler = TeamsNotificationHandler('https://outlook.office.com/webhook/test')

    @patch('notifications.urlopen')
    def test_send_notification(self, mock_urlopen) -> None:
        """Test envoi de notification Teams"""
        mock_urlopen.return_value = MagicMock()
        self.handler.send(
            'token_expired',
            'Token expiré',
            {'deployment_uuid': 'test-uuid'},
        )
        mock_urlopen.assert_called_once()


class TestGenericWebhookHandler(unittest.TestCase):
    """Tests pour le handler webhook générique"""

    def setUp(self) -> None:
        self.handler = GenericWebhookHandler('https://example.com/webhook')

    @patch('notifications.urlopen')
    def test_send_notification(self, mock_urlopen) -> None:
        """Test envoi de notification webhook"""
        mock_urlopen.return_value = MagicMock()
        self.handler.send(
            'installation_success',
            'Test message',
            {'key': 'value'},
        )
        mock_urlopen.assert_called_once()

    @patch('notifications.urlopen')
    def test_payload_format(self, mock_urlopen) -> None:
        """Test format du payload webhook"""
        mock_urlopen.return_value = MagicMock()
        self.handler.send(
            'installation_success',
            'Test message',
            {'hostname': 'srv01'},
        )

        # Vérifier que le payload contient les bonnes clés
        call_args = mock_urlopen.call_args
        request = call_args[0][0]
        payload = json.loads(request.data.decode('utf-8'))

        self.assertEqual(payload['event'], 'installation_success')
        self.assertEqual(payload['message'], 'Test message')
        self.assertEqual(payload['source'], 'tactical-rmm-linux-deployment')
        self.assertEqual(payload['data']['hostname'], 'srv01')


if __name__ == '__main__':
    unittest.main(verbosity=2)
