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

# Liste des disques
for disk in /dev/sd[a-z]; do
    if [ -b "$disk" ]; then
        disk_name=$(basename "$disk")

        # Informations SMART
        smart_info=$(smartctl -i "$disk" 2>/dev/null)
        model=$(echo "$smart_info" | grep "Device Model" | cut -d: -f2 | xargs)
        serial=$(echo "$smart_info" | grep "Serial Number" | cut -d: -f2 | xargs)

        # État de santé
        health=$(smartctl -H "$disk" 2>/dev/null | grep "SMART overall-health" | cut -d: -f2 | xargs)

        # Température
        temp=$(smartctl -A "$disk" 2>/dev/null | grep "Temperature_Celsius" | awk '{print $10}')

        echo "Disque: $disk_name"
        [ -n "$model" ] && echo "  Modèle: $model"
        [ -n "$serial" ] && echo "  Série: $serial"

        if [ "$health" == "PASSED" ]; then
            echo "  [OK] Santé SMART: $health"
        else
            echo "  [ALERTE] Santé SMART: $health"
            ERREUR=1
        fi

        if [ -n "$temp" ]; then
            if [ "$temp" -gt "$TEMP_MAX" ]; then
                echo "  [ALERTE] Température: ${temp}°C (> ${TEMP_MAX}°C)"
                ERREUR=1
            else
                echo "  [OK] Température: ${temp}°C"
            fi
        fi

        # Erreurs SMART
        reallocated=$(smartctl -A "$disk" 2>/dev/null | grep "Reallocated_Sector_Ct" | awk '{print $10}')
        pending=$(smartctl -A "$disk" 2>/dev/null | grep "Current_Pending_Sector" | awk '{print $10}')

        if [ -n "$reallocated" ] && [ "$reallocated" -gt 0 ]; then
            echo "  [ALERTE] Secteurs réalloués: $reallocated"
            ERREUR=1
        fi

        if [ -n "$pending" ] && [ "$pending" -gt 0 ]; then
            echo "  [ALERTE] Secteurs en attente: $pending"
            ERREUR=1
        fi

        echo ""
    fi
done

# Vérification via syno tools si disponible
if command -v synostorage &> /dev/null; then
    echo "--- État Synology Storage ---"
    synostorage --disk-list 2>/dev/null
fi

exit $ERREUR
