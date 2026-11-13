#!/bin/bash

###############################################################################
# Configuration de la mise à jour automatique Tactical RMM
# Configure un cron job pour vérifier les mises à jour régulièrement
#
# Usage: sudo ./setup-auto-update.sh [options]
# Options:
#   --daily        Mise à jour quotidienne (par défaut)
#   --weekly       Mise à jour hebdomadaire
#   --disable      Désactiver la mise à jour automatique
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update-tactical-rmm.sh"
CRON_FILE="/etc/cron.d/tactical-rmm-update"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Rendre le script d'update exécutable
chmod +x "$UPDATE_SCRIPT"

# Vérifier les arguments
if [ "$1" = "--disable" ]; then
    print_header "Désactivation de la mise à jour automatique"
    
    if [ -f "$CRON_FILE" ]; then
        rm -f "$CRON_FILE"
        log "Mise à jour automatique désactivée"
    else
        log "Aucune mise à jour automatique configurée"
    fi
    
    exit 0
fi

# Déterminer la fréquence
FREQUENCY="daily"
if [ "$1" = "--weekly" ]; then
    FREQUENCY="weekly"
fi

print_header "Configuration de la mise à jour automatique ($FREQUENCY)"

# Créer le fichier cron
case $FREQUENCY in
    "daily")
        # Mise à jour tous les jours à 2h du matin
        CRON_SCHEDULE="0 2 * * *"
        ;;
    "weekly")
        # Mise à jour tous les lundis à 2h du matin
        CRON_SCHEDULE="0 2 * * 1"
        ;;
esac

# Écrire le fichier cron
cat > "$CRON_FILE" << EOF
# Mise à jour automatique Tactical RMM
# Généré par setup-auto-update.sh
$CRON_SCHEDULE root cd $SCRIPT_DIR && ./update-tactical-rmm.sh --quiet >> /var/log/tacticalrmm-auto-update.log 2>&1
EOF

# Donner les permissions appropriées
chmod 644 "$CRON_FILE"

log "Mise à jour automatique configurée : $FREQUENCY"
log "Fichier cron : $CRON_FILE"
log "Logs : /var/log/tacticalrmm-auto-update.log"

# Afficher le contenu du cron
echo ""
echo "Contenu du cron configuré :"
cat "$CRON_FILE"

exit 0