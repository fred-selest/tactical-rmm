#!/bin/bash
# Surveillance des services Synology NAS
# Paquets installés et services actifs

ERREUR=0

echo "=== État des services Synology ==="
echo ""

# Vérifier si on est sur un Synology
if [ ! -f /etc/synoinfo.conf ]; then
    echo "[ERREUR] Ce script doit être exécuté sur un NAS Synology"
    exit 1
fi

echo "--- Services système ---"

# Services critiques à vérifier
services=(
    "nginx:Serveur Web"
    "sshd:SSH"
    "smbd:Samba/CIFS"
    "nmbd:NetBIOS"
    "avahi-daemon:Avahi/Bonjour"
    "synoscgi:Synology CGI"
    "synoindexd:Indexation"
    "synologand:Synology Land"
)

for service_info in "${services[@]}"; do
    service=$(echo "$service_info" | cut -d: -f1)
    nom=$(echo "$service_info" | cut -d: -f2)

    if pgrep -x "$service" > /dev/null; then
        echo "[OK] $nom ($service)"
    else
        # Certains services sont optionnels
        if [ "$service" == "sshd" ] || [ "$service" == "smbd" ]; then
            echo "[INFO] $nom ($service) - non actif"
        fi
    fi
done

echo ""
echo "--- Paquets installés ---"

# Liste des paquets via synopkg
if command -v synopkg &> /dev/null; then
    synopkg list --name 2>/dev/null | while read pkg; do
        if [ -n "$pkg" ]; then
            status=$(synopkg status "$pkg" 2>/dev/null)
            if echo "$status" | grep -q "started"; then
                echo "[OK] $pkg: actif"
            elif echo "$status" | grep -q "stopped"; then
                echo "[ARRET] $pkg: arrêté"
            fi
        fi
    done
else
    echo "Commande synopkg non disponible"
fi

echo ""
echo "--- Services Docker (si installé) ---"

if command -v docker &> /dev/null; then
    running=$(docker ps -q | wc -l)
    total=$(docker ps -aq | wc -l)
    echo "Conteneurs: $running/$total en cours"

    # Lister les conteneurs arrêtés
    stopped=$(docker ps -a --filter "status=exited" --format "{{.Names}}" | head -5)
    if [ -n "$stopped" ]; then
        echo ""
        echo "[INFO] Conteneurs arrêtés:"
        echo "$stopped"
    fi
else
    echo "Docker non installé"
fi

echo ""
echo "--- Connexions réseau ---"

# Connexions SMB/CIFS
smb_conn=$(smbstatus -b 2>/dev/null | grep -c "^[0-9]" || echo "0")
echo "Connexions SMB: $smb_conn"

# Connexions AFP (si actif)
if pgrep -x "netatalk" > /dev/null; then
    afp_conn=$(echo "asip-status localhost" | nc localhost 548 2>/dev/null | grep -c "session" || echo "0")
    echo "Connexions AFP: $afp_conn"
fi

exit $ERREUR
