#!/bin/bash
# Surveillance Docker
# Alerte si conteneurs arrêtés, images orphelines, ou problèmes de ressources

SEUIL_CONTENEURS_STOPPED=0  # Alerte si > 0 conteneurs arrêtés
SEUIL_ESPACE_DOCKER=85      # Alerte si utilisation espace Docker > 85%
LOG_FILE="/var/log/tacticalrmm-docker-check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérifier si Docker est installé et fonctionnel
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        echo "[ERREUR] Docker n'est pas installé"
        return 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        echo "[ERREUR] Docker n'est pas accessible (problème de permissions ou service arrêté)"
        return 1
    fi
    
    return 0
}

# Obtenir les statistiques Docker
get_docker_stats() {
    echo "=== Statistiques Docker ==="
    
    # Version Docker
    echo "Version Docker: $(docker version --format '{{.Server.Version}}')"
    
    # Informations système
    docker info --format 'Nombre de conteneurs: {{.Containers}}
Conteneurs en cours: {{.ContainersRunning}}
Conteneurs arrêtés: {{.ContainersStopped}}
Conteneurs suspendus: {{.ContainersPaused}}
Images: {{.Images}}'
    
    echo ""
}

# Vérifier l'état des conteneurs
check_containers() {
    echo "--- État des conteneurs ---"
    
    # Compter les conteneurs par état
    TOTAL=$(docker ps -a --format '{{.Status}}' | wc -l)
    RUNNING=$(docker ps --format '{{.Status}}' | wc -l)
    STOPPED=$(docker ps -a --filter "status=exited" --format '{{.Status}}' | wc -l)
    DEAD=$(docker ps -a --filter "status=dead" --format '{{.Status}}' | wc -l)
    
    echo "Total: $TOTAL"
    echo "En cours: $RUNNING"
    echo "Arrêtés: $STOPPED"
    echo "Morts: $DEAD"
    
    # Lister les conteneurs arrêtés
    if [ "$STOPPED" -gt "$SEUIL_CONTENEURS_STOPPED" ]; then
        echo "[ALERTE] Conteneurs arrêtés détectés:"
        docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    fi
    
    if [ "$DEAD" -gt 0 ]; then
        echo "[ALERTE CRITIQUE] Conteneurs morts détectés:"
        docker ps -a --filter "status=dead" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    fi
    
    # Retourner le nombre de problèmes
    echo $((STOPPED + DEAD))
}

# Vérifier l'utilisation de l'espace disque Docker
check_docker_disk_usage() {
    echo ""
    echo "--- Utilisation espace disque Docker ---"
    
    if docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}" > /dev/null 2>&1; then
        docker system df
        
        # Calculer le pourcentage d'espace utilisé
        TOTAL_SIZE=$(docker system df --format '{{json .}}' | jq -r '.[0].Size' 2>/dev/null || echo "0")
        RECLAIMABLE=$(docker system df --format '{{json .}}' | jq -r '.[0].Reclaimable' 2>/dev/null || echo "0")
        
        if [ "$TOTAL_SIZE" != "0" ] && command -v jq &> /dev/null; then
            # Convertir les tailles en octets pour calculer le pourcentage
            TOTAL_BYTES=$(echo "$TOTAL_SIZE" | sed 's/[A-Z]//g')
            RECLAIMABLE_BYTES=$(echo "$RECLAIMABLE" | sed 's/[A-Z]//g')
            
            if [ -n "$TOTAL_BYTES" ] && [ "$TOTAL_BYTES" -gt 0 ]; then
                USAGE_PERCENT=$((100 - (RECLAIMABLE_BYTES * 100 / TOTAL_BYTES)))
                if [ "$USAGE_PERCENT" -gt "$SEUIL_ESPACE_DOCKER" ]; then
                    echo "[ALERTE] Utilisation espace Docker > ${SEUIL_ESPACE_DOCKER}% ($USAGE_PERCENT%)"
                    return 1
                fi
            fi
        fi
    else
        echo "docker system df non disponible"
    fi
    
    return 0
}

# Vérifier les images orphelines
check_dangling_images() {
    echo ""
    echo "--- Images orphelines ---"
    
    DANGLING_IMAGES=$(docker images --filter "dangling=true" -q | wc -l)
    if [ "$DANGLING_IMAGES" -gt 0 ]; then
        echo "[ALERTE] $DANGLING_IMAGES images orphelines détectées"
        docker images --filter "dangling=true"
        return 1
    else
        echo "Aucune image orpheline"
    fi
    
    return 0
}

# Vérifier les volumes orphelines
check_dangling_volumes() {
    echo ""
    echo "--- Volumes orphelines ---"
    
    DANGLING_VOLUMES=$(docker volume ls --filter "dangling=true" -q | wc -l)
    if [ "$DANGLING_VOLUMES" -gt 0 ]; then
        echo "[ALERTE] $DANGLING_VOLUMES volumes orphelines détectés"
        docker volume ls --filter "dangling=true"
        return 1
    else
        echo "Aucun volume orphelin"
    fi
    
    return 0
}

# Vérifier les réseaux orphelins
check_dangling_networks() {
    echo ""
    echo "--- Réseaux orphelins ---"
    
    # Les réseaux par défaut ne sont pas considérés comme orphelins
    TOTAL_NETWORKS=$(docker network ls -q | wc -l)
    DEFAULT_NETWORKS=$(docker network ls --filter "name=bridge" --filter "name=host" --filter "name=none" -q | wc -l)
    CUSTOM_NETWORKS=$((TOTAL_NETWORKS - DEFAULT_NETWORKS))
    
    if [ "$CUSTOM_NETWORKS" -gt 0 ]; then
        echo "$CUSTOM_NETWORKS réseaux personnalisés détectés"
        docker network ls --filter "name!=bridge" --filter "name!=host" --filter "name!=none"
    else
        echo "Aucun réseau personnalisé"
    fi
    
    return 0
}

# Top conteneurs par utilisation CPU/mémoire
check_container_resources() {
    echo ""
    echo "--- Top conteneurs par ressources ---"
    
    if docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.MemUsage}}\t{{.NetIO}}" > /dev/null 2>&1; then
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -11
    else
        echo "docker stats non disponible"
    fi
}

echo "=== Surveillance Docker ==="
echo ""

# Vérification initiale
if ! check_docker_installed; then
    exit 1
fi

get_docker_stats

ALERTE=0

# Vérifier les conteneurs
PROBLEM_CONTAINERS=$(check_containers)
if [ "$PROBLEM_CONTAINERS" -gt 0 ]; then
    ALERTE=1
fi

# Vérifier l'espace disque
if ! check_docker_disk_usage; then
    ALERTE=1
fi

# Vérifier les éléments orphelins
if ! check_dangling_images; then
    ALERTE=1
fi

if ! check_dangling_volumes; then
    ALERTE=1
fi

check_dangling_networks

# Vérifier les ressources
check_container_resources

# Journaliser le résultat
if [ $ALERTE -eq 1 ]; then
    log "ALERTE: Problèmes Docker détectés"
else
    log "OK: Docker fonctionne normalement"
fi

exit $ALERTE