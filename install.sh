#!/bin/bash

#############################################
# Tactical RMM - Installation Universelle
# Détecte automatiquement le système et
# installe l'agent approprié
# Version: 1.0
#############################################

set -e

VERSION="1.0"
GITHUB_REPO="votre-user/tactical-rmm"
GITHUB_RAW="https://raw.githubusercontent.com/$GITHUB_REPO/main"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# === FONCTIONS UTILITAIRES ===

function print_header() {
    echo ""
    echo -e "${CYAN}=========================================="
    echo -e "  TACTICAL RMM - INSTALLATION UNIVERSELLE"
    echo -e "  Version $VERSION"
    echo -e "==========================================${NC}"
    echo ""
}

function log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

function check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Ce script doit être exécuté en tant que root"
        echo "Utilisez: sudo $0"
        exit 1
    fi
}

# === DÉTECTION DU SYSTÈME ===

function detect_os() {
    log_info "Détection du système d'exploitation..."

    # Détection de l'OS
    case "$(uname -s)" in
        Linux*)
            OS="linux"
            ;;
        Darwin*)
            OS="macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            OS="windows"
            ;;
        *)
            OS="unknown"
            ;;
    esac

    log_success "OS détecté: $OS"
}

function detect_distribution() {
    log_info "Détection de la distribution..."

    # Synology
    if [ -f /etc/synoinfo.conf ]; then
        DISTRO="synology"
        DISTRO_VERSION=$(grep -E 'productversion=' /etc.defaults/VERSION 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "unknown")
        log_success "Distribution: Synology DSM $DISTRO_VERSION"
        return
    fi

    # Standard Linux
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
        log_success "Distribution: $NAME $VERSION"
        return
    fi

    # Fallback
    if [ -f /etc/debian_version ]; then
        DISTRO="debian"
        DISTRO_VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        DISTRO="redhat"
        DISTRO_VERSION=$(cat /etc/redhat-release)
    else
        DISTRO="unknown"
        DISTRO_VERSION="unknown"
    fi

    log_warn "Distribution: $DISTRO $DISTRO_VERSION"
}

function detect_architecture() {
    log_info "Détection de l'architecture..."

    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH_NORMALIZED="amd64"
            ;;
        i386|i686)
            ARCH_NORMALIZED="x86"
            ;;
        aarch64)
            ARCH_NORMALIZED="arm64"
            ;;
        armv6l)
            ARCH_NORMALIZED="armv6"
            ;;
        armv7l)
            ARCH_NORMALIZED="armv7"
            ;;
        *)
            ARCH_NORMALIZED="unknown"
            ;;
    esac

    log_success "Architecture: $ARCH ($ARCH_NORMALIZED)"
}

# === COLLECTE DES PARAMÈTRES ===

function collect_parameters() {
    echo ""
    echo -e "${CYAN}=== CONFIGURATION DE L'AGENT ===${NC}"
    echo ""

    # API URL
    if [ -z "$API_URL" ]; then
        echo -n "URL de l'API Tactical RMM (ex: https://api.votredomaine.com): "
        read API_URL
    fi

    # Client ID
    if [ -z "$CLIENT_ID" ]; then
        echo -n "Client ID: "
        read CLIENT_ID
    fi

    # Site ID
    if [ -z "$SITE_ID" ]; then
        echo -n "Site ID: "
        read SITE_ID
    fi

    # Auth Key
    if [ -z "$AUTH_KEY" ]; then
        echo -n "Auth Key: "
        read AUTH_KEY
    fi

    # Agent Type
    if [ -z "$AGENT_TYPE" ]; then
        echo -n "Type d'agent (server/workstation) [workstation]: "
        read AGENT_TYPE
        AGENT_TYPE="${AGENT_TYPE:-workstation}"
    fi

    # Mesh URL (optionnel, généré depuis l'API)
    if [ -z "$MESH_URL" ]; then
        echo -n "URL Mesh Agent (optionnel, laisser vide si auto): "
        read MESH_URL
    fi

    echo ""
    log_info "Configuration:"
    echo "  API URL    : $API_URL"
    echo "  Client ID  : $CLIENT_ID"
    echo "  Site ID    : $SITE_ID"
    echo "  Type       : $AGENT_TYPE"
    echo ""
}

# === VÉRIFICATION INSTALLATION EXISTANTE ===

function check_existing_installation() {
    log_info "Vérification de l'installation existante..."

    # Linux
    if systemctl is-active --quiet tacticalagent 2>/dev/null; then
        log_warn "L'agent Tactical RMM est déjà installé et actif"
        echo -n "Voulez-vous réinstaller ? (o/N): "
        read CONFIRM
        if [ "$CONFIRM" != "o" ] && [ "$CONFIRM" != "O" ]; then
            log_info "Installation annulée"
            exit 0
        fi
    fi

    # Windows (à implémenter si nécessaire)
}

# === INSTALLATION SELON L'OS ===

function install_linux() {
    log_info "Installation de l'agent Linux..."

    # Télécharger le script Linux amélioré
    local script_url="$GITHUB_RAW/rmmagent-linux.sh"
    local script_path="/tmp/tactical-install-$$.sh"

    log_info "Téléchargement du script d'installation..."
    if ! wget -q -O "$script_path" "$script_url"; then
        log_error "Impossible de télécharger le script d'installation"
        log_info "URL: $script_url"
        exit 1
    fi

    chmod +x "$script_path"

    # Générer l'URL Mesh si non fournie
    if [ -z "$MESH_URL" ]; then
        MESH_URL="$API_URL/api/v3/meshcentral/?agent_type=$AGENT_TYPE&client_id=$CLIENT_ID&site_id=$SITE_ID&arch=$ARCH_NORMALIZED&token=$AUTH_KEY"
        log_info "URL Mesh générée automatiquement"
    fi

    # Lancer l'installation
    log_info "Lancement de l'installation..."
    "$script_path" install \
        "$MESH_URL" \
        "$API_URL" \
        "$CLIENT_ID" \
        "$SITE_ID" \
        "$AUTH_KEY" \
        "$AGENT_TYPE"

    local exit_code=$?
    rm -f "$script_path"

    if [ $exit_code -eq 0 ]; then
        log_success "Installation Linux terminée avec succès"
        return 0
    else
        log_error "Échec de l'installation Linux"
        return 1
    fi
}

function install_windows() {
    log_error "Installation Windows non supportée via ce script bash"
    echo ""
    echo "Pour Windows, utilisez PowerShell :"
    echo ""
    echo "# Télécharger et exécuter le script PowerShell"
    echo "Invoke-WebRequest -Uri \"$GITHUB_RAW/scripts/windows/install/windows_agent_install.ps1\" -OutFile \"tactical-install.ps1\""
    echo ""
    echo "# Puis exécuter :"
    echo ".\\tactical-install.ps1 -ApiUrl \"$API_URL\" -ClientId $CLIENT_ID -SiteId $SITE_ID -AuthKey \"$AUTH_KEY\" -AgentType \"$AGENT_TYPE\""
    echo ""
    exit 1
}

function install_macos() {
    log_error "Installation macOS non supportée actuellement"
    echo ""
    echo "Tactical RMM ne supporte pas officiellement macOS."
    echo "Pour le support macOS, consultez :"
    echo "  - https://docs.tacticalrmm.com/"
    echo ""
    exit 1
}

# === INSTALLATION AUTO-UPDATE ===

function install_auto_update() {
    if [ "$OS" != "linux" ]; then
        return
    fi

    echo ""
    echo -n "Voulez-vous installer le système de mise à jour automatique ? (O/n): "
    read INSTALL_AUTO_UPDATE

    if [ "$INSTALL_AUTO_UPDATE" = "n" ] || [ "$INSTALL_AUTO_UPDATE" = "N" ]; then
        log_info "Mise à jour automatique ignorée"
        return
    fi

    log_info "Installation du système de mise à jour automatique..."

    # Télécharger les fichiers
    local auto_update_url="$GITHUB_RAW/scripts/linux/auto-update"
    local temp_dir="/tmp/tactical-auto-update-$$"
    mkdir -p "$temp_dir"

    wget -q -O "$temp_dir/install-auto-update.sh" "$auto_update_url/install-auto-update.sh"
    wget -q -O "$temp_dir/tactical-agent-updater.sh" "$auto_update_url/tactical-agent-updater.sh"
    wget -q -O "$temp_dir/auto-update.conf" "$auto_update_url/auto-update.conf"
    wget -q -O "$temp_dir/tactical-agent-updater.service" "$auto_update_url/tactical-agent-updater.service"
    wget -q -O "$temp_dir/tactical-agent-updater.timer" "$auto_update_url/tactical-agent-updater.timer"

    chmod +x "$temp_dir/install-auto-update.sh"

    cd "$temp_dir"
    ./install-auto-update.sh

    cd -
    rm -rf "$temp_dir"

    log_success "Système de mise à jour automatique installé"
}

# === VÉRIFICATION POST-INSTALLATION ===

function verify_installation() {
    log_info "Vérification de l'installation..."

    case $OS in
        linux)
            if systemctl is-active --quiet tacticalagent; then
                log_success "Service tacticalagent actif"
                return 0
            else
                log_error "Service tacticalagent non actif"
                systemctl status tacticalagent --no-pager || true
                return 1
            fi
            ;;
        *)
            log_warn "Vérification non disponible pour $OS"
            return 0
            ;;
    esac
}

# === AFFICHAGE DU RÉSUMÉ ===

function show_summary() {
    echo ""
    echo -e "${GREEN}=========================================="
    echo -e "  INSTALLATION TERMINÉE"
    echo -e "==========================================${NC}"
    echo ""
    echo "Système       : $OS ($DISTRO $DISTRO_VERSION)"
    echo "Architecture  : $ARCH_NORMALIZED"
    echo "API URL       : $API_URL"
    echo "Type agent    : $AGENT_TYPE"
    echo ""

    if [ "$OS" = "linux" ]; then
        echo "Commandes utiles :"
        echo "  - État du service : sudo systemctl status tacticalagent"
        echo "  - Logs           : sudo journalctl -u tacticalagent -f"
        echo "  - Redémarrer     : sudo systemctl restart tacticalagent"
        echo ""
    fi

    echo "L'agent apparaîtra dans l'interface Tactical RMM sous peu."
    echo ""
}

# === AIDE ===

function show_help() {
    cat << EOF
Tactical RMM - Installation Universelle
Usage: $0 [OPTIONS]

Ce script détecte automatiquement votre système et installe l'agent
Tactical RMM approprié.

OPTIONS:
  -a, --api-url URL         URL de l'API Tactical RMM
  -c, --client-id ID        ID du client
  -s, --site-id ID          ID du site
  -k, --auth-key KEY        Clé d'authentification
  -t, --agent-type TYPE     Type d'agent (server|workstation)
  -m, --mesh-url URL        URL Mesh Agent (optionnel)
  -h, --help                Afficher cette aide

EXEMPLES:

  # Installation interactive (recommandé)
  sudo ./install.sh

  # Installation non-interactive
  sudo ./install.sh \\
    --api-url "https://api.votredomaine.com" \\
    --client-id 1 \\
    --site-id 2 \\
    --auth-key "votre-auth-key" \\
    --agent-type server

  # Installation via curl (one-liner)
  curl -sSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | \\
    sudo bash -s -- --api-url "https://api.votredomaine.com" \\
    --client-id 1 --site-id 2 --auth-key "key" --agent-type workstation

SYSTÈMES SUPPORTÉS:
  - Linux  : Ubuntu, Debian, CentOS, Rocky, Synology, etc.
  - Windows: Via PowerShell (voir documentation)
  - macOS  : Non supporté

DOCUMENTATION:
  https://github.com/$GITHUB_REPO

EOF
    exit 0
}

# === PARSING DES ARGUMENTS ===

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--api-url)
            API_URL="$2"
            shift 2
            ;;
        -c|--client-id)
            CLIENT_ID="$2"
            shift 2
            ;;
        -s|--site-id)
            SITE_ID="$2"
            shift 2
            ;;
        -k|--auth-key)
            AUTH_KEY="$2"
            shift 2
            ;;
        -t|--agent-type)
            AGENT_TYPE="$2"
            shift 2
            ;;
        -m|--mesh-url)
            MESH_URL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Option inconnue: $1"
            echo "Utilisez --help pour voir les options disponibles"
            exit 1
            ;;
    esac
done

# === MAIN ===

print_header

# Vérifier les droits root (sauf pour --help)
check_root

# Détection du système
detect_os
detect_distribution
detect_architecture

# Vérifier installation existante
check_existing_installation

# Collecter les paramètres si non fournis
if [ -z "$API_URL" ] || [ -z "$CLIENT_ID" ] || [ -z "$SITE_ID" ] || [ -z "$AUTH_KEY" ]; then
    collect_parameters
fi

# Installation selon l'OS
case $OS in
    linux)
        install_linux
        ;;
    windows)
        install_windows
        ;;
    macos)
        install_macos
        ;;
    *)
        log_error "Système non supporté: $OS"
        exit 1
        ;;
esac

# Vérification
verify_installation

# Installation auto-update (Linux uniquement)
install_auto_update

# Afficher le résumé
show_summary

exit 0
