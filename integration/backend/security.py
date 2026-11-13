"""
Utilitaires de sécurité pour l'intégration de déploiement Linux :
- récupération fiable de l'IP cliente (anti-spoofing X-Forwarded-For)
- contrôle d'accès par client (s'appuie sur les rôles Tactical RMM si disponibles)
"""
from __future__ import annotations

import ipaddress
from typing import Any

from django.conf import settings
from rest_framework.permissions import BasePermission

try:  # Fonctions de permission de Tactical RMM (présentes une fois intégré)
    from tacticalrmm.permissions import _has_perm, _has_perm_on_client  # type: ignore
except ImportError:  # pragma: no cover - dépend de l'environnement
    _has_perm = None
    _has_perm_on_client = None


def _valid_ip(value: str | None) -> str | None:
    if not value:
        return None
    value = value.strip()
    try:
        ipaddress.ip_address(value)
    except ValueError:
        return None
    return value


def get_client_ip(request: Any) -> str | None:
    """
    Retourne l'IP du client.

    L'en-tête X-Forwarded-For n'est pris en compte que si
    ``LINUX_DEPLOYMENT_TRUSTED_PROXY_COUNT`` (nombre de reverse proxies de
    confiance devant Django) est > 0. Dans ce cas on prend l'adresse ajoutée
    par le proxy le plus externe de confiance, et non la première de la liste
    (qui est entièrement contrôlée par le client).
    """
    remote_addr = _valid_ip(request.META.get('REMOTE_ADDR'))
    proxy_count = int(getattr(settings, 'LINUX_DEPLOYMENT_TRUSTED_PROXY_COUNT', 0) or 0)

    if proxy_count > 0:
        xff = request.META.get('HTTP_X_FORWARDED_FOR', '')
        hops = [h.strip() for h in xff.split(',') if h.strip()]
        if len(hops) >= proxy_count:
            candidate = _valid_ip(hops[-proxy_count])
            if candidate:
                return candidate

    return remote_addr


def user_can_access_client(user: Any, client_id: int) -> bool:
    """Indique si l'utilisateur a accès aux déploiements de ce client."""
    if not user or not user.is_authenticated:
        return False
    if getattr(user, 'is_superuser', False):
        return True
    if _has_perm_on_client is not None:
        return bool(_has_perm_on_client(user, client_id))
    # Hors Tactical RMM : seuls les membres du staff sont autorisés
    return bool(getattr(user, 'is_staff', False))


def filter_deployments_for_user(queryset: Any, user: Any) -> Any:
    """Restreint un QuerySet de déploiements aux clients accessibles par l'utilisateur."""
    if getattr(user, 'is_superuser', False):
        return queryset
    client_ids = set(queryset.values_list('client_id', flat=True).distinct())
    allowed = [cid for cid in client_ids if user_can_access_client(user, cid)]
    return queryset.filter(client_id__in=allowed)


class LinuxDeploymentPermission(BasePermission):
    """
    Autorise la gestion des déploiements Linux.

    Dans Tactical RMM : nécessite le droit de rôle ``can_manage_deployments``.
    Hors Tactical RMM : nécessite ``is_staff``.
    Le contrôle par client est fait via ``has_object_permission`` et les
    filtres de QuerySet.
    """

    def has_permission(self, request: Any, view: Any) -> bool:
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if getattr(user, 'is_superuser', False):
            return True
        if _has_perm is not None:
            return bool(_has_perm(request, 'can_manage_deployments'))
        return bool(getattr(user, 'is_staff', False))

    def has_object_permission(self, request: Any, view: Any, obj: Any) -> bool:
        return user_can_access_client(request.user, obj.client_id)
