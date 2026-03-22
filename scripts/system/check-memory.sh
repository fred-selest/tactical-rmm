#!/bin/bash
# Surveillance avancée de la mémoire
# Alerte si utilisation > 85% ou swap > 50%

SEUIL_MEMOIRE=85
SEUIL_SWAP=50
LOG_FILE="/var/log/tacticalrmm-memory-check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction pour obtenir les statistiques mémoire
get_memory_stats() {
    # Utiliser free pour obtenir les statistiques détaillées
    free -m | awk 'NR==2{printf "%.1f", $3*100/$2 }'
}

# Fonction pour obtenir les statistiques swap
get_swap_stats() {
    free -m | awk 'NR==3{if($2>0) printf "%.1f", $3*100/$2; else print "0.0"}'
}

# Fonction pour obtenir la mémoire disponible en Go
get_memory_available_gb() {
    free -g | awk 'NR==2{print $7}'
}

echo "=== Surveillance Mémoire Système ==="
echo ""

# Obtenir les statistiques actuelles
MEM_USAGE=$(get_memory_stats)
SWAP_USAGE=$(get_swap_stats)
MEM_AVAILABLE_GB=$(get_memory_available_gb)

# Mémoire totale
MEM_TOTAL_GB=$(free -g | awk 'NR==2{print $2}')

echo "Utilisation mémoire: ${MEM_USAGE}%"
echo "Utilisation swap: ${SWAP_USAGE}%"
echo "Mémoire disponible: ${MEM_AVAILABLE_GB} Go / ${MEM_TOTAL_GB} Go total"

# Vérifier les seuils
ALERTE=0

if (( $(echo "$MEM_USAGE > $SEUIL_MEMOIRE" | bc -l) )); then
    echo "[ALERTE] Utilisation mémoire > ${SEUIL_MEMOIRE}%"
    ALERTE=1
fi

if (( $(echo "$SWAP_USAGE > $SEUIL_SWAP" | bc -l) )); then
    echo "[ALERTE] Utilisation swap > ${SEUIL_SWAP}%"
    ALERTE=1
fi

# Détails mémoire
echo ""
echo "--- Détails mémoire (Mo) ---"
free -m

# Top 5 des processus consommateurs de mémoire
echo ""
echo "--- Top 5 processus mémoire ---"
ps aux --sort=-%mem | head -6 | column -t

# Informations sur la pression mémoire (si disponible)
echo ""
echo "--- Pression mémoire (kernel 4.15+) ---"
if [ -f "/proc/pressure/memory" ]; then
    echo "Pression mémoire:"
    cat /proc/pressure/memory | grep -E "some|full" | head -2
else
    echo "Non disponible (nécessite kernel 4.15+)"
fi

# Journaliser l'utilisation actuelle
log "Mémoire: ${MEM_USAGE}%, Swap: ${SWAP_USAGE}%, Disponible: ${MEM_AVAILABLE_GB}Go"

# Déterminer le code de sortie
if [ $ALERTE -eq 1 ]; then
    exit 1  # Alerte standard
else
    exit 0  # Tout va bien
fi