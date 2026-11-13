"""Tests du modèle LinuxDeployment (remplacent integration/backend/test_signing_tokens.py)."""
from __future__ import annotations

import re
from datetime import timedelta
from urllib.parse import parse_qs, urlparse

import pytest
from django.utils import timezone

from integration.backend.models import DeploymentLog, LinuxDeployment

from .conftest import make_deployment

pytestmark = pytest.mark.django_db


# --- Génération des tokens ----------------------------------------------------

def test_signing_token_is_64_hex_chars():
    assert re.fullmatch(r'[0-9a-f]{64}', LinuxDeployment.generate_signing_token())


def test_signature_secret_is_128_hex_chars():
    assert re.fullmatch(r'[0-9a-f]{128}', LinuxDeployment.generate_signature_secret())


def test_one_time_token_is_urlsafe_and_fits_column():
    token = LinuxDeployment.generate_one_time_token()
    assert re.fullmatch(r'[A-Za-z0-9_-]+', token)
    max_length = LinuxDeployment._meta.get_field('one_time_token').max_length
    assert 40 <= len(token) <= max_length


@pytest.mark.parametrize('generator', [
    LinuxDeployment.generate_signing_token,
    LinuxDeployment.generate_one_time_token,
    LinuxDeployment.generate_signature_secret,
])
def test_tokens_are_unique(generator):
    assert len({generator() for _ in range(200)}) == 200


# --- Signatures HMAC ------------------------------------------------------------

def test_signature_is_deterministic_and_secret_dependent():
    a = make_deployment()
    b = make_deployment()
    assert a.generate_signature('x') == a.generate_signature('x')
    assert a.generate_signature('x') != a.generate_signature('y')
    assert a.generate_signature('x') != b.generate_signature('x')


def test_validate_signature():
    dep = make_deployment()
    sig = dep.generate_signature('payload')
    assert dep.validate_signature('payload', sig)
    assert not dep.validate_signature('payload', sig[:-1] + ('0' if sig[-1] != '0' else '1'))
    assert not dep.validate_signature('other', sig)


def test_signed_url_format():
    dep = make_deployment()
    url = urlparse(dep.get_signed_url())
    query = parse_qs(url.query)
    assert f'{url.scheme}://{url.netloc}' == 'https://api.example.test'
    assert url.path == f'/clients/{dep.uuid}/deploy/linux/'
    assert query['t'] == [str(int(dep.expires_at.timestamp()))]
    assert dep.validate_signature(f"{dep.uuid}:{query['t'][0]}", query['sig'][0])


def test_signed_url_handles_trailing_slash_in_api_url():
    dep = make_deployment(api_url='https://api.example.test/')
    assert '//clients' not in dep.get_signed_url()


@pytest.mark.parametrize('t, sig, expected', [
    (None, None, (False, 403)),
    ('123', None, (False, 403)),
    ('abc', 'deadbeef', (False, 403)),
])
def test_check_signed_request_rejections(t, sig, expected):
    dep = make_deployment()
    ok, code, _ = dep.check_signed_request(t, sig)
    assert (ok, code) == expected


def test_check_signed_request_rejects_past_timestamp_even_if_signed():
    dep = make_deployment()
    past = int((timezone.now() - timedelta(minutes=1)).timestamp())
    ok, code, _ = dep.check_signed_request(str(past), dep.generate_signature(f'{dep.uuid}:{past}'))
    assert (ok, code) == (False, 410)


# --- One-time token et état ---------------------------------------------------

def test_fresh_deployment_can_be_used():
    dep = make_deployment()
    assert dep.is_token_valid()
    assert dep.can_be_used() == (True, 'OK')


def test_used_token_is_invalid():
    dep = make_deployment()
    dep.use_one_time_token()
    dep.refresh_from_db()
    assert dep.token_used and dep.token_used_at is not None
    assert not dep.is_token_valid()
    assert dep.can_be_used()[0] is False
    with pytest.raises(ValueError):
        dep.use_one_time_token()


def test_expired_deployment():
    dep = make_deployment(expires_at=timezone.now() - timedelta(seconds=1))
    assert dep.is_expired()
    assert not dep.is_token_valid()
    assert dep.can_be_used() == (False, "Ce lien de déploiement a expiré")


@pytest.mark.parametrize('provided', [None, '', 'wrong', 'é'])
def test_check_one_time_token_rejects_bad_values(provided):
    assert not make_deployment().check_one_time_token(provided)


def test_check_one_time_token_accepts_exact_value():
    dep = make_deployment()
    assert dep.check_one_time_token(dep.one_time_token)


# --- Divers -------------------------------------------------------------------

def test_script_url_defaults_and_custom():
    assert make_deployment().get_script_url().endswith('/rmmagent-linux.sh')
    custom = 'https://scripts.example.test/install.sh'
    assert make_deployment(custom_script_url=custom).get_script_url() == custom


def test_deleting_deployment_cascades_to_logs():
    dep = make_deployment()
    DeploymentLog.objects.create(deployment=dep, action='created')
    dep.delete()
    assert DeploymentLog.objects.count() == 0


def test_str_representations():
    dep = make_deployment(client_name='ACME', site_name='Paris')
    assert str(dep) == f'Linux Deployment {dep.uuid} - ACME/Paris'
    log = DeploymentLog.objects.create(deployment=dep, action='created')
    assert str(log).startswith(f'created - {dep.uuid}')
