#!/bin/bash

#############################################
# Tactical RMM - Mise à jour automatique de l'agent Linux
# Version: 2.0
#
# Lancé par tactical-agent-updater.timer. Délègue tout le travail à
# rmmagent-linux.sh (actions `check` puis `update`).
#
# Usage: tactical-agent-updater.sh [--check] [--now]
#   --check  affiche l'état et sort (0 à jour, 10 MAJ nécessaire, 1 erreur)
#   --now    ignore la fenêtre de mise à jour (lancement manuel)
#
# Corrigé par rapport à la v1.0 :
# - la version installée était lue dans /etc/tacticalagent/.version, chemin
#   impossible (/etc/tacticalagent est un fichier JSON), puis via
#   `/usr/local/bin/rmmagent -v` : mauvais chemin sur les installations
#   officielles et mauvaise option (-version). Résultat : « inconnue », donc
#   recompilation à chaque passage du timer ;
# - la version visée était la dernière release GitHub, alors que l'agent
#   doit correspondre à la version du serveur RMM ;
# - l'URL de téléchargement contenait encore YOUR_USER, et UPDATE_SCRIPT_URL
#   de la configuration était ignorée.
#############################################

CONFIG_FILE="${TACTICAL_UPDATER_CONF:-/etc/tactical-rmm/auto-update.conf}"
LOG_FILE="${TACTICAL_UPDATER_LOG:-/var/log/tactical-rmm-updater.log}"
LOCK_FILE="${TACTICAL_UPDATER_LOCK:-/var/run/tactical-agent-updater.lock}"

# Charger la configuration si elle existe
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Paramètres par défaut (peuvent être écrasés par le fichier de config)
AUTO_UPDATE_ENABLED="${AUTO_UPDATE_ENABLED:-true}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"
NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"
UPDATE_WINDOW_START="${UPDATE_WINDOW_START:-02:00}"
UPDATE_WINDOW_END="${UPDATE_WINDOW_END:-05:00}"
# Script moteur : copie locale si présente, sinon téléchargement (TLS vérifié).
UPDATE_SCRIPT="${UPDATE_SCRIPT:-/usr/local/bin/rmmagent-linux.sh}"
UPDATE_SCRIPT_URL="${UPDATE_SCRIPT_URL:-https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/rmmagent-linux.sh}"
# Tag rmmagent visé. Vide = celui épinglé dans rmmagent-linux.sh.
TARGET_AGENT_REF="${TARGET_AGENT_REF:-}"

CHECK_ONLY=false
IGNORE_WINDOW=false
for arg in "$@"; do
    case "$arg" in
        --check) CHECK_ONLY=true ;;
        --now)   IGNORE_WINDOW=true ;;
        -h|--help) sed -n '3,13p' "$0"; exit 0 ;;
        *) echo "Option inconnue: $arg" >&2; exit 1 ;;
    esac
done

if ! { [ -w "$LOG_FILE" ] || [ -w "$(dirname "$LOG_FILE")" ]; }; then
    LOG_FILE="/dev/null"
fi

# === FONCTIONS ===

function log() {
    local message
    message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_FILE"
}
function log_error()   { log "ERREUR: $1"; }
function log_info()    { log "INFO: $1"; }
function log_success() { log "SUCCESS: $1"; }

TMP_SCRIPT=""
function cleanup() {
    [ -n "$TMP_SCRIPT" ] && rm -f "$TMP_SCRIPT"
    if [ -f "$LOCK_FILE" ] && [ "$(cat "$LOCK_FILE" 2>/dev/null)" = "$$" ]; then
        rm -f "$LOCK_FILE"
    fi
}
trap cleanup EXIT

function acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid
        pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_error "Une mise à jour est déjà en cours (PID: $pid)"
            exit 1
        fi
        log_info "Suppression du fichier de verrouillage obsolète"
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
}

# "HH:MM" -> minutes depuis minuit
function to_minutes() {
    local h=${1%%:*} m=${1##*:}
    echo $(( 10#$h * 60 + 10#$m ))
}

# Vrai si l'heure courante est dans la fenêtre. Gère une fenêtre à cheval sur
# minuit (ex. 23:00-02:00), que la v1.0 rejetait toujours.
function in_update_window() {
    local now start end
    now=$(to_minutes "$(date +%H:%M)")
    start=$(to_minutes "$UPDATE_WINDOW_START")
    end=$(to_minutes "$UPDATE_WINDOW_END")
    if [ "$start" -le "$end" ]; then
        [ "$now" -ge "$start" ] && [ "$now" -le "$end" ]
    else
        [ "$now" -ge "$start" ] || [ "$now" -le "$end" ]
    fi
}

# Renseigne SCRIPT (script moteur), téléchargé si absent localement.
# Pas d'appel en $(...) : TMP_SCRIPT serait perdu dans le sous-shell et le
# fichier temporaire ne serait jamais supprimé.
function get_update_script() {
    if [ -f "$UPDATE_SCRIPT" ]; then
        SCRIPT="$UPDATE_SCRIPT"
        return 0
    fi
    TMP_SCRIPT=$(mktemp /tmp/rmmagent-linux.XXXXXX.sh) || return 1
    if ! curl -fsSL --max-time 60 -o "$TMP_SCRIPT" "$UPDATE_SCRIPT_URL"; then
        log_error "Téléchargement impossible : $UPDATE_SCRIPT_URL"
        return 1
    fi
    # Refuser une page d'erreur ou une ancienne version sans action `check`.
    if ! bash -n "$TMP_SCRIPT" 2>/dev/null || ! grep -q '^function check_agent()' "$TMP_SCRIPT"; then
        log_error "Script téléchargé invalide ou trop ancien (pas d'action check) : $UPDATE_SCRIPT_URL"
        return 1
    fi
    chmod 700 "$TMP_SCRIPT"
    SCRIPT="$TMP_SCRIPT"
}

# Lance `rmmagent-linux.sh check`. Remplit INSTALLED/TARGET/AGENT_PATH,
# renvoie le code du moteur (0 / 10 / 2).
function run_check() {
    local out rc
    if [ -n "$TARGET_AGENT_REF" ]; then
        out=$(TACTICAL_AGENT_REF="$TARGET_AGENT_REF" bash "$1" check 2>&1); rc=$?
    else
        out=$(bash "$1" check 2>&1); rc=$?
    fi
    AGENT_PATH=$(sed -n 's/^AGENT_PATH=//p' <<< "$out")
    INSTALLED=$(sed -n 's/^INSTALLED=//p' <<< "$out")
    TARGET=$(sed -n 's/^TARGET=//p' <<< "$out")
    CHECK_STATUS=$(sed -n 's/^STATUS=//p' <<< "$out")
    return $rc
}

function send_notification() {
    local subject="$1" message="$2"
    if [ -n "$NOTIFICATION_EMAIL" ]; then
        echo "$message" | mail -s "$subject" "$NOTIFICATION_EMAIL" 2>/dev/null || \
            log_error "Impossible d'envoyer l'email de notification"
    fi
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        local payload
        payload=$(printf '{"text":"%s\\n%s"}' "${subject//\"/\'}" "${message//\"/\'}")
        curl -fsS -X POST "$NOTIFICATION_WEBHOOK" -H 'Content-Type: application/json' \
            -d "$payload" >/dev/null 2>&1 || log_error "Impossible d'envoyer la notification webhook"
    fi
}

function perform_update() {
    local script="$1" rc
    log_info "=== DÉBUT DE LA MISE À JOUR ($INSTALLED -> $TARGET) ==="
    if [ -n "$TARGET_AGENT_REF" ]; then
        TACTICAL_AGENT_REF="$TARGET_AGENT_REF" bash "$script" update >> "$LOG_FILE" 2>&1; rc=$?
    else
        bash "$script" update >> "$LOG_FILE" 2>&1; rc=$?
    fi
    if [ $rc -ne 0 ]; then
        log_error "rmmagent-linux.sh update a échoué (code $rc), voir $LOG_FILE"
        return 1
    fi
    # Ne pas croire le code retour sur parole : revérifier la version.
    if ! run_check "$script"; then
        log_error "Après mise à jour : $CHECK_STATUS (installée $INSTALLED, visée $TARGET)"
        return 1
    fi
    return 0
}

# === DÉBUT DU SCRIPT ===

log_info "=========================================="
log_info "Tactical RMM - Vérification des mises à jour sur $(hostname)"

if [ "$AUTO_UPDATE_ENABLED" != "true" ] && [ "$CHECK_ONLY" = false ]; then
    log_info "Mise à jour automatique désactivée dans $CONFIG_FILE"
    exit 0
fi

SCRIPT=""
get_update_script || exit 1

run_check "$SCRIPT"
rc=$?
log_info "Agent: ${AGENT_PATH:-?} | installée: ${INSTALLED:-?} | visée: ${TARGET:-?} | état: ${CHECK_STATUS:-?}"

case $rc in
    0)  log_info "L'agent est à jour"; exit 0 ;;
    10) ;;
    *)  log_error "État indéterminable ($CHECK_STATUS), aucune mise à jour tentée"; exit 1 ;;
esac

if [ "$CHECK_ONLY" = true ]; then
    exit 10
fi

if [ "$IGNORE_WINDOW" = false ] && ! in_update_window; then
    log_info "Hors de la fenêtre $UPDATE_WINDOW_START-$UPDATE_WINDOW_END, mise à jour reportée"
    exit 0
fi

if [ "$EUID" -ne 0 ]; then
    log_error "La mise à jour nécessite root"
    exit 1
fi

acquire_lock

if perform_update "$SCRIPT"; then
    log_success "Agent mis à jour en $INSTALLED sur $(hostname)"
    send_notification "[Tactical RMM] Mise à jour réussie sur $(hostname)" \
        "Agent Tactical RMM mis à jour en $INSTALLED sur $(hostname)."
    exit 0
fi

send_notification "[Tactical RMM] Échec de mise à jour sur $(hostname)" \
    "La mise à jour de l'agent a échoué sur $(hostname). Voir $LOG_FILE."
exit 1
