"""
Tests de concurrence réels (threads + connexions distinctes).

Exécutés uniquement sur PostgreSQL (DATABASE_URL) : SQLite sérialise toutes
les écritures et ne permet pas de reproduire les conditions de course.
"""
from __future__ import annotations

import threading

import pytest
from django.db import connection, connections

from integration.backend.models import LinuxDeployment

from .conftest import make_deployment

pytestmark = [
    pytest.mark.django_db(transaction=True),
    pytest.mark.skipif(connection.vendor != 'postgresql', reason='nécessite PostgreSQL (DATABASE_URL)'),
]

THREADS = 8


def run_concurrently(func, count: int = THREADS) -> list:
    """Lance ``func`` dans ``count`` threads démarrés au même instant."""
    barrier = threading.Barrier(count)
    results: list = []
    lock = threading.Lock()

    def worker():
        try:
            barrier.wait()
            outcome = func()
        except Exception as exc:  # noqa: BLE001 - on veut collecter toutes les issues
            outcome = exc
        finally:
            connections.close_all()
        with lock:
            results.append(outcome)

    threads = [threading.Thread(target=worker) for _ in range(count)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=30)
    return results


def test_one_time_token_consumed_exactly_once():
    dep = make_deployment()

    def consume():
        LinuxDeployment.objects.get(pk=dep.pk).use_one_time_token()
        return 'ok'

    results = run_concurrently(consume)
    assert results.count('ok') == 1
    assert all(isinstance(r, ValueError) for r in results if r != 'ok')


def test_download_counter_loses_no_increment():
    dep = make_deployment()

    def download():
        LinuxDeployment.objects.get(pk=dep.pk).increment_download()

    run_concurrently(download)
    dep.refresh_from_db()
    assert dep.download_count == THREADS


def test_concurrent_success_callbacks_count_one_installation():
    from rest_framework.test import APIClient

    dep = make_deployment()
    body = {'hostname': 'h', 'status': 'success', 'one_time_token': dep.one_time_token}

    def callback():
        return APIClient().post(f'/api/v3/linux-deployments/{dep.uuid}/installed/', body).status_code

    # Moins de 5 threads : le throttle (5/min par IP) ne doit pas interférer
    codes = run_concurrently(callback, count=4)
    assert sorted(codes) == [200, 410, 410, 410]
    dep.refresh_from_db()
    assert dep.agents_installed == 1
