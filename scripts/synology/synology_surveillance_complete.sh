#!/bin/bash
# ============================================
# Script de surveillance complète Synology NAS
# Pour Tactical RMM - Version autonome
# ============================================

ERREUR=0

echo "========================================"
echo "  SURVEILLANCE NAS SYNOLOGY"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# Vérifier si on est sur un Synology
if [ ! -f /etc/synoinfo.conf ]; then
    echo "[ERREUR] Ce script doit être exécuté sur un NAS Synology"
    exit 1
fi

# ============================================
# INFORMATIONS SYSTÈME
# ============================================
echo "=== Informations système ==="
echo ""

# Modèle et version DSM
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
echo "--- Ressources ---"

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
    echo "[ALERTE] RAM: ${mem_percent}% (${mem_used}Mo / ${mem_total}Mo)"
    ERREUR=1
else
    echo "[OK] RAM: ${mem_percent}% (${mem_used}Mo / ${mem_total}Mo)"
fi

echo ""

# ============================================
# ÉTAT DES DISQUES
# ============================================
echo "=== État des disques ==="
echo ""

TEMP_MAX=50

# Trouver smartctl
SMARTCTL=""
if command -v smartctl &> /dev/null; then
    SMARTCTL="smartctl"
elif [ -x /usr/syno/bin/smartctl ]; then
    SMARTCTL="/usr/syno/bin/smartctl"
fi

# Trouver les disques - plusieurs méthodes pour DSM 7
DISKS=""
if command -v lsblk &> /dev/null; then
    DISKS=$(lsblk -d -n -o NAME 2>/dev/null | grep -E "^sd|^sata|^nvme")
fi
if [ -z "$DISKS" ]; then
    DISKS=$(ls /dev/sd[a-z] /dev/sata[0-9] /dev/nvme[0-9]n[0-9] 2>/dev/null | xargs -n1 basename 2>/dev/null)
fi
if [ -z "$DISKS" ]; then
    DISKS=$(ls /sys/block/ 2>/dev/null | grep -E "^sd|^sata|^nvme")
fi

# Parcourir les disques
for disk_name in $DISKS; do
    disk="/dev/$disk_name"

    if [ -b "$disk" ]; then
        echo "Disque: $disk_name"

        if [ -n "$SMARTCTL" ]; then
            # Informations SMART
            smart_info=$($SMARTCTL -i "$disk" 2>/dev/null)
            model=$(echo "$smart_info" | grep -E "Device Model|Model Family|Product:" | head -1 | cut -d: -f2 | xargs)

            [ -n "$model" ] && echo "  Modèle: $model"

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

            # Secteurs défaillants
            reallocated=$($SMARTCTL -A "$disk" 2>/dev/null | grep "Reallocated_Sector_Ct" | awk '{print $10}')
            if [ -n "$reallocated" ] && [ "$reallocated" -gt 0 ] 2>/dev/null; then
                echo "  [ALERTE] Secteurs réalloués: $reallocated"
                ERREUR=1
            fi
        fi

        echo ""
    fi
done

# ============================================
# ÉTAT RAID / VOLUMES
# ============================================
echo "=== État RAID / Volumes ==="
echo ""

# Volumes RAID
for md in /dev/md*; do
    if [ -b "$md" ]; then
        md_name=$(basename "$md")
        detail=$(mdadm --detail "$md" 2>/dev/null)

        if [ -n "$detail" ]; then
            state=$(echo "$detail" | grep "State :" | cut -d: -f2 | xargs)
            level=$(echo "$detail" | grep "Raid Level" | cut -d: -f2 | xargs)
            active=$(echo "$detail" | grep "Active Devices" | cut -d: -f2 | xargs)
            devices=$(echo "$detail" | grep "Raid Devices" | cut -d: -f2 | xargs)
            failed=$(echo "$detail" | grep "Failed Devices" | cut -d: -f2 | xargs)

            echo "Volume: $md_name ($level)"
            echo "  Disques: $active/$devices actifs"

            if [ "$state" == "clean" ] || [ "$state" == "active" ]; then
                echo "  [OK] État: $state"
            elif [[ "$state" == *"degraded"* ]]; then
                echo "  [ALERTE] État: $state (volume dégradé)"
                ERREUR=1
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

# Utilisation des volumes
echo "--- Utilisation des volumes ---"
SEUIL_DISK=85

for vol in /volume*; do
    if [ -d "$vol" ]; then
        usage=$(df -h "$vol" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
        total=$(df -h "$vol" 2>/dev/null | awk 'NR==2 {print $2}')
        used=$(df -h "$vol" 2>/dev/null | awk 'NR==2 {print $3}')

        if [ -n "$usage" ]; then
            vol_name=$(basename "$vol")
            if [ "$usage" -gt "$SEUIL_DISK" ]; then
                echo "[ALERTE] $vol_name: ${usage}% utilisé ($used / $total)"
                ERREUR=1
            else
                echo "[OK] $vol_name: ${usage}% utilisé ($used / $total)"
            fi
        fi
    fi
done

echo ""

# ============================================
# SERVICES
# ============================================
echo "=== Services ==="
echo ""

# Services critiques
services_check=(
    "nginx:Serveur Web"
    "sshd:SSH"
    "smbd:Samba/CIFS"
)

for service_info in "${services_check[@]}"; do
    service=$(echo "$service_info" | cut -d: -f1)
    nom=$(echo "$service_info" | cut -d: -f2)

    if ps aux 2>/dev/null | grep -v grep | grep -q "$service"; then
        echo "[OK] $nom"
    fi
done

# Docker si installé
if command -v docker &> /dev/null; then
    running=$(docker ps -q 2>/dev/null | wc -l)
    total=$(docker ps -aq 2>/dev/null | wc -l)
    echo "[OK] Docker: $running/$total conteneurs actifs"
    echo ""

    # Liste de tous les conteneurs
    echo "--- Liste des conteneurs ---"
    docker ps -a --format "{{.Names}}|{{.Status}}|{{.Image}}" 2>/dev/null | while read line; do
        name=$(echo "$line" | cut -d'|' -f1)
        status=$(echo "$line" | cut -d'|' -f2)
        image=$(echo "$line" | cut -d'|' -f3)

        if echo "$status" | grep -q "Up"; then
            echo "  [OK] $name ($image)"
        else
            echo "  [ARRÊT] $name ($image)"
        fi
    done
fi

echo ""

# ============================================
# SÉCURITÉ
# ============================================
echo "=== Sécurité ==="
echo ""

# IPs bloquées
if [ -f /etc/synoautoblock.db ]; then
    blocked=$(sqlite3 /etc/synoautoblock.db "SELECT COUNT(*) FROM AutoBlockIP;" 2>/dev/null)
    echo "IPs bloquées: ${blocked:-0}"

    if [ "${blocked:-0}" -gt 0 ]; then
        echo ""
        echo "--- Liste des IPs bloquées ---"
        sqlite3 /etc/synoautoblock.db "SELECT IP FROM AutoBlockIP ORDER BY rowid DESC LIMIT 10;" 2>/dev/null | while read ip; do
            echo "  - $ip"
        done
    fi
fi

# Tentatives de connexion
if [ -f /var/log/synolog/.SYNOLOGLOGIN.log ]; then
    failed=$(grep "$(date +%Y/%m/%d)" /var/log/synolog/.SYNOLOGLOGIN.log 2>/dev/null | grep -c "failed")
    echo "Connexions échouées (24h): $failed"

    if [ "$failed" -gt 50 ]; then
        echo "[ALERTE] Nombreuses tentatives échouées"
        ERREUR=1
    fi
fi

echo ""

# ============================================
# UPS
# ============================================
if command -v upsc &> /dev/null; then
    ups_list=$(upsc -l 2>/dev/null)
    if [ -n "$ups_list" ]; then
        echo "=== UPS ==="
        echo ""
        for ups in $ups_list; do
            status=$(upsc "$ups" ups.status 2>/dev/null)
            battery=$(upsc "$ups" battery.charge 2>/dev/null)

            if [ "$status" == "OL" ]; then
                echo "[OK] UPS en ligne - Batterie: ${battery}%"
            elif [ "$status" == "OB" ]; then
                echo "[ALERTE] UPS sur batterie - ${battery}%"
                ERREUR=1
            fi
        done
        echo ""
    fi
fi

# ============================================
# RÉSULTAT
# ============================================
echo "========================================"
if [ $ERREUR -eq 0 ]; then
    echo "RÉSULTAT: Tout est OK"
else
    echo "RÉSULTAT: ALERTES DÉTECTÉES"
fi
echo "========================================"

exit $ERREUR
