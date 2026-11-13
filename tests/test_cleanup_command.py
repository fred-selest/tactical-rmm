"""Tests de la commande cleanup_expired_deployments (jusqu'ici non testée)."""
from __future__ import annotations

from datetime import timedelta
from io import StringIO

import pytest
from django.core.management import call_command
from django.utils import timezone

from integration.backend.models import DeploymentLog, LinuxDeployment

from .conftest import make_deployment

pytestmark = pytest.mark.django_db


def run(*args) -> str:
    out = StringIO()
    call_command('cleanup_expired_deployments', *args, stdout=out)
    return out.getvalue()


def ago(days: int):
    return timezone.now() - timedelta(days=days)


def test_nothing_to_clean():
    make_deployment()
    assert 'Aucun déploiement expiré' in run()
    assert LinuxDeployment.objects.count() == 1


def test_deletes_only_deployments_expired_beyond_retention():
    active = make_deployment()
    recently_expired = make_deployment(expires_at=ago(5))
    old = make_deployment(expires_at=ago(45))
    DeploymentLog.objects.create(deployment=old, action='created')
    DeploymentLog.objects.create(deployment=old, action='downloaded')

    out = run()

    assert '1 déploiement(s) et 2 log(s) supprimés' in out
    remaining = set(LinuxDeployment.objects.values_list('pk', flat=True))
    assert remaining == {active.pk, recently_expired.pk}
    assert not DeploymentLog.objects.filter(deployment_id=old.pk).exists()


def test_custom_retention_days():
    make_deployment(expires_at=ago(5))
    run('--days', '2')
    assert LinuxDeployment.objects.count() == 0


def test_dry_run_deletes_nothing():
    for _ in range(12):
        make_deployment(expires_at=ago(60))
    out = run('--dry-run')
    assert '[DRY RUN] 12 déploiement(s)' in out
    assert '... et 2 autres' in out
    assert LinuxDeployment.objects.count() == 12
