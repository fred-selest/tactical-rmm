"""Tests des notifications (remplacent integration/backend/test_notifications.py)."""
from __future__ import annotations

import json
from urllib.error import URLError

import pytest

from integration.backend import notifications
from integration.backend.notifications import (
    DiscordNotificationHandler,
    GenericWebhookHandler,
    NotificationManager,
    SlackNotificationHandler,
    TeamsNotificationHandler,
)

from .conftest import callback_path, make_deployment

WEBHOOK = 'https://hooks.example.test/abc'
ENV_VARS = {
    'NOTIFICATION_SLACK_WEBHOOK': SlackNotificationHandler,
    'NOTIFICATION_DISCORD_WEBHOOK': DiscordNotificationHandler,
    'NOTIFICATION_TEAMS_WEBHOOK': TeamsNotificationHandler,
    'NOTIFICATION_GENERIC_WEBHOOK': GenericWebhookHandler,
}


@pytest.fixture
def sent(monkeypatch):
    """Capture les requêtes urlopen au lieu de les envoyer."""
    calls = []

    def fake_urlopen(req, timeout=None):
        calls.append({
            'url': req.full_url,
            'timeout': timeout,
            'content_type': req.get_header('Content-type'),
            'payload': json.loads(req.data.decode('utf-8')),
        })

    monkeypatch.setattr(notifications, 'urlopen', fake_urlopen)
    return calls


@pytest.fixture
def clean_env(monkeypatch):
    for var in ENV_VARS:
        monkeypatch.delenv(var, raising=False)


def test_manager_has_no_handler_without_env(clean_env):
    assert NotificationManager().handlers == []


@pytest.mark.parametrize('var, handler_cls', ENV_VARS.items())
def test_manager_configures_handler_from_env(clean_env, monkeypatch, var, handler_cls):
    monkeypatch.setenv(var, WEBHOOK)
    handlers = NotificationManager().handlers
    assert [type(h) for h in handlers] == [handler_cls]
    assert handlers[0].webhook_url == WEBHOOK


def test_manager_configures_all_handlers(clean_env, monkeypatch):
    for var in ENV_VARS:
        monkeypatch.setenv(var, WEBHOOK)
    assert len(NotificationManager().handlers) == 4


def test_slack_payload(sent):
    SlackNotificationHandler(WEBHOOK).send('installation_success', 'msg', {})
    (call,) = sent
    assert call['url'] == WEBHOOK and call['timeout'] == 10
    assert call['content_type'] == 'application/json'
    attachment = call['payload']['attachments'][0]
    assert attachment['title'] == 'Tactical RMM - Installation réussie'
    assert attachment['color'] == '#36a64f'
    assert attachment['text'] == 'msg'


def test_slack_failure_color(sent):
    SlackNotificationHandler(WEBHOOK).send('installation_failure', 'msg', {})
    assert sent[0]['payload']['attachments'][0]['color'] == '#dc3545'


def test_discord_payload(sent):
    DiscordNotificationHandler(WEBHOOK).send('token_expired', 'msg', {})
    embed = sent[0]['payload']['embeds'][0]
    assert embed['title'] == 'Tactical RMM - Token expiré'
    assert embed['description'] == 'msg'


def test_teams_payload(sent):
    TeamsNotificationHandler(WEBHOOK).send('installation_success', 'a\nb', {})
    payload = sent[0]['payload']
    assert payload['@type'] == 'MessageCard'
    assert payload['sections'][0]['text'] == 'a<br>b'


def test_generic_payload(sent):
    GenericWebhookHandler(WEBHOOK).send('installation_success', 'msg', {'hostname': 'h'})
    assert sent[0]['payload'] == {
        'event': 'installation_success', 'message': 'msg',
        'data': {'hostname': 'h'}, 'source': 'tactical-rmm-linux-deployment',
    }


@pytest.mark.parametrize('error', [URLError('down'), TimeoutError('slow'), RuntimeError('bug')])
def test_handler_errors_never_propagate(monkeypatch, clean_env, error):
    def boom(req, timeout=None):
        raise error

    monkeypatch.setattr(notifications, 'urlopen', boom)
    monkeypatch.setenv('NOTIFICATION_SLACK_WEBHOOK', WEBHOOK)
    monkeypatch.setenv('NOTIFICATION_GENERIC_WEBHOOK', WEBHOOK)
    NotificationManager().notify_installation_failure('u', 'c', 's', 'h', 'e')  # ne lève pas


def test_failure_message_content(sent, clean_env, monkeypatch):
    monkeypatch.setenv('NOTIFICATION_GENERIC_WEBHOOK', WEBHOOK)
    NotificationManager().notify_installation_failure('uuid-1', 'ACME', 'Paris', 'srv01', '')
    message = sent[0]['payload']['message']
    assert 'ACME' in message and 'srv01' in message and 'Erreur: Inconnue' in message


@pytest.mark.django_db
@pytest.mark.parametrize('status, method', [
    ('success', 'notify_installation_success'),
    ('failed', 'notify_installation_failure'),
])
def test_callback_triggers_notification(anon_client, monkeypatch, status, method):
    calls = []
    monkeypatch.setattr(notifications.notification_manager, method, lambda **kw: calls.append(kw))
    dep = make_deployment(client_name='ACME')
    anon_client.post(callback_path(dep), {
        'hostname': 'srv01', 'status': status, 'one_time_token': dep.one_time_token,
    })
    assert len(calls) == 1
    assert calls[0]['client_name'] == 'ACME' and calls[0]['hostname'] == 'srv01'


@pytest.mark.django_db
def test_rejected_callback_does_not_notify(anon_client, monkeypatch):
    calls = []
    monkeypatch.setattr(notifications.notification_manager, '_send_all', lambda *a: calls.append(a))
    dep = make_deployment()
    anon_client.post(callback_path(dep), {'hostname': 'h', 'status': 'success', 'one_time_token': 'bad'})
    assert calls == []
