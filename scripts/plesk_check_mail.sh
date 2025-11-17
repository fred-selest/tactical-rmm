#!/bin/bash
# Vérification de la file d'attente email Plesk
# Alerte si > 100 emails en attente

SEUIL=100
ERREUR=0

echo "=== File d'attente email ==="
echo ""

# Comptage de la file Postfix
if command -v postqueue &> /dev/null; then
    queue_count=$(postqueue -p 2>/dev/null | tail -1 | grep -oP '\d+(?= Request)')

    if [ -z "$queue_count" ]; then
        queue_count=0
    fi

    echo "Emails en attente: $queue_count"

    if [ $queue_count -gt $SEUIL ]; then
        echo "[ALERTE] File d'attente > $SEUIL emails"
        ERREUR=1

        echo ""
        echo "--- Détails ---"
        postqueue -p | head -20
    else
        echo "[OK] File d'attente normale"
    fi
else
    echo "Postfix non installé"
fi

echo ""
echo "--- Emails bloqués (deferred) ---"
deferred=$(find /var/spool/postfix/deferred -type f 2>/dev/null | wc -l)
echo "Emails différés: $deferred"

if [ $deferred -gt 50 ]; then
    echo "[ALERTE] Trop d'emails différés"
    ERREUR=1
fi

exit $ERREUR
