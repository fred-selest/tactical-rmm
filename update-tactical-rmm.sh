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
#   --dry-run          Affiche ce qui serait fait, sans rien modifier
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
DRY_RUN=false

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
    # --ff-only : interdit la création d'un commit de merge silencieux si le
    # dépôt local a divergé. Mieux vaut un échec explicite qu'une divergence
    # qui s'accumule à chaque exécution.
    if ! git pull --ff-only origin "$BRANCH"; then
        log "ERROR" "git pull --ff-only a échoué : le dépôt local a peut-être divergé de origin/$BRANCH."
        log "ERROR" "Résoudre manuellement (git log --oneline --graph HEAD origin/$BRANCH) avant de réessayer."
        exit 1
    fi

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

    # Le chemin du dépôt est SCRIPT_DIR, pas /home/debian/tactical-rmm figé en dur.
    local importer="$SCRIPT_DIR/import-monitoring-scripts.py"
    local out line imported missing
    IMPORT_FAILED=false

    if [ -f "$importer" ]; then
        log "STEP" "Importation des scripts dans la base de données..."

        # Trouver le bon chemin RMM
        # Mêmes règles de détection que install-automated.sh : ce script
        # retenait python3, l'autre python, et seul le second était vérifié.
        if [ -d "/rmm/api/tacticalrmm" ]; then
            RMM_PATH="/rmm/api/tacticalrmm"
            PYTHON_DIR="/rmm/api/env/bin"
        elif [ -d "/opt/tacticalrmm/api/tacticalrmm" ]; then
            RMM_PATH="/opt/tacticalrmm/api/tacticalrmm"
            PYTHON_DIR="/opt/tacticalrmm/api/env/bin"
        else
            log "ERROR" "Tactical RMM non trouvé"
            return 1
        fi
        if [ -f "$PYTHON_DIR/python" ]; then
            PYTHON_BIN="$PYTHON_DIR/python"
        elif [ -f "$PYTHON_DIR/python3" ]; then
            PYTHON_BIN="$PYTHON_DIR/python3"
        else
            log "ERROR" "Interpréteur Python introuvable dans $PYTHON_DIR"
            return 1
        fi

        if [ "$DRY_RUN" = true ]; then
            log "INFO" "[dry-run] Importation via $importer (non exécutée)"
            return 0
        fi

        if out=$( cd "$RMM_PATH" && sudo -u tactical $PYTHON_BIN "$importer" "$SCRIPT_DIR" "$RMM_PATH" 2>&1 ); then
            line=$(printf '%s\n' "$out" | grep '^RESULTAT_IMPORT ' | tail -1)
            if [ -n "$line" ]; then
                imported=$(printf '%s' "$line" | awk '{print $2}')
                missing=$(printf '%s' "$line" | awk '{print $3}')
                if [ "${missing:-0}" -gt 0 ]; then
                    log "WARNING" "$imported scripts importés, $missing introuvables :"
                    printf '%s\n' "$out" | grep '^MANQUANT ' | sed 's/^MANQUANT /  - /' | while read -r m; do
                        log "WARNING" "$m"
                    done
                else
                    log "SUCCESS" "$imported scripts importés dans Tactical RMM"
                fi
            else
                log "WARNING" "Pas de compte rendu d'import, voir $LOG_FILE"
            fi
        else
            log "ERROR" "L'importation des scripts a échoué (voir $LOG_FILE)"
            log "ERROR" "Les scripts de surveillance n'ont pas été mis à jour en base."
            IMPORT_FAILED=true
        fi
    else
        log "WARNING" "Script d'importation non trouvé ($importer), importation ignorée"
    fi
}

reinstall_integration() {
    print_header "Réinstallation de l'intégration Linux Deployments"

    log "STEP" "Exécution de l'installation automatisée..."

    if [ "$DRY_RUN" = true ]; then
        log "INFO" "[dry-run] Commande prévue : ./install-automated.sh --force --quiet"
        return 0
    fi

    # Utiliser l'installation automatisée en mode force
    if [ -f "./install-automated.sh" ]; then
        # --no-backup a été retiré : cette étape réécrit settings.py, urls.py et
        # l'ensemble de linux_deployments/, puis applique des migrations.
        # Sans sauvegarde, un échec est irréversible sur le serveur de production.
        if ./install-automated.sh --force --quiet; then
            log "SUCCESS" "Intégration réinstallée avec succès"
        else
            log "ERROR" "L'installation automatisée a échoué : l'intégration est potentiellement désynchronisée."
            log "ERROR" "Restaurer depuis /root/tactical-rmm-backups/ si nécessaire."
            exit 1
        fi
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
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log "ERROR" "Option inconnue: $1"
                echo "Usage: $0 [--force] [--scripts-only] [--full] [--quiet] [--dry-run]"
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
    clear 2>/dev/null || true
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

if [ "$DRY_RUN" = true ]; then
    print_header "🔍 Simulation (--dry-run) — aucune modification"
    log "INFO" "Commit local  : $(git rev-parse HEAD 2>/dev/null || echo 'inconnu')"
    if git fetch --quiet origin "$BRANCH" 2>/dev/null; then
        log "INFO" "Commit origin : $(git rev-parse origin/$BRANCH 2>/dev/null || echo 'inconnu')"
        if [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/$BRANCH)" ]; then
            log "INFO" "Résultat      : déjà à jour"
        else
            log "INFO" "Résultat      : mise à jour disponible"
            git log --oneline HEAD..origin/$BRANCH | while read -r line; do
                log "INFO" "  $line"
            done
        fi
    else
        log "WARNING" "Impossible de joindre origin (réseau ?)"
    fi
    log "INFO" "Aurait exécuté : git pull --ff-only origin $BRANCH"
    log "INFO" "Aurait exécuté : ./install-automated.sh --force --quiet (avec sauvegarde)"
    log "INFO" "Aurait exécuté : $SCRIPT_DIR/import-monitoring-scripts.py"
    print_header "Fin de la simulation — rien n'a été modifié"
    exit 0
fi

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

if [ "${IMPORT_FAILED:-false}" = true ]; then
    print_header "⚠️  Mise à jour partiellement appliquée"
    log "ERROR" "Le dépôt et l'intégration ont été mis à jour, mais l'import des"
    log "ERROR" "scripts de surveillance a échoué. Corriger puis relancer :"
    log "ERROR" "    cd \$RMM_PATH && sudo -u tactical \$PYTHON_BIN \$SCRIPT_DIR/import-monitoring-scripts.py \$SCRIPT_DIR \$RMM_PATH"
    exit 1
fi

print_header "✅ Mise à jour terminée"

echo -e "${GREEN}La mise à jour a été appliquée avec succès !${NC}"
echo ""
echo -e "${CYAN}Logs : $LOG_FILE${NC}"

exit 0
