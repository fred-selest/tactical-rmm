#!/bin/bash
# Vérification des services Plesk
# Retourne 1 si un service critique est arrêté

ERREUR=0

echo "=== État des services Plesk ==="
echo ""

# Liste des services à vérifier
services=(
    "psa:Plesk"
    "sw-engine:Plesk Web Server"
    "sw-cp-server:Plesk Control Panel"
    "mariadb:MariaDB"
    "mysql:MySQL"
    "nginx:Nginx"
    "apache2:Apache"
    "httpd:Apache"
    "postfix:Postfix Mail"
    "dovecot:Dovecot IMAP"
    "named:DNS BIND"
    "fail2ban:Fail2ban"
)

for service_info in "${services[@]}"; do
    service=$(echo "$service_info" | cut -d: -f1)
    nom=$(echo "$service_info" | cut -d: -f2)

    if systemctl list-unit-files | grep -q "^${service}"; then
        if systemctl is-active --quiet "$service"; then
            echo "[OK] $nom ($service)"
        else
            echo "[ARRET] $nom ($service)"
            ERREUR=1
        fi
    fi
done

echo ""
echo "--- Processus PHP-FPM ---"
php_fpm_count=$(pgrep -c php-fpm 2>/dev/null || echo 0)
if [ $php_fpm_count -gt 0 ]; then
    echo "[OK] PHP-FPM ($php_fpm_count processus)"
else
    echo "[ALERTE] PHP-FPM non détecté"
fi

exit $ERREUR
