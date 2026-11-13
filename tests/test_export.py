"""Tests des exports CSV / JSON (remplacent integration/backend/test_export.py)."""
from __future__ import annotations

import csv
import io
import json
from datetime import timedelta

import pytest
from django.utils import timezone

from .conftest import make_deployment

pytestmark = pytest.mark.django_db

CSV_URL = '/api/v3/linux-deployments/export/csv/'
JSON_URL = '/api/v3/linux-deployments/export/json/'


def read_csv(response) -> list[list[str]]:
    return list(csv.reader(io.StringIO(response.content.decode('utf-8')), delimiter=';'))


def test_csv_header_and_row(admin_client):
    dep = make_deployment(client_name='ACME; Inc', site_name='Paris', download_count=3, agents_installed=1)
    resp = admin_client.get(CSV_URL)
    assert resp.status_code == 200
    assert resp['Content-Type'].startswith('text/csv')
    assert 'attachment; filename="deployments_' in resp['Content-Disposition']

    rows = read_csv(resp)
    assert rows[0] == ['UUID', 'Client', 'Site', 'Type Agent', 'Architecture', 'Statut',
                       'Téléchargements', 'Installations', 'Créé le', 'Expire le', 'Créé par']
    assert rows[1][:8] == [str(dep.uuid), 'ACME; Inc', 'Paris', 'server', 'amd64', 'Actif', '3', '1']
    assert rows[1][10] == 'admin'


def test_csv_does_not_leak_secrets(admin_client):
    dep = make_deployment()
    content = admin_client.get(CSV_URL).content.decode()
    for secret in (dep.auth_key, dep.one_time_token, dep.signature_secret, dep.signing_token):
        assert secret not in content


@pytest.mark.parametrize('payload', ['=HYPERLINK("http://evil")', '+1+1', '-2+3', '@SUM(A1)'])
def test_csv_neutralises_formula_injection(admin_client, payload):
    make_deployment(client_name=payload)
    cell = read_csv(admin_client.get(CSV_URL))[1][1]
    assert cell == "'" + payload


def test_status_filter(admin_client):
    active = make_deployment()
    expired = make_deployment(expires_at=timezone.now() - timedelta(days=1))
    for url in (CSV_URL, JSON_URL):
        only_active = admin_client.get(f'{url}?status=active').content.decode()
        only_expired = admin_client.get(f'{url}?status=expired').content.decode()
        assert str(active.uuid) in only_active and str(expired.uuid) not in only_active
        assert str(expired.uuid) in only_expired and str(active.uuid) not in only_expired


def test_json_structure_and_unicode(admin_client):
    dep = make_deployment(client_name='Société Générale', site_name='Île-de-France')
    resp = admin_client.get(f'{JSON_URL}?client_id={dep.client_id}')
    assert resp.status_code == 200
    raw = resp.content.decode('utf-8')
    assert 'Société Générale' in raw  # ensure_ascii=False
    data = json.loads(raw)
    assert data['total_count'] == 1
    item = data['deployments'][0]
    assert item['uuid'] == str(dep.uuid)
    assert item['status'] == 'active'
    assert set(item) >= {'client_id', 'site_id', 'agent_type', 'arch', 'download_count',
                         'agents_installed', 'created_at', 'expires_at', 'enable_ping'}
    assert 'auth_key' not in item
