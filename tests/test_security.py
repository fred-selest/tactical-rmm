"""
Tests de non-régression des correctifs de sécurité de l'intégration Linux.
Ils exécutent les vraies vues, modèles et serializers (pas de mocks).
"""
from __future__ import annotations

import shutil
import subprocess
from datetime import timedelta
from urllib.parse import parse_qs, urlparse

import pytest
from django.contrib.auth import get_user_model
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from integration.backend.models import DeploymentLog, LinuxDeployment
from integration.backend.views import generate_install_script

from .conftest import callback_path, make_deployment, signed_path

pytestmark = pytest.mark.django_db

CREATE_URL = '/api/v3/linux-deployments/create/'
LIST_URL = '/api/v3/linux-deployments/'


def script_path(dep: LinuxDeployment) -> str:
    return f'/clients/{dep.uuid}/deploy/linux/'


# --- 1. Injection de commandes dans le script généré -------------------------

MALICIOUS = 'Evil"; touch /tmp/pwned; echo "$(id)`id`'


def test_create_rejects_control_characters_in_names(admin_client):
    resp = admin_client.post(CREATE_URL, {
        'client_id': 1, 'client_name': 'Client\n; rm -rf /', 'site_id': 1, 'site_name': 'Site',
    }, format='json')
    assert resp.status_code == 400
    assert 'client_name' in resp.data['details']


def test_script_quotes_all_dynamic_values():
    dep = make_deployment(client_name=MALICIOUS, site_name=MALICIOUS)
    script = generate_install_script(dep)
    # La valeur n'apparaît que dans une affectation entre quotes simples ou en commentaire
    for line in script.splitlines():
        if MALICIOUS in line:
            assert line.startswith('# ') or line.startswith(("CLIENT_NAME='", "SITE_NAME='")), line


@pytest.mark.skipif(shutil.which('bash') is None, reason='bash indisponible')
def test_script_does_not_execute_injected_payload(tmp_path):
    marker = tmp_path / 'pwned'
    payload = f'X"; touch {marker.as_posix()}; echo "$(touch {marker.as_posix()})'
    dep = make_deployment(client_name=payload, site_name=payload)
    script = generate_install_script(dep)

    # Syntaxe valide
    subprocess.run(['bash', '-n'], input=script.encode(), check=True)

    # N'exécute que le bloc d'affectations puis affiche les variables
    lines = script.splitlines()
    start = next(i for i, ln in enumerate(lines) if ln.startswith('CLIENT_NAME='))
    end = next(i for i, ln in enumerate(lines) if ln.startswith('ONE_TIME_TOKEN='))
    snippet = '\n'.join(lines[start:end + 1]) + '\nprintf "%s" "$CLIENT_NAME"\n'
    out = subprocess.run(['bash', '-c', snippet], capture_output=True, check=True)
    assert out.stdout.decode() == payload
    assert not marker.exists()


# --- 2. Validation des entrées à la création ---------------------------------

@pytest.mark.parametrize('payload_update, field', [
    ({'expires_days': 'abc'}, 'expires_days'),
    ({'expires_days': 0}, 'expires_days'),
    ({'expires_days': 1000}, 'expires_days'),
    ({'custom_script_url': 'http://evil.example/x.sh'}, 'custom_script_url'),
    ({'mesh_url': 'http://mesh.example/x'}, 'mesh_url'),
    ({'agent_type': 'rootkit'}, 'agent_type'),
    ({'client_id': -1}, 'client_id'),
])
def test_create_validates_input(admin_client, payload_update, field):
    payload = {'client_id': 1, 'client_name': 'C', 'site_id': 1, 'site_name': 'S', **payload_update}
    resp = admin_client.post(CREATE_URL, payload, format='json')
    assert resp.status_code == 400
    assert field in resp.data['details']


def test_create_success_uses_settings_and_hides_secrets(admin_client):
    resp = admin_client.post(CREATE_URL, {
        'client_id': 1, 'client_name': 'C', 'site_id': 1, 'site_name': 'S', 'expires_days': 7,
    }, format='json')
    assert resp.status_code == 201
    dep = LinuxDeployment.objects.get(uuid=resp.data['uuid'])
    assert dep.api_url == 'https://api.example.test'
    assert dep.mesh_url == 'https://mesh.example.test/meshagents?id=abc'
    assert timedelta(days=6) < dep.expires_at - timezone.now() <= timedelta(days=7)
    assert 'sig=' in resp.data['deployment_url']


@override_settings(LINUX_DEPLOYMENT_MESH_URL='')
def test_create_requires_mesh_url_when_mesh_enabled(admin_client):
    resp = admin_client.post(CREATE_URL, {
        'client_id': 1, 'client_name': 'C', 'site_id': 1, 'site_name': 'S',
    }, format='json')
    assert resp.status_code == 400


# --- 3. Signature HMAC obligatoire -------------------------------------------

def test_download_without_signature_is_refused(anon_client):
    dep = make_deployment()
    resp = anon_client.get(script_path(dep))
    assert resp.status_code == 403
    assert dep.auth_key.encode() not in resp.content
    assert DeploymentLog.objects.filter(deployment=dep, action='invalid_signature').exists()


def test_download_with_bad_signature_is_refused(anon_client):
    dep = make_deployment()
    t = int(dep.expires_at.timestamp())
    resp = anon_client.get(f'{script_path(dep)}?t={t}&sig={"0" * 64}')
    assert resp.status_code == 403


def test_signature_cannot_be_reused_with_other_timestamp(anon_client):
    dep = make_deployment()
    sig = parse_qs(urlparse(dep.get_signed_url()).query)['sig'][0]
    t = int(dep.expires_at.timestamp()) + 86400 * 365
    resp = anon_client.get(f'{script_path(dep)}?t={t}&sig={sig}')
    assert resp.status_code == 403


def test_non_ascii_signature_does_not_crash(anon_client):
    dep = make_deployment()
    resp = anon_client.get(f'{script_path(dep)}?t=1&sig=%C3%A9')
    assert resp.status_code == 403


def test_signed_url_from_model_is_accepted(anon_client):
    dep = make_deployment()
    resp = anon_client.get(signed_path(dep))
    assert resp.status_code == 200
    assert dep.auth_key.encode() in resp.content
    dep.refresh_from_db()
    assert dep.download_count == 1


def test_expired_deployment_is_refused(anon_client):
    dep = make_deployment(expires_at=timezone.now() - timedelta(minutes=1))
    resp = anon_client.get(signed_path(dep))
    assert resp.status_code == 410


# --- 4. One-time token obligatoire sur le callback ---------------------------

def test_callback_without_token_is_refused(anon_client):
    dep = make_deployment()
    resp = anon_client.post(callback_path(dep), {'hostname': 'h', 'status': 'success'}, format='json')
    assert resp.status_code == 403
    dep.refresh_from_db()
    assert dep.agents_installed == 0


def test_callback_with_wrong_token_is_refused(anon_client):
    dep = make_deployment()
    resp = anon_client.post(callback_path(dep), {
        'hostname': 'h', 'status': 'success', 'one_time_token': 'nope',
    }, format='json')
    assert resp.status_code == 403


def test_callback_rejects_unknown_status(anon_client):
    dep = make_deployment()
    resp = anon_client.post(callback_path(dep), {
        'hostname': 'h', 'status': 'pwned', 'one_time_token': dep.one_time_token,
    }, format='json')
    assert resp.status_code == 400


def test_callback_success_consumes_token_once(anon_client):
    dep = make_deployment()
    body = {'hostname': 'h', 'status': 'success', 'one_time_token': dep.one_time_token}
    assert anon_client.post(callback_path(dep), body, format='json').status_code == 200
    assert anon_client.post(callback_path(dep), body, format='json').status_code == 410
    dep.refresh_from_db()
    assert dep.token_used and dep.agents_installed == 1


def test_callback_accepts_form_encoded_body_sent_by_script(anon_client):
    dep = make_deployment()
    resp = anon_client.post(callback_path(dep), {
        'hostname': 'srv01', 'status': 'failed', 'one_time_token': dep.one_time_token,
    })  # multipart/form, comme curl --data-urlencode (form)
    assert resp.status_code == 200
    assert DeploymentLog.objects.filter(deployment=dep, action='installed_failed', hostname='srv01').exists()


# --- 5. Secrets non exposés par l'API ----------------------------------------

SECRET_FIELDS = ('auth_key', 'signing_token', 'one_time_token', 'signature_secret')


def test_list_and_detail_do_not_expose_secrets(admin_client):
    dep = make_deployment()
    listed = admin_client.get(LIST_URL).data[0]
    detail = admin_client.get(f'{LIST_URL}{dep.uuid}/').data
    for data in (listed, detail):
        for field in SECRET_FIELDS:
            assert field not in data


# --- 6. Contrôle d'accès ------------------------------------------------------

def test_regular_user_without_role_is_forbidden():
    user = get_user_model().objects.create_user('bob', password='pw')
    client = APIClient()
    client.force_authenticate(user)
    dep = make_deployment()
    assert client.get(LIST_URL).status_code == 403
    assert client.delete(f'{LIST_URL}{dep.uuid}/').status_code == 403
    assert LinuxDeployment.objects.filter(pk=dep.pk).exists()


def test_access_is_filtered_per_client(monkeypatch):
    from integration.backend import security

    monkeypatch.setattr(security, '_has_perm', lambda request, perm: True)
    monkeypatch.setattr(security, '_has_perm_on_client', lambda user, client_id: client_id == 1)

    user = get_user_model().objects.create_user('tech', password='pw')
    client = APIClient()
    client.force_authenticate(user)
    mine = make_deployment(client_id=1)
    other = make_deployment(client_id=2)

    uuids = [d['uuid'] for d in client.get(LIST_URL).data]
    assert uuids == [str(mine.uuid)]
    assert client.get(f'{LIST_URL}{other.uuid}/').status_code == 404
    assert client.delete(f'{LIST_URL}{other.uuid}/').status_code == 404
    assert LinuxDeployment.objects.filter(pk=other.pk).exists()
    assert client.get('/api/v3/linux-deployments/stats/').data['total_deployments'] == 1
    assert client.post(CREATE_URL, {
        'client_id': 2, 'client_name': 'C', 'site_id': 1, 'site_name': 'S',
    }, format='json').status_code == 403
    csv = client.get('/api/v3/linux-deployments/export/csv/').content.decode()
    assert str(mine.uuid) in csv and str(other.uuid) not in csv


def test_anonymous_cannot_access_management_api(anon_client):
    assert anon_client.get(LIST_URL).status_code in (401, 403)
    assert anon_client.get('/api/v3/linux-deployments/export/json/').status_code in (401, 403)


# --- 7. X-Forwarded-For non fiable ------------------------------------------

def test_spoofed_x_forwarded_for_is_ignored_by_default(anon_client):
    dep = make_deployment()
    anon_client.get(signed_path(dep), HTTP_X_FORWARDED_FOR='6.6.6.6', REMOTE_ADDR='10.0.0.5')
    log = DeploymentLog.objects.get(deployment=dep, action='downloaded')
    assert log.ip_address == '10.0.0.5'


@override_settings(LINUX_DEPLOYMENT_TRUSTED_PROXY_COUNT=1)
def test_x_forwarded_for_uses_proxy_appended_value():
    from django.test import RequestFactory

    from integration.backend.security import get_client_ip

    req = RequestFactory().get('/', HTTP_X_FORWARDED_FOR='6.6.6.6, 203.0.113.7', REMOTE_ADDR='127.0.0.1')
    assert get_client_ip(req) == '203.0.113.7'
    req = RequestFactory().get('/', HTTP_X_FORWARDED_FOR='not-an-ip', REMOTE_ADDR='127.0.0.1')
    assert get_client_ip(req) == '127.0.0.1'


def test_throttle_cannot_be_bypassed_by_rotating_x_forwarded_for(anon_client):
    dep = make_deployment()
    path = signed_path(dep)
    codes = [
        anon_client.get(path, HTTP_X_FORWARDED_FOR=f'1.2.3.{i}').status_code
        for i in range(12)
    ]
    assert 429 in codes


# --- 8. Opérations atomiques --------------------------------------------------

def test_use_one_time_token_is_atomic_on_stale_instances():
    dep = make_deployment()
    stale_a = LinuxDeployment.objects.get(pk=dep.pk)
    stale_b = LinuxDeployment.objects.get(pk=dep.pk)
    stale_a.use_one_time_token()
    with pytest.raises(ValueError):
        stale_b.use_one_time_token()  # l'instance en mémoire croit encore token_used=False


def test_counters_use_database_increment():
    dep = make_deployment()
    stale = LinuxDeployment.objects.get(pk=dep.pk)
    dep.increment_download()
    stale.increment_download()  # n'écrase pas l'incrément précédent
    dep.refresh_from_db()
    assert dep.download_count == 2


def test_install_command_is_shell_safe():
    dep = make_deployment()
    cmd = dep.get_install_command()
    assert "'" + dep.get_signed_url() + "'" in cmd  # l'URL contient '&' : elle doit être quotée
