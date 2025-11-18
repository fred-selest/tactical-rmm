#!/bin/bash
# Script complet de surveillance Synology NAS
# Combine toutes les vérifications

SCRIPT_DIR="$(dirname "$0")"
ERREUR=0

echo "========================================"
echo "  SURVEILLANCE NAS SYNOLOGY"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# Système
echo "========================================"
bash "$SCRIPT_DIR/synology_check_system.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# Disques
echo "========================================"
bash "$SCRIPT_DIR/synology_check_disks.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# RAID/Volumes
echo "========================================"
bash "$SCRIPT_DIR/synology_check_raid.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# Services
echo "========================================"
bash "$SCRIPT_DIR/synology_check_services.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# Sauvegardes
echo "========================================"
bash "$SCRIPT_DIR/synology_check_backup.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

# Sécurité
echo "========================================"
bash "$SCRIPT_DIR/synology_check_security.sh"
[ $? -ne 0 ] && ERREUR=1
echo ""

echo "========================================"
if [ $ERREUR -eq 0 ]; then
    echo "RESULTAT: Tout est OK"
else
    echo "RESULTAT: ALERTES DETECTEES"
fi
echo "========================================"

exit $ERREUR
