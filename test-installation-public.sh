#!/bin/bash

###############################################################################
# Script de test et vérification de l'installation Linux Deployments
# Pour Tactical RMM - rmm.votre-domaine.com
#
# Usage: ./test-installation.sh
###############################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Compteurs
PASSED=0
FAILED=0
TOTAL=0

# Fonction pour afficher un test
run_test() {
    local test_name="$1"
    local test_command="$2"
    TOTAL=$((TOTAL + 1))

    echo -e "${BLUE}[TEST $TOTAL] $test_name${NC}"

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ PASS${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}  ✗ FAIL${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# Fonction pour afficher un test avec sortie
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    TOTAL=$((TOTAL + 1))

    echo -e "${BLUE}[TEST $TOTAL] $test_name${NC}"

    output=$(eval "$test_command" 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}  ✓ PASS${NC}"
        echo -e "${CYAN}    → $output${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}  ✗ FAIL${NC}"
        echo -e "${YELLOW}    → $output${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# Banner
clear
echo -e "${CYAN}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        🧪  TEST DE L'INSTALLATION LINUX DEPLOYMENTS  🧪       ║
║                                                               ║
║              Tests pour rmm.votre-domaine.com                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

# Détecter le chemin de Tactical RMM
if [ -d "/rmm/api/tacticalrmm" ]; then
    RMM_PATH="/rmm/api/tacticalrmm"
    PYTHON_BIN="/rmm/api/env/bin/python"
elif [ -d "/opt/tacticalrmm/api/tacticalrmm" ]; then
    RMM_PATH="/opt/tacticalrmm/api/tacticalrmm"
    PYTHON_BIN="/opt/tacticalrmm/api/env/bin/python"
else
    echo -e "${RED}✗ Tactical RMM non trouvé${NC}"
    echo -e "${YELLOW}  Ce script doit être exécuté sur le serveur Tactical RMM${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Tactical RMM trouvé : $RMM_PATH${NC}"
echo ""

# ============================================================================
# SECTION 1 : Tests de présence des fichiers
# ============================================================================
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  SECTION 1 : Vérification des fichiers${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

run_test "Dossier linux_deployments existe" \
    "[ -d '$RMM_PATH/linux_deployments' ]"

run_test "Fichier models.py existe" \
    "[ -f '$RMM_PATH/linux_deployments/models.py' ]"

run_test "Fichier views.py existe" \
    "[ -f '$RMM_PATH/linux_deployments/views.py' ]"

run_test "Fichier serializers.py existe" \
    "[ -f '$RMM_PATH/linux_deployments/serializers.py' ]"

run_test "Fichier urls.py existe" \
    "[ -f '$RMM_PATH/linux_deployments/urls.py' ]"

run_test "Fichier admin.py existe" \
    "[ -f '$RMM_PATH/linux_deployments/admin.py' ]"

run_test "Fichier apps.py existe" \
    "[ -f '$RMM_PATH/linux_deployments/apps.py' ]"

run_test "Fichier __init__.py existe" \
    "[ -f '$RMM_PATH/linux_deployments/__init__.py' ]"

echo ""

# ============================================================================
# SECTION 2 : Tests de configuration Django
# ============================================================================
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  SECTION 2 : Configuration Django${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

run_test "App dans INSTALLED_APPS" \
    "grep -q 'linux_deployments' '$RMM_PATH/tacticalrmm/settings.py'"

run_test "URLs configurées" \
    "grep -q 'linux_deployments.urls' '$RMM_PATH/tacticalrmm/urls.py'"

run_test "Syntaxe Python valide (models.py)" \
    "sudo -u tactical $PYTHON_BIN -m py_compile '$RMM_PATH/linux_deployments/models.py'"

run_test "Syntaxe Python valide (views.py)" \
    "sudo -u tactical $PYTHON_BIN -m py_compile '$RMM_PATH/linux_deployments/views.py'"

run_test "Syntaxe Python valide (serializers.py)" \
    "sudo -u tactical $PYTHON_BIN -m py_compile '$RMM_PATH/linux_deployments/serializers.py'"

echo ""

# ============================================================================
# SECTION 3 : Tests Django
# ============================================================================
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  SECTION 3 : Tests Django${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

run_test "Django check (pas d'erreurs)" \
    "cd '$RMM_PATH' && sudo -u tactical $PYTHON_BIN manage.py check"

run_test "Import du modèle LinuxDeployment" \
    "cd '$RMM_PATH' && sudo -u tactical $PYTHON_BIN -c 'from linux_deployments.models import LinuxDeployment'"

run_test "Import des views" \
    "cd '$RMM_PATH' && sudo -u tactical $PYTHON_BIN -c 'from linux_deployments.views import LinuxDeploymentListCreateView'"

run_test "Import des serializers" \
    "cd '$RMM_PATH' && sudo -u tactical $PYTHON_BIN -c 'from linux_deployments.serializers import LinuxDeploymentSerializer'"

echo ""

# ============================================================================
# SECTION 4 : Tests de base de données
# ============================================================================
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  SECTION 4 : Base de données${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

run_test "Migrations appliquées" \
    "cd '$RMM_PATH' && sudo -u tactical $PYTHON_BIN manage.py showmigrations linux_deployments | grep -q '\[X\]'"

run_test_with_output "Compter les déploiements" \
    "cd '$RMM_PATH' && sudo -u tactical $PYTHON_BIN -c 'from linux_deployments.models import LinuxDeployment; print(f\"{LinuxDeployment.objects.count()} déploiement(s)\")'"

echo ""

# ============================================================================
# SECTION 5 : Tests du service
# ============================================================================
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  SECTION 5 : Service RMM${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

run_test "Service rmm.service actif" \
    "systemctl is-active --quiet rmm.service"

run_test "Service rmm.service enabled" \
    "systemctl is-enabled --quiet rmm.service"

run_test "Pas d'erreurs Python dans les logs (dernières 50 lignes)" \
    "! journalctl -u rmm.service -n 50 | grep -i 'error.*python'"

echo ""

# ============================================================================
# SECTION 6 : Tests API (si possible)
# ============================================================================
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  SECTION 6 : Tests API${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Test si curl est disponible
if command -v curl > /dev/null 2>&1; then
    echo -e "${BLUE}[TEST $((TOTAL + 1))] API endpoint répond (401 attendu)${NC}"
    TOTAL=$((TOTAL + 1))

    response=$(curl -s -o /dev/null -w "%{http_code}" https://api.rmm.votre-domaine.com/api/v3/linux-deployments/ 2>/dev/null || echo "000")

    if [ "$response" = "401" ] || [ "$response" = "200" ]; then
        echo -e "${GREEN}  ✓ PASS${NC}"
        echo -e "${CYAN}    → HTTP $response (endpoint accessible)${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${YELLOW}  ⚠ WARNING${NC}"
        echo -e "${YELLOW}    → HTTP $response (attendu 401 ou 200)${NC}"
        echo -e "${YELLOW}    → L'API pourrait ne pas être accessible depuis ce serveur${NC}"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${YELLOW}  ⚠ SKIP - curl non disponible${NC}"
fi

echo ""

# ============================================================================
# SECTION 7 : Tests de permissions
# ============================================================================
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  SECTION 7 : Permissions${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

run_test "Permissions correctes sur linux_deployments/" \
    "[ \$(stat -c '%U' '$RMM_PATH/linux_deployments') = 'tactical' ]"

run_test "models.py lisible par tactical" \
    "sudo -u tactical test -r '$RMM_PATH/linux_deployments/models.py'"

run_test "views.py lisible par tactical" \
    "sudo -u tactical test -r '$RMM_PATH/linux_deployments/views.py'"

echo ""

# ============================================================================
# Résumé
# ============================================================================
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  RÉSUMÉ DES TESTS${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "Total de tests : ${BOLD}$TOTAL${NC}"
echo -e "Tests réussis  : ${GREEN}${BOLD}$PASSED${NC}"
echo -e "Tests échoués  : ${RED}${BOLD}$FAILED${NC}"
echo ""

PERCENTAGE=$((PASSED * 100 / TOTAL))

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           ✅  TOUS LES TESTS SONT PASSÉS !  ✅                ║
║                                                               ║
║       L'installation est complète et fonctionnelle !          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}Prochaines étapes :${NC}"
    echo "  1. Activer l'admin Django : voir GUIDE_UTILISATION_ADMIN.md"
    echo "  2. Créer votre premier déploiement"
    echo "  3. Tester l'installation sur un serveur Linux"
    echo ""
    exit 0
elif [ $PERCENTAGE -ge 80 ]; then
    echo -e "${YELLOW}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        ⚠️  INSTALLATION PARTIELLEMENT RÉUSSIE  ⚠️            ║
║                                                               ║
║     Certains tests ont échoué mais l'essentiel fonctionne     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}Recommandations :${NC}"
    echo "  • Vérifier les tests échoués ci-dessus"
    echo "  • Consulter les logs : sudo journalctl -u rmm.service -n 100"
    echo "  • Relancer l'installation si nécessaire"
    echo ""
    exit 1
else
    echo -e "${RED}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║            ❌  INSTALLATION INCOMPLÈTE  ❌                    ║
║                                                               ║
║        De nombreux tests ont échoué - action requise          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo -e "${RED}Actions à prendre :${NC}"
    echo "  1. Vérifier les erreurs ci-dessus"
    echo "  2. Consulter les logs : sudo journalctl -u rmm.service -n 100"
    echo "  3. Relancer l'installation : cd ~/tactical-rmm && sudo ./install-interactive.sh"
    echo "  4. Si le problème persiste, créer une issue sur GitHub"
    echo ""
    exit 2
fi
