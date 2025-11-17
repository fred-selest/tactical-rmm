#!/bin/bash
# Vérification des sauvegardes Plesk
# Alerte si dernière sauvegarde > 7 jours

JOURS_MAX=7
ERREUR=0

echo "=== État des sauvegardes Plesk ==="
echo ""

# Répertoire des sauvegardes
BACKUP_DIR="/var/lib/psa/dumps"

if [ -d "$BACKUP_DIR" ]; then
    # Dernière sauvegarde
    derniere=$(find "$BACKUP_DIR" -name "*.xml" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1)

    if [ -n "$derniere" ]; then
        fichier=$(echo "$derniere" | cut -d' ' -f2-)
        timestamp=$(echo "$derniere" | cut -d' ' -f1 | cut -d. -f1)
        now=$(date +%s)
        jours=$(( (now - timestamp) / 86400 ))
        date_backup=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M")

        echo "Dernière sauvegarde: $date_backup"
        echo "Il y a $jours jours"

        if [ $jours -gt $JOURS_MAX ]; then
            echo "[ALERTE] Sauvegarde trop ancienne (> $JOURS_MAX jours)"
            ERREUR=1
        else
            echo "[OK] Sauvegarde récente"
        fi
    else
        echo "[ALERTE] Aucune sauvegarde trouvée"
        ERREUR=1
    fi

    echo ""
    echo "--- Espace utilisé par les sauvegardes ---"
    du -sh "$BACKUP_DIR" 2>/dev/null

    echo ""
    echo "--- 5 dernières sauvegardes ---"
    ls -lht "$BACKUP_DIR"/*.xml 2>/dev/null | head -5
else
    echo "[ALERTE] Répertoire de sauvegarde non trouvé"
    ERREUR=1
fi

exit $ERREUR
