#!/bin/bash

#############################################
# Tactical RMM - Script d'installation Linux
# Version Dashboard avec support UUID
# Version: 3.0
#############################################

# Ce script peut être appelé de deux façons:
# 1. Avec tous les paramètres (compatibilité)
# 2. Avec un UUID de déploiement (nouveau)

# Arrêter en cas d'erreur (désactivé pour gérer manuellement)
# set -e

# === VARIABLES GLOBALES ===
VERSION="3.0"
LOG_FILE="/var/log/tacticalrmm-install.log"
# `check` et `status` tournent aussi sans root : on ne journalise alors pas sur disque.
if ! { [ -w "$LOG_FILE" ] || [ -w "$(dirname "$LOG_FILE")" ]; }; then
    LOG_FILE="/dev/null"
fi
GO_INSTALLED_BY_SCRIPT=false
LANG="${TACTICAL_LANG:-fr_FR}"
GO_VERSION="1.21.6"

# Source de l'agent compile localement.
# Le script compilait "refs/heads/master" : la version obtenue ne dependait
# donc d'aucun controle, et la doc amont rappelle que "the agent's version is
# directly tied to the RMM's version". Compiler une branche mutable sur un
# serveur de production expose aussi a executer du code non verifie.
# On epingle sur un tag ; TACTICAL_AGENT_REF permet de surcharger.
# v2.12.0 = LATEST_AGENT_VER de Tactical RMM 1.6.1 (settings.py, verifie sur
# api.selest.info le 14/11/2026). A chaque montee de version du serveur, aligner
# ce tag : un agent plus ancien reste en "agentupdate pending" indefiniment.
AGENT_REPO="https://github.com/amidaware/rmmagent"
AGENT_REF="${TACTICAL_AGENT_REF:-v2.12.0}"
# Binaire deja compile a installer tel quel (saute Go + compilation).
# Obligatoire sur Synology : l'agent y est un build modifie (rmmagent-synology/).
AGENT_BINARY="${TACTICAL_AGENT_BINARY:-}"

# === COULEURS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === FONCTIONS UTILITAIRES ===

function log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_FILE"
}

function msg() {
    case $1 in
        install_start)
            [ "$LANG" = "fr_FR" ] && echo "Début de l'installation de Tactical RMM..." || echo "Starting Tactical RMM installation..."
            ;;
        install_complete)
            [ "$LANG" = "fr_FR" ] && echo "Installation terminée avec succès !" || echo "Installation completed successfully!"
            ;;
        update_start)
            [ "$LANG" = "fr_FR" ] && echo "Début de la mise à jour..." || echo "Starting update..."
            ;;
        update_complete)
            [ "$LANG" = "fr_FR" ] && echo "Mise à jour terminée avec succès !" || echo "Update completed successfully!"
            ;;
        uninstall_complete)
            [ "$LANG" = "fr_FR" ] && echo "Désinstallation terminée." || echo "Uninstall completed."
            ;;
        error_deps)
            [ "$LANG" = "fr_FR" ] && echo "ERREUR: Dépendances manquantes" || echo "ERROR: Missing dependencies"
            ;;
        checking_deps)
            [ "$LANG" = "fr_FR" ] && echo "Vérification des dépendances..." || echo "Checking dependencies..."
            ;;
    esac
}

function print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function print_error() {
    echo -e "${RED}✗ $1${NC}"
}

function print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

function print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

function detect_system() {
    log "Détection du système..."

    # Architecture
    system=$(uname -m)
    case $system in
        x86_64) ARCH="amd64" ;;
        i386|i686) ARCH="x86" ;;
        aarch64) ARCH="arm64" ;;
        armv6l) ARCH="armv6" ;;
        *) log "Architecture non supportée: $system"; exit 1 ;;
    esac
    log "Architecture: $ARCH"

    # Détection de Synology
    if [ -f /etc/synoinfo.conf ]; then
        OS_TYPE="synology"
        INSTALL_PATH="/volume1/@appstore/tactical-rmm"
        GO_PATH="$INSTALL_PATH/go"
        log "Système détecté: Synology DSM"

        # Lire les infos Synology
        if [ -f /etc.defaults/VERSION ]; then
            SYNO_VERSION=$(grep -E 'productversion=' /etc.defaults/VERSION | cut -d'=' -f2 | tr -d '"')
            log "Version DSM: $SYNO_VERSION"
        fi
        return
    fi

    # Détection standard via /etc/os-release
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE="$ID"
        OS_VERSION="${VERSION_ID:-unknown}"
        log "Système détecté: $NAME $VERSION"
    else
        OS_TYPE="unknown"
        log "ATTENTION: Système non identifié, utilisation des paramètres par défaut"
    fi

    # Chemins standards pour Linux classique
    INSTALL_PATH="/opt/tacticalrmm"
    GO_PATH="/usr/local/go"
}

function check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Ce script doit être exécuté en tant que root"
        echo "Utilisez: sudo $0"
        exit 1
    fi
}

function check_dependencies() {
    msg checking_deps
    local missing=()
    local to_install=()

    # Vérification des commandes de base
    for cmd in wget tar curl jq; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
            to_install+=($cmd)
        fi
    done

    # systemd (pas sur Synology avec DSM < 7)
    if [ "$OS_TYPE" != "synology" ]; then
        if ! command -v systemctl &> /dev/null; then
            missing+=(systemd)
            to_install+=(systemd)
        fi
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log "Dépendances manquantes: ${missing[*]}"
        log "Installation automatique..."

        # Détection du gestionnaire de paquets
        if command -v apt-get &> /dev/null; then
            apt-get update -qq && apt-get install -y -qq ${to_install[*]}
        elif command -v yum &> /dev/null; then
            yum install -y -q ${to_install[*]}
        elif command -v dnf &> /dev/null; then
            dnf install -y -q ${to_install[*]}
        elif command -v opkg &> /dev/null; then
            # Synology
            opkg update && opkg install ${to_install[*]}
        elif command -v apk &> /dev/null; then
            # Alpine
            apk add --no-cache ${to_install[*]}
        else
            print_error "Gestionnaire de paquets non supporté"
            log "Veuillez installer manuellement: ${missing[*]}"
            exit 1
        fi

        log "Dépendances installées avec succès"
    else
        log "Toutes les dépendances sont présentes"
    fi
}

function setup_temp_dir() {
    if [[ -w /tmp ]]; then
        TMPDIR="/tmp/tacticalrmm-$$"
    else
        TMPDIR="$(pwd)/tmp_tacticalrmm_$$"
    fi

    mkdir -p "$TMPDIR"

    if [[ ! -w "$TMPDIR" ]]; then
        log "ERREUR: Impossible de créer le répertoire temporaire"
        exit 1
    fi

    log "Répertoire temporaire: $TMPDIR"
}

function cleanup() {
    log "Nettoyage des fichiers temporaires..."

    # Nettoyer Go si installé par ce script
    if [ "$GO_INSTALLED_BY_SCRIPT" = "true" ] && [ "$OS_TYPE" != "synology" ]; then
        log "Suppression de Go (installé temporairement)..."
        rm -rf "$GO_PATH"
    fi

    # Nettoyer le répertoire temporaire
    if [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
        log "Fichiers temporaires supprimés"
    fi
}

function download_file() {
    local url=$1
    local output=$2
    local description=${3:-fichier}

    log "Téléchargement: $description"

    if wget -q --show-progress --timeout=60 -O "$output" "$url" 2>&1 | tee -a "$LOG_FILE"; then
        if [ ! -s "$output" ]; then
            log "ERREUR: Fichier téléchargé vide"
            return 1
        fi
        local size=$(du -h "$output" | cut -f1)
        log "Téléchargement réussi: $size"
        return 0
    else
        log "ERREUR: Échec du téléchargement de $url"
        return 1
    fi
}

# === NOUVELLE FONCTION: RÉCUPÉRATION CONFIG DEPUIS API ===

function fetch_deployment_config() {
    local deployment_uuid=$1
    local api_url=$2

    print_info "Récupération de la configuration depuis l'API..."
    log "UUID de déploiement: $deployment_uuid"
    log "API URL: $api_url"

    # URL de l'endpoint de configuration (à définir dans l'API)
    local config_url="${api_url}/api/v3/linux-deployments/${deployment_uuid}/config/"

    # Télécharger la configuration JSON
    local config_file="$TMPDIR/deployment_config.json"

    if ! curl -sf -L "$config_url" -o "$config_file"; then
        print_error "Impossible de récupérer la configuration depuis l'API"
        log "URL tentée: $config_url"

        # Essayer l'URL alternative (sans /config/)
        config_url="${api_url}/api/v3/linux-deployments/${deployment_uuid}/"
        if ! curl -sf -L "$config_url" -o "$config_file"; then
            print_error "Échec de récupération de la configuration"
            return 1
        fi
    fi

    # Vérifier que le fichier JSON est valide
    if ! jq empty "$config_file" 2>/dev/null; then
        print_error "Configuration JSON invalide"
        cat "$config_file" | tee -a "$LOG_FILE"
        return 1
    fi

    # Parser le JSON et extraire les variables
    mesh_url=$(jq -r '.mesh_url' "$config_file")
    rmm_url=$(jq -r '.api_url' "$config_file")
    rmm_client_id=$(jq -r '.client_id' "$config_file")
    rmm_site_id=$(jq -r '.site_id' "$config_file")
    rmm_auth=$(jq -r '.auth_key' "$config_file")
    rmm_agent_type=$(jq -r '.agent_type' "$config_file")

    # Afficher les informations récupérées
    print_success "Configuration récupérée avec succès"
    print_info "Client: $(jq -r '.client_name' "$config_file")"
    print_info "Site: $(jq -r '.site_name' "$config_file")"
    print_info "Type d'agent: $rmm_agent_type"
    print_info "Architecture: $(jq -r '.arch' "$config_file")"

    # Valider les données
    if [ -z "$mesh_url" ] || [ -z "$rmm_url" ] || [ -z "$rmm_client_id" ] || [ -z "$rmm_site_id" ] || [ -z "$rmm_auth" ]; then
        print_error "Configuration incomplète"
        return 1
    fi

    log "Configuration validée"
    return 0
}

function notify_installation_status() {
    local deployment_uuid=$1
    local api_url=$2
    local status=$3
    local error_message=${4:-""}

    local hostname=$(hostname)
    local callback_url="${api_url}/api/v3/linux-deployments/${deployment_uuid}/installed/"

    # Créer le payload JSON
    local payload
    if [ -n "$error_message" ]; then
        payload=$(jq -n \
            --arg hostname "$hostname" \
            --arg status "$status" \
            --arg error "$error_message" \
            '{hostname: $hostname, status: $status, error: $error}')
    else
        payload=$(jq -n \
            --arg hostname "$hostname" \
            --arg status "$status" \
            '{hostname: $hostname, status: $status}')
    fi

    # Envoyer la notification
    if curl -sf -X POST "$callback_url" \
        -H "Content-Type: application/json" \
        -d "$payload" > /dev/null 2>&1; then
        log "Notification envoyée au serveur: $status"
    else
        log "ATTENTION: Impossible d'envoyer la notification au serveur"
    fi
}

# === GO INSTALLATION (inchangé) ===

function go_install() {
    # Vérifier si Go est déjà installé
    if command -v go &> /dev/null; then
        local installed_version=$(go version | grep -oP 'go\K[0-9.]+')
        log "Go déjà installé (version $installed_version)"
        return 0
    fi

    log "Installation de Go $GO_VERSION..."

    # URLs selon l'architecture
    local go_url
    case $ARCH in
        amd64) go_url="https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" ;;
        x86) go_url="https://go.dev/dl/go${GO_VERSION}.linux-386.tar.gz" ;;
        arm64) go_url="https://go.dev/dl/go${GO_VERSION}.linux-arm64.tar.gz" ;;
        armv6) go_url="https://go.dev/dl/go${GO_VERSION}.linux-armv6l.tar.gz" ;;
    esac

    # Télécharger Go
    if ! download_file "$go_url" "$TMPDIR/golang.tar.gz" "Go $GO_VERSION"; then
        log "ERREUR: Impossible de télécharger Go"
        exit 1
    fi

    # Extraire Go
    log "Extraction de Go..."
    mkdir -p "$(dirname $GO_PATH)"
    rm -rf "$GO_PATH"

    if tar -xzf "$TMPDIR/golang.tar.gz" -C "$(dirname $GO_PATH)/" 2>&1 | tee -a "$LOG_FILE"; then
        # Renommer si nécessaire
        if [ "$(dirname $GO_PATH)/go" != "$GO_PATH" ]; then
            mv "$(dirname $GO_PATH)/go" "$GO_PATH"
        fi

        rm "$TMPDIR/golang.tar.gz"
        export PATH=$PATH:$GO_PATH/bin
        GO_INSTALLED_BY_SCRIPT=true
        log "Go installé avec succès dans $GO_PATH"
    else
        log "ERREUR: Échec de l'extraction de Go"
        exit 1
    fi
}

# === COMPILATION AGENT (inchangé) ===

function agent_compile() {
    log "Téléchargement du code source de rmmagent..."

    case "$AGENT_REF" in
        v[0-9]*)
            ARCHIVE_URL="$AGENT_REPO/archive/refs/tags/${AGENT_REF}.tar.gz"
            ;;
        *)
            log "ATTENTION: AGENT_REF='$AGENT_REF' n'est pas un tag de version."
            log "ATTENTION: le build ne sera pas reproductible (branche mutable)."
            ARCHIVE_URL="$AGENT_REPO/archive/refs/heads/${AGENT_REF}.tar.gz"
            ;;
    esac
    log "Source agent: $AGENT_REF -> $ARCHIVE_URL"
    if ! download_file "$ARCHIVE_URL" "$TMPDIR/rmmagent.tar.gz" "rmmagent source ($AGENT_REF)"; then
        log "ERREUR: telechargement de la source agent en echec"
        log "       verifiez que le tag $AGENT_REF existe, ou surchargez :"
        log "       TACTICAL_AGENT_REF=<tag|branche> $0"
        exit 1
    fi

    log "Extraction du code source..."
    if ! tar -xzf "$TMPDIR/rmmagent.tar.gz" -C "$TMPDIR/" 2>&1 | tee -a "$LOG_FILE"; then
        log "ERREUR: Échec de l'extraction du code source"
        exit 1
    fi
    rm "$TMPDIR/rmmagent.tar.gz"

    # GitHub n'extrait pas toujours dans le meme repertoire :
    #   refs/heads/master  -> rmmagent-master/
    #   refs/tags/v2.11.0  -> rmmagent-2.11.0/
    # Un chemin en dur cassait donc des que AGENT_REF etait un tag.
    SRC_DIR=$(find "$TMPDIR" -maxdepth 1 -type d -name 'rmmagent-*' | head -1)
    if [ -z "$SRC_DIR" ]; then
        log "ERREUR: repertoire source introuvable apres extraction dans $TMPDIR"
        log "       contenu: $(ls "$TMPDIR")"
        exit 1
    fi
    log "Repertoire source: $SRC_DIR"

    log "Compilation de l'agent pour $ARCH..."
    # Sans cette garde, un cd raté fait compiler le code du repertoire
    # courant : go build produirait un binaire valide mais faux, et le
    # script l installerait sans bruit.
    cd "$SRC_DIR" || { log "ERREUR: cd $SRC_DIR a echoue"; exit 1; }

    # S'assurer que Go est dans le PATH
    export PATH=$PATH:$GO_PATH/bin
    export CGO_ENABLED=0
    export GOOS=linux

    case $ARCH in
        amd64) export GOARCH=amd64 ;;
        x86) export GOARCH=386 ;;
        arm64) export GOARCH=arm64 ;;
        armv6) export GOARCH=arm; export GOARM=6 ;;
    esac

    if go build -ldflags "-s -w" -o "$TMPDIR/temp_rmmagent" 2>&1 | tee -a "$LOG_FILE"; then
        if [ ! -f "$TMPDIR/temp_rmmagent" ]; then
            log "ERREUR: Le binaire compilé n'existe pas"
            exit 1
        fi

        local size=$(du -h "$TMPDIR/temp_rmmagent" | cut -f1)
        log "Compilation réussie (taille: $size)"

        # Rendre exécutable
        chmod +x "$TMPDIR/temp_rmmagent"
    else
        log "ERREUR: Échec de la compilation"
        exit 1
    fi

    cd "$TMPDIR" || exit 1
    rm -rf "$SRC_DIR"
}

# === MESH AGENT (inchangé) ===

function install_mesh() {
    log "Installation de Mesh Agent..."

    if ! download_file "$mesh_url" "$TMPDIR/meshagent" "Mesh Agent"; then
        log "ERREUR: Impossible de télécharger Mesh Agent"
        exit 1
    fi

    chmod +x "$TMPDIR/meshagent"

    local mesh_path="/opt/tacticalmesh"
    mkdir -p "$mesh_path"

    if "$TMPDIR/meshagent" -install --installPath="$mesh_path" 2>&1 | tee -a "$LOG_FILE"; then
        log "Mesh Agent installé avec succès"
    else
        log "ATTENTION: Problème lors de l'installation de Mesh Agent"
    fi

    rm -f "$TMPDIR/meshagent"
    rm -f "$TMPDIR/meshagent.msh"
}

# === INSTALLATION AGENT (inchangé) ===

function install_agent() {
    if [ "$OS_TYPE" = "synology" ]; then
        install_agent_synology
        return
    fi

    log "Installation de l'agent Tactical RMM..."

    # Créer le répertoire d'installation
    mkdir -p "$INSTALL_PATH/bin"

    # Copier le binaire
    if ! cp "$TMPDIR/temp_rmmagent" "$INSTALL_PATH/bin/rmmagent"; then
        log "ERREUR: Impossible de copier le binaire"
        exit 1
    fi
    chmod +x "$INSTALL_PATH/bin/rmmagent"

    # Créer un lien symbolique dans /usr/local/bin pour compatibilité
    ln -sf "$INSTALL_PATH/bin/rmmagent" /usr/local/bin/rmmagent

    # Initialiser l'agent
    log "Initialisation de l'agent..."
    if ! "$INSTALL_PATH/bin/rmmagent" -m install -api "$rmm_url" -client-id "$rmm_client_id" -site-id "$rmm_site_id" -agent-type "$rmm_agent_type" -auth "$rmm_auth" 2>&1 | tee -a "$LOG_FILE"; then
        log "ERREUR: Échec de l'initialisation de l'agent"
        exit 1
    fi

    rm "$TMPDIR/temp_rmmagent"

    # Créer le service systemd
    log "Création du service systemd..."
    cat > /etc/systemd/system/tacticalagent.service << EOF
[Unit]
Description=Tactical RMM Linux Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$INSTALL_PATH/bin/rmmagent -m svc
User=root
Group=root
Restart=always
RestartSec=5s
LimitNOFILE=1000000
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tacticalagent 2>&1 | tee -a "$LOG_FILE"
    systemctl start tacticalagent 2>&1 | tee -a "$LOG_FILE"

    log "Service tacticalagent démarré"
}

function install_agent_synology() {
    log "Installation de l'agent Tactical RMM pour Synology..."

    mkdir -p "$INSTALL_PATH"

    # Copier le binaire
    if ! cp "$TMPDIR/temp_rmmagent" "$INSTALL_PATH/rmmagent"; then
        log "ERREUR: Impossible de copier le binaire"
        exit 1
    fi
    chmod +x "$INSTALL_PATH/rmmagent"

    # Initialiser l'agent
    log "Initialisation de l'agent..."
    if ! "$INSTALL_PATH/rmmagent" -m install -api "$rmm_url" -client-id "$rmm_client_id" -site-id "$rmm_site_id" -agent-type "$rmm_agent_type" -auth "$rmm_auth" 2>&1 | tee -a "$LOG_FILE"; then
        log "ERREUR: Échec de l'initialisation de l'agent"
        exit 1
    fi

    rm "$TMPDIR/temp_rmmagent"

    # Service systemd pour Synology
    log "Création du service systemd..."
    cat > /etc/systemd/system/tacticalagent.service << EOF
[Unit]
Description=Tactical RMM Linux Agent
After=network.target syno-volume.target
Wants=network.target

[Service]
Type=simple
ExecStart=$INSTALL_PATH/rmmagent -m svc
User=root
Group=root
Restart=always
RestartSec=5s
LimitNOFILE=1000000
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tacticalagent 2>&1 | tee -a "$LOG_FILE"
    systemctl start tacticalagent 2>&1 | tee -a "$LOG_FILE"

    log "Agent Tactical RMM installé dans $INSTALL_PATH"
}

# === DÉTECTION DE L'AGENT INSTALLÉ ===

# Chemin reel du binaire de l'agent, liens symboliques resolus.
# Ordre : TACTICAL_AGENT_PATH > ExecStart du service > chemins connus.
# L'ancien code supposait /usr/local/bin/rmmagent : sur les installations
# officielles (/usr/local/bin/tacticalagent), `update` ecrivait donc un
# binaire que le service n'utilisait pas, et annoncait un succes.
function resolve_agent_path() {
    local p=""
    if [ -n "${TACTICAL_AGENT_PATH:-}" ]; then
        # Chemin impose : pas de repli silencieux sur un autre agent.
        [ -e "$TACTICAL_AGENT_PATH" ] || return 1
        readlink -f "$TACTICAL_AGENT_PATH"
        return 0
    elif command -v systemctl >/dev/null 2>&1; then
        # `show -p` sans --value : le systemd de DSM ne connait pas --value.
        p=$(systemctl show -p ExecStart tacticalagent 2>/dev/null \
            | sed -n 's/.*path=\([^ ;]*\).*/\1/p' | head -1)
    fi
    if [ -z "$p" ] || [ ! -e "$p" ]; then
        local c
        for c in /usr/local/bin/tacticalagent /usr/local/bin/rmmagent \
                 "$INSTALL_PATH/bin/rmmagent" "$INSTALL_PATH/rmmagent"; do
            if [ -e "$c" ]; then p="$c"; break; fi
        done
    fi
    [ -n "$p" ] && [ -e "$p" ] || return 1
    readlink -f "$p"
}

# Version annoncee par un binaire d'agent ("Tactical RMM Agent: 2.12.0").
function agent_version() {
    "$1" -version 2>/dev/null | sed -n 's/^Tactical RMM Agent: *v\{0,1\}\([0-9][0-9.]*\).*/\1/p' | head -1
}

# Version visee : celle du tag AGENT_REF. Vide si AGENT_REF est une branche.
function target_version() {
    case "$AGENT_REF" in
        v[0-9]*) echo "${AGENT_REF#v}" ;;
        [0-9]*)  echo "$AGENT_REF" ;;
    esac
}

# Vrai si $1 < $2 (comparaison de versions).
function version_lt() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# `check` : etat machine-lisible, sans rien modifier.
#   0 = a jour, 10 = mise a jour necessaire, 2 = indeterminable
function check_agent() {
    local path installed target
    path=$(resolve_agent_path) || { echo "STATUS=agent_introuvable"; return 2; }
    installed=$(agent_version "$path")
    target=$(target_version)
    echo "AGENT_PATH=$path"
    echo "INSTALLED=${installed:-inconnue}"
    echo "TARGET=${target:-inconnue}"
    if [ -z "$installed" ] || [ -z "$target" ]; then
        echo "STATUS=indeterminable"; return 2
    fi
    if version_lt "$installed" "$target"; then
        echo "STATUS=update_needed"; return 10
    fi
    echo "STATUS=up_to_date"; return 0
}

# Binaire fourni par TACTICAL_AGENT_BINARY, a la place de la compilation.
function use_prebuilt_binary() {
    if [ ! -f "$AGENT_BINARY" ]; then
        log "ERREUR: TACTICAL_AGENT_BINARY=$AGENT_BINARY introuvable"
        exit 1
    fi
    cp "$AGENT_BINARY" "$TMPDIR/temp_rmmagent" && chmod 755 "$TMPDIR/temp_rmmagent" || {
        log "ERREUR: copie de $AGENT_BINARY impossible"; exit 1; }
    log "Binaire fourni: $AGENT_BINARY"
}

# === MISE À JOUR AGENT ===

function restart_agent_service() {
    systemctl restart tacticalagent 2>&1 | tee -a "$LOG_FILE"
    sleep 3
    systemctl is-active --quiet tacticalagent
}

function update_agent() {
    log "Mise à jour de l'agent..."

    local agent_path new_version target old_version
    if ! agent_path=$(resolve_agent_path); then
        log "ERREUR: agent installé introuvable (service tacticalagent, /usr/local/bin/{tacticalagent,rmmagent})"
        log "       surchargez avec TACTICAL_AGENT_PATH=/chemin/vers/agent"
        exit 1
    fi
    old_version=$(agent_version "$agent_path")
    log "Agent installé: $agent_path (version ${old_version:-inconnue})"

    # Le binaire doit annoncer la version visee AVANT de toucher a la prod.
    new_version=$(agent_version "$TMPDIR/temp_rmmagent")
    target=$(target_version)
    if [ -z "$new_version" ]; then
        log "ERREUR: le nouveau binaire ne s'exécute pas ou n'annonce aucune version"
        exit 1
    fi
    if [ -z "$AGENT_BINARY" ] && [ -n "$target" ] && [ "$new_version" != "$target" ]; then
        log "ERREUR: binaire compilé en $new_version, attendu $target"
        exit 1
    fi
    log "Nouveau binaire: version $new_version"

    local backup="${agent_path}.backup"
    cp -p "$agent_path" "$backup" || { log "ERREUR: sauvegarde $backup impossible"; exit 1; }
    log "Agent sauvegardé: $backup"

    # Copie dans le meme repertoire puis rename : remplacement atomique,
    # meme si le binaire est en cours d'execution ("Text file busy").
    local staged
    staged=$(mktemp "$(dirname "$agent_path")/.rmmagent.XXXXXX") || {
        log "ERREUR: écriture impossible dans $(dirname "$agent_path")"; exit 1; }
    if ! { cp "$TMPDIR/temp_rmmagent" "$staged" && chmod 755 "$staged" && mv -f "$staged" "$agent_path"; }; then
        rm -f "$staged"
        log "ERREUR: Échec du remplacement du binaire, l'ancien est intact"
        exit 1
    fi
    if command -v restorecon >/dev/null 2>&1; then
        restorecon "$agent_path" 2>/dev/null || true
    fi
    rm -f "$TMPDIR/temp_rmmagent"

    if restart_agent_service && [ "$(agent_version "$agent_path")" = "$new_version" ]; then
        log "Agent mis à jour: ${old_version:-inconnue} -> $new_version, service actif"
        rm -f "$backup"
        return 0
    fi

    log "ERREUR: le service ne redémarre pas avec la nouvelle version, retour arrière..."
    systemctl status tacticalagent --no-pager 2>&1 | tail -15 | tee -a "$LOG_FILE"
    cp -p "$backup" "$agent_path"
    if restart_agent_service; then
        log "Ancienne version ${old_version:-inconnue} restaurée, service actif"
        rm -f "$backup"
    else
        log "ERREUR CRITIQUE: service inactif même après restauration de $backup"
    fi
    exit 1
}

# === DÉSINSTALLATION (inchangé) ===

function uninstall_agent() {
    log "Désinstallation de l'agent Tactical RMM..."

    # Arrêter et désactiver le service
    if systemctl is-active --quiet tacticalagent; then
        systemctl stop tacticalagent
    fi
    systemctl disable tacticalagent 2>/dev/null || true

    # Supprimer le service
    rm -f /etc/systemd/system/tacticalagent.service
    systemctl daemon-reload

    # Supprimer les binaires
    rm -f /usr/local/bin/rmmagent
    rm -rf "$INSTALL_PATH"

    # Supprimer la configuration
    rm -rf /etc/tacticalagent

    log "Agent désinstallé"
}

function uninstall_mesh() {
    log "Désinstallation de Mesh Agent..."

    if ! download_file "https://$mesh_fqdn/meshagents?script=1" "$TMPDIR/meshinstall.sh" "Mesh uninstall script"; then
        log "ATTENTION: Impossible de télécharger le script de désinstallation Mesh"
        return 1
    fi

    chmod 755 "$TMPDIR/meshinstall.sh"

    "$TMPDIR/meshinstall.sh" uninstall https://$mesh_fqdn $mesh_id 2>&1 | tee -a "$LOG_FILE" || \
    "$TMPDIR/meshinstall.sh" uninstall uninstall uninstall https://$mesh_fqdn $mesh_id 2>&1 | tee -a "$LOG_FILE"

    rm -f "$TMPDIR/meshinstall.sh"
    log "Mesh Agent désinstallé"
}

# === STATUS (inchangé) ===

function status_agent() {
    echo ""
    echo "==========================================="
    echo "STATUT DE L'AGENT TACTICAL RMM"
    echo "==========================================="
    echo ""

    local agent_path
    agent_path=$(resolve_agent_path) || agent_path="/usr/local/bin/rmmagent"

    # Service systemd
    if systemctl is-active --quiet tacticalagent 2>/dev/null; then
        echo "✓ Service: ACTIF"
        local uptime
        uptime=$(systemctl show tacticalagent -p ActiveEnterTimestamp | cut -d= -f2-)
        echo "  Démarré: $uptime"
    else
        echo "✗ Service: INACTIF"
    fi

    # Binaire
    if [ -f "$agent_path" ]; then
        local size
        size=$(ls -lh "$agent_path" | awk '{print $5}')
        echo "✓ Binaire: $agent_path ($size, version $(agent_version "$agent_path"))"
    else
        echo "✗ Binaire: NON TROUVÉ"
    fi

    # Configuration
    if [ -d /etc/tacticalagent ]; then
        echo "✓ Configuration: /etc/tacticalagent"
    else
        echo "✗ Configuration: MANQUANTE"
    fi

    # Mesh
    if [ -d /opt/tacticalmesh ]; then
        echo "✓ Mesh Agent: INSTALLÉ"
    else
        echo "✗ Mesh Agent: NON INSTALLÉ"
    fi

    # Logs récents (si systemd disponible)
    if command -v journalctl &>/dev/null; then
        echo ""
        echo "--- Logs récents (5 dernières lignes) ---"
        journalctl -u tacticalagent -n 5 --no-pager 2>/dev/null || echo "Aucun log disponible"
    fi

    echo ""
    echo "==========================================="
}

# === AIDE ===

function show_help() {
    cat << EOF

==============================================
Tactical RMM - Script d'installation Linux
Version $VERSION avec support Dashboard
==============================================

UTILISATION:
  $0 <action> [arguments]

ACTIONS:

  install
    Installation complète de l'agent Tactical RMM

    Méthode 1 - Via UUID de déploiement (recommandé):
      Arguments:
        1. UUID de déploiement
        2. URL API Tactical RMM

      Exemple:
        $0 install "a1b2c3d4-e5f6-7890-abcd-ef1234567890" \\
          "https://api.exemple.com"

    Méthode 2 - Manuelle (ancienne méthode):
      Arguments:
        1. URL Mesh Agent
        2. URL API Tactical RMM
        3. Client ID
        4. Site ID
        5. Auth Key
        6. Type d'agent: 'server' ou 'workstation'

      Exemple:
        $0 install "https://mesh.exemple.com/meshagents?id=..." \\
          "https://api.exemple.com" \\
          123 456 "auth-key-xyz" "server"

  update
    Mise à jour de l'agent : compile le tag AGENT_REF, vérifie la version du
    binaire, remplace l'agent du service, redémarre, revient en arrière en cas
    d'échec. Aucun argument requis.
    Synology : TACTICAL_AGENT_BINARY obligatoire (voir rmmagent-synology/).

  check
    Compare l'agent installé à la version visée, sans rien modifier.
    Code retour : 0 = à jour, 10 = mise à jour nécessaire, 2 = indéterminable.
    Ne nécessite pas root.

  uninstall
    Désinstallation complète de l'agent
    Arguments:
      1. FQDN Mesh (ex: mesh.exemple.com)
      2. Mesh Agent ID (entre guillemets)

  status
    Affiche l'état de l'agent
    Aucun argument requis

  help
    Affiche cette aide

EXEMPLES D'INSTALLATION DEPUIS LE DASHBOARD:

  # Récupérer le lien depuis le dashboard
  wget https://api.exemple.com/clients/{uuid}/deploy/linux/ -O install.sh
  chmod +x install.sh
  sudo ./install.sh

  # Ou directement avec curl
  curl -L https://api.exemple.com/clients/{uuid}/deploy/linux/ | sudo bash

VARIABLES D'ENVIRONNEMENT:

  TACTICAL_LANG          Langue (fr_FR ou en_US). Défaut: fr_FR
  TACTICAL_AGENT_REF     Tag rmmagent à compiler. Défaut: $AGENT_REF
  TACTICAL_AGENT_BINARY  Binaire déjà compilé à installer (pas de compilation)
  TACTICAL_AGENT_PATH    Chemin de l'agent installé (sinon : ExecStart du service)

SUPPORT:
  Documentation: github.com/amidaware/tacticalrmm
  Script amélioré: https://github.com/fred-selest/tactical-rmm

==============================================
EOF
}

# === MAIN ===

# Piège pour le nettoyage en cas d'arrêt
trap cleanup EXIT

# Vérifier les droits root (check/status/help sont en lecture seule)
case "${1:-}" in
    check|status|help|--help|-h|"") ;;
    *) check_root ;;
esac

# Afficher la version
log "=== Tactical RMM Installation Script v$VERSION ==="

# Vérifier l'action
if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

ACTION=$1

# Valider l'action
if [[ "$ACTION" != "install" && "$ACTION" != "update" && "$ACTION" != "uninstall" && "$ACTION" != "status" && "$ACTION" != "check" ]]; then
    log "ERREUR: Action invalide: $ACTION"
    echo "Utilisez '$0 help' pour voir l'aide"
    exit 1
fi

# Détecter le système
detect_system

# Créer le répertoire temporaire
setup_temp_dir

# Exécuter l'action
case $ACTION in
    install)
        # Déterminer le mode d'installation
        if [ $# -eq 3 ]; then
            # Mode UUID (nouveau)
            deployment_uuid=$2
            api_url=$3

            print_header "Installation via Dashboard (UUID)"

            msg install_start
            check_dependencies

            # Récupérer la configuration depuis l'API
            if ! fetch_deployment_config "$deployment_uuid" "$api_url"; then
                print_error "Impossible de récupérer la configuration"
                notify_installation_status "$deployment_uuid" "$api_url" "failed" "Configuration fetch failed"
                exit 1
            fi

            # Continuer l'installation normale
            go_install
            install_mesh
            agent_compile
            install_agent

            # Notifier le succès
            notify_installation_status "$deployment_uuid" "$api_url" "success"

            msg install_complete

        elif [ $# -eq 7 ]; then
            # Mode manuel (ancien)
            mesh_url=$2
            rmm_url=$3
            rmm_client_id=$4
            rmm_site_id=$5
            rmm_auth=$6
            rmm_agent_type=$7

            print_header "Installation manuelle"

            msg install_start
            check_dependencies
            go_install
            install_mesh
            agent_compile
            install_agent
            msg install_complete

        else
            print_error "Nombre d'arguments incorrect pour 'install'"
            show_help
            exit 1
        fi

        log "=== Installation terminée ==="
        log "Agent installé dans: $INSTALL_PATH"

        # Afficher le status
        echo ""
        status_agent
        ;;

    update)
        msg update_start
        if [ "$OS_TYPE" = "synology" ] && [ -z "$AGENT_BINARY" ]; then
            log "ERREUR: Synology détecté. La compilation standard supprimerait la"
            log "        détection DSM/disques de l'agent modifié."
            log "        Compilez avec rmmagent-synology/build.sh, puis :"
            log "        TACTICAL_AGENT_BINARY=/chemin/rmmagent-synology $0 update"
            exit 1
        fi
        if [ -n "$AGENT_BINARY" ]; then
            use_prebuilt_binary
        else
            check_dependencies
            go_install
            agent_compile
        fi
        update_agent
        msg update_complete

        log "=== Mise à jour terminée ==="

        # Afficher le status
        echo ""
        status_agent
        ;;

    uninstall)
        if [ $# -ne 3 ]; then
            log "ERREUR: Nombre d'arguments incorrect pour 'uninstall'"
            show_help
            exit 1
        fi

        mesh_fqdn=$2
        mesh_id=$3

        uninstall_agent
        uninstall_mesh
        msg uninstall_complete

        log "=== Désinstallation terminée ==="
        ;;

    status)
        status_agent
        ;;

    check)
        check_agent
        exit $?
        ;;
esac

exit 0