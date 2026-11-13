"""Tests fonctionnels de l'API (remplacent integration/backend/test_api_integration.py)."""
from __future__ import annotations

from datetime import timedelta

import pytest
from django.utils import timezone

from integration.backend.models import DeploymentLog, LinuxDeployment

from .conftest import callback_path, make_deployment, signed_path

pytestmark = pytest.mark.django_db

BASE = '/api/v3/linux-deployments/'
CREATE_URL = f'{BASE}create/'
STATS_URL = f'{BASE}stats/'

PAYLOAD = {
    'client_id': 12, 'client_name': 'ACME', 'site_id': 34, 'site_name': 'Paris',
    'agent_type': 'workstation', 'arch': 'arm64', 'expires_days': 10,
    'enable_ping': False, 'enable_rdp': True, 'install_mesh': True,
}


def test_full_deployment_flow(admin_client, anon_client):
    """Création → téléchargement du script → callback → statistiques."""
    created = admin_client.post(CREATE_URL, PAYLOAD, format='json')
    assert created.status_code == 201
    data = created.data
    for key in ('client_name', 'site_name', 'agent_type', 'arch', 'enable_rdp'):
        assert data[key] == PAYLOAD[key]
    assert data['created_by'] == 'admin'
    assert data['is_expired'] is False
    assert data['deployment_url'] in data['install_command']

    dep = LinuxDeployment.objects.get(uuid=data['uuid'])
    assert DeploymentLog.objects.filter(deployment=dep, action='created').exists()

    script = anon_client.get(signed_path(dep))
    assert script.status_code == 200
    assert script['Content-Type'] == 'text/x-shellscript'
    assert script['Cache-Control'] == 'no-store'
    body = script.content.decode()
    assert body.startswith('#!/bin/bash')
    for expected in ("CLIENT_ID=12", "SITE_ID=34", "AGENT_TYPE=workstation",
                     f"AUTH_KEY={dep.auth_key}", f"ONE_TIME_TOKEN={dep.one_time_token}"):
        assert expected in body

    done = anon_client.post(callback_path(dep), {
        'hostname': 'srv01', 'status': 'success', 'one_time_token': dep.one_time_token,
    })
    assert done.status_code == 200

    stats = admin_client.get(STATS_URL).data
    assert stats == {
        'total_deployments': 1, 'active_deployments': 1, 'expired_deployments': 0,
        'total_downloads': 1, 'total_installations': 1, 'success_rate': 100.0,
    }


def test_create_requires_fields(admin_client):
    resp = admin_client.post(CREATE_URL, {}, format='json')
    assert resp.status_code == 400
    assert set(resp.data['details']) >= {'client_id', 'client_name', 'site_id', 'site_name'}


def test_create_applies_defaults(admin_client):
    resp = admin_client.post(CREATE_URL, {
        'client_id': 1, 'client_name': 'C', 'site_id': 1, 'site_name': 'S',
    }, format='json')
    assert resp.status_code == 201
    dep = LinuxDeployment.objects.get(uuid=resp.data['uuid'])
    assert (dep.agent_type, dep.arch, dep.enable_ping, dep.enable_rdp) == ('server', 'amd64', True, False)
    assert timedelta(days=29) < dep.expires_at - timezone.now() <= timedelta(days=30)


def test_create_generates_distinct_secrets(admin_client):
    uuids = [
        admin_client.post(CREATE_URL, {'client_id': 1, 'client_name': 'C', 'site_id': 1, 'site_name': 'S'},
                          format='json').data['uuid']
        for _ in range(3)
    ]
    deps = LinuxDeployment.objects.filter(uuid__in=uuids)
    for field in ('auth_key', 'signing_token', 'one_time_token', 'signature_secret'):
        assert len({getattr(d, field) for d in deps}) == 3


def test_list_filters(admin_client):
    a = make_deployment(client_id=1, site_id=10)
    b = make_deployment(client_id=1, site_id=20)
    c = make_deployment(client_id=2, site_id=30)

    def uuids(query=''):
        return {d['uuid'] for d in admin_client.get(f'{BASE}{query}').data}

    assert uuids() == {str(a.uuid), str(b.uuid), str(c.uuid)}
    assert uuids('?client_id=1') == {str(a.uuid), str(b.uuid)}
    assert uuids('?site_id=20') == {str(b.uuid)}
    assert admin_client.get(f'{BASE}?client_id=abc').status_code == 400
    assert admin_client.get(f'{BASE}?site_id=1;DROP').status_code == 400


def test_list_is_ordered_newest_first(admin_client):
    old = make_deployment()
    LinuxDeployment.objects.filter(pk=old.pk).update(created_at=timezone.now() - timedelta(days=1))
    new = make_deployment()
    assert [d['uuid'] for d in admin_client.get(BASE).data] == [str(new.uuid), str(old.uuid)]


def test_detail_and_delete(admin_client):
    dep = make_deployment()
    url = f'{BASE}{dep.uuid}/'
    assert admin_client.get(url).data['uuid'] == str(dep.uuid)
    assert admin_client.delete(url).status_code == 204
    assert admin_client.get(url).status_code == 404
    assert admin_client.delete(url).status_code == 404


def test_unknown_uuid_on_public_endpoints(anon_client):
    unknown = '00000000-0000-0000-0000-000000000000'
    assert anon_client.get(f'/clients/{unknown}/deploy/linux/').status_code == 404
    assert anon_client.post(f'{BASE}{unknown}/installed/', {}).status_code == 404


def test_failed_callback_does_not_consume_token(anon_client):
    dep = make_deployment()
    body = {'hostname': 'h', 'one_time_token': dep.one_time_token}
    assert anon_client.post(callback_path(dep), {**body, 'status': 'failed', 'error': 'boom'}).status_code == 200
    dep.refresh_from_db()
    assert not dep.token_used and dep.agents_installed == 0
    log = DeploymentLog.objects.get(deployment=dep, action='installed_failed')
    assert log.error_message == 'boom'
    # Une nouvelle tentative réussie reste possible
    assert anon_client.post(callback_path(dep), {**body, 'status': 'success'}).status_code == 200


def test_callback_strips_control_characters_from_hostname(anon_client):
    dep = make_deployment()
    anon_client.post(callback_path(dep), {
        'hostname': 'srv\n01\x1b[31m', 'status': 'failed', 'one_time_token': dep.one_time_token,
    })
    assert DeploymentLog.objects.get(deployment=dep, action='installed_failed').hostname == 'srv01[31m'


def test_stats_empty(admin_client):
    assert admin_client.get(STATS_URL).data == {
        'total_deployments': 0, 'active_deployments': 0, 'expired_deployments': 0,
        'total_downloads': 0, 'total_installations': 0, 'success_rate': 0,
    }


def test_stats_counts_active_and_expired(admin_client):
    make_deployment(download_count=4, agents_installed=1)
    make_deployment(expires_at=timezone.now() - timedelta(days=1), download_count=4, agents_installed=2)
    stats = admin_client.get(STATS_URL).data
    assert (stats['active_deployments'], stats['expired_deployments']) == (1, 1)
    assert stats['success_rate'] == 37.5
