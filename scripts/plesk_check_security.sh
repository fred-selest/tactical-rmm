#!/bin/bash
# Vérification de la sécurité Plesk
# Fail2ban, tentatives de connexion, mises à jour

ERREUR=0

echo "=== Vérification sécurité Plesk ==="
echo ""

# Fail2ban
echo "--- Fail2ban ---"
if systemctl is-active --quiet fail2ban; then
    echo "[OK] Fail2ban actif"

    # IPs bannies
    banned=$(fail2ban-client status 2>/dev/null | grep "Jail list" | cut -d: -f2 | tr ',' '\n' | while read jail; do
        jail=$(echo $jail | tr -d ' ')
        if [ -n "$jail" ]; then
            fail2ban-client status "$jail" 2>/dev/null | grep "Currently banned" | awk '{print $4}'
        fi
    done | awk '{sum+=$1} END {print sum}')

    echo "IPs bannies: ${banned:-0}"
else
    echo "[ALERTE] Fail2ban inactif"
    ERREUR=1
fi

echo ""
echo "--- Tentatives de connexion échouées (24h) ---"
if [ -f /var/log/auth.log ]; then
    echecs=$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date +%b\ %d)" | wc -l)
elif [ -f /var/log/secure ]; then
    echecs=$(grep "Failed password" /var/log/secure 2>/dev/null | grep "$(date +%b\ %d)" | wc -l)
else
    echecs=0
fi
echo "Tentatives échouées: $echecs"

if [ $echecs -gt 100 ]; then
    echo "[ALERTE] Nombreuses tentatives de connexion échouées"
    ERREUR=1
fi

echo ""
echo "--- Mises à jour Plesk disponibles ---"
if command -v plesk &> /dev/null; then
    updates=$(plesk installer --select-product-id plesk --show-components 2>/dev/null | grep -c "upgrade")
    echo "Composants à mettre à jour: $updates"

    if [ $updates -gt 5 ]; then
        echo "[INFO] Plusieurs mises à jour disponibles"
    fi
fi

echo ""
echo "--- Ports ouverts ---"
ss -tlnp | grep LISTEN | awk '{print $4}' | sort -u

exit $ERREUR
