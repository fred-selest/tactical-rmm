#!/bin/bash
# Vérification de l'espace disque par abonnement Plesk
# Alerte si utilisation > 80%

SEUIL=80
ERREUR=0

echo "=== Espace disque par abonnement ==="
echo ""

# Espace disque global
utilisation=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
echo "Disque système: ${utilisation}%"
if [ $utilisation -gt $SEUIL ]; then
    echo "[ALERTE] Disque système > ${SEUIL}%"
    ERREUR=1
fi
echo ""

# Par abonnement
echo "--- Abonnements ---"
plesk bin subscription --list 2>/dev/null | while read sub; do
    if [ -n "$sub" ]; then
        info=$(plesk bin subscription --info "$sub" 2>/dev/null)
        espace_utilise=$(echo "$info" | grep "Disk space used" | awk '{print $4}')
        limite=$(echo "$info" | grep "Disk space" | head -1 | awk '{print $3}')

        if [ -n "$espace_utilise" ]; then
            echo "$sub: ${espace_utilise} utilisé"
        fi
    fi
done

# Vérification des répertoires volumineux
echo ""
echo "--- Top 5 répertoires /var/www/vhosts ---"
du -sh /var/www/vhosts/*/ 2>/dev/null | sort -rh | head -5

exit $ERREUR
