#!/bin/bash
# =============================================================================
# Bibliothèque commune pour les scripts Tactical RMM
# Source: source "$(dirname "$0")/lib/common.sh"
# =============================================================================

set -euo pipefail

# --- Couleurs ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# --- Variables globales ---
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${LOG_DIR:-/var/log/tactical-rmm}/${SCRIPT_NAME%.sh}.log"
TEMP_FILES=()

# --- Charger la configuration ---
load_config() {
    local config_file="${SCRIPT_DIR}/config.sh"
    if [ -f "$config_file" ]; then
        # shellcheck source=/dev/null
        source "$config_file"
    fi
}

# --- Journalisation : repertoire ---
# LOG_FILE pointait vers /var/log/tacticalrmm/<script>.log alors que le
# repertoire n'est cree nulle part : toute ecriture de log echouait, et la
# redirection fuyait sur stderr avant meme d'atteindre le fichier.
_ensure_log_dir() {
    local dir
    dir="$(dirname "$LOG_FILE")"
    [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null || return 1
    return 0
}

# --- Dépendances ---
# Aucun script ne vérifiait ses dépendances, alors que bc/jq/sensors/
# smartctl/timeout sont utilisés sans être garantis sur une image minimale.
# AGENTS.md exige : « les scripts doivent détecter et installer
# automatiquement les dépendances manquantes ».
check_dependencies() {
    local missing=() cmd pkg
    local -A PKG=( [bc]="bc" [jq]="jq" [sensors]="lm-sensors" [smartctl]="smartmontools" [column]="bsdmainutils" )

    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    [ ${#missing[@]} -eq 0 ] && return 0

    for cmd in "${missing[@]}"; do
        log_warn "dépendance manquante : $cmd"
    done

    # Tentative d'installation non interactive, best-effort.
    if [ "${NO_AUTO_INSTALL:-0}" = "1" ]; then
        return 1
    fi

    local pkgs=()
    for cmd in "${missing[@]}"; do
        [ -n "${PKG[$cmd]:-}" ] && pkgs+=("${PKG[$cmd]}")
    done
    [ ${#pkgs[@]} -eq 0 ] && return 1

    local mgr=""
    for mgr in apt-get dnf yum apk opkg; do
        command -v "$mgr" >/dev/null 2>&1 && break
        mgr=""
    done
    [ -z "$mgr" ] && { log_error "aucun gestionnaire de paquets pour installer : ${pkgs[*]}"; return 1; }

    log_info "installation de : ${pkgs[*]} (via $mgr)"
    case "$mgr" in
        apt-get) DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}" >/dev/null 2>&1 ;;
        dnf)     dnf install -y "${pkgs[@]}" >/dev/null 2>&1 ;;
        yum)     yum install -y "${pkgs[@]}" >/dev/null 2>&1 ;;
        apk)     apk add --no-cache "${pkgs[@]}" >/dev/null 2>&1 ;;
        opkg)    opkg install "${pkgs[@]}" >/dev/null 2>&1 ;;
    esac

    for cmd in "${missing[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || { log_error "toujours absent après installation : $cmd"; return 1; }
    done
    return 0
}

# --- Logging ---
log_info() {
    local message="$1"
    echo -e "${GREEN}[INFO]${NC} $message"
    _ensure_log_dir || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message"
    _ensure_log_dir || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $message" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message" >&2
    _ensure_log_dir || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "$LOG_FILE" 2>/dev/null || true
}

log_debug() {
    local message="$1"
    if [ "${LOG_LEVEL:-INFO}" = "DEBUG" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $message"
        _ensure_log_dir || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# --- Gestion des signaux ---
cleanup() {
    local exit_code=$?
    log_debug "Nettoyage en cours (code de sortie: $exit_code)..."

    # Supprimer les fichiers temporaires
    for tmp_file in "${TEMP_FILES[@]}"; do
        if [ -f "$tmp_file" ]; then
            rm -f "$tmp_file"
            log_debug "Fichier temporaire supprimé: $tmp_file"
        fi
    done

    if [ $exit_code -ne 0 ]; then
        log_error "Script terminé avec le code d'erreur $exit_code"
    fi

    exit $exit_code
}

# Intercepter les signaux
trap cleanup EXIT
trap 'log_warn "Signal INT reçu, interruption..."; exit 130' INT
trap 'log_warn "Signal TERM reçu, arrêt..."; exit 143' TERM

# --- Fonctions utilitaires ---
register_temp_file() {
    TEMP_FILES+=("$1")
}

create_temp_file() {
    local tmp_file
    tmp_file=$(mktemp "/tmp/${SCRIPT_NAME%.sh}.XXXXXX")
    register_temp_file "$tmp_file"
    echo "$tmp_file"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Ce script doit être exécuté en tant que root"
        echo "Utilisez: sudo $0 $*"
        exit 1
    fi
}

check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Commande requise non trouvée: $cmd"
        return 1
    fi
}

check_disk_space() {
    local path="${1:-/}"
    local min_mb="${2:-100}"
    local available_mb
    available_mb=$(df -m "$path" | awk 'NR==2 {print $4}')

    if [ "$available_mb" -lt "$min_mb" ]; then
        log_error "Espace disque insuffisant sur $path: ${available_mb}MB disponible, ${min_mb}MB requis"
        return 1
    fi
    log_debug "Espace disque OK sur $path: ${available_mb}MB disponible"
}

detect_rmm_path() {
    if [ -d "/rmm/api/tacticalrmm" ]; then
        echo "/rmm/api/tacticalrmm"
    elif [ -d "/opt/tacticalrmm/api/tacticalrmm" ]; then
        echo "/opt/tacticalrmm/api/tacticalrmm"
    else
        log_error "Tactical RMM non trouvé"
        return 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# Charger la configuration au sourcing
load_config
