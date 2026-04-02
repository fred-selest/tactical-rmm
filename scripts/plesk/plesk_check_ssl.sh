#!/bin/bash
# Vérification des certificats SSL Plesk
# Alerte si un certificat expire dans moins de 30 jours

JOURS_ALERTE=30
ERREUR=0

echo "=== Vérification des certificats SSL ==="
echo ""

for domaine in $(plesk bin site --list 2>/dev/null); do
    cert_file="/usr/local/psa/var/certificates/cert-${domaine}"

    if [ -f "$cert_file" ]; then
        expiration=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
        if [ -n "$expiration" ]; then
            exp_epoch=$(date -d "$expiration" +%s 2>/dev/null)
            now_epoch=$(date +%s)
            jours_restants=$(( (exp_epoch - now_epoch) / 86400 ))

            if [ $jours_restants -lt 0 ]; then
                echo "[EXPIRE] $domaine - Certificat expiré depuis $((-jours_restants)) jours"
                ERREUR=1
            elif [ $jours_restants -lt $JOURS_ALERTE ]; then
                echo "[ALERTE] $domaine - Expire dans $jours_restants jours"
                ERREUR=1
            else
                echo "[OK] $domaine - Expire dans $jours_restants jours"
            fi
        fi
    fi
done

# Vérification via Let's Encrypt
for cert in /etc/letsencrypt/live/*/cert.pem; do
    if [ -f "$cert" ]; then
        domaine=$(basename $(dirname "$cert"))
        expiration=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
        exp_epoch=$(date -d "$expiration" +%s 2>/dev/null)
        now_epoch=$(date +%s)
        jours_restants=$(( (exp_epoch - now_epoch) / 86400 ))

        if [ $jours_restants -lt $JOURS_ALERTE ]; then
            echo "[ALERTE] $domaine (LE) - Expire dans $jours_restants jours"
            ERREUR=1
        fi
    fi
done

exit $ERREUR
