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

# Utiliser les fichiers système Synology pour lister les disques
for disk_path in /sys/block/sd*; do
    if [ -d "$disk_path" ]; then
        disk_name=$(basename "$disk_path")
        disk="/dev/$disk_name"

        if [ -b "$disk" ]; then
            echo "Disque: $disk_name"

            # Utiliser smartctl avec chemin complet si nécessaire
            SMARTCTL=""
            if command -v smartctl &> /dev/null; then
                SMARTCTL="smartctl"
            elif [ -x /usr/syno/bin/smartctl ]; then
                SMARTCTL="/usr/syno/bin/smartctl"
            fi

            if [ -n "$SMARTCTL" ]; then
                # Informations SMART
                smart_info=$($SMARTCTL -i "$disk" 2>/dev/null)
                model=$(echo "$smart_info" | grep -E "Device Model|Model Family" | head -1 | cut -d: -f2 | xargs)
                serial=$(echo "$smart_info" | grep "Serial Number" | cut -d: -f2 | xargs)

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
                temp=$($SMARTCTL -A "$disk" 2>/dev/null | grep -E "Temperature_Celsius|Airflow_Temperature" | head -1 | awk '{print $10}')

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
            else
                echo "  [INFO] smartctl non disponible"
            fi

            # Taille du disque
            size_bytes=$(cat /sys/block/$disk_name/size 2>/dev/null)
            if [ -n "$size_bytes" ]; then
                size_gb=$((size_bytes * 512 / 1024 / 1024 / 1024))
                echo "  Taille: ${size_gb} Go"
            fi

            echo ""
        fi
    fi
done

# Alternative : utiliser les logs système Synology
echo "--- État via DSM ---"

# Vérifier les alertes disques dans les logs
if [ -f /var/log/synolog/synobackup.log ]; then
    recent_errors=$(grep -i "error\|failed\|bad" /var/log/synolog/synobackup.log 2>/dev/null | tail -3)
    if [ -n "$recent_errors" ]; then
        echo "[INFO] Erreurs récentes dans les logs"
    fi
fi

# Afficher l'état des disques via /proc
echo ""
echo "--- Statistiques E/S ---"
cat /proc/diskstats 2>/dev/null | grep -E "sd[a-z] " | awk '{print $3": "$4" lectures, "$8" écritures"}'

exit $ERREUR
