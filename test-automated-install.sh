#!/bin/bash

###############################################################################
# Script de test pour l'installation automatisée
# Vérifie que tous les composants sont correctement installés
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/tacticalrmm-test-automated.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log() {
    local level="$1"
    local message="$2"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    
    echo "$timestamp [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "INFO") echo -e "${CYAN}ℹ $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✓ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠ $message${NC}" ;;
        "ERROR") echo -e "${RED}✗ $message${NC}" ;;
        "TEST") echo -e "${BLUE}[TEST] $message${NC}" ;;
    esac
}

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Détection de Tactical RMM
detect_rmm_path() {
    if [ -d "/rmm/api/tacticalrmm" ]; then
        RMM_PATH="/rmm/api/tacticalrmm"
        PYTHON_BIN="/rmm/api/env/bin/python"
    elif [ -d "/opt/tacticalrmm/api/tacticalrmm" ]; then
        RMM_PATH="/opt/tacticalrmm/api/tacticalrmm"
        PYTHON_BIN="/opt/tacticalrmm/api/env/bin/python"
    else
        log "ERROR" "Tactical RMM non trouvé"
        exit 1
    fi
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log "TEST" "$test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        log "SUCCESS" "PASS"
        return 0
    else
        log "ERROR" "FAIL"
        return 1
    fi
}

# Tests principaux
print_header "🧪 Tests de l'installation automatisée"

detect_rmm_path
log "INFO" "Chemin RMM détecté : $RMM_PATH"

# Test 1: Application Django installée
run_test "Application linux_deployments existe" "[ -d '$RMM_PATH/linux_deployments' ]"

# Test 2: Fichiers essentiels présents
run_test "Fichier models.py présent" "[ -f '$RMM_PATH/linux_deployments/models.py' ]"
run_test "Fichier views.py présent" "[ -f '$RMM_PATH/linux_deployments/views.py' ]"
run_test "Fichier urls.py présent" "[ -f '$RMM_PATH/linux_deployments/urls.py' ]"

# Test 3: Permissions correctes
run_test "Permissions tactical:tactical" "[ \$(stat -c '%U:%G' '$RMM_PATH/linux_deployments') = 'tactical:tactical' ]"

# Test 4: Configuration Django
run_test "linux_deployments dans INSTALLED_APPS" "grep -q 'linux_deployments' '$RMM_PATH/tacticalrmm/settings.py'"

# Test 5: URLs configurées
run_test "URLs linux_deployments configurées" "grep -q 'linux_deployments.urls' '$RMM_PATH/tacticalrmm/urls.py'"

# Test 6: Syntaxe Python valide
run_test "Syntaxe models.py valide" "sudo -u tactical $PYTHON_BIN -m py_compile '$RMM_PATH/linux_deployments/models.py'"
run_test "Syntaxe views.py valide" "sudo -u tactical $PYTHON_BIN -m py_compile '$RMM_PATH/linux_deployments/views.py'"

# Test 7: Migrations disponibles
run_test "Migrations existent" "[ -d '$RMM_PATH/linux_deployments/migrations' ]"

# Test 8: Service actif
run_test "Service rmm.service actif" "systemctl is-active --quiet rmm.service"

# Test 9: API accessible (doit retourner 401 Unauthorized)
if command -v curl > /dev/null 2>&1; then
    # Essayer de détecter l'URL API
    API_URL=""
    if [ -f "$RMM_PATH/tacticalrmm/local_settings.py" ]; then
        HOST=$(grep "ALLOWED_HOSTS" "$RMM_PATH/tacticalrmm/local_settings.py" | head -1 | grep -oE "'[^']*'" | head -1 | tr -d "'")
        if [ -n "$HOST" ] && [ "$HOST" != "*" ]; then
            API_URL="https://$HOST"
        fi
    fi
    
    if [ -z "$API_URL" ]; then
        HOSTNAME=$(hostname -f 2>/dev/null || hostname)
        API_URL="https://$HOSTNAME"
    fi
    
    if [ -n "$API_URL" ]; then
        log "TEST" "API accessible (401 attendu)"
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/v3/linux-deployments/" --insecure 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "200" ]; then
            log "SUCCESS" "PASS (HTTP $HTTP_CODE)"
        else
            log "WARNING" "HTTP $HTTP_CODE (attendu 401 ou 200)"
        fi
    fi
fi

print_header "✅ Tests terminés"

echo -e "${GREEN}Tous les tests ont été exécutés. Vérifiez les résultats ci-dessus.${NC}"
echo ""
echo -e "${CYAN}Logs détaillés : $LOG_FILE${NC}"

exit 0