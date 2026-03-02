#!/bin/bash

#############################################
# Installation du système de mise à jour
# automatique pour Tactical RMM
#############################################

set -e

# Vérifier les droits root
if [ "$EUID" -ne 0 ]; then
    echo "ERREUR: Ce script doit être exécuté en tant que root"
    exit 1
fi

echo "=========================================="
echo "Installation du système de mise à jour"
echo "automatique Tactical RMM"
echo "=========================================="
echo ""

# Créer les répertoires nécessaires
echo "[1/5] Création des répertoires..."
mkdir -p /etc/tactical-rmm
mkdir -p /var/log

# Copier le script de mise à jour
echo "[2/5] Installation du script de mise à jour..."
cp tactical-agent-updater.sh /usr/local/bin/tactical-agent-updater.sh
chmod +x /usr/local/bin/tactical-agent-updater.sh

# Copier la configuration
echo "[3/5] Installation de la configuration..."
if [ ! -f /etc/tactical-rmm/auto-update.conf ]; then
    cp auto-update.conf /etc/tactical-rmm/auto-update.conf
    echo "  Configuration créée: /etc/tactical-rmm/auto-update.conf"
    echo "  IMPORTANT: Éditez ce fichier pour personnaliser la configuration !"
else
    echo "  Configuration existante conservée: /etc/tactical-rmm/auto-update.conf"
fi

# Installer les fichiers systemd
echo "[4/5] Installation des services systemd..."
cp tactical-agent-updater.service /etc/systemd/system/
cp tactical-agent-updater.timer /etc/systemd/system/

# Recharger systemd et activer le timer
echo "[5/5] Activation du timer systemd..."
systemctl daemon-reload
systemctl enable tactical-agent-updater.timer
systemctl start tactical-agent-updater.timer

echo ""
echo "=========================================="
echo "Installation terminée avec succès !"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  - Fichier de config: /etc/tactical-rmm/auto-update.conf"
echo "  - Script: /usr/local/bin/tactical-agent-updater.sh"
echo "  - Logs: /var/log/tactical-rmm-updater.log"
echo ""
echo "Le timer systemd vérifiera les mises à jour:"
echo "  - Tous les dimanches à 03:00"
echo "  - Avec un décalage aléatoire de 0-30 minutes"
echo ""
echo "Commandes utiles:"
echo "  - État du timer: systemctl status tactical-agent-updater.timer"
echo "  - Logs: journalctl -u tactical-agent-updater.service"
echo "  - Test manuel: /usr/local/bin/tactical-agent-updater.sh"
echo "  - Désactiver: systemctl disable tactical-agent-updater.timer"
echo ""
echo "IMPORTANT:"
echo "  Éditez /etc/tactical-rmm/auto-update.conf pour configurer:"
echo "    - Notifications par email ou webhook"
echo "    - Fenêtre de mise à jour"
echo "    - Activation/désactivation"
echo ""
