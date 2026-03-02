#!/bin/bash

###############################################################################
# Script d'installation automatique de l'intégration Dashboard Linux
# Pour Tactical RMM
#
# Usage: sudo ./install-backend.sh
###############################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}"
echo "========================================================================="
echo "  Installation de l'intégration Dashboard Linux pour Tactical RMM"
echo "========================================================================="
echo -e "${NC}"

# Vérifier les privilèges root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
    echo "Utilisez: sudo $0"
    exit 1
fi

# Détecter le chemin de Tactical RMM
echo -e "${BLUE}[1/8] Détection de Tactical RMM...${NC}"
if [ -d "/rmm/api/tacticalrmm" ]; then
    RMM_PATH="/rmm/api/tacticalrmm"
    echo -e "${GREEN}✓ Tactical RMM trouvé dans /rmm${NC}"
elif [ -d "/opt/tacticalrmm/api/tacticalrmm" ]; then
    RMM_PATH="/opt/tacticalrmm/api/tacticalrmm"
    echo -e "${GREEN}✓ Tactical RMM trouvé dans /opt/tacticalrmm${NC}"
else
    echo -e "${RED}✗ Tactical RMM non trouvé${NC}"
    echo "Veuillez installer Tactical RMM d'abord"
    exit 1
fi

# Vérifier que le dossier integration existe
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ ! -d "$SCRIPT_DIR/integration/backend" ]; then
    echo -e "${RED}✗ Dossier integration/backend non trouvé${NC}"
    echo "Assurez-vous d'être dans le dossier tactical-rmm cloné"
    exit 1
fi

# Créer le dossier linux_deployments
echo -e "${BLUE}[2/8] Création du dossier linux_deployments...${NC}"
mkdir -p "$RMM_PATH/linux_deployments"
echo -e "${GREEN}✓ Dossier créé${NC}"

# Copier les fichiers backend
echo -e "${BLUE}[3/8] Copie des fichiers backend...${NC}"
cp "$SCRIPT_DIR/integration/backend/models.py" "$RMM_PATH/linux_deployments/"
cp "$SCRIPT_DIR/integration/backend/views.py" "$RMM_PATH/linux_deployments/"
cp "$SCRIPT_DIR/integration/backend/serializers.py" "$RMM_PATH/linux_deployments/"
cp "$SCRIPT_DIR/integration/backend/urls.py" "$RMM_PATH/linux_deployments/"
cp "$SCRIPT_DIR/integration/backend/admin.py" "$RMM_PATH/linux_deployments/"
echo -e "${GREEN}✓ Fichiers copiés${NC}"

# Créer __init__.py
echo -e "${BLUE}[4/8] Création des fichiers Python...${NC}"
touch "$RMM_PATH/linux_deployments/__init__.py"

# Créer apps.py
cat > "$RMM_PATH/linux_deployments/apps.py" << 'EOF'
from django.apps import AppConfig


class LinuxDeploymentsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'linux_deployments'
    verbose_name = 'Linux Deployments'
EOF
echo -e "${GREEN}✓ Fichiers Python créés${NC}"

# Corriger les imports
echo -e "${BLUE}[5/8] Correction des imports...${NC}"
sed -i 's/from \.models import/from linux_deployments.models import/g' "$RMM_PATH/linux_deployments/views.py"
sed -i 's/from \.serializers import/from linux_deployments.serializers import/g' "$RMM_PATH/linux_deployments/views.py"
sed -i 's/from \.models import/from linux_deployments.models import/g' "$RMM_PATH/linux_deployments/serializers.py"
sed -i 's/from \.models import/from linux_deployments.models import/g' "$RMM_PATH/linux_deployments/admin.py"
sed -i 's/from \.views import/from linux_deployments.views import/g' "$RMM_PATH/linux_deployments/urls.py"
echo -e "${GREEN}✓ Imports corrigés${NC}"

# Ajuster les permissions
chown -R tactical:tactical "$RMM_PATH/linux_deployments/"

# Sauvegarder settings.py
echo -e "${BLUE}[6/8] Configuration de Django...${NC}"
cp "$RMM_PATH/tacticalrmm/settings.py" "$RMM_PATH/tacticalrmm/settings.py.backup-$(date +%Y%m%d-%H%M%S)"

# Ajouter l'app dans INSTALLED_APPS si elle n'existe pas
if ! grep -q '"linux_deployments"' "$RMM_PATH/tacticalrmm/settings.py"; then
    # Trouver la ligne avec "ee.sso" et insérer avant
    sed -i '/"ee\.sso",/i\    "linux_deployments",' "$RMM_PATH/tacticalrmm/settings.py"
    echo -e "${GREEN}✓ App ajoutée dans INSTALLED_APPS${NC}"
else
    echo -e "${YELLOW}⚠ App déjà présente dans INSTALLED_APPS${NC}"
fi

# Configurer les URLs
echo -e "${BLUE}[7/8] Configuration des URLs...${NC}"
cp "$RMM_PATH/tacticalrmm/urls.py" "$RMM_PATH/tacticalrmm/urls.py.backup-$(date +%Y%m%d-%H%M%S)"

# Vérifier si les URLs sont déjà configurées
if grep -q 'linux_deployments.urls' "$RMM_PATH/tacticalrmm/urls.py"; then
    echo -e "${YELLOW}⚠ URLs déjà configurées${NC}"
else
    # Ajouter les URLs dans la section DEMO
    sed -i '/path("api\/v3\/", include("apiv3.urls")),/a\        path("api/v3/", include("linux_deployments.urls")),' "$RMM_PATH/tacticalrmm/urls.py"
    sed -i '/path("api\/v3\/", include("apiv3.urls")),/a\        path("", include("linux_deployments.urls")),' "$RMM_PATH/tacticalrmm/urls.py"
    echo -e "${GREEN}✓ URLs configurées${NC}"
fi

# Créer et appliquer les migrations
echo -e "${BLUE}[8/8] Création et application des migrations...${NC}"
cd "$RMM_PATH"
sudo -u tactical /rmm/api/env/bin/python manage.py makemigrations linux_deployments
sudo -u tactical /rmm/api/env/bin/python manage.py migrate linux_deployments
echo -e "${GREEN}✓ Migrations appliquées${NC}"

# Vérifier la configuration
echo -e "${BLUE}Vérification de la configuration...${NC}"
sudo -u tactical /rmm/api/env/bin/python manage.py check

# Redémarrer le service
echo -e "${BLUE}Redémarrage du service Tactical RMM...${NC}"
systemctl restart rmm.service
sleep 3

# Vérifier le statut
if systemctl is-active --quiet rmm.service; then
    echo -e "${GREEN}✓ Service redémarré avec succès${NC}"
else
    echo -e "${RED}✗ Erreur lors du redémarrage du service${NC}"
    systemctl status rmm.service
    exit 1
fi

# Résumé
echo ""
echo -e "${GREEN}=========================================================================${NC}"
echo -e "${GREEN}  ✓ Installation terminée avec succès !${NC}"
echo -e "${GREEN}=========================================================================${NC}"
echo ""
echo -e "${BLUE}Endpoints API disponibles :${NC}"
echo "  - GET  /api/v3/linux-deployments/          (liste)"
echo "  - POST /api/v3/linux-deployments/create/   (créer)"
echo "  - GET  /api/v3/linux-deployments/{uuid}/   (détails)"
echo "  - GET  /api/v3/linux-deployments/stats/    (statistiques)"
echo "  - GET  /clients/{uuid}/deploy/linux/       (télécharger script - public)"
echo ""
echo -e "${BLUE}Pour créer un déploiement de test :${NC}"
echo "  sudo -u tactical /rmm/api/env/bin/python $RMM_PATH/manage.py shell"
echo ""
echo -e "${BLUE}Pour activer l'interface d'administration Django :${NC}"
echo "  1. Éditer /rmm/api/tacticalrmm/tacticalrmm/local_settings.py"
echo "  2. Ajouter: ADMIN_ENABLED = True"
echo "  3. Redémarrer: systemctl restart rmm.service"
echo "  4. Accéder à: https://votre-domaine.com/admin/"
echo ""
echo -e "${BLUE}Documentation complète :${NC}"
echo "  - integration/docs/INTEGRATION_GUIDE.md"
echo "  - integration/README.md"
echo ""
echo -e "${GREEN}Bon déploiement ! 🚀${NC}"
