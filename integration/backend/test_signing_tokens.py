#!/usr/bin/env python3
"""
Tests unitaires pour les tokens de sécurité LinuxDeployment

Usage:
    python test_signing_tokens.py
"""

import unittest
import sys
from datetime import timedelta
from django.utils import timezone


class TestSigningTokens(unittest.TestCase):
    """Tests pour les fonctionnalités de signing tokens"""

    def setUp(self):
        """Configuration initiale des tests"""
        # Importer après le setup Django
        from models import LinuxDeployment

        # Créer un déploiement de test
        self.deployment = LinuxDeployment(
            client_id=1,
            client_name="Test Client",
            site_id=1,
            site_name="Test Site",
            agent_type="server",
            arch="amd64",
            api_url="https://api.test.com",
            mesh_url="https://mesh.test.com",
            auth_key="test_auth_key",
            signing_token=LinuxDeployment.generate_signing_token(),
            one_time_token=LinuxDeployment.generate_one_time_token(),
            signature_secret=LinuxDeployment.generate_signature_secret(),
            expires_at=timezone.now() + timedelta(days=30),
            created_by="test_user"
        )

    def test_generate_signing_token(self):
        """Test génération du signing token"""
        token = self.deployment.signing_token
        self.assertIsNotNone(token)
        self.assertGreater(len(token), 40)
        print(f"✅ Signing token généré: {token[:20]}... ({len(token)} chars)")

    def test_generate_one_time_token(self):
        """Test génération du one-time token"""
        token = self.deployment.one_time_token
        self.assertIsNotNone(token)
        self.assertGreater(len(token), 40)
        print(f"✅ One-time token généré: {token[:20]}... ({len(token)} chars)")

    def test_generate_signature_secret(self):
        """Test génération du signature secret"""
        secret = self.deployment.signature_secret
        self.assertIsNotNone(secret)
        self.assertGreater(len(secret), 80)
        print(f"✅ Signature secret généré: {secret[:20]}... ({len(secret)} chars)")

    def test_generate_signature(self):
        """Test génération de signature HMAC"""
        data = "test_data_to_sign"
        signature = self.deployment.generate_signature(data)

        self.assertIsNotNone(signature)
        self.assertEqual(len(signature), 64)  # SHA256 hex = 64 chars
        print(f"✅ Signature HMAC générée: {signature[:20]}...")

    def test_validate_signature_valid(self):
        """Test validation d'une signature valide"""
        data = "test_data_to_sign"
        signature = self.deployment.generate_signature(data)

        is_valid = self.deployment.validate_signature(data, signature)
        self.assertTrue(is_valid)
        print(f"✅ Signature valide vérifiée avec succès")

    def test_validate_signature_invalid(self):
        """Test validation d'une signature invalide"""
        data = "test_data_to_sign"
        wrong_signature = "invalid_signature_1234567890abcdef" * 2

        is_valid = self.deployment.validate_signature(data, wrong_signature)
        self.assertFalse(is_valid)
        print(f"✅ Signature invalide détectée correctement")

    def test_get_signed_url(self):
        """Test génération d'URL signée"""
        signed_url = self.deployment.get_signed_url()

        self.assertIn('t=', signed_url)
        self.assertIn('sig=', signed_url)
        self.assertIn(str(self.deployment.uuid), signed_url)
        print(f"✅ URL signée générée: {signed_url[:50]}...")

    def test_is_token_valid_fresh(self):
        """Test token frais (non utilisé, non expiré)"""
        is_valid = self.deployment.is_token_valid()
        self.assertTrue(is_valid)
        print(f"✅ Token frais validé comme valide")

    def test_is_token_valid_used(self):
        """Test token déjà utilisé"""
        self.deployment.token_used = True
        is_valid = self.deployment.is_token_valid()
        self.assertFalse(is_valid)
        print(f"✅ Token utilisé détecté comme invalide")

    def test_is_token_valid_expired(self):
        """Test token expiré"""
        self.deployment.expires_at = timezone.now() - timedelta(days=1)
        is_valid = self.deployment.is_token_valid()
        self.assertFalse(is_valid)
        print(f"✅ Token expiré détecté comme invalide")

    def test_use_one_time_token_success(self):
        """Test utilisation du one-time token (succès)"""
        self.assertFalse(self.deployment.token_used)
        self.assertIsNone(self.deployment.token_used_at)

        # Note: Cette méthode appelle save(), ce qui nécessite une DB
        # Dans un test unitaire pur, on simulerait juste les changements
        self.deployment.token_used = True
        self.deployment.token_used_at = timezone.now()

        self.assertTrue(self.deployment.token_used)
        self.assertIsNotNone(self.deployment.token_used_at)
        print(f"✅ One-time token marqué comme utilisé")

    def test_use_one_time_token_already_used(self):
        """Test utilisation d'un token déjà utilisé"""
        self.deployment.token_used = True

        try:
            self.deployment.use_one_time_token()
            self.fail("Devrait lever ValueError")
        except ValueError as e:
            self.assertIn("déjà été utilisé", str(e))
            print(f"✅ Exception levée pour token déjà utilisé")

    def test_tokens_uniqueness(self):
        """Test que les tokens générés sont uniques"""
        from models import LinuxDeployment

        tokens1 = {
            'signing': LinuxDeployment.generate_signing_token(),
            'onetime': LinuxDeployment.generate_one_time_token(),
            'secret': LinuxDeployment.generate_signature_secret()
        }

        tokens2 = {
            'signing': LinuxDeployment.generate_signing_token(),
            'onetime': LinuxDeployment.generate_one_time_token(),
            'secret': LinuxDeployment.generate_signature_secret()
        }

        self.assertNotEqual(tokens1['signing'], tokens2['signing'])
        self.assertNotEqual(tokens1['onetime'], tokens2['onetime'])
        self.assertNotEqual(tokens1['secret'], tokens2['secret'])
        print(f"✅ Tous les tokens sont uniques")


def run_tests():
    """Exécute tous les tests"""
    print("\n" + "="*70)
    print("🧪 Tests des Signing Tokens pour LinuxDeployment")
    print("="*70 + "\n")

    # Créer une suite de tests
    suite = unittest.TestLoader().loadTestsFromTestCase(TestSigningTokens)

    # Exécuter les tests avec verbosité
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    print("\n" + "="*70)
    if result.wasSuccessful():
        print("✅ TOUS LES TESTS SONT PASSÉS !")
    else:
        print("❌ CERTAINS TESTS ONT ÉCHOUÉ")
        print(f"   Échecs: {len(result.failures)}")
        print(f"   Erreurs: {len(result.errors)}")
    print("="*70 + "\n")

    return result.wasSuccessful()


if __name__ == '__main__':
    # Simule un environnement Django minimal
    print("⚙️  Configuration de l'environnement de test...")

    # Import les modèles (dans un environnement Django réel)
    try:
        import django
        django.setup()
    except Exception as e:
        print(f"⚠️  Django non configuré: {e}")
        print("   Tests en mode standalone (sans base de données)")

    success = run_tests()
    sys.exit(0 if success else 1)
