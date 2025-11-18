#!/bin/bash
# Script: Surveillance Hyper Backup Synology
# Usage dans Tactical RMM: Exécuter sur le NAS Synology
# Vérifie l'état des tâches Hyper Backup

# Configuration
WARNING_HOURS=24    # Alerte si backup > X heures
CRITICAL_HOURS=48   # Critique si backup > X heures

echo "=========================================="
echo "SURVEILLANCE HYPER BACKUP"
echo "NAS: $(hostname)"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# Vérifier si Hyper Backup est installé
if ! command -v synobackup &> /dev/null; then
    echo "[ERREUR] Hyper Backup n'est pas installé"
    exit 1
fi

# ============================================
# ÉTAT DES TÂCHES HYPER BACKUP
# ============================================
echo "--- TACHES HYPER BACKUP ---"

# Récupérer la liste des tâches
TASKS=$(synobackup --list 2>/dev/null)

if [ -z "$TASKS" ]; then
    echo "Aucune tâche Hyper Backup configurée"
else
    FAILED_TASKS=0
    WARNING_TASKS=0

    # Parser les tâches
    echo "$TASKS" | while read -r LINE; do
        if [[ -n "$LINE" && ! "$LINE" =~ ^Task ]]; then
            TASK_ID=$(echo "$LINE" | awk '{print $1}')
            TASK_NAME=$(echo "$LINE" | awk '{print $2}')

            if [ -n "$TASK_ID" ]; then
                # Obtenir les détails de la tâche
                TASK_INFO=$(synobackup --get "$TASK_ID" 2>/dev/null)

                # Extraire le statut
                LAST_RESULT=$(echo "$TASK_INFO" | grep -i "last_backup_result" | cut -d'=' -f2)
                LAST_TIME=$(echo "$TASK_INFO" | grep -i "last_backup_time" | cut -d'=' -f2)

                if [ -n "$LAST_TIME" ] && [ "$LAST_TIME" != "0" ]; then
                    # Calculer l'âge du backup
                    CURRENT_TIME=$(date +%s)
                    BACKUP_AGE=$(( (CURRENT_TIME - LAST_TIME) / 3600 ))
                    BACKUP_DATE=$(date -d "@$LAST_TIME" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$LAST_TIME" '+%Y-%m-%d %H:%M')

                    # Déterminer le statut
                    if [ "$LAST_RESULT" = "0" ] || [ "$LAST_RESULT" = "success" ]; then
                        if [ "$BACKUP_AGE" -gt "$CRITICAL_HOURS" ]; then
                            echo "[CRITIQUE] $TASK_NAME"
                            echo "   Dernier backup: $BACKUP_DATE (il y a ${BACKUP_AGE}h)"
                            ((FAILED_TASKS++))
                        elif [ "$BACKUP_AGE" -gt "$WARNING_HOURS" ]; then
                            echo "[ATTENTION] $TASK_NAME"
                            echo "   Dernier backup: $BACKUP_DATE (il y a ${BACKUP_AGE}h)"
                            ((WARNING_TASKS++))
                        else
                            echo "[OK] $TASK_NAME"
                            echo "   Dernier backup: $BACKUP_DATE (il y a ${BACKUP_AGE}h)"
                        fi
                    else
                        echo "[ERREUR] $TASK_NAME"
                        echo "   Résultat: Échec (code $LAST_RESULT)"
                        echo "   Dernier backup: $BACKUP_DATE"
                        ((FAILED_TASKS++))
                    fi
                else
                    echo "[ATTENTION] $TASK_NAME - Jamais exécuté"
                    ((WARNING_TASKS++))
                fi
                echo ""
            fi
        fi
    done
fi

echo ""

# ============================================
# LOGS RÉCENTS HYPER BACKUP
# ============================================
echo "--- LOGS RECENTS ---"

# Chercher les logs Hyper Backup
HB_LOG_DIR="/var/log/synolog"
if [ -d "$HB_LOG_DIR" ]; then
    # Dernières entrées de log
    if [ -f "$HB_LOG_DIR/synobackup.log" ]; then
        echo "Dernières entrées:"
        tail -20 "$HB_LOG_DIR/synobackup.log" 2>/dev/null | grep -E "error|fail|success|complet" -i | tail -5
    fi
fi

# Vérifier les logs système pour Hyper Backup
if [ -f "/var/log/messages" ]; then
    HB_ERRORS=$(grep -i "hyper.backup\|synobackup" /var/log/messages 2>/dev/null | grep -i "error\|fail" | tail -5)
    if [ -n "$HB_ERRORS" ]; then
        echo ""
        echo "Erreurs récentes:"
        echo "$HB_ERRORS"
    fi
fi

echo ""

# ============================================
# ESPACE DES DESTINATIONS
# ============================================
echo "--- DESTINATIONS DE SAUVEGARDE ---"

# Vérifier les destinations locales (volumes)
for VOL in /volume*; do
    if [ -d "$VOL" ]; then
        # Chercher les dossiers de backup
        for BACKUP_DIR in "$VOL"/@*backup* "$VOL"/backup* "$VOL"/Backup*; do
            if [ -d "$BACKUP_DIR" ]; then
                SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
                echo "$BACKUP_DIR: $SIZE"
            fi
        done
    fi
done

# Espace disponible sur les volumes
echo ""
echo "Espace disponible:"
df -h /volume* 2>/dev/null | grep volume | while read -r LINE; do
    MOUNT=$(echo "$LINE" | awk '{print $6}')
    USED=$(echo "$LINE" | awk '{print $5}')
    AVAIL=$(echo "$LINE" | awk '{print $4}')

    PERCENT=${USED%\%}
    if [ "$PERCENT" -gt 90 ]; then
        STATUS="[CRITIQUE]"
    elif [ "$PERCENT" -gt 80 ]; then
        STATUS="[ATTENTION]"
    else
        STATUS="[OK]"
    fi

    echo "$STATUS $MOUNT: $USED utilisé, $AVAIL libre"
done

echo ""

# ============================================
# TÂCHES EN COURS
# ============================================
echo "--- SAUVEGARDES EN COURS ---"

RUNNING=$(ps aux 2>/dev/null | grep -E "synobackup|hyper.backup" | grep -v grep)
if [ -n "$RUNNING" ]; then
    echo "Processus de sauvegarde actifs:"
    echo "$RUNNING" | awk '{print "  " $11}'
else
    echo "Aucune sauvegarde en cours"
fi

echo ""

# ============================================
# SNAPSHOT REPLICATION (si disponible)
# ============================================
if command -v synoshare &> /dev/null; then
    echo "--- SNAPSHOT REPLICATION ---"

    # Vérifier les snapshots
    SNAPSHOTS=$(synoshare --get-snapshot-info 2>/dev/null)
    if [ -n "$SNAPSHOTS" ]; then
        echo "$SNAPSHOTS" | head -20
    else
        echo "Snapshot Replication non configuré ou pas de snapshots"
    fi
    echo ""
fi

# ============================================
# RÉSUMÉ
# ============================================
echo "=========================================="
echo "RESUME"
echo "=========================================="

# Compter les tâches
TOTAL_TASKS=$(synobackup --list 2>/dev/null | grep -c "^[0-9]")
echo "Tâches configurées: $TOTAL_TASKS"

# Vérifier s'il y a des erreurs récentes
RECENT_ERRORS=$(grep -i "error\|fail" /var/log/synolog/synobackup.log 2>/dev/null | wc -l)
if [ "$RECENT_ERRORS" -gt 0 ]; then
    echo "[ATTENTION] Erreurs dans les logs: $RECENT_ERRORS"
fi

echo "=========================================="
