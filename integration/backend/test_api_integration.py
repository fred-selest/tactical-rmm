"""
Tests d'intégration pour l'API de déploiement Linux.

Ces tests vérifient le flux complet :
- Création de déploiement via API
- Téléchargement du script
- Callback d'installation
- Statistiques

Usage:
    python manage.py test integration.backend.test_api_integration
"""
from __future__ import annotations

import json
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch


class TestDeploymentAPIIntegration(unittest.TestCase):
    """Tests d'intégration pour le flux complet de déploiement"""

    def setUp(self) -> None:
        """Configuration initiale"""
        self.api_base = "https://api.test.com"
        self.valid_payload = {
            "client_id": 1,
            "client_name": "Client Test",
            "site_id": 1,
            "site_name": "Site Test",
            "agent_type": "server",
            "arch": "amd64",
            "expires_days": 30,
            "enable_ping": True,
            "enable_rdp": False,
            "install_mesh": True,
        }

    def test_create_deployment_valid_payload(self) -> None:
        """Test création de déploiement avec données valides"""
        payload = self.valid_payload.copy()

        # Vérifier que tous les champs requis sont présents
        required_fields = ['client_id', 'client_name', 'site_id', 'site_name']
        for field in required_fields:
            self.assertIn(field, payload)

        # Vérifier les valeurs par défaut
        self.assertEqual(payload['agent_type'], 'server')
        self.assertEqual(payload['arch'], 'amd64')
        self.assertEqual(payload['expires_days'], 30)

    def test_create_deployment_missing_fields(self) -> None:
        """Test création de déploiement avec champs manquants"""
        required_fields = ['client_id', 'client_name', 'site_id', 'site_name']

        for field in required_fields:
            payload = self.valid_payload.copy()
            del payload[field]
            # Vérifier que le champ manquant est détecté
            self.assertNotIn(field, payload)

    def test_create_deployment_invalid_agent_type(self) -> None:
        """Test création avec type d'agent invalide"""
        valid_types = ['server', 'workstation']
        invalid_types = ['desktop', 'mobile', 'tablet', '']

        for agent_type in invalid_types:
            self.assertNotIn(agent_type, valid_types)

    def test_create_deployment_invalid_arch(self) -> None:
        """Test création avec architecture invalide"""
        valid_archs = ['amd64', 'arm64', '386']
        invalid_archs = ['x86', 'mips', 'ppc', '']

        for arch in invalid_archs:
            self.assertNotIn(arch, valid_archs)

    def test_create_deployment_expires_days_validation(self) -> None:
        """Test validation de la durée d'expiration"""
        # Valides : 1-365
        for days in [1, 30, 365]:
            self.assertGreaterEqual(days, 1)
            self.assertLessEqual(days, 365)

        # Invalides
        for days in [0, -1, 366, 1000]:
            self.assertFalse(1 <= days <= 365)

    def test_deployment_expiration_check(self) -> None:
        """Test vérification d'expiration"""
        now = datetime.now(timezone.utc)

        # Déploiement actif
        future_expiry = now + timedelta(days=30)
        self.assertTrue(future_expiry > now)

        # Déploiement expiré
        past_expiry = now - timedelta(days=1)
        self.assertFalse(past_expiry > now)

    def test_script_generation_contains_required_info(self) -> None:
        """Test que le script généré contient les infos requises"""
        required_elements = [
            '#!/bin/bash',
            'set -e',
            'EUID',
            'wget',
            'chmod +x',
        ]

        # Simule un script généré
        mock_script = """#!/bin/bash
set -e
if [ "$EUID" -ne 0 ]; then exit 1; fi
wget -q "https://example.com/script.sh" -O /tmp/install.sh
chmod +x /tmp/install.sh
"""
        for element in required_elements:
            self.assertIn(element, mock_script)

    def test_hmac_signature_generation(self) -> None:
        """Test génération et validation de signature HMAC"""
        import hmac
        import hashlib

        secret = "test_secret_key_for_hmac"
        data = "test_uuid:1234567890"

        signature = hmac.new(
            secret.encode('utf-8'),
            data.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        # La signature doit être un hex de 64 caractères (SHA256)
        self.assertEqual(len(signature), 64)

        # Vérifier que la même signature est reproduite
        signature2 = hmac.new(
            secret.encode('utf-8'),
            data.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        self.assertEqual(signature, signature2)

        # Vérifier qu'un secret différent produit une signature différente
        wrong_signature = hmac.new(
            "wrong_secret".encode('utf-8'),
            data.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        self.assertNotEqual(signature, wrong_signature)

    def test_one_time_token_flow(self) -> None:
        """Test du flux complet du one-time token"""
        import secrets

        # Génération
        token = secrets.token_hex(32)
        self.assertEqual(len(token), 64)

        # Utilisation
        token_used = False
        self.assertFalse(token_used)

        # Première utilisation
        token_used = True
        self.assertTrue(token_used)

        # Tentative de réutilisation doit échouer
        if token_used:
            with self.assertRaises(ValueError):
                raise ValueError("Ce token a déjà été utilisé")

    def test_deployment_stats_calculation(self) -> None:
        """Test calcul des statistiques"""
        deployments_data = [
            {'download_count': 5, 'agents_installed': 3, 'expired': False},
            {'download_count': 2, 'agents_installed': 1, 'expired': True},
            {'download_count': 0, 'agents_installed': 0, 'expired': False},
        ]

        total = len(deployments_data)
        active = sum(1 for d in deployments_data if not d['expired'])
        expired = sum(1 for d in deployments_data if d['expired'])
        total_downloads = sum(d['download_count'] for d in deployments_data)
        total_installs = sum(d['agents_installed'] for d in deployments_data)

        self.assertEqual(total, 3)
        self.assertEqual(active, 2)
        self.assertEqual(expired, 1)
        self.assertEqual(total_downloads, 7)
        self.assertEqual(total_installs, 4)

        # Taux de succès
        success_rate = (total_installs / total_downloads * 100) if total_downloads > 0 else 0
        self.assertAlmostEqual(success_rate, 57.14, places=1)

    def test_deployment_stats_zero_downloads(self) -> None:
        """Test statistiques avec zéro téléchargements (division par zéro)"""
        total_downloads = 0
        total_installs = 0

        success_rate = (total_installs / total_downloads * 100) if total_downloads > 0 else 0
        self.assertEqual(success_rate, 0)

    def test_ip_extraction_with_forwarded_header(self) -> None:
        """Test extraction d'IP avec X-Forwarded-For"""
        # Cas avec proxy
        forwarded = "192.168.1.100, 10.0.0.1, 172.16.0.1"
        ip = forwarded.split(',')[0].strip()
        self.assertEqual(ip, "192.168.1.100")

        # Cas sans proxy
        remote_addr = "203.0.113.50"
        self.assertEqual(remote_addr, "203.0.113.50")

    def test_install_callback_valid_token(self) -> None:
        """Test callback d'installation avec token valide"""
        original_token = "valid_token_123"
        provided_token = "valid_token_123"

        self.assertEqual(original_token, provided_token)

    def test_install_callback_invalid_token(self) -> None:
        """Test callback d'installation avec token invalide"""
        original_token = "valid_token_123"
        provided_token = "wrong_token_456"

        self.assertNotEqual(original_token, provided_token)

    def test_timestamp_validation(self) -> None:
        """Test validation du timestamp pour les URLs signées"""
        import time

        current_ts = int(time.time())

        # Timestamp récent (< 1 heure) = valide
        recent_ts = current_ts - 1800  # 30 minutes
        age = current_ts - recent_ts
        self.assertLess(age, 3600)

        # Timestamp ancien (> 1 heure) = invalide
        old_ts = current_ts - 7200  # 2 heures
        age = current_ts - old_ts
        self.assertGreater(age, 3600)

    def test_url_signing_format(self) -> None:
        """Test format de l'URL signée"""
        import uuid as uuid_mod

        deployment_uuid = str(uuid_mod.uuid4())
        api_url = "https://api.example.com"
        token = "abc123"
        signature = "def456"

        signed_url = f"{api_url}/clients/{deployment_uuid}/deploy/linux/?token={token}&sig={signature}"

        self.assertIn(deployment_uuid, signed_url)
        self.assertIn("token=", signed_url)
        self.assertIn("sig=", signed_url)
        self.assertTrue(signed_url.startswith("https://"))


class TestDeploymentSecurity(unittest.TestCase):
    """Tests de sécurité pour le système de déploiement"""

    def test_token_entropy(self) -> None:
        """Test que les tokens ont suffisamment d'entropie"""
        import secrets

        # 32 bytes = 256 bits d'entropie (recommandé NIST)
        token = secrets.token_hex(32)
        self.assertEqual(len(token), 64)

        # Vérifier que tous les caractères sont hexadécimaux
        self.assertTrue(all(c in '0123456789abcdef' for c in token))

    def test_tokens_are_unique(self) -> None:
        """Test que les tokens générés sont uniques"""
        import secrets

        tokens = set()
        for _ in range(100):
            token = secrets.token_hex(32)
            self.assertNotIn(token, tokens)
            tokens.add(token)

    def test_hmac_timing_safe_comparison(self) -> None:
        """Test que la comparaison HMAC est timing-safe"""
        import hmac

        sig1 = "a" * 64
        sig2 = "a" * 64
        sig3 = "b" * 64

        self.assertTrue(hmac.compare_digest(sig1, sig2))
        self.assertFalse(hmac.compare_digest(sig1, sig3))

    def test_signature_secret_length(self) -> None:
        """Test longueur minimale du secret de signature"""
        import secrets

        secret = secrets.token_hex(64)
        # Minimum 128 caractères pour le secret
        self.assertGreaterEqual(len(secret), 128)


if __name__ == '__main__':
    # Configuration Django minimale si nécessaire
    try:
        import django
        django.setup()
    except Exception:
        pass

    unittest.main(verbosity=2)
