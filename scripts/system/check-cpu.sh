#!/bin/bash
# Surveillance avancée du CPU
# Alerte si utilisation > 80% ou charge par cœur élevée

SEUIL_CPU=80
DUREE_ALERTE=300  # 5 minutes en secondes
LOG_FILE="/var/log/tacticalrmm-cpu-check.log"

log() {
    local message="$1"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo "$timestamp $message" | tee -a "$LOG_FILE"
}

# Obtenir la charge système
get_load_average() {
    cat /proc/loadavg | awk '{print $1","$2","$3}'
}

# Obtenir le taux d'utilisation du CPU
get_cpu_usage() {
    # Utiliser top pour obtenir l'utilisation CPU (exclure le temps idle)
    top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}'
}

# Fonction pour vérifier l'historique d'utilisation élevée
check_cpu_history() {
    local current_time=$(date +%s)
    local high_usage_count=0
    local recent_logs=0
    # Format des lignes de log : [YYYY-MM-DD HH:MM:SS] Utilisation: XX.X%
    # Le regex est passé par une variable : écrit en ligne dans
    # [[ $line =~ ... ]], la séquence " (" fait échouer le tokenizer de bash
    # ("syntax error in conditional expression") et le script sortait en 0
    # en masquant l'erreur.
    local LOG_LINE_RE='\[([0-9-]+\ [0-9:]+)\].*Utilisation.* ([0-9.]+)%'

    # Compter les entrées récentes avec utilisation élevée
    if [ -f "$LOG_FILE" ]; then
        while IFS= read -r line; do
            # Extraire le timestamp et l'utilisation.
            # Le regex est passé par une variable : écrit en ligne dans
            # [[ $line =~ ... ]], la séquence " (" fait échouer le
            # tokenizer de bash ("syntax error in conditional expression")
            # et le script sortait en 0 en masquant l'erreur.
            if [[ $line =~ $LOG_LINE_RE ]]; then
                log_time="${BASH_REMATCH[1]}"
                usage="${BASH_REMATCH[2]}"
                log_timestamp=$(date -d "$log_time" +%s 2>/dev/null || echo 0)

                # Vérifier si l'entrée est dans les dernières 5 minutes
                if [ $((current_time - log_timestamp)) -le $DUREE_ALERTE ] && [ "$(awk -v a="$usage" -v b="$SEUIL_CPU" 'BEGIN{print (a>b)?1:0}' 2>/dev/null || echo 0)" -eq 1 ]; then
                    high_usage_count=$((high_usage_count + 1))
                fi
                recent_logs=$((recent_logs + 1))
            fi
        done < "$LOG_FILE"
    fi

    echo "Entrées récentes dans le log: $recent_logs"
    echo "Entrées avec utilisation élevée: $high_usage_count"
    return $high_usage_count
}

echo "=== Surveillance CPU Système ==="
echo ""

LOAD_AVG=$(get_load_average)
LOAD_1M=$(echo "$LOAD_AVG" | cut -d, -f1)
LOAD_5M=$(echo "$LOAD_AVG" | cut -d, -f2)
LOAD_15M=$(echo "$LOAD_AVG" | cut -d, -f3)

echo "Charge système (1m, 5m, 15m): $LOAD_AVG"

CPU_USAGE=$(get_cpu_usage)
CPU_USAGE_ROUNDED=$(printf "%.1f" $CPU_USAGE)
echo "Utilisation CPU actuelle: ${CPU_USAGE_ROUNDED}%"
echo "Nombre de cœurs CPU: $(nproc)"

# bc n'est pas garanti sur une image minimale : awk fait le même calcul.
LOAD_PER_CORE=$(awk -v a="$LOAD_1M" -v b="$(nproc)" 'BEGIN{printf "%.2f", (b>0?a/b:0)}')
echo "Charge moyenne par cœur (1m): $LOAD_PER_CORE"

ALERTE=0

# Alerte si l'utilisation du CPU dépasse le seuil
if [ "$(awk -v a="$CPU_USAGE" -v b="$SEUIL_CPU" 'BEGIN{print (a>b)?1:0}')" -eq 1 ]; then
    echo "[ALERTE] Utilisation CPU > ${SEUIL_CPU}%"
    ALERTE=1
else
    echo "[OK] Utilisation CPU normale"
fi

# Alerte si la charge par cœur dépasse le nombre de cœurs
if [ "$(awk -v a="$LOAD_1M" -v b="$(nproc)" 'BEGIN{print (a>b)?1:0}')" -eq 1 ]; then
    echo "[ALERTE] Charge par cœur > 1.0"
    ALERTE=1
fi

# Vérifier l'historique
echo ""
echo "--- Historique récent ---"
HISTORY_COUNT=$(check_cpu_history)
if [ "$HISTORY_COUNT" -gt 0 ]; then
    echo "[INFO] Alertes CPU récentes détectées: $HISTORY_COUNT"
fi

# Top processus CPU
echo ""
echo "--- Top 5 processus CPU ---"
# column (util-linux) n'est pas garanti sur une image minimale : awk fait le même travail.
ps aux --sort=-%cpu | head -6 | awk '{printf "%-8s %-6s %-6s %-6s %s\n", $1, $3, $4, $8, substr($0, index($0,$11))}'

# Température si disponible
echo ""
echo "--- Informations système ---"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"

echo "Température CPU (si disponible):"
if command -v sensors >/dev/null 2>&1; then
    sensors 2>/dev/null | grep -E "Core 0|Package id" | head -3
else
    echo "  Non disponible"
fi

# Journaliser
log "Utilisation CPU: ${CPU_USAGE_ROUNDED}%, Charge: $LOAD_AVG, Cœurs: $(nproc)"

# Code de sortie
if [ "$ALERTE" -eq 1 ]; then
    if [ "$HISTORY_COUNT" -gt 2 ]; then
        exit 2  # Alerte critique
    else
        exit 1  # Alerte standard
    fi
else
    exit 0  # Tout va bien
fi
