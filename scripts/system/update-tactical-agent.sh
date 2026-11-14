#!/bin/bash

###############################################################################
# Mise à jour manuelle de l'agent Tactical RMM Linux
#
# Usage: sudo ./update-tactical-agent.sh [options]
#   --force        Mettre à jour même si l'agent est déjà à la version visée
#   --backup       Copier binaire + /etc/tacticalagent dans /root/tactical-agent-backups/
#   --ref vX.Y.Z   Tag rmmagent visé (défaut : celui de rmmagent-linux.sh)
#   --quiet        N'afficher que les avertissements et erreurs
#   --dry-run      Afficher l'état et la décision, sans rien modifier (sans root)
#
# Codes retour : 0 succès ou déjà à jour, 1 erreur, 10 (--dry-run) MAJ nécessaire.
#
# v2.0 : réécriture. La v1.2 cherchait /usr/local/tactical/tactical.sh et
# /var/tactical/tactical.sh, qui n'existent sur aucune installation (ni
# officielle, ni rmmagent-linux.sh) : le script sortait en erreur dès la
# première vérification. Son repli téléchargeait $TACTICAL_URL/api/v3/linux/update/,
# route inexistante, et l'exécutait en root avec la vérification TLS
# désactivée (curl -k / wget --no-check-certificate).
# Le travail est désormais délégué à rmmagent-linux.sh (check / update).
###############################################################################

set -u

SCRIPT_VERSION="2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_URL="${UPDATE_SCRIPT_URL:-https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/rmmagent-linux.sh}"
AGENT_CONFIG="/etc/tacticalagent"

if [ -w "/var/log" ]; then
    LOG_FILE="/var/log/tacticalrmm-agent-update.log"
else
    LOG_FILE="/dev/null"
fi

FORCE_UPDATE=false
CREATE_BACKUP=false
QUIET_MODE=false
DRY_RUN=false
AGENT_REF_OVERRIDE=""
TMP_ENGINE=""

log() {
    local level="$1" message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
    if [ "$QUIET_MODE" = false ] || [ "$level" != "INFO" ]; then
        echo "[$level] $message"
    fi
}

cleanup() { [ -n "$TMP_ENGINE" ] && rm -f "$TMP_ENGINE"; }
trap cleanup EXIT

usage() { sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'; }

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --force)   FORCE_UPDATE=true ;;
            --backup)  CREATE_BACKUP=true ;;
            --quiet)   QUIET_MODE=true ;;
            --dry-run) DRY_RUN=true ;;
            --ref)     shift; AGENT_REF_OVERRIDE="${1:-}"
                       [ -n "$AGENT_REF_OVERRIDE" ] || { echo "--ref attend un tag" >&2; exit 1; } ;;
            -h|--help) usage; exit 0 ;;
            *) echo "Option inconnue: $1" >&2; usage; exit 1 ;;
        esac
        shift
    done
}

# Script moteur : copie du dépôt, copie installée, ou téléchargement TLS vérifié.
find_engine() {
    local c
    for c in "$SCRIPT_DIR/../../rmmagent-linux.sh" /usr/local/bin/rmmagent-linux.sh; do
        if [ -f "$c" ] && grep -q '^function check_agent()' "$c"; then
            ENGINE="$(readlink -f "$c")"
            return 0
        fi
    done
    TMP_ENGINE=$(mktemp /tmp/rmmagent-linux.XXXXXX.sh) || return 1
    if ! curl -fsSL --max-time 60 -o "$TMP_ENGINE" "$ENGINE_URL" \
        || ! bash -n "$TMP_ENGINE" 2>/dev/null \
        || ! grep -q '^function check_agent()' "$TMP_ENGINE"; then
        log "ERROR" "rmmagent-linux.sh introuvable localement et téléchargement invalide : $ENGINE_URL"
        return 1
    fi
    ENGINE="$TMP_ENGINE"
}

engine() {
    if [ -n "$AGENT_REF_OVERRIDE" ]; then
        TACTICAL_AGENT_REF="$AGENT_REF_OVERRIDE" bash "$ENGINE" "$@"
    else
        bash "$ENGINE" "$@"
    fi
}

# Remplit AGENT_PATH / INSTALLED / TARGET / STATUS, renvoie 0 / 10 / 2.
run_check() {
    local out rc
    out=$(engine check 2>&1); rc=$?
    AGENT_PATH=$(sed -n 's/^AGENT_PATH=//p' <<< "$out")
    INSTALLED=$(sed -n 's/^INSTALLED=//p' <<< "$out")
    TARGET=$(sed -n 's/^TARGET=//p' <<< "$out")
    STATUS=$(sed -n 's/^STATUS=//p' <<< "$out")
    return $rc
}

# Serveur lu dans la configuration de l'agent, TLS vérifié.
check_server_connectivity() {
    local url code
    url="${TACTICAL_URL:-}"
    if [ -z "$url" ] && [ -r "$AGENT_CONFIG" ]; then
        url=$(sed -n 's/.*"baseurl" *: *"\([^"]*\)".*/\1/p' "$AGENT_CONFIG" | head -1)
    fi
    if [ -z "$url" ]; then
        log "WARNING" "URL du serveur inconnue (ni TACTICAL_URL ni $AGENT_CONFIG lisible), test sauté"
        return 0
    fi
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$url/" 2>/dev/null)
    if [ -z "$code" ] || [ "$code" = "000" ]; then
        log "ERROR" "Serveur injoignable ou certificat invalide : $url"
        return 1
    fi
    log "INFO" "Serveur joignable : $url (HTTP $code)"
}

create_backup() {
    local dir
    dir="/root/tactical-agent-backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$dir" && chmod 700 "$dir" || { log "ERROR" "Création de $dir impossible"; return 1; }
    cp -p "$AGENT_PATH" "$dir/" || { log "ERROR" "Copie de $AGENT_PATH impossible"; return 1; }
    [ -f "$AGENT_CONFIG" ] && cp -p "$AGENT_CONFIG" "$dir/"
    log "SUCCESS" "Sauvegarde : $dir"
}

# === MAIN ===

parse_arguments "$@"
log "INFO" "update-tactical-agent v$SCRIPT_VERSION"

if [ "$DRY_RUN" = false ] && [ "$EUID" -ne 0 ]; then
    log "ERROR" "Ce script doit être exécuté en tant que root (ou avec --dry-run)"
    exit 1
fi

ENGINE=""
find_engine || exit 1
log "INFO" "Moteur : $ENGINE"

run_check
rc=$?
log "INFO" "Agent : ${AGENT_PATH:-?} | installée : ${INSTALLED:-?} | visée : ${TARGET:-?} | état : ${STATUS:-?}"
if [ $rc -ne 0 ] && [ $rc -ne 10 ]; then
    log "ERROR" "État indéterminable ($STATUS)"
    exit 1
fi

if [ $rc -eq 0 ] && [ "$FORCE_UPDATE" = false ]; then
    log "SUCCESS" "Agent déjà à jour"
    exit 0
fi

check_server_connectivity || exit 1

if [ "$DRY_RUN" = true ]; then
    log "INFO" "Simulation : rmmagent-linux.sh update serait lancé"
    exit 10
fi

if [ "$CREATE_BACKUP" = true ]; then
    create_backup || exit 1
fi

log "INFO" "Lancement de rmmagent-linux.sh update..."
if ! engine update >> "$LOG_FILE" 2>&1; then
    log "ERROR" "Échec de la mise à jour (détail : $LOG_FILE)"
    exit 1
fi

if ! run_check; then
    log "ERROR" "Après mise à jour : $STATUS (installée $INSTALLED, visée $TARGET)"
    exit 1
fi
log "SUCCESS" "Agent en $INSTALLED, service actif"
exit 0
