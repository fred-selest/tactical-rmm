#!/bin/bash

###############################################################################
# Script de mise à jour de l'agent Tactical RMM Linux
# Compatible avec toutes les distributions Linux supportées
#
# Usage: sudo ./update-tactical-agent.sh [options]
# Options:
#   --force            Forcer la mise à jour même si déjà à jour
#   --backup           Créer une sauvegarde avant la mise à jour
#   --quiet            Mode silencieux (moins de logs)
#   --dry-run          Simuler la mise à jour sans l'exécuter
###############################################################################

set -e

# === VARIABLES GLOBALES ===
SCRIPT_VERSION="1.2"
SCRIPT_NAME="Mise à jour Agent Tactical RMM"

# Déterminer le fichier de log en fonction des permissions
if [ -w "/var/log" ]; then
    LOG_FILE="/var/log/tacticalrmm-agent-update.log"
else
    LOG_FILE="/tmp/tacticalrmm-agent-update.log"
fi

# URL de votre serveur Tactical RMM
TACTICAL_URL="https://rmm.selest.info"

# Options
FORCE_UPDATE=false
CREATE_BACKUP=false  
QUIET_MODE=false
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
    
    # Journalisation dans le fichier
    echo "$timestamp [$level] $message" >> "$LOG_FILE"
    
    # Affichage console (sauf en mode silencieux pour INFO)
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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "Ce script doit être exécuté en tant que root"
        echo "Utilisez: sudo $0"
        exit 1
    fi
}

check_tactical_installed() {
    log "STEP" "Vérification de l'installation Tactical RMM..."
    
    if [ -f "/usr/local/tactical/tactical.sh" ]; then
        TACTICAL_SCRIPT="/usr/local/tactical/tactical.sh"
        log "SUCCESS" "Agent Tactical trouvé : $TACTICAL_SCRIPT"
    elif [ -f "/var/tactical/tactical.sh" ]; then
        TACTICAL_SCRIPT="/var/tactical/tactical.sh"
        log "SUCCESS" "Agent Tactical trouvé : $TACTICAL_SCRIPT"
    else
        log "ERROR" "Agent Tactical RMM non trouvé"
        log "INFO" "Chemin vérifiés : /usr/local/tactical/tactical.sh, /var/tactical/tactical.sh"
        exit 1
    fi
    
    # Vérifier que le script est exécutable
    if [ ! -x "$TACTICAL_SCRIPT" ]; then
        log "WARNING" "Le script Tactical n'est pas exécutable, tentative de correction..."
        chmod +x "$TACTICAL_SCRIPT"
    fi
}

get_current_version() {
    log "INFO" "Récupération de la version actuelle..."
    
    if [ -f "/usr/local/tactical/agent-version.txt" ]; then
        CURRENT_VERSION=$(cat /usr/local/tactical/agent-version.txt)
    elif [ -f "/var/tactical/agent-version.txt" ]; then
        CURRENT_VERSION=$(cat /var/tactical/agent-version.txt)
    else
        # Essayer d'extraire la version du script
        CURRENT_VERSION=$($TACTICAL_SCRIPT --version 2>/dev/null || echo "inconnue")
    fi
    
    log "INFO" "Version actuelle : $CURRENT_VERSION"
    echo "$CURRENT_VERSION"
}

check_server_connectivity() {
    log "STEP" "Vérification de la connectivité au serveur..."
    
    if command -v curl >/dev/null 2>&1; then
        if curl -k --max-time 10 --silent --head --output /dev/null "$TACTICAL_URL/api/v3/" 2>/dev/null; then
            log "SUCCESS" "Connexion au serveur réussie : $TACTICAL_URL"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget --no-check-certificate --timeout=10 --spider "$TACTICAL_URL/api/v3/" >/dev/null 2>&1; then
            log "SUCCESS" "Connexion au serveur réussie : $TACTICAL_URL"
            return 0
        fi
    fi
    
    log "ERROR" "Impossible de se connecter au serveur : $TACTICAL_URL"
    log "INFO" "Vérifiez que le serveur est accessible et que les certificats SSL sont valides"
    exit 1
}

create_backup() {
    if [ "$CREATE_BACKUP" = false ]; then
        return 0
    fi
    
    print_header "Création de la sauvegarde"
    
    BACKUP_DIR="/root/tactical-agent-backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Sauvegarder le script principal
    if [ -f "$TACTICAL_SCRIPT" ]; then
        cp "$TACTICAL_SCRIPT" "$BACKUP_DIR/"
        log "SUCCESS" "Script agent sauvegardé"
    fi
    
    # Sauvegarder les fichiers de configuration
    if [ -d "/usr/local/tactical/" ]; then
        cp -r /usr/local/tactical/ "$BACKUP_DIR/tactical/"
        log "SUCCESS" "Configuration sauvegardée (/usr/local/tactical/)"
    elif [ -d "/var/tactical/" ]; then
        cp -r /var/tactical/ "$BACKUP_DIR/tactical/"
        log "SUCCESS" "Configuration sauvegardée (/var/tactical/)"
    fi
    
    # Sauvegarder les logs
    if [ -f "/var/log/tacticalrmm.log" ]; then
        cp "/var/log/tacticalrmm.log" "$BACKUP_DIR/"
        log "SUCCESS" "Logs sauvegardés"
    fi
    
    log "SUCCESS" "Sauvegarde créée dans : $BACKUP_DIR"
}

update_via_script() {
    print_header "Mise à jour de l'agent"
    
    if [ "$DRY_RUN" = true ]; then
        log "INFO" "Mode simulation - aucune mise à jour réelle effectuée"
        log "INFO" "Commande qui serait exécutée : $TACTICAL_SCRIPT"
        return 0
    fi
    
    log "STEP" "Exécution du script de mise à jour..."
    
    # Méthode 1 : Utiliser le script existant
    if "$TACTICAL_SCRIPT" update 2>>"$LOG_FILE"; then
        log "SUCCESS" "Mise à jour via script existant réussie"
        return 0
    fi
    
    # Méthode 2 : Télécharger et exécuter le script de mise à jour
    log "WARNING" "Méthode 1 échouée, tentative avec téléchargement direct..."
    
    TEMP_SCRIPT="/tmp/tactical-update-$$"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -k -s "$TACTICAL_URL/api/v3/linux/update/" -o "$TEMP_SCRIPT" 2>>"$LOG_FILE"; then
            chmod +x "$TEMP_SCRIPT"
            if "$TEMP_SCRIPT" 2>>"$LOG_FILE"; then
                log "SUCCESS" "Mise à jour par téléchargement réussie"
                rm -f "$TEMP_SCRIPT"
                return 0
            fi
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget --no-check-certificate -q "$TACTICAL_URL/api/v3/linux/update/" -O "$TEMP_SCRIPT" 2>>"$LOG_FILE"; then
            chmod +x "$TEMP_SCRIPT"
            if "$TEMP_SCRIPT" 2>>"$LOG_FILE"; then
                log "SUCCESS" "Mise à jour par téléchargement réussie"
                rm -f "$TEMP_SCRIPT"
                return 0
            fi
        fi
    fi
    
    # Nettoyer le script temporaire
    rm -f "$TEMP_SCRIPT"
    
    log "ERROR" "Échec de la mise à jour par toutes les méthodes"
    exit 1
}

verify_update() {
    print_header "Vérification de la mise à jour"
    
    sleep 5  # Attendre que l'agent redémarre
    
    NEW_VERSION=$(get_current_version)
    log "INFO" "Nouvelle version : $NEW_VERSION"
    
    # Vérifier que l'agent est actif
    if systemctl is-active --quiet tacticalagent 2>/dev/null; then
        log "SUCCESS" "Agent Tactical actif après la mise à jour"
    elif pgrep -f "tacticalagent" >/dev/null 2>&1; then
        log "SUCCESS" "Agent Tactical en cours d'exécution après la mise à jour"
    else
        log "WARNING" "Agent Tactical non détecté comme actif"
        log "INFO" "Cela peut être normal si l'agent utilise un autre système de démarrage"
    fi
    
    # Vérifier la connectivité
    check_server_connectivity
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_UPDATE=true
                shift
                ;;
            --backup)
                CREATE_BACKUP=true
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
                echo "Usage: $0 [--force] [--backup] [--quiet] [--dry-run]"
                exit 1
                ;;
        esac
    done
}

show_completion_summary() {
    if [ "$QUIET_MODE" = true ]; then
        return
    fi
    
    clear
    echo -e "${GREEN}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          ✅  MISE À JOUR AGENT RÉUSSIE !  ✅                  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    print_header "🎯 Résumé de la mise à jour"
    echo -e "${GREEN}✓ Agent Tactical RMM mis à jour${NC}"
    echo -e "${GREEN}✓ Connexion au serveur vérifiée${NC}"
    echo ""
    
    if [ "$CREATE_BACKUP" = true ]; then
        echo -e "${CYAN}📁 Sauvegarde créée dans /root/tactical-agent-backups/${NC}"
    fi
    
    echo -e "${CYAN}📋 Logs : $LOG_FILE${NC}"
}

# === MAIN ===

# Analyse des arguments
parse_arguments "$@"

# Banner initial
if [ "$QUIET_MODE" = false ] && [ "$DRY_RUN" = false ]; then
    clear
    echo -e "${MAGENTA}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🔄  TACTICAL RMM - MISE À JOUR AGENT LINUX  🔄             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
fi

log "INFO" "Démarrage de la mise à jour v$SCRIPT_VERSION"

# Vérification des privilèges root
check_root

# Vérification de l'installation Tactical
check_tactical_installed

# Vérification de la connectivité au serveur
check_server_connectivity

# Récupération de la version actuelle
CURRENT_VERSION=$(get_current_version)

# Création de la sauvegarde
create_backup

# Mise à jour de l'agent
update_via_script

# Vérification de la mise à jour
if [ "$DRY_RUN" = false ]; then
    verify_update
fi

# Affichage du résumé
show_completion_summary

log "INFO" "Mise à jour de l'agent Tactical RMM terminée avec succès"

exit 0