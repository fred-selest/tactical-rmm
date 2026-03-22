#!/bin/bash
# Surveillance avancée du réseau
# Alerte si problèmes de connectivité ou saturation bande passante

SEUIL_PING=100  # ms
TIMEOUT_PING=5
LOG_FILE="/var/log/tacticalrmm-network-check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction pour obtenir les interfaces réseau
get_network_interfaces() {
    ip -br addr show | grep -v LOOPBACK | awk '{print $1}'
}

# Fonction pour tester la connectivité
test_connectivity() {
    local target="$1"
    local timeout="$2"
    
    if ping -c 1 -W "$timeout" "$target" > /dev/null 2>&1; then
        local ping_time=$(ping -c 1 -W "$timeout" "$target" | grep "time=" | awk -F'time=' '{print $2}' | cut -d' ' -f1)
        echo "$ping_time"
        return 0
    else
        echo "0"
        return 1
    fi
}

# Fonction pour obtenir les statistiques réseau
get_network_stats() {
    echo "=== Statistiques réseau ==="
    ip -s link show
}

echo "=== Surveillance Réseau Système ==="
echo ""

ALERTE=0

# Interfaces réseau disponibles
echo "--- Interfaces réseau ---"
INTERFACES=$(get_network_interfaces)
if [ -n "$INTERFACES" ]; then
    for iface in $INTERFACES; do
        echo "Interface: $iface"
        ip addr show "$iface" | grep -E "(inet|ether)" | grep -v "inet6"
    done
else
    echo "Aucune interface réseau trouvée"
    ALERTE=1
fi

echo ""

# Test de connectivité DNS
echo "--- Tests de connectivité ---"
DNS_SERVERS="8.8.8.8 1.1.1.1"

for dns in $DNS_SERVERS; do
    echo "Test DNS ($dns):"
    if test_connectivity "$dns" "$TIMEOUT_PING"; then
        PING_TIME=$(test_connectivity "$dns" "$TIMEOUT_PING")
        if (( $(echo "$PING_TIME > $SEUIL_PING" | bc -l) )); then
            echo "[ALERTE] Latence élevée vers $dns: ${PING_TIME}ms"
            ALERTE=1
        else
            echo "  OK - ${PING_TIME}ms"
        fi
    else
        echo "[ALERTE] Pas de connectivité vers $dns"
        ALERTE=1
    fi
done

# Test de résolution DNS
echo ""
echo "Test résolution DNS:"
if nslookup google.com > /dev/null 2>&1; then
    echo "  OK - Résolution DNS fonctionnelle"
else
    echo "[ALERTE] Problème de résolution DNS"
    ALERTE=1
fi

# Statistiques réseau
echo ""
echo "--- Statistiques réseau ---"
get_network_stats

# Connexions établies
echo ""
echo "--- Connexions établies (top 10) ---"
if command -v ss &> /dev/null; then
    ss -tuln | head -11
elif command -v netstat &> /dev/null; then
    netstat -tuln | head -11
else
    echo "ss/netstat non disponible"
fi

# Processus utilisant le plus de connexions
echo ""
echo "--- Top 5 processus par connexions ---"
if command -v lsof &> /dev/null; then
    lsof -i | awk 'NR>1 {print $1}' | sort | uniq -c | sort -nr | head -5
else
    echo "lsof non disponible (installez lsof)"
fi

# Journaliser le statut
if [ $ALERTE -eq 1 ]; then
    log "ALERTE: Problèmes réseau détectés"
else
    log "OK: Réseau fonctionnel"
fi

# Déterminer le code de sortie
if [ $ALERTE -eq 1 ]; then
    exit 1  # Alerte standard
else
    exit 0  # Tout va bien
fi