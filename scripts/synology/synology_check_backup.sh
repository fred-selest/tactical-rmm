#!/bin/bash
# Surveillance des sauvegardes Synology
# Hyper Backup, Snapshot Replication, etc.

ERREUR=0
JOURS_MAX=7

echo "=== État des sauvegardes Synology ==="
echo ""

# Vérifier si on est sur un Synology
if [ ! -f /etc/synoinfo.conf ]; then
    echo "[ERREUR] Ce script doit être exécuté sur un NAS Synology"
    exit 1
fi

echo "--- Hyper Backup ---"

# Répertoire des configurations Hyper Backup
HB_CONFIG="/var/packages/HyperBackup/target"

if [ -d "$HB_CONFIG" ]; then
    # Chercher les logs de backup
    backup_logs=$(find /var/log -name "*hyper*backup*" -type f 2>/dev/null | head -5)

    if [ -n "$backup_logs" ]; then
        for log in $backup_logs; do
            echo "Log: $log"
            # Dernière entrée
            last_entry=$(tail -1 "$log" 2>/dev/null)
            echo "Dernière entrée: $last_entry"
        done
    fi

    # Vérifier les tâches via synobackup si disponible
    if command -v synobackup &> /dev/null; then
        echo ""
        synobackup --list 2>/dev/null
    fi
else
    echo "Hyper Backup non installé"
fi

echo ""
echo "--- Snapshot Replication ---"

# Vérifier les snapshots
SNAP_CONFIG="/var/packages/SnapshotReplication/target"

if [ -d "$SNAP_CONFIG" ]; then
    echo "Snapshot Replication installé"

    # Compter les snapshots par volume
    for vol in /volume*; do
        if [ -d "$vol/@snapshot" ]; then
            snap_count=$(ls -1 "$vol/@snapshot" 2>/dev/null | wc -l)
            vol_name=$(basename "$vol")
            echo "$vol_name: $snap_count snapshots"
        fi
    done
else
    echo "Snapshot Replication non installé"
fi

echo ""
echo "--- USB Copy (si configuré) ---"

# Vérifier les périphériques USB connectés
usb_devices=$(lsusb 2>/dev/null | grep -v "root hub" | wc -l)
echo "Périphériques USB: $usb_devices"

echo ""
echo "--- Cloud Sync ---"

CLOUD_CONFIG="/var/packages/CloudSync/target"
if [ -d "$CLOUD_CONFIG" ]; then
    echo "Cloud Sync installé"
else
    echo "Cloud Sync non installé"
fi

echo ""
echo "--- Dernières sauvegardes ---"

# Chercher les fichiers de sauvegarde récents
echo "Fichiers .hbk récents:"
find /volume* -name "*.hbk" -mtime -$JOURS_MAX -type f 2>/dev/null | head -10

# Vérifier s'il y a des sauvegardes anciennes
old_backups=$(find /volume* -name "*.hbk" -mtime +$JOURS_MAX -type f 2>/dev/null | wc -l)
if [ "$old_backups" -gt 0 ]; then
    echo ""
    echo "[INFO] $old_backups fichier(s) de sauvegarde > $JOURS_MAX jours"
fi

exit $ERREUR
