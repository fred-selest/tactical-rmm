#!/bin/bash
# Script complet de surveillance Plesk
# Combine toutes les vérifications

SCRIPT_DIR="$(dirname "$0")"
ERREUR=0

echo "========================================"
echo "  SURVEILLANCE SERVEUR PLESK"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# Services
echo "========================================"
bash "$SCRIPT_DIR/plesk_check_services.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# Espace disque
echo "========================================"
bash "$SCRIPT_DIR/plesk_check_disk.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# Certificats SSL
echo "========================================"
bash "$SCRIPT_DIR/plesk_check_ssl.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# File email
echo "========================================"
bash "$SCRIPT_DIR/plesk_check_mail.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# Sauvegardes
echo "========================================"
bash "$SCRIPT_DIR/plesk_check_backup.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# Sécurité
echo "========================================"
bash "$SCRIPT_DIR/plesk_check_security.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# Docker (si installé)
if command -v docker &> /dev/null; then
    echo "========================================"
    bash "$SCRIPT_DIR/plesk_check_docker.sh"
    [ $? -ne 0 ] && ERREUR=1
    echo ""
fi

echo "========================================"
if [ $ERREUR -eq 0 ]; then
    echo "RESULTAT: Tout est OK"
else
    echo "RESULTAT: ALERTES DETECTEES"
fi
echo "========================================"

exit $ERREUR
