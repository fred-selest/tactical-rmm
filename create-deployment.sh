#!/bin/bash

###############################################################################
# Script helper pour créer un déploiement Linux rapidement
# Usage: ./create-deployment.sh
###############################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}"
echo "========================================================================="
echo "  Création d'un déploiement d'agent Linux"
echo "========================================================================="
echo -e "${NC}"

# Détection du chemin RMM
if [ -d "/rmm/api/tacticalrmm" ]; then
    RMM_PATH="/rmm/api/tacticalrmm"
elif [ -d "/opt/tacticalrmm/api/tacticalrmm" ]; then
    RMM_PATH="/opt/tacticalrmm/api/tacticalrmm"
else
    echo -e "${RED}✗ Tactical RMM non trouvé${NC}"
    exit 1
fi

# Questions interactives
echo -e "${BLUE}Informations du déploiement:${NC}"
echo ""

read -p "Nom du client: " CLIENT_NAME
read -p "ID du client: " CLIENT_ID
read -p "Nom du site: " SITE_NAME
read -p "ID du site: " SITE_ID

echo ""
echo -e "${BLUE}Configuration de l'agent:${NC}"
echo ""

PS3="Type d'agent: "
select AGENT_TYPE in "server" "workstation"; do
    break
done

PS3="Architecture: "
select ARCH in "amd64" "arm64" "i386"; do
    break
done

read -p "Expiration (jours) [30]: " EXPIRES_DAYS
EXPIRES_DAYS=${EXPIRES_DAYS:-30}

read -p "URL API (ex: https://api.selest.info): " API_URL
read -p "URL Mesh (ex: https://mesh.selest.info/meshagents?id=...): " MESH_URL
read -p "Auth Key: " AUTH_KEY

# Confirmation
echo ""
echo -e "${YELLOW}=========================================================================${NC}"
echo -e "${YELLOW}Récapitulatif:${NC}"
echo "  Client: $CLIENT_NAME (ID: $CLIENT_ID)"
echo "  Site: $SITE_NAME (ID: $SITE_ID)"
echo "  Type: $AGENT_TYPE"
echo "  Architecture: $ARCH"
echo "  Expiration: $EXPIRES_DAYS jours"
echo -e "${YELLOW}=========================================================================${NC}"
echo ""

read -p "Confirmer la création ? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${RED}Annulé${NC}"
    exit 0
fi

# Créer le déploiement
echo ""
echo -e "${BLUE}Création du déploiement...${NC}"

RESULT=$(sudo -u tactical /rmm/api/env/bin/python "$RMM_PATH/manage.py" shell << PYTHON
from linux_deployments.models import LinuxDeployment
from datetime import timedelta
from django.utils import timezone

deployment = LinuxDeployment.objects.create(
    client_id=$CLIENT_ID,
    client_name="$CLIENT_NAME",
    site_id=$SITE_ID,
    site_name="$SITE_NAME",
    agent_type="$AGENT_TYPE",
    arch="$ARCH",
    api_url="$API_URL",
    mesh_url="$MESH_URL",
    auth_key="$AUTH_KEY",
    enable_ping=True,
    install_mesh=True,
    expires_at=timezone.now() + timedelta(days=$EXPIRES_DAYS),
    created_by="script"
)

print(f"UUID:{deployment.uuid}")
print(f"URL:{API_URL}/clients/{deployment.uuid}/deploy/linux/")
PYTHON
)

# Extraire UUID et URL
UUID=$(echo "$RESULT" | grep "UUID:" | cut -d':' -f2)
URL=$(echo "$RESULT" | grep "URL:" | cut -d':' -f2-)

if [ -z "$UUID" ]; then
    echo -e "${RED}✗ Erreur lors de la création${NC}"
    echo "$RESULT"
    exit 1
fi

# Succès
echo ""
echo -e "${GREEN}=========================================================================${NC}"
echo -e "${GREEN}✓ Déploiement créé avec succès !${NC}"
echo -e "${GREEN}=========================================================================${NC}"
echo ""
echo -e "${BLUE}UUID:${NC} $UUID"
echo ""
echo -e "${BLUE}URL de téléchargement:${NC}"
echo "$URL"
echo ""
echo -e "${BLUE}Commande d'installation (à exécuter sur le serveur Linux cible):${NC}"
echo ""
echo -e "${GREEN}wget $URL -O install.sh${NC}"
echo -e "${GREEN}chmod +x install.sh${NC}"
echo -e "${GREEN}sudo ./install.sh${NC}"
echo ""
echo -e "${YELLOW}Ou en une seule ligne:${NC}"
echo ""
echo -e "${GREEN}curl -L $URL | sudo bash${NC}"
echo ""
echo -e "${GREEN}=========================================================================${NC}"
