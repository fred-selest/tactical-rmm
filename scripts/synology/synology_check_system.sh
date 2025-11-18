#!/bin/bash
# Surveillance système Synology NAS
# CPU, RAM, température, ventilateurs, UPS

ERREUR=0

echo "=== État système Synology ==="
echo ""

# Vérifier si on est sur un Synology
if [ ! -f /etc/synoinfo.conf ]; then
    echo "[ERREUR] Ce script doit être exécuté sur un NAS Synology"
    exit 1
fi

# Informations DSM
echo "--- Informations NAS ---"
if [ -f /etc/synoinfo.conf ]; then
    model=$(grep "upnpmodelname" /etc/synoinfo.conf | cut -d'"' -f2)
    echo "Modèle: $model"
fi

dsm_version=$(cat /etc.defaults/VERSION 2>/dev/null | grep "productversion" | cut -d'"' -f2)
dsm_build=$(cat /etc.defaults/VERSION 2>/dev/null | grep "buildnumber" | cut -d'"' -f2)
echo "DSM: $dsm_version (build $dsm_build)"

# Uptime
uptime_info=$(uptime -p 2>/dev/null || uptime)
echo "Uptime: $uptime_info"

echo ""
echo "--- Ressources système ---"

# CPU
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if [ -n "$cpu_usage" ]; then
    cpu_int=${cpu_usage%.*}
    if [ "$cpu_int" -gt 80 ]; then
        echo "[ALERTE] CPU: ${cpu_usage}%"
        ERREUR=1
    else
        echo "[OK] CPU: ${cpu_usage}%"
    fi
fi

# RAM
mem_info=$(free -m | awk 'NR==2')
mem_total=$(echo "$mem_info" | awk '{print $2}')
mem_used=$(echo "$mem_info" | awk '{print $3}')
mem_percent=$((mem_used * 100 / mem_total))

if [ "$mem_percent" -gt 90 ]; then
    echo "[ALERTE] RAM: ${mem_percent}% (${mem_used}MB / ${mem_total}MB)"
    ERREUR=1
else
    echo "[OK] RAM: ${mem_percent}% (${mem_used}MB / ${mem_total}MB)"
fi

# Swap
swap_info=$(free -m | awk 'NR==3')
swap_total=$(echo "$swap_info" | awk '{print $2}')
swap_used=$(echo "$swap_info" | awk '{print $3}')
if [ "$swap_total" -gt 0 ]; then
    swap_percent=$((swap_used * 100 / swap_total))
    echo "Swap: ${swap_percent}% (${swap_used}MB / ${swap_total}MB)"
fi

echo ""
echo "--- Température système ---"

# Température CPU (via sysctl ou fichiers système)
cpu_temp=""
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    cpu_temp=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
fi

if [ -n "$cpu_temp" ]; then
    if [ "$cpu_temp" -gt 80 ]; then
        echo "[ALERTE] Température CPU: ${cpu_temp}°C"
        ERREUR=1
    else
        echo "[OK] Température CPU: ${cpu_temp}°C"
    fi
fi

echo ""
echo "--- Ventilateurs ---"

# État des ventilateurs via synohw si disponible
if command -v synoha &> /dev/null; then
    synoha --fan-status 2>/dev/null
else
    # Alternative via fichiers système
    for fan in /sys/class/hwmon/hwmon*/fan*_input; do
        if [ -f "$fan" ]; then
            fan_speed=$(cat "$fan")
            fan_name=$(basename "$fan")
            if [ "$fan_speed" -eq 0 ]; then
                echo "[ALERTE] $fan_name: arrêté"
                ERREUR=1
            else
                echo "[OK] $fan_name: ${fan_speed} RPM"
            fi
        fi
    done
fi

echo ""
echo "--- UPS ---"

# État UPS si connecté
if command -v upsc &> /dev/null; then
    ups_list=$(upsc -l 2>/dev/null)
    if [ -n "$ups_list" ]; then
        for ups in $ups_list; do
            status=$(upsc "$ups" ups.status 2>/dev/null)
            battery=$(upsc "$ups" battery.charge 2>/dev/null)
            runtime=$(upsc "$ups" battery.runtime 2>/dev/null)

            echo "UPS: $ups"
            if [ "$status" == "OL" ]; then
                echo "  [OK] État: En ligne"
            elif [ "$status" == "OB" ]; then
                echo "  [ALERTE] État: Sur batterie"
                ERREUR=1
            else
                echo "  État: $status"
            fi

            [ -n "$battery" ] && echo "  Batterie: ${battery}%"
            [ -n "$runtime" ] && echo "  Autonomie: $((runtime / 60)) minutes"
        done
    else
        echo "Aucun UPS détecté"
    fi
else
    echo "UPS non configuré"
fi

exit $ERREUR
