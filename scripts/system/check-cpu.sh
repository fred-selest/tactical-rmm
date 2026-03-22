#!/bin/bash
# Surveillance avancée du CPU
# Alerte si utilisation > 80% pendant plus de 5 minutes

SEUIL_CPU=80
DUREE_ALERTE=300  # 5 minutes en secondes
LOG_FILE="/var/log/tacticalrmm-cpu-check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction pour obtenir l'utilisation CPU moyenne sur 1, 5 et 15 minutes
get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | tr -d ' '
}

# Fonction pour obtenir l'utilisation CPU en temps réel
get_cpu_usage() {
    # Utiliser top pour obtenir l'utilisation CPU (exclure le temps idle)
    top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}'
}

# Fonction pour vérifier l'historique d'utilisation élevée
check_cpu_history() {
    local current_time=$(date +%s)
    local high_usage_count=0
    local recent_logs=0
    
    # Compter les entrées récentes avec utilisation élevée
    if [ -f "$LOG_FILE" ]; then
        while IFS= read -r line; do
            # Extraire le timestamp et l'utilisation
            if [[ $line =~ \[([0-9-]+\ [0-9:]+)\].*Utilisation.* ([0-9.]+)% ]]; then
                log_time="${BASH_REMATCH[1]}"
                usage="${BASH_REMATCH[2]}"
                log_timestamp=$(date -d "$log_time" +%s 2>/dev/null || echo 0)
                
                # Vérifier si l'entrée est dans les dernières 5 minutes
                if [ $((current_time - log_timestamp)) -le $DUREE_ALERTE ] && [ $(echo "$usage > $SEUIL_CPU" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
                    ((high_usage_count++))
                fi
                ((recent_logs++))
            fi
        done < "$LOG_FILE"
    fi
    
    echo $high_usage_count
}

echo "=== Surveillance CPU Système ==="
echo ""

# Obtenir les informations de charge système
LOAD_AVG=$(get_load_average)
echo "Charge système (1m, 5m, 15m): $LOAD_AVG"

# Obtenir l'utilisation CPU actuelle
CPU_USAGE=$(get_cpu_usage)
CPU_USAGE_ROUNDED=$(printf "%.1f" $CPU_USAGE)
echo "Utilisation CPU actuelle: ${CPU_USAGE_ROUNDED}%"

# Nombre de cœurs CPU
CPU_CORES=$(nproc)
echo "Nombre de cœurs CPU: $CPU_CORES"

# Calculer la charge par cœur
IFS=',' read -ra LOAD_ARRAY <<< "$LOAD_AVG"
LOAD_1M=${LOAD_ARRAY[0]}
LOAD_PER_CORE=$(echo "scale=2; $LOAD_1M / $CPU_CORES" | bc)

echo "Charge moyenne par cœur (1m): $LOAD_PER_CORE"

# Vérifier les seuils
ALERTE=0

if (( $(echo "$CPU_USAGE > $SEUIL_CPU" | bc -l) )); then
    echo "[ALERTE] Utilisation CPU > ${SEUIL_CPU}%"
    ALERTE=1
fi

# Vérifier la charge système
if (( $(echo "$LOAD_1M > $CPU_CORES" | bc -l) )); then
    echo "[ALERTE] Charge système 1m ($LOAD_1M) > nombre de cœurs ($CPU_CORES)"
    ALERTE=1
fi

# Vérifier l'historique d'utilisation élevée
HISTORY_COUNT=$(check_cpu_history)
if [ "$HISTORY_COUNT" -gt 3 ]; then
    echo "[ALERTE CRITIQUE] Utilisation CPU élevée persistante depuis plus de 5 minutes"
    ALERTE=2
fi

# Top 5 des processus consommateurs de CPU
echo ""
echo "--- Top 5 processus CPU ---"
ps aux --sort=-%cpu | head -6 | column -t

# Informations supplémentaires
echo ""
echo "--- Informations système ---"
echo "Uptime: $(uptime -p)"
echo "Température CPU (si disponible):"
if command -v sensors &> /dev/null; then
    sensors | grep -E "(Package|Core|Tdie|Tctl)" | head -3
elif [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    if [ -n "$TEMP" ]; then
        echo "  $(echo "scale=1; $TEMP/1000" | bc)°C"
    fi
else
    echo "  Non disponible"
fi

# Journaliser l'utilisation actuelle
log "Utilisation CPU: ${CPU_USAGE_ROUNDED}%, Charge: $LOAD_AVG, Cœurs: $CPU_CORES"

# Déterminer le code de sortie
if [ $ALERTE -eq 2 ]; then
    exit 2  # Alerte critique
elif [ $ALERTE -eq 1 ]; then
    exit 1  # Alerte standard
else
    exit 0  # Tout va bien
fi