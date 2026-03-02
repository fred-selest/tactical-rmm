#!/bin/bash
#
# 🔐 Script de déploiement rapide des Signing Tokens
# Pour Tactical RMM - Linux Deployments
#
# Usage: sudo ./deploy-signing-tokens.sh
#

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RMM_DIR="/rmm/api/tacticalrmm"
TACTICAL_USER="tactical"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🔐  Déploiement des Signing Tokens                         ║
║      pour Tactical RMM - Linux Deployments                   ║
║                                                               ║
║   Triple sécurité:                                           ║
║   ✓ Signature HMAC-SHA256                                    ║
║   ✓ One-Time Tokens                                          ║
║   ✓ Signature Secrets                                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Fonction pour afficher les étapes
step() {
    echo -e "\n${BLUE}▶${NC} ${CYAN}$1${NC}"
}

# Fonction pour afficher le succès
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Fonction pour afficher les erreurs
error() {
    echo -e "${RED}✗${NC} $1"
}

# Fonction pour afficher les warnings
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Fonction pour demander confirmation
confirm() {
    read -p "$(echo -e ${YELLOW}$1 [o/N]:${NC} )" -n 1 -r
    echo
    [[ $REPLY =~ ^[OoYy]$ ]]
}

# Vérifier que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
   error "Ce script doit être exécuté en tant que root"
   echo "  Utilisez: sudo $0"
   exit 1
fi

# Étape 1 : Vérifications préalables
step "Étape 1/7 - Vérifications préalables"

# Vérifier que le répertoire RMM existe
if [ ! -d "$RMM_DIR" ]; then
    error "Répertoire Tactical RMM non trouvé: $RMM_DIR"
    exit 1
fi
success "Répertoire RMM trouvé: $RMM_DIR"

# Vérifier que l'utilisateur tactical existe
if ! id "$TACTICAL_USER" &>/dev/null; then
    error "Utilisateur '$TACTICAL_USER' non trouvé"
    exit 1
fi
success "Utilisateur '$TACTICAL_USER' trouvé"

# Vérifier que Python est disponible
PYTHON="/rmm/api/env/bin/python"
if [ ! -f "$PYTHON" ]; then
    error "Python non trouvé: $PYTHON"
    exit 1
fi
success "Python trouvé: $PYTHON"

# Vérifier que Django est fonctionnel
if ! sudo -u $TACTICAL_USER $PYTHON $RMM_DIR/manage.py check --deploy &>/dev/null; then
    warning "Django check a échoué, mais on continue..."
else
    success "Django est fonctionnel"
fi

# Étape 2 : Sauvegarde de la base de données
step "Étape 2/7 - Sauvegarde de la base de données"

if confirm "Voulez-vous sauvegarder la base de données avant de continuer ?"; then
    BACKUP_FILE="/tmp/tactical_rmm_backup_$(date +%Y%m%d_%H%M%S).sql"

    echo "  Création de la sauvegarde..."
    if sudo -u postgres pg_dump tacticalrmm > "$BACKUP_FILE" 2>/dev/null; then
        success "Sauvegarde créée: $BACKUP_FILE"
        echo "  Taille: $(du -h $BACKUP_FILE | cut -f1)"
    else
        warning "Impossible de créer la sauvegarde (pg_dump non disponible ?)"
        if ! confirm "Continuer sans sauvegarde ?"; then
            error "Déploiement annulé par l'utilisateur"
            exit 1
        fi
    fi
else
    warning "Sauvegarde ignorée"
fi

# Étape 3 : Copie des fichiers de migration
step "Étape 3/7 - Copie des fichiers de migration"

# Créer le répertoire linux_deployments s'il n'existe pas
LINUX_DEPLOY_DIR="$RMM_DIR/linux_deployments"
if [ ! -d "$LINUX_DEPLOY_DIR" ]; then
    warning "Répertoire linux_deployments non trouvé"
    if confirm "Créer le répertoire $LINUX_DEPLOY_DIR ?"; then
        mkdir -p "$LINUX_DEPLOY_DIR"
        chown $TACTICAL_USER:$TACTICAL_USER "$LINUX_DEPLOY_DIR"
        success "Répertoire créé"
    else
        error "Impossible de continuer sans le répertoire linux_deployments"
        exit 1
    fi
fi

# Copier les fichiers backend
echo "  Copie des fichiers backend..."
if [ -d "$SCRIPT_DIR/integration/backend" ]; then
    cp -v "$SCRIPT_DIR/integration/backend/models.py" "$LINUX_DEPLOY_DIR/"
    cp -v "$SCRIPT_DIR/integration/backend/views.py" "$LINUX_DEPLOY_DIR/"
    cp -v "$SCRIPT_DIR/integration/backend/serializers.py" "$LINUX_DEPLOY_DIR/" 2>/dev/null || true
    cp -v "$SCRIPT_DIR/integration/backend/urls.py" "$LINUX_DEPLOY_DIR/" 2>/dev/null || true
    cp -v "$SCRIPT_DIR/integration/backend/admin.py" "$LINUX_DEPLOY_DIR/" 2>/dev/null || true

    # Copier les migrations
    if [ -d "$SCRIPT_DIR/integration/backend/migrations" ]; then
        cp -rv "$SCRIPT_DIR/integration/backend/migrations" "$LINUX_DEPLOY_DIR/"
    fi

    # Corriger les permissions
    chown -R $TACTICAL_USER:$TACTICAL_USER "$LINUX_DEPLOY_DIR"

    success "Fichiers backend copiés"
else
    error "Répertoire source non trouvé: $SCRIPT_DIR/integration/backend"
    exit 1
fi

# Étape 4 : Application des migrations
step "Étape 4/7 - Application des migrations Django"

echo "  Création des migrations..."
if sudo -u $TACTICAL_USER $PYTHON $RMM_DIR/manage.py makemigrations linux_deployments; then
    success "Migrations créées"
else
    warning "makemigrations a échoué (migrations déjà créées ?)"
fi

echo "  Application des migrations..."
if sudo -u $TACTICAL_USER $PYTHON $RMM_DIR/manage.py migrate linux_deployments; then
    success "Migrations appliquées avec succès"
else
    error "Échec de l'application des migrations"
    exit 1
fi

# Vérifier l'état des migrations
echo "  Vérification de l'état des migrations..."
sudo -u $TACTICAL_USER $PYTHON $RMM_DIR/manage.py showmigrations linux_deployments | grep -A 10 "linux_deployments" || true

# Étape 5 : Vérification de l'installation
step "Étape 5/7 - Vérification de l'installation"

echo "  Vérification du modèle LinuxDeployment..."
if sudo -u $TACTICAL_USER $PYTHON $RMM_DIR/manage.py shell << 'PYEOF'
try:
    from linux_deployments.models import LinuxDeployment
    print("✓ Modèle LinuxDeployment importé avec succès")

    # Vérifier les nouveaux champs
    fields = LinuxDeployment._meta.get_fields()
    field_names = [f.name for f in fields]

    required_fields = ['signing_token', 'one_time_token', 'signature_secret', 'token_used', 'token_used_at']
    missing = [f for f in required_fields if f not in field_names]

    if missing:
        print(f"✗ Champs manquants: {', '.join(missing)}")
        exit(1)
    else:
        print("✓ Tous les champs de sécurité sont présents")
        print(f"  - signing_token")
        print(f"  - one_time_token")
        print(f"  - signature_secret")
        print(f"  - token_used")
        print(f"  - token_used_at")

    # Vérifier les méthodes
    methods = ['generate_signing_token', 'generate_one_time_token', 'generate_signature_secret',
               'generate_signature', 'validate_signature', 'get_signed_url', 'use_one_time_token', 'is_token_valid']

    for method in methods:
        if hasattr(LinuxDeployment, method):
            print(f"✓ Méthode {method} présente")
        else:
            print(f"✗ Méthode {method} manquante")
            exit(1)

    print("\n✓ Vérification réussie !")
    exit(0)
except Exception as e:
    print(f"✗ Erreur: {e}")
    exit(1)
PYEOF
then
    success "Vérification du modèle réussie"
else
    error "Erreur lors de la vérification du modèle"
    exit 1
fi

# Étape 6 : Redémarrage des services
step "Étape 6/7 - Redémarrage des services"

if confirm "Redémarrer le service rmm.service maintenant ?"; then
    echo "  Redémarrage de rmm.service..."
    systemctl restart rmm.service

    sleep 3

    if systemctl is-active --quiet rmm.service; then
        success "Service rmm.service redémarré avec succès"
    else
        error "Le service rmm.service n'est pas actif"
        echo "  Vérifiez les logs: sudo journalctl -u rmm.service -n 50"
        exit 1
    fi
else
    warning "Service non redémarré - pensez à le faire manuellement:"
    echo "  sudo systemctl restart rmm.service"
fi

# Étape 7 : Test de création d'un déploiement
step "Étape 7/7 - Test de création d'un déploiement"

if confirm "Voulez-vous créer un déploiement de test ?"; then
    echo "  Création d'un déploiement de test..."

    sudo -u $TACTICAL_USER $PYTHON $RMM_DIR/manage.py shell << 'PYEOF'
from linux_deployments.models import LinuxDeployment
from django.utils import timezone
from datetime import timedelta

try:
    # Créer un déploiement de test
    deployment = LinuxDeployment.objects.create(
        client_id=999,
        client_name="Test Client",
        site_id=999,
        site_name="Test Site",
        agent_type="server",
        arch="amd64",
        api_url="https://api.selest.info",
        mesh_url="https://mesh.selest.info",
        auth_key="test_auth_key",
        signing_token=LinuxDeployment.generate_signing_token(),
        one_time_token=LinuxDeployment.generate_one_time_token(),
        signature_secret=LinuxDeployment.generate_signature_secret(),
        expires_at=timezone.now() + timedelta(days=30),
        created_by="deploy_script"
    )

    print(f"\n✓ Déploiement de test créé avec succès !")
    print(f"  UUID: {deployment.uuid}")
    print(f"  Signing Token: {deployment.signing_token[:20]}...({len(deployment.signing_token)} chars)")
    print(f"  One-Time Token: {deployment.one_time_token[:20]}...({len(deployment.one_time_token)} chars)")
    print(f"  Token Used: {deployment.token_used}")

    # Tester la génération d'URL signée
    signed_url = deployment.get_signed_url()
    print(f"\n✓ URL signée générée:")
    print(f"  {signed_url[:80]}...")

    # Tester la validation
    data_to_sign = f"{deployment.uuid}:1234567890"
    signature = deployment.generate_signature(data_to_sign)
    is_valid = deployment.validate_signature(data_to_sign, signature)
    print(f"\n✓ Test de signature HMAC: {'Valide' if is_valid else 'Invalide'}")

    # Tester is_token_valid
    print(f"✓ Token valid: {deployment.is_token_valid()}")

    # Supprimer le déploiement de test
    deployment.delete()
    print(f"\n✓ Déploiement de test supprimé")

    print("\n🎉 TOUS LES TESTS SONT PASSÉS !")

except Exception as e:
    print(f"✗ Erreur lors du test: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
PYEOF

    if [ $? -eq 0 ]; then
        success "Tests réussis"
    else
        error "Les tests ont échoué"
    fi
else
    warning "Tests ignorés"
fi

# Résumé final
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║   ✓ DÉPLOIEMENT TERMINÉ AVEC SUCCÈS !                        ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${CYAN}📚 Prochaines étapes:${NC}"
echo ""
echo "  1. Accédez à l'admin Django:"
echo "     https://api.selest.info/admin/"
echo ""
echo "  2. Créez un nouveau déploiement dans:"
echo "     Linux Deployments → Add Linux Deployment"
echo ""
echo "  3. Les 3 tokens seront générés automatiquement:"
echo "     ✓ Signing Token (signature HMAC)"
echo "     ✓ One-Time Token (usage unique)"
echo "     ✓ Signature Secret (serveur uniquement)"
echo ""
echo "  4. Utilisez get_signed_url() pour obtenir l'URL sécurisée"
echo ""
echo "  5. Consultez la documentation:"
echo "     - SIGNING_TOKENS_README.md (technique)"
echo "     - GUIDE_UTILISATION_ADMIN_PRIVATE.md (utilisateur)"
echo ""

echo -e "${CYAN}🔍 Commandes utiles:${NC}"
echo ""
echo "  # Voir les logs du service"
echo "  sudo journalctl -u rmm.service -f"
echo ""
echo "  # Accéder au shell Django"
echo "  sudo -u tactical /rmm/api/env/bin/python $RMM_DIR/manage.py shell"
echo ""
echo "  # Lister les déploiements"
echo "  sudo -u tactical /rmm/api/env/bin/python $RMM_DIR/manage.py shell"
echo "  >>> from linux_deployments.models import LinuxDeployment"
echo "  >>> LinuxDeployment.objects.all()"
echo ""

echo -e "${GREEN}✨ Bon déploiement !${NC}\n"

exit 0
