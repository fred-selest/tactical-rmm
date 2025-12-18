#!/bin/bash

#############################################
# Tactical RMM - Script d'installation Linux
# Version améliorée avec support Synology
# Version: 2.0
#############################################

# Arrêter en cas d'erreur (désactivé pour gérer manuellement)
# set -e

# === VARIABLES GLOBALES ===
VERSION="2.0"
LOG_FILE="/var/log/tacticalrmm-install.log"
GO_INSTALLED_BY_SCRIPT=false
LANG="${TACTICAL_LANG:-fr_FR}"
GO_VERSION="1.21.6"

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
        log "ERREUR: Ce script doit être exécuté en tant que root"
        exit 1
    fi
}

function check_dependencies() {
    msg checking_deps
    local missing=()
    local to_install=()

    # Vérification des commandes de base
    for cmd in wget tar; do
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
            log "ERREUR: Gestionnaire de paquets non supporté"
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

# === GO INSTALLATION ===

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

# === COMPILATION AGENT ===

function agent_compile() {
    log "Téléchargement du code source de rmmagent..."

    if ! download_file "https://github.com/amidaware/rmmagent/archive/refs/heads/master.tar.gz" "$TMPDIR/rmmagent.tar.gz" "rmmagent source"; then
        exit 1
    fi

    log "Extraction du code source..."
    if ! tar -xzf "$TMPDIR/rmmagent.tar.gz" -C "$TMPDIR/" 2>&1 | tee -a "$LOG_FILE"; then
        log "ERREUR: Échec de l'extraction du code source"
        exit 1
    fi
    rm "$TMPDIR/rmmagent.tar.gz"

    log "Compilation de l'agent pour $ARCH..."
    cd "$TMPDIR/rmmagent-master"

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

    cd "$TMPDIR"
    rm -rf "$TMPDIR/rmmagent-master"
}

# === MESH AGENT ===

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

# === INSTALLATION AGENT ===

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

# === MISE À JOUR AGENT ===

function update_agent() {
    log "Mise à jour de l'agent..."

    # Détecter le chemin de l'agent
    local agent_path="/usr/local/bin/rmmagent"
    if [ -f "$INSTALL_PATH/bin/rmmagent" ]; then
        agent_path="$INSTALL_PATH/bin/rmmagent"
    elif [ -f "$INSTALL_PATH/rmmagent" ]; then
        agent_path="$INSTALL_PATH/rmmagent"
    fi

    # Arrêter le service
    if systemctl is-active --quiet tacticalagent; then
        systemctl stop tacticalagent
        log "Service arrêté"
    fi

    # Sauvegarder l'ancien agent
    if [ -f "$agent_path" ]; then
        cp "$agent_path" "${agent_path}.backup"
        log "Agent sauvegardé: ${agent_path}.backup"
    fi

    # Copier le nouvel agent
    if cp "$TMPDIR/temp_rmmagent" "$agent_path" 2>&1 | tee -a "$LOG_FILE"; then
        chmod +x "$agent_path"
        log "Agent mis à jour avec succès"
        rm "$TMPDIR/temp_rmmagent"
        rm -f "${agent_path}.backup"
    else
        log "ERREUR: Échec de la mise à jour"
        if [ -f "${agent_path}.backup" ]; then
            log "Restauration de l'ancienne version..."
            cp "${agent_path}.backup" "$agent_path"
            log "Agent restauré"
        fi
        exit 1
    fi

    # Redémarrer le service
    systemctl start tacticalagent 2>&1 | tee -a "$LOG_FILE"

    if systemctl is-active --quiet tacticalagent; then
        log "Service redémarré avec succès"
    else
        log "ATTENTION: Le service n'a pas démarré correctement"
        systemctl status tacticalagent --no-pager | tee -a "$LOG_FILE"
    fi
}

# === DÉSINSTALLATION ===

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

# === STATUS ===

function status_agent() {
    echo ""
    echo "==========================================="
    echo "STATUT DE L'AGENT TACTICAL RMM"
    echo "==========================================="
    echo ""

    # Détecter le chemin de l'agent
    local agent_path="/usr/local/bin/rmmagent"
    if [ -f "$INSTALL_PATH/bin/rmmagent" ]; then
        agent_path="$INSTALL_PATH/bin/rmmagent"
    elif [ -f "$INSTALL_PATH/rmmagent" ]; then
        agent_path="$INSTALL_PATH/rmmagent"
    fi

    # Service systemd
    if systemctl is-active --quiet tacticalagent 2>/dev/null; then
        echo "✓ Service: ACTIF"
        local uptime=$(systemctl show tacticalagent -p ActiveEnterTimestamp --value)
        echo "  Démarré: $uptime"
    else
        echo "✗ Service: INACTIF"
    fi

    # Binaire
    if [ -f "$agent_path" ]; then
        local size=$(ls -lh "$agent_path" | awk '{print $5}')
        echo "✓ Binaire: $agent_path ($size)"
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
Version $VERSION
==============================================

UTILISATION:
  $0 <action> [arguments]

ACTIONS:

  install
    Installation complète de l'agent Tactical RMM
    Arguments:
      1. URL Mesh Agent
      2. URL API Tactical RMM
      3. Client ID
      4. Site ID
      5. Auth Key
      6. Type d'agent: 'server' ou 'workstation'

  update
    Mise à jour de l'agent (recompile et redémarre)
    Aucun argument requis

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

EXEMPLES:

  Installation:
    $0 install "https://mesh.exemple.com/meshagents?id=..." \\
      "https://api.exemple.com" \\
      123 456 "auth-key-xyz" "server"

  Mise à jour:
    $0 update

  Désinstallation:
    $0 uninstall "mesh.exemple.com" "mesh-agent-id-xyz"

  Status:
    $0 status

VARIABLES D'ENVIRONNEMENT:

  TACTICAL_LANG    Langue (fr_FR ou en_US)
                   Défaut: fr_FR

SUPPORT:
  Documentation: github.com/amidaware/tacticalrmm
  Script amélioré: https://github.com/fred-selest/tactical-rmm

==============================================
EOF
}

# === MAIN ===

# Piège pour le nettoyage en cas d'arrêt
trap cleanup EXIT

# Vérifier les droits root
check_root

# Afficher la version
log "=== Tactical RMM Installation Script v$VERSION ==="

# Vérifier l'action
if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

ACTION=$1

# Valider l'action
if [[ "$ACTION" != "install" && "$ACTION" != "update" && "$ACTION" != "uninstall" && "$ACTION" != "status" ]]; then
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
        if [ $# -ne 7 ]; then
            log "ERREUR: Nombre d'arguments incorrect pour 'install'"
            show_help
            exit 1
        fi

        mesh_url=$2
        rmm_url=$3
        rmm_client_id=$4
        rmm_site_id=$5
        rmm_auth=$6
        rmm_agent_type=$7

        msg install_start
        check_dependencies
        go_install
        install_mesh
        agent_compile
        install_agent
        msg install_complete

        log "=== Installation terminée ==="
        log "Agent installé dans: $INSTALL_PATH"

        # Afficher le status
        echo ""
        status_agent
        ;;

    update)
        msg update_start
        check_dependencies
        go_install
        agent_compile
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
esac

exit 0
