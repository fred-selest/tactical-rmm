#!/bin/bash

#############################################
# Tactical RMM - Mise à jour automatique
# Version: 1.0
#############################################

# Configuration
CONFIG_FILE="/etc/tactical-rmm/auto-update.conf"
LOG_FILE="/var/log/tactical-rmm-updater.log"
LOCK_FILE="/var/run/tactical-agent-updater.lock"
GITHUB_REPO="amidaware/rmmagent"
CURRENT_VERSION_FILE="/etc/tacticalagent/.version"

# Charger la configuration si elle existe
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Paramètres par défaut (peuvent être écrasés par le fichier de config)
AUTO_UPDATE_ENABLED="${AUTO_UPDATE_ENABLED:-true}"
CHECK_INTERVAL_DAYS="${CHECK_INTERVAL_DAYS:-7}"
BACKUP_ENABLED="${BACKUP_ENABLED:-true}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"
NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"
UPDATE_WINDOW_START="${UPDATE_WINDOW_START:-02:00}"
UPDATE_WINDOW_END="${UPDATE_WINDOW_END:-05:00}"

# === FONCTIONS ===

function log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_FILE"
}

function log_error() {
    log "ERREUR: $1"
}

function log_info() {
    log "INFO: $1"
}

function log_success() {
    log "SUCCESS: $1"
}

function acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_error "Une mise à jour est déjà en cours (PID: $pid)"
            exit 1
        else
            log_info "Suppression du fichier de verrouillage obsolète"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

function release_lock() {
    rm -f "$LOCK_FILE"
}

function cleanup() {
    release_lock
    log_info "Nettoyage terminé"
}

trap cleanup EXIT

function check_if_enabled() {
    if [ "$AUTO_UPDATE_ENABLED" != "true" ]; then
        log_info "Mise à jour automatique désactivée dans $CONFIG_FILE"
        exit 0
    fi
}

function check_update_window() {
    local current_time=$(date +%H:%M)
    local start_time="$UPDATE_WINDOW_START"
    local end_time="$UPDATE_WINDOW_END"

    # Convertir en minutes depuis minuit
    local current_min=$(date -d "$current_time" +%s)
    local start_min=$(date -d "$start_time" +%s)
    local end_min=$(date -d "$end_time" +%s)

    if [ "$current_min" -ge "$start_min" ] && [ "$current_min" -le "$end_min" ]; then
        return 0
    else
        log_info "Hors de la fenêtre de mise à jour ($start_time - $end_time). Mise à jour reportée."
        exit 0
    fi
}

function get_installed_version() {
    # Essayer de lire depuis le fichier de version
    if [ -f "$CURRENT_VERSION_FILE" ]; then
        cat "$CURRENT_VERSION_FILE"
        return
    fi

    # Sinon, essayer via l'agent
    local agent_bin=""
    for path in "/usr/local/bin/rmmagent" "/opt/tacticalrmm/bin/rmmagent" "/volume1/@appstore/tactical-rmm/rmmagent"; do
        if [ -f "$path" ]; then
            agent_bin="$path"
            break
        fi
    done

    if [ -n "$agent_bin" ]; then
        # Extraire la version du binaire (si disponible)
        local version=$("$agent_bin" -v 2>/dev/null | grep -oP 'v\K[0-9.]+' || echo "unknown")
        echo "$version"
    else
        echo "unknown"
    fi
}

function get_latest_version() {
    # Récupérer la dernière version depuis GitHub
    local latest=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep -oP '"tag_name": "\K[^"]+' || echo "")

    if [ -z "$latest" ]; then
        # Fallback: essayer via git tags
        latest=$(git ls-remote --tags "https://github.com/$GITHUB_REPO.git" | tail -n1 | grep -oP 'refs/tags/\K.*' || echo "")
    fi

    echo "$latest"
}

function compare_versions() {
    local current="$1"
    local latest="$2"

    # Supprimer le 'v' initial si présent
    current="${current#v}"
    latest="${latest#v}"

    if [ "$current" = "unknown" ]; then
        return 1  # Mettre à jour si version inconnue
    fi

    if [ "$current" = "$latest" ]; then
        return 0  # Même version
    fi

    # Comparaison de version simple
    if [ "$(printf '%s\n' "$current" "$latest" | sort -V | head -n1)" = "$current" ] && [ "$current" != "$latest" ]; then
        return 1  # Mise à jour disponible
    fi

    return 0  # Pas de mise à jour nécessaire
}

function send_notification() {
    local subject="$1"
    local message="$2"

    # Email
    if [ -n "$NOTIFICATION_EMAIL" ]; then
        echo "$message" | mail -s "$subject" "$NOTIFICATION_EMAIL" 2>/dev/null || \
            log_error "Impossible d'envoyer l'email de notification"
    fi

    # Webhook (Slack, Discord, etc.)
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        curl -X POST "$NOTIFICATION_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"$subject\n$message\"}" 2>/dev/null || \
            log_error "Impossible d'envoyer la notification webhook"
    fi
}

function perform_update() {
    log_info "=== DÉBUT DE LA MISE À JOUR ==="

    # Vérifier la présence du script de mise à jour
    local update_script="/usr/local/bin/rmmagent-linux-ameliore.sh"

    if [ ! -f "$update_script" ]; then
        # Télécharger le script depuis le dépôt
        log_info "Téléchargement du script de mise à jour..."
        wget -q -O /tmp/rmmagent-update.sh "https://raw.githubusercontent.com/YOUR_USER/tactical-rmm/main/rmmagent-linux-ameliore.sh"

        if [ $? -eq 0 ]; then
            chmod +x /tmp/rmmagent-update.sh
            update_script="/tmp/rmmagent-update.sh"
        else
            log_error "Impossible de télécharger le script de mise à jour"
            return 1
        fi
    fi

    # Lancer la mise à jour
    log_info "Exécution de la mise à jour..."
    "$update_script" update >> "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        log_success "Mise à jour terminée avec succès"

        # Enregistrer la nouvelle version
        local new_version=$(get_installed_version)
        echo "$new_version" > "$CURRENT_VERSION_FILE"

        # Notification de succès
        send_notification \
            "[Tactical RMM] Mise à jour réussie sur $(hostname)" \
            "L'agent Tactical RMM a été mis à jour vers la version $new_version sur $(hostname)."

        return 0
    else
        log_error "La mise à jour a échoué"

        # Notification d'échec
        send_notification \
            "[Tactical RMM] Échec de mise à jour sur $(hostname)" \
            "La mise à jour de l'agent Tactical RMM a échoué sur $(hostname). Consultez $LOG_FILE pour plus de détails."

        return 1
    fi
}

# === DÉBUT DU SCRIPT ===

log_info "=========================================="
log_info "Tactical RMM - Vérification des mises à jour"
log_info "Serveur: $(hostname)"
log_info "=========================================="

# Acquérir le verrou
acquire_lock

# Vérifier si activé
check_if_enabled

# Vérifier la fenêtre de mise à jour
check_update_window

# Récupérer les versions
log_info "Vérification des versions..."
INSTALLED_VERSION=$(get_installed_version)
LATEST_VERSION=$(get_latest_version)

log_info "Version installée: $INSTALLED_VERSION"
log_info "Dernière version: $LATEST_VERSION"

# Comparer les versions
if compare_versions "$INSTALLED_VERSION" "$LATEST_VERSION"; then
    log_info "L'agent est à jour (version $INSTALLED_VERSION)"
    exit 0
fi

log_info "Nouvelle version disponible: $LATEST_VERSION"

# Effectuer la mise à jour
if perform_update; then
    log_success "=== MISE À JOUR TERMINÉE AVEC SUCCÈS ==="
    exit 0
else
    log_error "=== ÉCHEC DE LA MISE À JOUR ==="
    exit 1
fi
