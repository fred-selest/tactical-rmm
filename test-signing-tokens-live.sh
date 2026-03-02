#!/bin/bash
#
# 🧪 Script de test rapide des Signing Tokens
# Vérifie que le système est correctement déployé
#
# Usage: sudo ./test-signing-tokens-live.sh
#

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

RMM_DIR="/rmm/api/tacticalrmm"
TACTICAL_USER="tactical"
PYTHON="/rmm/api/env/bin/python"

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║   🧪 Tests des Signing Tokens - Tactical RMM                 ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Vérifier root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}✗${NC} Ce script doit être exécuté en tant que root"
   exit 1
fi

echo -e "${CYAN}▶ Lancement des tests...${NC}\n"

# Test complet via Django shell
sudo -u $TACTICAL_USER $PYTHON $RMM_DIR/manage.py shell << 'PYEOF'
import sys
from linux_deployments.models import LinuxDeployment
from django.utils import timezone
from datetime import timedelta

# Compteur de tests
tests_passed = 0
tests_failed = 0

def test(name, condition):
    global tests_passed, tests_failed
    if condition:
        print(f"✓ {name}")
        tests_passed += 1
    else:
        print(f"✗ {name}")
        tests_failed += 1

print("="*70)
print("TEST 1: Import du modèle LinuxDeployment")
print("="*70)
try:
    from linux_deployments.models import LinuxDeployment
    test("Import LinuxDeployment", True)
except Exception as e:
    test(f"Import LinuxDeployment: {e}", False)
    sys.exit(1)

print("\n" + "="*70)
print("TEST 2: Vérification des champs de sécurité")
print("="*70)
fields = LinuxDeployment._meta.get_fields()
field_names = [f.name for f in fields]

test("Champ 'signing_token' présent", 'signing_token' in field_names)
test("Champ 'one_time_token' présent", 'one_time_token' in field_names)
test("Champ 'signature_secret' présent", 'signature_secret' in field_names)
test("Champ 'token_used' présent", 'token_used' in field_names)
test("Champ 'token_used_at' présent", 'token_used_at' in field_names)

print("\n" + "="*70)
print("TEST 3: Vérification des méthodes de sécurité")
print("="*70)
methods = [
    'generate_signing_token',
    'generate_one_time_token',
    'generate_signature_secret',
    'generate_signature',
    'validate_signature',
    'get_signed_url',
    'use_one_time_token',
    'is_token_valid'
]

for method in methods:
    test(f"Méthode '{method}' présente", hasattr(LinuxDeployment, method))

print("\n" + "="*70)
print("TEST 4: Création d'un déploiement de test")
print("="*70)
try:
    deployment = LinuxDeployment.objects.create(
        client_id=9999,
        client_name="Test Client - Signing Tokens",
        site_id=9999,
        site_name="Test Site - Signing Tokens",
        agent_type="server",
        arch="amd64",
        api_url="https://api.selest.info",
        mesh_url="https://mesh.selest.info",
        auth_key="test_auth_key_" + str(timezone.now().timestamp()),
        signing_token=LinuxDeployment.generate_signing_token(),
        one_time_token=LinuxDeployment.generate_one_time_token(),
        signature_secret=LinuxDeployment.generate_signature_secret(),
        expires_at=timezone.now() + timedelta(days=7),
        created_by="test_script"
    )
    test("Déploiement créé avec succès", True)
    print(f"  → UUID: {deployment.uuid}")
except Exception as e:
    test(f"Création du déploiement: {e}", False)
    sys.exit(1)

print("\n" + "="*70)
print("TEST 5: Validation des tokens générés")
print("="*70)
test("signing_token non vide", deployment.signing_token and len(deployment.signing_token) > 0)
test("signing_token longueur correcte", len(deployment.signing_token) >= 40)
test("one_time_token non vide", deployment.one_time_token and len(deployment.one_time_token) > 0)
test("one_time_token longueur correcte", len(deployment.one_time_token) >= 40)
test("signature_secret non vide", deployment.signature_secret and len(deployment.signature_secret) > 0)
test("signature_secret longueur correcte", len(deployment.signature_secret) >= 80)
test("token_used initialisé à False", deployment.token_used == False)
test("token_used_at initialisé à None", deployment.token_used_at is None)

print(f"  → Signing Token: {deployment.signing_token[:30]}... ({len(deployment.signing_token)} chars)")
print(f"  → One-Time Token: {deployment.one_time_token[:30]}... ({len(deployment.one_time_token)} chars)")
print(f"  → Signature Secret: {deployment.signature_secret[:30]}... ({len(deployment.signature_secret)} chars)")

print("\n" + "="*70)
print("TEST 6: Génération et validation de signature HMAC")
print("="*70)
data_to_sign = f"{deployment.uuid}:test_data:1234567890"
signature = deployment.generate_signature(data_to_sign)

test("Signature HMAC générée", signature and len(signature) > 0)
test("Signature HMAC longueur (SHA256 hex)", len(signature) == 64)
test("Validation signature correcte", deployment.validate_signature(data_to_sign, signature))
test("Détection signature invalide", not deployment.validate_signature(data_to_sign, "invalid_signature" * 4))

print(f"  → Signature: {signature[:40]}...")

print("\n" + "="*70)
print("TEST 7: Génération d'URL signée")
print("="*70)
try:
    signed_url = deployment.get_signed_url()
    test("URL signée générée", signed_url and len(signed_url) > 0)
    test("URL contient timestamp 't='", 't=' in signed_url)
    test("URL contient signature 'sig='", 'sig=' in signed_url)
    test("URL contient UUID", str(deployment.uuid) in signed_url)
    print(f"  → URL: {signed_url[:80]}...")
except Exception as e:
    test(f"Génération URL signée: {e}", False)

print("\n" + "="*70)
print("TEST 8: Validation de token (is_token_valid)")
print("="*70)
test("Token frais est valide", deployment.is_token_valid() == True)

# Marquer comme utilisé
deployment.token_used = True
test("Token utilisé est invalide", deployment.is_token_valid() == False)

# Remettre à False pour le test suivant
deployment.token_used = False

# Expirer le déploiement
deployment.expires_at = timezone.now() - timedelta(days=1)
test("Token expiré est invalide", deployment.is_token_valid() == False)

# Remettre une expiration future
deployment.expires_at = timezone.now() + timedelta(days=7)

print("\n" + "="*70)
print("TEST 9: Utilisation du one-time token")
print("="*70)
try:
    # Vérifier l'état initial
    test("token_used initial = False", deployment.token_used == False)
    test("token_used_at initial = None", deployment.token_used_at is None)

    # Utiliser le token
    deployment.use_one_time_token()
    deployment.refresh_from_db()

    test("token_used après utilisation = True", deployment.token_used == True)
    test("token_used_at défini après utilisation", deployment.token_used_at is not None)

    # Tenter une seconde utilisation (doit échouer)
    try:
        deployment.use_one_time_token()
        test("Seconde utilisation bloquée", False)
    except ValueError as e:
        test("Seconde utilisation bloquée (ValueError)", "déjà été utilisé" in str(e))

except Exception as e:
    test(f"Test one-time token: {e}", False)

print("\n" + "="*70)
print("TEST 10: Unicité des tokens")
print("="*70)
token1 = LinuxDeployment.generate_signing_token()
token2 = LinuxDeployment.generate_signing_token()
token3 = LinuxDeployment.generate_one_time_token()
token4 = LinuxDeployment.generate_one_time_token()

test("Signing tokens uniques", token1 != token2)
test("One-time tokens uniques", token3 != token4)
test("Tous les tokens différents", len(set([token1, token2, token3, token4])) == 4)

print("\n" + "="*70)
print("TEST 11: Nettoyage")
print("="*70)
try:
    deployment.delete()
    test("Déploiement de test supprimé", True)
except Exception as e:
    test(f"Suppression: {e}", False)

# Résumé
print("\n" + "="*70)
print("RÉSUMÉ DES TESTS")
print("="*70)
print(f"Tests réussis: {tests_passed}")
print(f"Tests échoués: {tests_failed}")
print(f"Total: {tests_passed + tests_failed}")

if tests_failed == 0:
    print("\n🎉 TOUS LES TESTS SONT PASSÉS !")
    sys.exit(0)
else:
    print(f"\n❌ {tests_failed} test(s) ont échoué")
    sys.exit(1)
PYEOF

exit_code=$?

echo ""
if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✓ TOUS LES TESTS SONT PASSÉS !                            ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║   Le système de signing tokens est correctement déployé     ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}✨ Vous pouvez maintenant créer des déploiements sécurisés !${NC}"
    echo ""
else
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║   ✗ CERTAINS TESTS ONT ÉCHOUÉ                                ║${NC}"
    echo -e "${RED}║                                                               ║${NC}"
    echo -e "${RED}║   Vérifiez les erreurs ci-dessus                            ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
fi

exit $exit_code
