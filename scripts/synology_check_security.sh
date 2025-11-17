#!/bin/bash
# Surveillance sécurité Synology NAS
# Connexions, blocages IP, mises à jour

ERREUR=0

echo "=== Sécurité Synology ==="
echo ""

# Vérifier si on est sur un Synology
if [ ! -f /etc/synoinfo.conf ]; then
    echo "[ERREUR] Ce script doit être exécuté sur un NAS Synology"
    exit 1
fi

echo "--- Blocage automatique ---"

# IPs bloquées via Synology firewall
if [ -f /etc/synoautoblock.db ]; then
    blocked=$(sqlite3 /etc/synoautoblock.db "SELECT COUNT(*) FROM AutoBlockIP;" 2>/dev/null)
    echo "IPs bloquées: ${blocked:-0}"

    # Dernières IPs bloquées
    echo ""
    echo "5 dernières IPs bloquées:"
    sqlite3 /etc/synoautoblock.db "SELECT IP, Deny FROM AutoBlockIP ORDER BY Deny DESC LIMIT 5;" 2>/dev/null
else
    echo "Base de blocage non trouvée"
fi

echo ""
echo "--- Tentatives de connexion (24h) ---"

# Logs de connexion
if [ -f /var/log/synolog/.SYNOLOGLOGIN.log ]; then
    failed=$(grep "$(date +%Y/%m/%d)" /var/log/synolog/.SYNOLOGLOGIN.log 2>/dev/null | grep -c "failed")
    success=$(grep "$(date +%Y/%m/%d)" /var/log/synolog/.SYNOLOGLOGIN.log 2>/dev/null | grep -c "succeeded")

    echo "Connexions réussies: $success"
    echo "Connexions échouées: $failed"

    if [ "$failed" -gt 50 ]; then
        echo "[ALERTE] Nombreuses tentatives échouées"
        ERREUR=1
    fi
fi

echo ""
echo "--- Comptes utilisateurs ---"

# Compter les utilisateurs
users=$(cat /etc/passwd | grep "/var/services/homes" | wc -l)
echo "Utilisateurs: $users"

# Utilisateurs admin
admins=$(grep "^administrators:" /etc/group | cut -d: -f4 | tr ',' '\n' | wc -l)
echo "Administrateurs: $admins"

echo ""
echo "--- Mises à jour DSM ---"

# Vérifier les mises à jour disponibles
if command -v synoupgrade &> /dev/null; then
    update_check=$(synoupgrade --check 2>/dev/null)
    if echo "$update_check" | grep -qi "available"; then
        echo "[INFO] Mise à jour DSM disponible"
        echo "$update_check"
    else
        echo "[OK] DSM à jour"
    fi
else
    # Alternative via fichier
    current=$(cat /etc.defaults/VERSION 2>/dev/null | grep "productversion" | cut -d'"' -f2)
    echo "Version actuelle: $current"
fi

echo ""
echo "--- Certificats SSL ---"

# Vérifier les certificats
cert_dir="/usr/syno/etc/certificate/_archive"
if [ -d "$cert_dir" ]; then
    for cert_folder in "$cert_dir"/*; do
        if [ -d "$cert_folder" ]; then
            cert_file="$cert_folder/cert.pem"
            if [ -f "$cert_file" ]; then
                expiry=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
                if [ -n "$expiry" ]; then
                    exp_epoch=$(date -d "$expiry" +%s 2>/dev/null)
                    now_epoch=$(date +%s)
                    days_left=$(( (exp_epoch - now_epoch) / 86400 ))

                    cert_name=$(basename "$cert_folder")
                    if [ $days_left -lt 30 ]; then
                        echo "[ALERTE] Certificat $cert_name expire dans $days_left jours"
                        ERREUR=1
                    else
                        echo "[OK] Certificat $cert_name - $days_left jours restants"
                    fi
                fi
            fi
        fi
    done
else
    echo "Aucun certificat personnalisé"
fi

echo ""
echo "--- Ports ouverts ---"

# Ports en écoute
netstat -tlnp 2>/dev/null | grep LISTEN | awk '{print $4}' | rev | cut -d: -f1 | rev | sort -nu | head -20

exit $ERREUR
