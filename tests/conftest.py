"""Fixtures partagées par toute la suite de tests."""
from __future__ import annotations

from datetime import timedelta
from urllib.parse import urlparse

import pytest
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.utils import timezone
from rest_framework.test import APIClient

from integration.backend import notifications
from integration.backend.models import LinuxDeployment


@pytest.fixture(autouse=True)
def _clear_cache():
    """Remet à zéro les compteurs de throttling entre deux tests."""
    cache.clear()
    yield
    cache.clear()


@pytest.fixture(autouse=True)
def _no_real_notifications(monkeypatch):
    """Aucun test ne doit envoyer de vraie requête HTTP vers un webhook."""
    monkeypatch.setattr(notifications.notification_manager, 'handlers', [])


@pytest.fixture
def admin_client(db):
    user = get_user_model().objects.create_superuser('admin', 'admin@example.test', 'pw')
    client = APIClient()
    client.force_authenticate(user)
    return client


@pytest.fixture
def anon_client():
    return APIClient()


def make_deployment(**overrides) -> LinuxDeployment:
    values = dict(
        client_id=1, client_name='Client', site_id=1, site_name='Site',
        api_url='https://api.example.test', mesh_url='https://mesh.example.test/x',
        auth_key='agentauthkey',
        signing_token=LinuxDeployment.generate_signing_token(),
        one_time_token=LinuxDeployment.generate_one_time_token(),
        signature_secret=LinuxDeployment.generate_signature_secret(),
        expires_at=timezone.now() + timedelta(days=30), created_by='admin',
    )
    values.update(overrides)
    return LinuxDeployment.objects.create(**values)


def signed_path(dep: LinuxDeployment) -> str:
    """Chemin + query de l'URL signée, utilisable avec APIClient."""
    parsed = urlparse(dep.get_signed_url())
    return f'{parsed.path}?{parsed.query}'


def callback_path(dep: LinuxDeployment) -> str:
    return f'/api/v3/linux-deployments/{dep.uuid}/installed/'
