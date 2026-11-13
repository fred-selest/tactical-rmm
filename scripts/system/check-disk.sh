#!/bin/bash
# Surveillance avancée du disque
# Alerte si utilisation > 85% ou inodes > 90%

SEUIL_ESPACE=85
SEUIL_INODES=90
LOG_FILE="/var/log/tacticalrmm-disk-check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction pour vérifier un système de fichiers spécifique
check_filesystem() {
    local filesystem="$1"
    local mount_point="$2"
    
    # Utilisation espace
    local usage=$(df -h "$mount_point" | awk 'NR==2 {print $5}' | tr -d '%')
    # Utilisation inodes
    local inodes=$(df -i "$mount_point" | awk 'NR==2 {print $5}' | tr -d '%')
    
    echo "Système de fichiers: $filesystem"
    echo "Point de montage: $mount_point"
    echo "Utilisation espace: ${usage}%"
    echo "Utilisation inodes: ${inodes}%"
    
    local alert=0
    
    if [ "$usage" -gt "$SEUIL_ESPACE" ]; then
        echo "[ALERTE] Espace disque > ${SEUIL_ESPACE}%"
        alert=1
    fi
    
    if [ "$inodes" -gt "$SEUIL_INODES" ]; then
        echo "[ALERTE] Inodes disque > ${SEUIL_INODES}%"
        alert=1
    fi
    
    # Détails du système de fichiers
    echo "Détails:"
    df -h "$mount_point" | head -2
    df -i "$mount_point" | head -2
    echo ""
    
    return $alert
}

echo "=== Surveillance Disque Système ==="
echo ""

ALERTE_GLOBALE=0

# Vérifier tous les systèmes de fichiers locaux
echo "--- Systèmes de fichiers locaux ---"
while IFS= read -r line; do
    if [ -n "$line" ]; then
        filesystem=$(echo "$line" | awk '{print $1}')
        mount_point=$(echo "$line" | awk '{print $6}')
        
        # Ignorer les systèmes de fichiers temporaires et virtuels
        if [[ "$mount_point" != /proc* && "$mount_point" != /sys* && "$mount_point" != /dev* && "$mount_point" != /run* ]]; then
            if check_filesystem "$filesystem" "$mount_point"; then
                ALERTE_GLOBALE=1
            fi
        fi
    fi
done < <(df -T | grep -E "ext4|ext3|xfs|btrfs|zfs" | tail -n +2)

# Top 5 des répertoires les plus volumineux
echo "--- Top 5 répertoires volumineux (/) ---"
du -sh /* 2>/dev/null | sort -rh | head -5

echo ""
echo "--- Top 5 répertoires volumineux (/var) ---"
if [ -d "/var" ]; then
    du -sh /var/* 2>/dev/null | sort -rh | head -5
fi

echo ""
echo "--- Top 5 répertoires volumineux (/home) ---"
if [ -d "/home" ]; then
    du -sh /home/* 2>/dev/null | sort -rh | head -5
fi

# Informations sur les E/S disque
echo ""
echo "--- Statistiques E/S disque (dernières 5 secondes) ---"
if command -v iostat &> /dev/null; then
    iostat -x 1 2 | tail -n +7 | head -10
else
    echo "iostat non disponible (installez sysstat)"
fi

# Journaliser le statut global
if [ $ALERTE_GLOBALE -eq 1 ]; then
    log "ALERTE: Problèmes d'espace disque détectés"
else
    log "OK: Espace disque dans les limites normales"
fi

# Déterminer le code de sortie
if [ $ALERTE_GLOBALE -eq 1 ]; then
    exit 1  # Alerte standard
else
    exit 0  # Tout va bien
fi