#!/bin/bash
# Surveillance des stacks Docker Compose sur Plesk
# Vérifie l'état des services définis dans docker-compose

ERREUR=0

echo "=== Surveillance Docker Compose ==="
echo ""

# Vérifier si docker-compose est installé
if command -v docker-compose &> /dev/null; then
    compose_cmd="docker-compose"
elif docker compose version &> /dev/null; then
    compose_cmd="docker compose"
else
    echo "[ERREUR] Docker Compose n'est pas installé"
    exit 1
fi

echo "Commande: $compose_cmd"
echo ""

# Répertoires typiques pour les projets Docker Compose
SEARCH_DIRS=(
    "/var/www/vhosts"
    "/opt"
    "/root"
    "/home"
)

echo "--- Projets Docker Compose détectés ---"
echo ""

projects_found=0

for dir in "${SEARCH_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        # Chercher les fichiers docker-compose
        while IFS= read -r -d '' compose_file; do
            project_dir=$(dirname "$compose_file")
            project_name=$(basename "$project_dir")

            echo "=== Projet: $project_name ==="
            echo "Chemin: $project_dir"

            cd "$project_dir" 2>/dev/null || continue

            # Vérifier l'état des services
            if [ "$compose_cmd" == "docker-compose" ]; then
                status=$($compose_cmd ps 2>/dev/null)
            else
                status=$($compose_cmd ps 2>/dev/null)
            fi

            if [ -n "$status" ]; then
                echo "$status"

                # Compter les services down
                down_count=$(echo "$status" | grep -c -E "Exit|exited|stopped" || true)
                if [ "$down_count" -gt 0 ]; then
                    echo "[ALERTE] $down_count service(s) arrêté(s)"
                    ERREUR=1
                fi
            else
                echo "Aucun service en cours"
            fi

            echo ""
            ((projects_found++))

        done < <(find "$dir" -maxdepth 4 -name "docker-compose.yml" -o -name "docker-compose.yaml" -print0 2>/dev/null)
    fi
done

if [ $projects_found -eq 0 ]; then
    echo "Aucun projet Docker Compose trouvé"
fi

echo "--- Résumé ---"
echo "Projets trouvés: $projects_found"

exit $ERREUR
