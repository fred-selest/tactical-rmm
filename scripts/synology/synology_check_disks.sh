#!/bin/bash
# Surveillance des disques Synology NAS
# Vérifie l'état SMART, la température et la santé des disques

ERREUR=0
TEMP_MAX=50  # Température max en °C

echo "=== État des disques Synology ==="
echo ""

# Vérifier si on est sur un Synology
if [ ! -f /etc/synoinfo.conf ]; then
    echo "[ERREUR] Ce script doit être exécuté sur un NAS Synology"
    exit 1
fi

echo "--- Informations disques ---"
echo ""

# Trouver smartctl
SMARTCTL=""
if command -v smartctl &> /dev/null; then
    SMARTCTL="smartctl"
elif [ -x /usr/syno/bin/smartctl ]; then
    SMARTCTL="/usr/syno/bin/smartctl"
elif [ -x /usr/bin/smartctl ]; then
    SMARTCTL="/usr/bin/smartctl"
fi

# Trouver les disques - plusieurs méthodes
DISKS=""

# Méthode 1: lsblk
if command -v lsblk &> /dev/null; then
    DISKS=$(lsblk -d -n -o NAME 2>/dev/null | grep -E "^sd|^sata|^nvme")
fi

# Méthode 2: /dev
if [ -z "$DISKS" ]; then
    DISKS=$(ls /dev/sd[a-z] /dev/sata[0-9] /dev/nvme[0-9]n[0-9] 2>/dev/null | xargs -n1 basename 2>/dev/null)
fi

# Méthode 3: /sys/block
if [ -z "$DISKS" ]; then
    DISKS=$(ls /sys/block/ 2>/dev/null | grep -E "^sd|^sata|^nvme")
fi

# Parcourir les disques trouvés
if [ -n "$DISKS" ]; then
    for disk_name in $DISKS; do
        disk="/dev/$disk_name"

        if [ -b "$disk" ]; then
            echo "Disque: $disk_name"

            if [ -n "$SMARTCTL" ]; then
                # Informations SMART
                smart_info=$($SMARTCTL -i "$disk" 2>/dev/null)
                model=$(echo "$smart_info" | grep -E "Device Model|Model Family|Product:" | head -1 | cut -d: -f2 | xargs)
                serial=$(echo "$smart_info" | grep -E "Serial Number|Serial number:" | head -1 | cut -d: -f2 | xargs)

                [ -n "$model" ] && echo "  Modèle: $model"
                [ -n "$serial" ] && echo "  Série: $serial"

                # État de santé
                health=$($SMARTCTL -H "$disk" 2>/dev/null | grep -E "SMART overall-health|SMART Health Status" | cut -d: -f2 | xargs)

                if [ -n "$health" ]; then
                    if [[ "$health" == "PASSED" ]] || [[ "$health" == "OK" ]]; then
                        echo "  [OK] Santé SMART: $health"
                    else
                        echo "  [ALERTE] Santé SMART: $health"
                        ERREUR=1
                    fi
                fi

                # Température
                temp=$($SMARTCTL -A "$disk" 2>/dev/null | grep -E "Temperature_Celsius|Airflow_Temperature|Temperature:" | head -1 | awk '{print $10}')
                # Alternative pour certains disques
                if [ -z "$temp" ]; then
                    temp=$($SMARTCTL -A "$disk" 2>/dev/null | grep "Current Drive Temperature" | awk '{print $4}')
                fi

                if [ -n "$temp" ] && [ "$temp" -gt 0 ] 2>/dev/null; then
                    if [ "$temp" -gt "$TEMP_MAX" ]; then
                        echo "  [ALERTE] Température: ${temp}°C (> ${TEMP_MAX}°C)"
                        ERREUR=1
                    else
                        echo "  [OK] Température: ${temp}°C"
                    fi
                fi

                # Erreurs SMART
                reallocated=$($SMARTCTL -A "$disk" 2>/dev/null | grep "Reallocated_Sector_Ct" | awk '{print $10}')
                pending=$($SMARTCTL -A "$disk" 2>/dev/null | grep "Current_Pending_Sector" | awk '{print $10}')

                if [ -n "$reallocated" ] && [ "$reallocated" -gt 0 ] 2>/dev/null; then
                    echo "  [ALERTE] Secteurs réalloués: $reallocated"
                    ERREUR=1
                fi

                if [ -n "$pending" ] && [ "$pending" -gt 0 ] 2>/dev/null; then
                    echo "  [ALERTE] Secteurs en attente: $pending"
                    ERREUR=1
                fi
            fi

            # Taille du disque
            if [ -f "/sys/block/$disk_name/size" ]; then
                size_sectors=$(cat /sys/block/$disk_name/size 2>/dev/null)
                if [ -n "$size_sectors" ]; then
                    size_gb=$((size_sectors * 512 / 1024 / 1024 / 1024))
                    echo "  Taille: ${size_gb} Go"
                fi
            fi

            echo ""
        fi
    done
else
    echo "[INFO] Aucun disque détecté via les méthodes standard"
    echo ""
    echo "Périphériques bloc disponibles:"
    ls /sys/block/ 2>/dev/null
fi

# Statistiques E/S
echo "--- Statistiques E/S ---"
if [ -f /proc/diskstats ]; then
    cat /proc/diskstats 2>/dev/null | grep -E "sd[a-z] |sata[0-9] |nvme" | awk '{print $3": "$4" lectures, "$8" écritures"}'
fi

exit $ERREUR
