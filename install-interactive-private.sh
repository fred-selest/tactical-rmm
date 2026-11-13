#!/bin/bash

###############################################################################
# Script d'installation INTERACTIF de l'intégration Dashboard Linux
# Pour Tactical RMM - rmm.selest.info
#
# Usage: sudo ./install-interactive.sh
###############################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Fonction pour afficher un titre
print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Fonction pour afficher une étape
print_step() {
    echo -e "${BLUE}${BOLD}[$1] $2${NC}"
}

# Fonction pour afficher un succès
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Fonction pour afficher un avertissement
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Fonction pour afficher une erreur
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Fonction pour afficher une info
print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Fonction pour demander confirmation
ask_confirmation() {
    echo -e "${YELLOW}$1${NC}"
    read -p "Continuer ? (o/N) : " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
        echo -e "${RED}Installation annulée.${NC}"
        exit 1
    fi
}

# Banner
clear
echo -e "${MAGENTA}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🚀  TACTICAL RMM - INSTALLATION DASHBOARD LINUX  🚀         ║
║                                                               ║
║   Installation interactive pour :                            ║
║   📍 rmm.selest.info                                          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Cette installation va configurer l'interface de déploiement d'agents Linux"
print_info "similaire à celle qui existe pour Windows."
echo ""

# Vérifier les privilèges root
if [ "$EUID" -ne 0 ]; then
    print_error "Ce script doit être exécuté en tant que root"
    echo "Utilisez: sudo $0"
    exit 1
fi

print_success "Privilèges root confirmés"
echo ""

# Demander confirmation avant de commencer
ask_confirmation "Prêt à commencer l'installation ?"

# ============================================================================
# ÉTAPE 1 : Vérifications préliminaires
# ============================================================================
print_header "ÉTAPE 1/9 - Vérifications préliminaires"

print_step "1.1" "Détection de Tactical RMM..."
if [ -d "/rmm/api/tacticalrmm" ]; then
    RMM_PATH="/rmm/api/tacticalrmm"
    print_success "Tactical RMM trouvé : $RMM_PATH"
elif [ -d "/opt/tacticalrmm/api/tacticalrmm" ]; then
    RMM_PATH="/opt/tacticalrmm/api/tacticalrmm"
    print_success "Tactical RMM trouvé : $RMM_PATH"
else
    print_error "Tactical RMM non trouvé"
    echo "Chemins vérifiés :"
    echo "  - /rmm/api/tacticalrmm"
    echo "  - /opt/tacticalrmm/api/tacticalrmm"
    exit 1
fi

print_step "1.2" "Vérification de l'environnement virtuel Python..."
if [ -f "/rmm/api/env/bin/python" ]; then
    PYTHON_BIN="/rmm/api/env/bin/python"
    PYTHON_VERSION=$($PYTHON_BIN --version 2>&1)
    print_success "Python trouvé : $PYTHON_VERSION"
elif [ -f "/opt/tacticalrmm/api/env/bin/python" ]; then
    PYTHON_BIN="/opt/tacticalrmm/api/env/bin/python"
    PYTHON_VERSION=$($PYTHON_BIN --version 2>&1)
    print_success "Python trouvé : $PYTHON_VERSION"
else
    print_error "Environnement Python non trouvé"
    exit 1
fi

print_step "1.3" "Vérification de Django..."
DJANGO_VERSION=$(sudo -u tactical $PYTHON_BIN -c 'import django; print(django.get_version())' 2>&1)
print_success "Django version : $DJANGO_VERSION"

print_step "1.4" "Vérification du dossier integration..."
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ ! -d "$SCRIPT_DIR/integration/backend" ]; then
    print_error "Dossier integration/backend non trouvé"
    echo "Chemin attendu : $SCRIPT_DIR/integration/backend"
    exit 1
fi
print_success "Dossier integration trouvé"

echo ""
print_info "Configuration détectée :"
echo "  • Chemin RMM     : $RMM_PATH"
echo "  • Python         : $PYTHON_BIN"
echo "  • Django         : $DJANGO_VERSION"
echo "  • Integration    : $SCRIPT_DIR/integration"
echo ""

ask_confirmation "Les vérifications sont OK. Continuer l'installation ?"

# ============================================================================
# ÉTAPE 2 : Sauvegarde
# ============================================================================
print_header "ÉTAPE 2/9 - Sauvegarde des fichiers existants"

BACKUP_DIR="/root/tactical-rmm-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

print_step "2.1" "Sauvegarde de settings.py..."
if [ -f "$RMM_PATH/tacticalrmm/settings.py" ]; then
    cp "$RMM_PATH/tacticalrmm/settings.py" "$BACKUP_DIR/settings.py"
    print_success "Sauvegardé dans : $BACKUP_DIR/settings.py"
else
    print_warning "Fichier settings.py non trouvé (première installation)"
fi

print_step "2.2" "Sauvegarde de urls.py..."
if [ -f "$RMM_PATH/tacticalrmm/urls.py" ]; then
    cp "$RMM_PATH/tacticalrmm/urls.py" "$BACKUP_DIR/urls.py"
    print_success "Sauvegardé dans : $BACKUP_DIR/urls.py"
else
    print_warning "Fichier urls.py non trouvé"
fi

print_success "Sauvegardes créées dans : $BACKUP_DIR"

# ============================================================================
# ÉTAPE 3 : Création de l'application Django
# ============================================================================
print_header "ÉTAPE 3/9 - Création de l'application linux_deployments"

print_step "3.1" "Création du dossier..."
mkdir -p "$RMM_PATH/linux_deployments"
print_success "Dossier créé : $RMM_PATH/linux_deployments"

print_step "3.2" "Copie des fichiers backend..."
cp "$SCRIPT_DIR/integration/backend/models.py" "$RMM_PATH/linux_deployments/"
cp "$SCRIPT_DIR/integration/backend/views.py" "$RMM_PATH/linux_deployments/"
cp "$SCRIPT_DIR/integration/backend/serializers.py" "$RMM_PATH/linux_deployments/"
cp "$SCRIPT_DIR/integration/backend/urls.py" "$RMM_PATH/linux_deployments/"
cp "$SCRIPT_DIR/integration/backend/admin.py" "$RMM_PATH/linux_deployments/"
print_success "5 fichiers copiés"

print_step "3.3" "Création de __init__.py..."
touch "$RMM_PATH/linux_deployments/__init__.py"

print_step "3.4" "Création de apps.py..."
cat > "$RMM_PATH/linux_deployments/apps.py" << 'EOF'
from django.apps import AppConfig


class LinuxDeploymentsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'linux_deployments'
    verbose_name = 'Linux Deployments'

    def ready(self):
        """Signal handlers initialization"""
        pass
EOF
print_success "apps.py créé"

# ============================================================================
# ÉTAPE 4 : Correction des imports
# ============================================================================
print_header "ÉTAPE 4/9 - Correction des imports Python"

print_step "4.1" "Correction des imports dans views.py..."
sed -i 's/from \.models import/from linux_deployments.models import/g' "$RMM_PATH/linux_deployments/views.py"
sed -i 's/from \.serializers import/from linux_deployments.serializers import/g' "$RMM_PATH/linux_deployments/views.py"

print_step "4.2" "Correction des imports dans serializers.py..."
sed -i 's/from \.models import/from linux_deployments.models import/g' "$RMM_PATH/linux_deployments/serializers.py"

print_step "4.3" "Correction des imports dans admin.py..."
sed -i 's/from \.models import/from linux_deployments.models import/g' "$RMM_PATH/linux_deployments/admin.py"

print_step "4.4" "Correction des imports dans urls.py..."
sed -i 's/from \.views import/from linux_deployments.views import/g' "$RMM_PATH/linux_deployments/urls.py"

print_success "Tous les imports corrigés"

# ============================================================================
# ÉTAPE 5 : Permissions
# ============================================================================
print_header "ÉTAPE 5/9 - Configuration des permissions"

print_step "5.1" "Attribution des permissions à l'utilisateur tactical..."
chown -R tactical:tactical "$RMM_PATH/linux_deployments/"
print_success "Permissions configurées (tactical:tactical)"

# ============================================================================
# ÉTAPE 6 : Configuration Django
# ============================================================================
print_header "ÉTAPE 6/9 - Configuration de Django (settings.py)"

print_step "6.1" "Vérification de INSTALLED_APPS..."
if grep -q '"linux_deployments"' "$RMM_PATH/tacticalrmm/settings.py"; then
    print_warning "L'application linux_deployments est déjà dans INSTALLED_APPS"
else
    print_step "6.2" "Ajout de linux_deployments dans INSTALLED_APPS..."
    # Trouver la ligne avec "ee.sso" et insérer avant
    if grep -q '"ee\.sso"' "$RMM_PATH/tacticalrmm/settings.py"; then
        sed -i '/"ee\.sso",/i\    "linux_deployments",' "$RMM_PATH/tacticalrmm/settings.py"
        print_success "Application ajoutée avant ee.sso"
    else
        # Si ee.sso n'existe pas, ajouter avant "apiv3"
        sed -i '/"apiv3",/i\    "linux_deployments",' "$RMM_PATH/tacticalrmm/settings.py"
        print_success "Application ajoutée avant apiv3"
    fi
fi

# ============================================================================
# ÉTAPE 7 : Configuration des URLs
# ============================================================================
print_header "ÉTAPE 7/9 - Configuration des URLs Django"

print_step "7.1" "Vérification des URLs..."
if grep -q 'linux_deployments.urls' "$RMM_PATH/tacticalrmm/urls.py"; then
    print_warning "Les URLs linux_deployments sont déjà configurées"
else
    print_step "7.2" "Ajout des URLs linux_deployments..."
    # Ajouter après les URLs apiv3
    sed -i '/path("api\/v3\/", include("apiv3.urls")),/a\    path("api/v3/", include("linux_deployments.urls")),' "$RMM_PATH/tacticalrmm/urls.py"
    # Ajouter aussi l'URL publique pour le téléchargement
    sed -i '/path("api\/v3\/", include("apiv3.urls")),/a\    path("", include("linux_deployments.urls")),' "$RMM_PATH/tacticalrmm/urls.py"
    print_success "URLs configurées"
fi

# ============================================================================
# ÉTAPE 8 : Migrations de base de données
# ============================================================================
print_header "ÉTAPE 8/9 - Création et application des migrations"

print_step "8.1" "Création des migrations..."
cd "$RMM_PATH"
sudo -u tactical $PYTHON_BIN manage.py makemigrations linux_deployments
print_success "Migrations créées"

print_step "8.2" "Application des migrations..."
sudo -u tactical $PYTHON_BIN manage.py migrate linux_deployments
print_success "Migrations appliquées à la base de données"

print_step "8.3" "Vérification de la configuration Django..."
if sudo -u tactical $PYTHON_BIN manage.py check; then
    print_success "Configuration Django OK"
else
    print_error "Erreur de configuration Django"
    exit 1
fi

# ============================================================================
# ÉTAPE 9 : Redémarrage des services
# ============================================================================
print_header "ÉTAPE 9/9 - Redémarrage des services"

print_step "9.1" "Redémarrage de rmm.service..."
systemctl restart rmm.service
sleep 3

print_step "9.2" "Vérification du statut du service..."
if systemctl is-active --quiet rmm.service; then
    print_success "Service rmm.service actif"
else
    print_error "Erreur : le service rmm.service n'est pas actif"
    echo ""
    print_info "Logs du service :"
    journalctl -u rmm.service -n 30 --no-pager
    exit 1
fi

# ============================================================================
# Installation terminée !
# ============================================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          ✅  INSTALLATION TERMINÉE AVEC SUCCÈS !  ✅          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "🎉 Récapitulatif de l'installation"

echo -e "${GREEN}✓ Application Django créée${NC}"
echo -e "${GREEN}✓ Fichiers backend installés${NC}"
echo -e "${GREEN}✓ Base de données migrée${NC}"
echo -e "${GREEN}✓ URLs configurées${NC}"
echo -e "${GREEN}✓ Services redémarrés${NC}"
echo ""

print_header "📊 Endpoints API disponibles"

echo -e "${CYAN}Endpoints authentifiés (nécessite Token API) :${NC}"
echo "  • GET    https://api.rmm.selest.info/api/v3/linux-deployments/"
echo "  • POST   https://api.rmm.selest.info/api/v3/linux-deployments/create/"
echo "  • GET    https://api.rmm.selest.info/api/v3/linux-deployments/{uuid}/"
echo "  • DELETE https://api.rmm.selest.info/api/v3/linux-deployments/{uuid}/"
echo "  • GET    https://api.rmm.selest.info/api/v3/linux-deployments/stats/"
echo ""
echo -e "${CYAN}Endpoint public (sans authentification) :${NC}"
echo "  • GET    https://api.rmm.selest.info/clients/{uuid}/deploy/linux/"
echo ""

print_header "🧪 Tests de vérification"

echo -e "${YELLOW}Test 1 : Vérifier que l'API répond${NC}"
echo "  curl -I https://api.rmm.selest.info/api/v3/linux-deployments/"
echo "  ${GREEN}→ Doit retourner 401 Unauthorized (c'est normal !)${NC}"
echo ""

echo -e "${YELLOW}Test 2 : Vérifier le service${NC}"
echo "  systemctl status rmm.service"
echo ""

print_header "🚀 Prochaines étapes"

echo -e "${BOLD}Option 1 : Utiliser l'Admin Django (Recommandé)${NC}"
echo ""
echo "  1. Activer l'admin :"
echo "     ${CYAN}sudo nano /rmm/api/tacticalrmm/tacticalrmm/local_settings.py${NC}"
echo "     Ajouter : ${GREEN}ADMIN_ENABLED = True${NC}"
echo ""
echo "  2. Créer un superuser (si nécessaire) :"
echo "     ${CYAN}sudo -u tactical $PYTHON_BIN $RMM_PATH/manage.py createsuperuser${NC}"
echo ""
echo "  3. Redémarrer :"
echo "     ${CYAN}sudo systemctl restart rmm.service${NC}"
echo ""
echo "  4. Accéder à l'admin :"
echo "     ${GREEN}https://api.rmm.selest.info/admin/${NC}"
echo ""
echo "  Dans l'admin, vous verrez la section ${BOLD}Linux Deployments${NC} !"
echo ""

echo -e "${BOLD}Option 2 : Utiliser le Django Shell${NC}"
echo "  ${CYAN}sudo -u tactical $PYTHON_BIN $RMM_PATH/manage.py shell${NC}"
echo ""

echo -e "${BOLD}Option 3 : Utiliser l'API REST${NC}"
echo "  Obtenir un token API depuis le dashboard : Settings → API Keys"
echo ""

print_header "📁 Sauvegardes créées"
echo "  $BACKUP_DIR/"
echo ""

print_header "📚 Documentation"
echo "  • Guide d'intégration : integration/docs/INTEGRATION_GUIDE.md"
echo "  • Architecture        : DASHBOARD_INTEGRATION_README.md"
echo "  • README             : integration/README.md"
echo ""

print_header "🆘 Support"
echo "  • GitHub Issues : https://github.com/fred-selest/tactical-rmm/issues"
echo "  • Logs RMM      : sudo journalctl -u rmm.service -f"
echo ""

echo -e "${GREEN}${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎊 Bon déploiement avec rmm.selest.info ! 🎊"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${NC}"
