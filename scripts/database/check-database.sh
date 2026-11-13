#!/bin/bash
# Surveillance complète des bases de données
# Détecte automatiquement MySQL/MariaDB et PostgreSQL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/tacticalrmm-database-check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo "=== Surveillance Complète Bases de Données ==="
echo ""

ALERTE=0

# Vérifier MySQL/MariaDB
if command -v mysql &> /dev/null; then
    echo "--- Vérification MySQL/MariaDB ---"
    if "$SCRIPT_DIR/check-mysql.sh"; then
        echo "MySQL: OK"
    else
        echo "MySQL: ALERTE"
        ALERTE=1
    fi
    echo ""
fi

# Vérifier PostgreSQL
if command -v psql &> /dev/null; then
    echo "--- Vérification PostgreSQL ---"
    if "$SCRIPT_DIR/check-postgresql.sh"; then
        echo "PostgreSQL: OK"
    else
        echo "PostgreSQL: ALERTE"
        ALERTE=1
    fi
    echo ""
fi

# Si aucune base de données n'est trouvée
if ! command -v mysql &> /dev/null && ! command -v psql &> /dev/null; then
    echo "Aucun système de base de données détecté (MySQL/PostgreSQL)"
    log "INFO: Aucune base de données détectée"
    exit 0
fi

# Journaliser le résultat global
if [ $ALERTE -eq 1 ]; then
    log "ALERTE: Problèmes bases de données détectés"
else
    log "OK: Toutes les bases de données fonctionnent normalement"
fi

exit $ALERTE