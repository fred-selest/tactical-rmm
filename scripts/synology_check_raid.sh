#!/bin/bash
# Surveillance RAID/Storage Pool Synology
# Vérifie l'état des volumes et pools de stockage

ERREUR=0

echo "=== État RAID/Storage Synology ==="
echo ""

# Vérifier si on est sur un Synology
if [ ! -f /etc/synoinfo.conf ]; then
    echo "[ERREUR] Ce script doit être exécuté sur un NAS Synology"
    exit 1
fi

# État des volumes via mdadm
echo "--- Volumes RAID (mdadm) ---"
for md in /dev/md*; do
    if [ -b "$md" ]; then
        md_name=$(basename "$md")
        detail=$(mdadm --detail "$md" 2>/dev/null)

        if [ -n "$detail" ]; then
            state=$(echo "$detail" | grep "State :" | cut -d: -f2 | xargs)
            level=$(echo "$detail" | grep "Raid Level" | cut -d: -f2 | xargs)
            devices=$(echo "$detail" | grep "Raid Devices" | cut -d: -f2 | xargs)
            active=$(echo "$detail" | grep "Active Devices" | cut -d: -f2 | xargs)
            failed=$(echo "$detail" | grep "Failed Devices" | cut -d: -f2 | xargs)

            echo "Volume: $md_name ($level)"
            echo "  Disques: $active/$devices actifs"

            if [ "$state" == "clean" ] || [ "$state" == "active" ]; then
                echo "  [OK] État: $state"
            elif [[ "$state" == *"degraded"* ]]; then
                echo "  [ALERTE] État: $state (volume dégradé)"
                ERREUR=1
            elif [[ "$state" == *"rebuilding"* ]] || [[ "$state" == *"recovering"* ]]; then
                echo "  [INFO] État: $state (reconstruction en cours)"
                progress=$(echo "$detail" | grep "Rebuild Status" | cut -d: -f2 | xargs)
                [ -n "$progress" ] && echo "  Progression: $progress"
            else
                echo "  [ALERTE] État: $state"
                ERREUR=1
            fi

            if [ "$failed" -gt 0 ]; then
                echo "  [ALERTE] $failed disque(s) en échec"
                ERREUR=1
            fi

            echo ""
        fi
    fi
done

# Pools de stockage via synospace si disponible
echo "--- Pools de stockage ---"
if command -v synospace &> /dev/null; then
    synospace --status 2>/dev/null
else
    # Alternative via df
    df -h | grep "/volume"
fi

echo ""
echo "--- Utilisation des volumes ---"

# Vérifier l'utilisation des volumes
SEUIL=85
for vol in /volume*; do
    if [ -d "$vol" ]; then
        usage=$(df -h "$vol" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
        total=$(df -h "$vol" 2>/dev/null | awk 'NR==2 {print $2}')
        used=$(df -h "$vol" 2>/dev/null | awk 'NR==2 {print $3}')

        if [ -n "$usage" ]; then
            vol_name=$(basename "$vol")
            if [ "$usage" -gt "$SEUIL" ]; then
                echo "[ALERTE] $vol_name: ${usage}% utilisé ($used / $total)"
                ERREUR=1
            else
                echo "[OK] $vol_name: ${usage}% utilisé ($used / $total)"
            fi
        fi
    fi
done

exit $ERREUR
