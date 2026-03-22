#!/bin/bash
# Surveillance complète du système
# Exécute toutes les vérifications système et retourne le statut global

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/tacticalrmm-system-check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo "=== Surveillance Complète Système ==="
echo ""

# Exécuter chaque vérification
echo "--- Vérification CPU ---"
"$SCRIPT_DIR/check-cpu.sh"
CPU_STATUS=$?

echo ""
echo "--- Vérification Mémoire ---"
"$SCRIPT_DIR/check-memory.sh"
MEMORY_STATUS=$?

echo ""
echo "--- Vérification Disque ---"
"$SCRIPT_DIR/check-disk.sh"
DISK_STATUS=$?

echo ""
echo "--- Vérification Réseau ---"
"$SCRIPT_DIR/check-network.sh"
NETWORK_STATUS=$?

# Déterminer le statut global
GLOBAL_STATUS=0

if [ $CPU_STATUS -eq 2 ]; then
    GLOBAL_STATUS=2  # Alerte critique
elif [ $CPU_STATUS -eq 1 ] || [ $MEMORY_STATUS -eq 1 ] || [ $DISK_STATUS -eq 1 ] || [ $NETWORK_STATUS -eq 1 ]; then
    GLOBAL_STATUS=1  # Alerte standard
fi

# Journaliser le résultat global
case $GLOBAL_STATUS in
    0)
        log "OK: Tous les systèmes fonctionnent normalement"
        ;;
    1)
        log "ALERTE: Problèmes détectés sur un ou plusieurs systèmes"
        ;;
    2)
        log "ALERTE CRITIQUE: Problèmes critiques détectés"
        ;;
esac

echo ""
echo "=== Résumé du statut ==="
echo "CPU:       $( [ $CPU_STATUS -eq 0 ] && echo "OK" || ( [ $CPU_STATUS -eq 1 ] && echo "ALERTE" || echo "CRITIQUE" ) )"
echo "Mémoire:   $( [ $MEMORY_STATUS -eq 0 ] && echo "OK" || echo "ALERTE" )"
echo "Disque:    $( [ $DISK_STATUS -eq 0 ] && echo "OK" || echo "ALERTE" )"
echo "Réseau:    $( [ $NETWORK_STATUS -eq 0 ] && echo "OK" || echo "ALERTE" )"
echo "Global:    $( [ $GLOBAL_STATUS -eq 0 ] && echo "OK" || ( [ $GLOBAL_STATUS -eq 1 ] && echo "ALERTE" || echo "CRITIQUE" ) )"

exit $GLOBAL_STATUS