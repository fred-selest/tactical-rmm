#!/bin/bash
# ============================================
# Script de surveillance complète Plesk
# Pour Tactical RMM - Version autonome
# ============================================

ERREUR=0

echo "========================================"
echo "  SURVEILLANCE SERVEUR PLESK"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# ============================================
# SERVICES
# ============================================
echo "=== État des services ==="
echo ""

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

    if systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
        if systemctl is-active --quiet "$service"; then
            echo "[OK] $nom ($service)"
        else
            echo "[ARRÊT] $nom ($service)"
            ERREUR=1
        fi
    fi
done

# PHP-FPM
php_fpm_count=$(pgrep -c php-fpm 2>/dev/null || echo 0)
if [ $php_fpm_count -gt 0 ]; then
    echo "[OK] PHP-FPM ($php_fpm_count processus)"
else
    echo "[ALERTE] PHP-FPM non détecté"
fi

echo ""

# ============================================
# ESPACE DISQUE
# ============================================
echo "=== Espace disque ==="
echo ""

SEUIL=80

# Disque système
utilisation=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
total=$(df -h / | awk 'NR==2 {print $2}')
used=$(df -h / | awk 'NR==2 {print $3}')

if [ $utilisation -gt $SEUIL ]; then
    echo "[ALERTE] Système: ${utilisation}% utilisé ($used / $total)"
    ERREUR=1
else
    echo "[OK] Système: ${utilisation}% utilisé ($used / $total)"
fi

# Top 5 répertoires vhosts
echo ""
echo "--- Top 5 domaines par taille ---"
du -sh /var/www/vhosts/*/ 2>/dev/null | sort -rh | head -5

echo ""

# ============================================
# CERTIFICATS SSL
# ============================================
echo "=== Certificats SSL ==="
echo ""

JOURS_ALERTE=30

# Vérification Let's Encrypt
for cert in /etc/letsencrypt/live/*/cert.pem; do
    if [ -f "$cert" ]; then
        domaine=$(basename $(dirname "$cert"))
        expiration=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
        exp_epoch=$(date -d "$expiration" +%s 2>/dev/null)
        now_epoch=$(date +%s)
        jours_restants=$(( (exp_epoch - now_epoch) / 86400 ))

        if [ $jours_restants -lt 0 ]; then
            echo "[EXPIRÉ] $domaine - Expiré depuis $((-jours_restants)) jours"
            ERREUR=1
        elif [ $jours_restants -lt $JOURS_ALERTE ]; then
            echo "[ALERTE] $domaine - Expire dans $jours_restants jours"
            ERREUR=1
        else
            echo "[OK] $domaine - $jours_restants jours restants"
        fi
    fi
done

echo ""

# ============================================
# FILE D'ATTENTE EMAIL
# ============================================
echo "=== File d'attente email ==="
echo ""

SEUIL_MAIL=100

if command -v postqueue &> /dev/null; then
    queue_count=$(postqueue -p 2>/dev/null | tail -1 | grep -oP '\d+(?= Request)')

    if [ -z "$queue_count" ]; then
        queue_count=0
    fi

    if [ $queue_count -gt $SEUIL_MAIL ]; then
        echo "[ALERTE] $queue_count emails en attente (> $SEUIL_MAIL)"
        ERREUR=1
    else
        echo "[OK] $queue_count emails en attente"
    fi

    # Emails différés
    deferred=$(find /var/spool/postfix/deferred -type f 2>/dev/null | wc -l)
    if [ $deferred -gt 50 ]; then
        echo "[ALERTE] $deferred emails différés"
        ERREUR=1
    else
        echo "[OK] $deferred emails différés"
    fi
else
    echo "Postfix non installé"
fi

echo ""

# ============================================
# SAUVEGARDES
# ============================================
echo "=== Sauvegardes ==="
echo ""

JOURS_MAX=7
BACKUP_DIR="/var/lib/psa/dumps"

if [ -d "$BACKUP_DIR" ]; then
    derniere=$(find "$BACKUP_DIR" -name "*.xml" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1)

    if [ -n "$derniere" ]; then
        timestamp=$(echo "$derniere" | cut -d' ' -f1 | cut -d. -f1)
        now=$(date +%s)
        jours=$(( (now - timestamp) / 86400 ))
        date_backup=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M")

        if [ $jours -gt $JOURS_MAX ]; then
            echo "[ALERTE] Dernière sauvegarde: $date_backup ($jours jours)"
            ERREUR=1
        else
            echo "[OK] Dernière sauvegarde: $date_backup ($jours jours)"
        fi
    else
        echo "[ALERTE] Aucune sauvegarde trouvée"
        ERREUR=1
    fi

    # Espace utilisé
    backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
    echo "Espace sauvegardes: $backup_size"
else
    echo "Répertoire de sauvegarde non trouvé"
fi

echo ""

# ============================================
# SÉCURITÉ
# ============================================
echo "=== Sécurité ==="
echo ""

# Fail2ban
if systemctl is-active --quiet fail2ban; then
    banned=$(fail2ban-client status 2>/dev/null | grep "Jail list" | cut -d: -f2 | tr ',' '\n' | while read jail; do
        jail=$(echo $jail | tr -d ' ')
        if [ -n "$jail" ]; then
            fail2ban-client status "$jail" 2>/dev/null | grep "Currently banned" | awk '{print $4}'
        fi
    done | awk '{sum+=$1} END {print sum}')
    echo "[OK] Fail2ban actif - ${banned:-0} IPs bannies"
else
    echo "[ALERTE] Fail2ban inactif"
    ERREUR=1
fi

# Tentatives de connexion
if [ -f /var/log/auth.log ]; then
    echecs=$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date +%b\ %d)" | wc -l)
elif [ -f /var/log/secure ]; then
    echecs=$(grep "Failed password" /var/log/secure 2>/dev/null | grep "$(date +%b\ %d)" | wc -l)
else
    echecs=0
fi

if [ $echecs -gt 100 ]; then
    echo "[ALERTE] $echecs tentatives de connexion échouées (24h)"
    ERREUR=1
else
    echo "[OK] $echecs tentatives de connexion échouées (24h)"
fi

echo ""

# ============================================
# DOCKER (si installé)
# ============================================
if command -v docker &> /dev/null; then
    echo "=== Docker ==="
    echo ""

    # Service Docker
    if systemctl is-active --quiet docker; then
        echo "[OK] Service Docker actif"
    else
        echo "[ERREUR] Service Docker arrêté"
        ERREUR=1
    fi

    # Conteneurs
    total=$(docker ps -a --format "{{.ID}}" 2>/dev/null | wc -l)
    running=$(docker ps --format "{{.ID}}" 2>/dev/null | wc -l)
    echo "Conteneurs: $running/$total actifs"

    # Conteneurs arrêtés
    stopped=$(docker ps -a --filter "status=exited" --format "{{.Names}}: {{.Status}}" 2>/dev/null)
    if [ -n "$stopped" ]; then
        echo ""
        echo "[INFO] Conteneurs arrêtés:"
        echo "$stopped" | head -5
    fi

    # Conteneurs unhealthy
    docker ps --format "{{.Names}}" 2>/dev/null | while read container; do
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
        if [ "$health" == "unhealthy" ]; then
            echo "[ALERTE] $container: unhealthy"
            ERREUR=1
        fi
    done

    echo ""
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
