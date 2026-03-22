#!/bin/bash

###############################################################################
# Script de test pour la mise à jour de l'agent Tactical RMM
# Vérifie que le script de mise à jour fonctionne correctement
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/tacticalrmm-test-agent-update.log"

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
print_header "🧪 Test du script de mise à jour de l'agent"

# Test 1: Script existe
run_test "Script de mise à jour existe" "[ -f '$SCRIPT_DIR/scripts/system/update-tactical-agent.sh' ]"

# Test 2: Script exécutable
run_test "Script exécutable" "[ -x '$SCRIPT_DIR/scripts/system/update-tactical-agent.sh' ]"

# Test 3: Syntaxe bash valide
run_test "Syntaxe valide" "bash -n '$SCRIPT_DIR/scripts/system/update-tactical-agent.sh'"

# Test 4: Présence dans la base de données
log "TEST" "Présence dans la base de données"
if cd /rmm/api/tacticalrmm && sudo -u tactical /rmm/api/env/bin/python3 -c "
import os, sys, django
sys.path.append('/rmm/api/tacticalrmm')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tacticalrmm.settings')
django.setup()
from scripts.models import Script
script = Script.objects.filter(name='Mise à jour Agent Tactical RMM').first()
if script:
    print('FOUND')
else:
    print('NOT_FOUND')
" | grep -q "FOUND"; then
    log "SUCCESS" "PASS"
else
    log "ERROR" "FAIL"
fi

# Test 5: Test en mode dry-run (simulation)
log "TEST" "Test en mode simulation (--dry-run)"
if timeout 30 "$SCRIPT_DIR/scripts/system/update-tactical-agent.sh" --dry-run --quiet; then
    log "SUCCESS" "PASS"
else
    log "ERROR" "FAIL"
fi

print_header "✅ Tests terminés"

echo -e "${GREEN}Tous les tests ont été exécutés. Vérifiez les résultats ci-dessus.${NC}"
echo ""
echo -e "${CYAN}Logs détaillés : $LOG_FILE${NC}"

exit 0