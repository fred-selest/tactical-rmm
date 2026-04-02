#!/bin/bash
# Surveillance Docker sur serveur Plesk
# Vérifie l'état des conteneurs, images, volumes et ressources

ERREUR=0

echo "=== Surveillance Docker ==="
echo ""

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    echo "[ERREUR] Docker n'est pas installé"
    exit 1
fi

# Vérifier si le service Docker tourne
echo "--- Service Docker ---"
if systemctl is-active --quiet docker; then
    echo "[OK] Service Docker actif"
    docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
    echo "Version: $docker_version"
else
    echo "[ERREUR] Service Docker arrêté"
    exit 1
fi

echo ""
echo "--- Conteneurs ---"

# Compter les conteneurs
total=$(docker ps -a --format "{{.ID}}" | wc -l)
running=$(docker ps --format "{{.ID}}" | wc -l)
stopped=$((total - running))

echo "Total: $total | En cours: $running | Arrêtés: $stopped"
echo ""

# Lister les conteneurs avec leur état
if [ $total -gt 0 ]; then
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20

    # Vérifier les conteneurs arrêtés ou en erreur
    echo ""
    problemes=$(docker ps -a --filter "status=exited" --filter "status=dead" --format "{{.Names}}: {{.Status}}")
    if [ -n "$problemes" ]; then
        echo "[ALERTE] Conteneurs arrêtés ou en erreur:"
        echo "$problemes"
        ERREUR=1
    fi

    # Vérifier les conteneurs qui redémarrent en boucle
    restarting=$(docker ps -a --filter "status=restarting" --format "{{.Names}}")
    if [ -n "$restarting" ]; then
        echo "[ALERTE] Conteneurs en redémarrage:"
        echo "$restarting"
        ERREUR=1
    fi
else
    echo "Aucun conteneur"
fi

echo ""
echo "--- Utilisation des ressources ---"

# Stats des conteneurs en cours
if [ $running -gt 0 ]; then
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
fi

echo ""
echo "--- Espace disque Docker ---"

# Utilisation disque
docker_info=$(docker system df 2>/dev/null)
echo "$docker_info"

# Calculer l'espace total utilisé
espace_total=$(docker system df --format "{{.Size}}" 2>/dev/null | head -1)
echo ""
echo "Espace total Docker: $espace_total"

# Vérifier les images non utilisées
images_dangling=$(docker images -f "dangling=true" -q | wc -l)
if [ $images_dangling -gt 5 ]; then
    echo ""
    echo "[INFO] $images_dangling images non utilisées (nettoyage recommandé)"
    echo "Commande: docker image prune -f"
fi

echo ""
echo "--- Volumes ---"
volumes_total=$(docker volume ls -q | wc -l)
echo "Volumes: $volumes_total"

# Volumes non utilisés
volumes_unused=$(docker volume ls -f "dangling=true" -q | wc -l)
if [ $volumes_unused -gt 0 ]; then
    echo "[INFO] $volumes_unused volumes non utilisés"
fi

echo ""
echo "--- Réseaux ---"
networks=$(docker network ls --format "{{.Name}}" | wc -l)
echo "Réseaux: $networks"

echo ""
echo "--- Santé des conteneurs ---"

# Vérifier les health checks
docker ps --format "{{.Names}}" | while read container; do
    health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
    if [ "$health" == "unhealthy" ]; then
        echo "[ALERTE] $container: unhealthy"
        ERREUR=1
    elif [ "$health" == "healthy" ]; then
        echo "[OK] $container: healthy"
    fi
done

echo ""
echo "--- Logs récents (erreurs) ---"

# Chercher les erreurs dans les logs des conteneurs actifs
docker ps --format "{{.Names}}" | while read container; do
    errors=$(docker logs --tail 50 "$container" 2>&1 | grep -i -c "error\|fatal\|exception" 2>/dev/null)
    if [ "$errors" -gt 5 ]; then
        echo "[ALERTE] $container: $errors erreurs dans les logs récents"
    fi
done

exit $ERREUR
