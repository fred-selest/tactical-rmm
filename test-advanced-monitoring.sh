#!/bin/bash

###############################################################################
# Script de test pour la surveillance avancée
# Vérifie que tous les nouveaux scripts de monitoring fonctionnent correctement
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/tacticalrmm-test-advanced-monitoring.log"

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
print_header "🧪 Tests de la Surveillance Avancée"

# Test 1: Scripts système existent
run_test "Répertoire system existe" "[ -d '$SCRIPT_DIR/scripts/system' ]"
run_test "Script check-cpu.sh existe" "[ -f '$SCRIPT_DIR/scripts/system/check-cpu.sh' ]"
run_test "Script check-memory.sh existe" "[ -f '$SCRIPT_DIR/scripts/system/check-memory.sh' ]"
run_test "Script check-disk.sh existe" "[ -f '$SCRIPT_DIR/scripts/system/check-disk.sh' ]"
run_test "Script check-network.sh existe" "[ -f '$SCRIPT_DIR/scripts/system/check-network.sh' ]"
run_test "Script check-system.sh existe" "[ -f '$SCRIPT_DIR/scripts/system/check-system.sh' ]"

# Test 2: Scripts Docker existent
run_test "Répertoire docker existe" "[ -d '$SCRIPT_DIR/scripts/docker' ]"
run_test "Script check-docker.sh existe" "[ -f '$SCRIPT_DIR/scripts/docker/check-docker.sh' ]"

# Test 3: Scripts base de données existent
run_test "Répertoire database existe" "[ -d '$SCRIPT_DIR/scripts/database' ]"
run_test "Script check-mysql.sh existe" "[ -f '$SCRIPT_DIR/scripts/database/check-mysql.sh' ]"
run_test "Script check-postgresql.sh existe" "[ -f '$SCRIPT_DIR/scripts/database/check-postgresql.sh' ]"
run_test "Script check-database.sh existe" "[ -f '$SCRIPT_DIR/scripts/database/check-database.sh' ]"

# Test 4: Permissions d'exécution
run_test "Scripts système exécutables" "[ -x '$SCRIPT_DIR/scripts/system/check-cpu.sh' ]"
run_test "Scripts Docker exécutables" "[ -x '$SCRIPT_DIR/scripts/docker/check-docker.sh' ]"
run_test "Scripts base de données exécutables" "[ -x '$SCRIPT_DIR/scripts/database/check-mysql.sh' ]"

# Test 5: Syntaxe bash valide
run_test "Syntaxe check-cpu.sh valide" "bash -n '$SCRIPT_DIR/scripts/system/check-cpu.sh'"
run_test "Syntaxe check-memory.sh valide" "bash -n '$SCRIPT_DIR/scripts/system/check-memory.sh'"
run_test "Syntaxe check-disk.sh valide" "bash -n '$SCRIPT_DIR/scripts/system/check-disk.sh'"
run_test "Syntaxe check-network.sh valide" "bash -n '$SCRIPT_DIR/scripts/system/check-network.sh'"
run_test "Syntaxe check-system.sh valide" "bash -n '$SCRIPT_DIR/scripts/system/check-system.sh'"
run_test "Syntaxe check-docker.sh valide" "bash -n '$SCRIPT_DIR/scripts/docker/check-docker.sh'"
run_test "Syntaxe check-mysql.sh valide" "bash -n '$SCRIPT_DIR/scripts/database/check-mysql.sh'"
run_test "Syntaxe check-postgresql.sh valide" "bash -n '$SCRIPT_DIR/scripts/database/check-postgresql.sh'"
run_test "Syntaxe check-database.sh valide" "bash -n '$SCRIPT_DIR/scripts/database/check-database.sh'"

# Test 6: README existent
run_test "README system existe" "[ -f '$SCRIPT_DIR/scripts/system/README.md' ]"
run_test "README docker existe" "[ -f '$SCRIPT_DIR/scripts/docker/README.md' ]"
run_test "README database existe" "[ -f '$SCRIPT_DIR/scripts/database/README.md' ]"

# Test 7: Exécution basique des scripts (sans erreurs fatales)
print_header "🚀 Tests d'exécution basique"

log "TEST" "Exécution basique check-cpu.sh (doit s'exécuter sans erreur fatale)"
if timeout 10 "$SCRIPT_DIR/scripts/system/check-cpu.sh" > /dev/null 2>&1; then
    log "SUCCESS" "PASS"
else
    # Accepter le code de sortie 1 (alerte) mais pas d'erreur fatale
    if [ $? -le 2 ]; then
        log "SUCCESS" "PASS (code de sortie acceptable)"
    else
        log "ERROR" "FAIL (erreur fatale)"
        exit 1
    fi
fi

log "TEST" "Exécution basique check-memory.sh"
if timeout 10 "$SCRIPT_DIR/scripts/system/check-memory.sh" > /dev/null 2>&1; then
    log "SUCCESS" "PASS"
else
    if [ $? -le 1 ]; then
        log "SUCCESS" "PASS (code de sortie acceptable)"
    else
        log "ERROR" "FAIL (erreur fatale)"
        exit 1
    fi
fi

log "TEST" "Exécution basique check-disk.sh"
if timeout 10 "$SCRIPT_DIR/scripts/system/check-disk.sh" > /dev/null 2>&1; then
    log "SUCCESS" "PASS"
else
    if [ $? -le 1 ]; then
        log "SUCCESS" "PASS (code de sortie acceptable)"
    else
        log "ERROR" "FAIL (erreur fatale)"
        exit 1
    fi
fi

log "TEST" "Exécution basique check-network.sh"
if timeout 10 "$SCRIPT_DIR/scripts/system/check-network.sh" > /dev/null 2>&1; then
    log "SUCCESS" "PASS"
else
    if [ $? -le 1 ]; then
        log "SUCCESS" "PASS (code de sortie acceptable)"
    else
        log "ERROR" "FAIL (erreur fatale)"
        exit 1
    fi
fi

# Tests conditionnels pour Docker et bases de données
if command -v docker &> /dev/null; then
    log "TEST" "Exécution basique check-docker.sh"
    if timeout 15 "$SCRIPT_DIR/scripts/docker/check-docker.sh" > /dev/null 2>&1; then
        log "SUCCESS" "PASS"
    else
        if [ $? -le 1 ]; then
            log "SUCCESS" "PASS (code de sortie acceptable)"
        else
            log "ERROR" "FAIL (erreur fatale)"
            exit 1
        fi
    fi
else
    log "INFO" "Docker non installé, test check-docker.sh ignoré"
fi

if command -v mysql &> /dev/null; then
    log "TEST" "Exécution basique check-mysql.sh"
    if timeout 15 "$SCRIPT_DIR/scripts/database/check-mysql.sh" > /dev/null 2>&1; then
        log "SUCCESS" "PASS"
    else
        if [ $? -le 1 ]; then
            log "SUCCESS" "PASS (code de sortie acceptable)"
        else
            log "ERROR" "FAIL (erreur fatale)"
            exit 1
        fi
    fi
else
    log "INFO" "MySQL non installé, test check-mysql.sh ignoré"
fi

if command -v psql &> /dev/null; then
    log "TEST" "Exécution basique check-postgresql.sh"
    if timeout 15 "$SCRIPT_DIR/scripts/database/check-postgresql.sh" > /dev/null 2>&1; then
        log "SUCCESS" "PASS"
    else
        if [ $? -le 1 ]; then
            log "SUCCESS" "PASS (code de sortie acceptable)"
        else
            log "ERROR" "FAIL (erreur fatale)"
            exit 1
        fi
    fi
else
    log "INFO" "PostgreSQL non installé, test check-postgresql.sh ignoré"
fi

print_header "✅ Tests terminés"

echo -e "${GREEN}Tous les tests ont été exécutés avec succès !${NC}"
echo ""
echo -e "${CYAN}Logs détaillés : $LOG_FILE${NC}"

exit 0