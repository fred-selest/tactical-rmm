#!/bin/bash

###############################################################################
# Système de mise à jour Tactical RMM
# Met à jour les scripts, l'intégration, et les nouvelles fonctionnalités
#
# Usage: sudo ./update-tactical-rmm.sh [options]
# Options:
#   --force            Forcer la mise à jour même si déjà à jour
#   --scripts-only     Mettre à jour uniquement les scripts de surveillance
#   --full             Mise à jour complète (par défaut)
#   --quiet            Mode silencieux
###############################################################################

set -e

# === VARIABLES GLOBALES ===
SCRIPT_VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/tacticalrmm-update.log"
REPO_URL="https://github.com/fred-selest/tactical-rmm.git"
BRANCH="main"

QUIET_MODE=false
FORCE_UPDATE=false
SCRIPTS_ONLY=false

# Couleurs
if [ "$QUIET_MODE" = false ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    BOLD='\033[1m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''; BOLD=''
fi

# === FONCTIONS UTILITAIRES ===

log() {
    local level="$1"
    local message="$2"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    
    echo "$timestamp [$level] $message" >> "$LOG_FILE"
    
    if [ "$QUIET_MODE" = false ] || [ "$level" != "INFO" ]; then
        case $level in
            "INFO") echo -e "${CYAN}ℹ $message${NC}" ;;
            "SUCCESS") echo -e "${GREEN}✓ $message${NC}" ;;
            "WARNING") echo -e "${YELLOW}⚠ $message${NC}" ;;
            "ERROR") echo -e "${RED}✗ $message${NC}" ;;
            "STEP") echo -e "${BLUE}${BOLD}[$message]${NC}" ;;
        esac
    fi
}

print_header() {
    if [ "$QUIET_MODE" = false ]; then
        echo ""
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}${BOLD}  $1${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    fi
}

# === FONCTIONS DE MISE À JOUR ===

check_git_status() {
    log "STEP" "Vérification de l'état Git..."
    
    if [ ! -d ".git" ]; then
        log "ERROR" "Ce répertoire n'est pas un dépôt Git"
        exit 1
    fi
    
    # Vérifier si des modifications locales existent
    if ! git diff-index --quiet HEAD --; then
        log "WARNING" "Modifications locales détectées. La mise à jour pourrait échouer."
        if [ "$FORCE_UPDATE" = false ]; then
            log "INFO" "Utilisez --force pour ignorer cet avertissement"
            exit 1
        fi
    fi
    
    # Obtenir le commit actuel
    CURRENT_COMMIT=$(git rev-parse HEAD)
    log "INFO" "Commit actuel: $CURRENT_COMMIT"
    
    # Récupérer les derniers commits
    git fetch origin
    
    # Vérifier si nous sommes à jour
    LATEST_COMMIT=$(git rev-parse origin/$BRANCH)
    if [ "$CURRENT_COMMIT" = "$LATEST_COMMIT" ] && [ "$FORCE_UPDATE" = false ]; then
        log "SUCCESS" "Déjà à jour avec le dernier commit"
        return 1  # Pas besoin de mise à jour
    fi
    
    log "INFO" "Nouveau commit disponible: $LATEST_COMMIT"
    return 0
}

update_repository() {
    print_header "Mise à jour du dépôt"
    
    log "STEP" "Pull des dernières modifications..."
    git pull origin $BRANCH
    
    log "SUCCESS" "Dépôt mis à jour avec succès"
}

update_scripts_only() {
    print_header "Mise à jour des scripts de surveillance uniquement"
    
    # Télécharger les derniers scripts depuis GitHub
    SCRIPTS_URL="https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts"
    
    # Scripts système
    mkdir -p scripts/system
    for script in check-cpu.sh check-memory.sh check-disk.sh check-network.sh check-system.sh; do
        log "STEP" "Mise à jour de $script..."
        wget -q "$SCRIPTS_URL/system/$script" -O "scripts/system/$script"
        chmod +x "scripts/system/$script"
    done
    
    # Scripts Docker
    mkdir -p scripts/docker
    wget -q "$SCRIPTS_URL/docker/check-docker.sh" -O "scripts/docker/check-docker.sh"
    chmod +x "scripts/docker/check-docker.sh"
    
    # Scripts bases de données
    mkdir -p scripts/database
    for script in check-mysql.sh check-postgresql.sh check-database.sh; do
        log "STEP" "Mise à jour de $script..."
        wget -q "$SCRIPTS_URL/database/$script" -O "scripts/database/$script"
        chmod +x "scripts/database/$script"
    done
    
    log "SUCCESS" "Scripts de surveillance mis à jour"
}

import_updated_scripts() {
    print_header "Importation des scripts mis à jour dans Tactical RMM"
    
    # Utiliser le script d'importation existant
    if [ -f "/home/debian/tactical-rmm/import-monitoring-scripts.py" ]; then
        log "STEP" "Importation des scripts dans la base de données..."
        
        # Trouver le bon chemin RMM
        if [ -d "/rmm/api/tacticalrmm" ]; then
            RMM_PATH="/rmm/api/tacticalrmm"
            PYTHON_BIN="/rmm/api/env/bin/python3"
        elif [ -d "/opt/tacticalrmm/api/tacticalrmm" ]; then
            RMM_PATH="/opt/tacticalrmm/api/tacticalrmm"
            PYTHON_BIN="/opt/tacticalrmm/api/env/bin/python3"
        else
            log "ERROR" "Tactical RMM non trouvé"
            return 1
        fi
        
        cd "$RMM_PATH"
        sudo -u tactical $PYTHON_BIN /home/debian/tactical-rmm/import-monitoring-scripts.py
        
        log "SUCCESS" "Scripts importés dans Tactical RMM"
    else
        log "WARNING" "Script d'importation non trouvé, importation ignorée"
    fi
}

reinstall_integration() {
    print_header "Réinstallation de l'intégration Linux Deployments"
    
    log "STEP" "Exécution de l'installation automatisée..."
    
    # Utiliser l'installation automatisée en mode force
    if [ -f "./install-automated.sh" ]; then
        ./install-automated.sh --force --no-backup --quiet
        log "SUCCESS" "Intégration réinstallée avec succès"
    else
        log "WARNING" "Script d'installation automatisé non trouvé"
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_UPDATE=true
                shift
                ;;
            --scripts-only)
                SCRIPTS_ONLY=true
                shift
                ;;
            --full)
                SCRIPTS_ONLY=false
                shift
                ;;
            --quiet)
                QUIET_MODE=true
                shift
                ;;
            *)
                log "ERROR" "Option inconnue: $1"
                echo "Usage: $0 [--force] [--scripts-only] [--full] [--quiet]"
                exit 1
                ;;
        esac
    done
}

# === MAIN ===

# Analyse des arguments
parse_arguments "$@"

# Banner initial
if [ "$QUIET_MODE" = false ]; then
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🔄  TACTICAL RMM - SYSTÈME DE MISE À JOUR  🔄               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
fi

log "INFO" "Démarrage de la mise à jour v$SCRIPT_VERSION"

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
    log "ERROR" "Ce script doit être exécuté en tant que root"
    echo "Utilisez: sudo $0"
    exit 1
fi

cd "$SCRIPT_DIR"

if [ "$SCRIPTS_ONLY" = true ]; then
    # Mise à jour des scripts uniquement
    update_scripts_only
    import_updated_scripts
else
    # Mise à jour complète
    if check_git_status; then
        update_repository
        reinstall_integration
        import_updated_scripts
    else
        log "INFO" "Aucune mise à jour nécessaire"
        exit 0
    fi
fi

print_header "✅ Mise à jour terminée"

echo -e "${GREEN}La mise à jour a été appliquée avec succès !${NC}"
echo ""
echo -e "${CYAN}Logs : $LOG_FILE${NC}"

exit 0