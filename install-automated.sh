#!/bin/bash

###############################################################################
# Script d'installation AUTOMATISÉE de l'intégration Dashboard Linux
# Pour Tactical RMM - rmm.selest.info
#
# Usage: sudo ./install-automated.sh [options]
# Options:
#   --api-url URL          URL de l'API Tactical RMM (détection auto si omis)
#   --mesh-url URL         URL du Mesh Agent (détection auto si omis)  
#   --force                Forcer l'installation même si déjà installé
#   --no-backup            Ne pas créer de sauvegarde
#   --quiet                Mode silencieux (moins de logs)
#
# Ce script détecte automatiquement:
#   - L'emplacement de Tactical RMM
#   - La configuration Python/Django existante
#   - Les URLs API et Mesh à partir de la configuration
#   - Les dépendances requises
###############################################################################

set -e

# === VARIABLES GLOBALES ===
SCRIPT_VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/tacticalrmm-install-automated.log"
BACKUP_ENABLED=true
QUIET_MODE=false
FORCE_INSTALL=false

# URLs détectées automatiquement
DETECTED_API_URL=""
DETECTED_MESH_URL=""

# Couleurs (uniquement en mode non silencieux)
if [ "$QUIET_MODE" = false ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
    BOLD='\033[1m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''; NC=''; BOLD=''
fi

# === FONCTIONS UTILITAIRES ===

log() {
    local level="$1"
    local message="$2"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    
    # Journalisation dans le fichier
    echo "$timestamp [$level] $message" >> "$LOG_FILE"
    
    # Affichage console (sauf en mode silencieux pour INFO)
    if [ "$QUIET_MODE" = false ] || [ "$level" != "INFO" ]; then
        case $level in
            "INFO") echo -e "${CYAN}ℹ $message${NC}" ;;
            "SUCCESS") echo -e "${GREEN}✓ $message${NC}" ;;
            "WARNING") echo -e "${YELLOW}⚠ $message${NC}" ;;
            "ERROR") echo -e "${RED}✗ $message${NC}" ;;
            "STEP") echo -e "${BLUE}${BOLD}[$message]${NC}" ;;
        esac
    fi
}

print_header() {
    if [ "$QUIET_MODE" = false ]; then
        echo ""
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}${BOLD}  $1${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    fi
}

detect_tactical_rmm() {
    log "STEP" "Détection de Tactical RMM..."
    
    if [ -d "/rmm/api/tacticalrmm" ]; then
        RMM_PATH="/rmm/api/tacticalrmm"
        PYTHON_BIN="/rmm/api/env/bin/python"
        log "SUCCESS" "Tactical RMM trouvé : $RMM_PATH"
    elif [ -d "/opt/tacticalrmm/api/tacticalrmm" ]; then
        RMM_PATH="/opt/tacticalrmm/api/tacticalrmm"
        PYTHON_BIN="/opt/tacticalrmm/api/env/bin/python"
        log "SUCCESS" "Tactical RMM trouvé : $RMM_PATH"
    else
        log "ERROR" "Tactical RMM non trouvé"
        log "INFO" "Chemins vérifiés : /rmm/api/tacticalrmm, /opt/tacticalrmm/api/tacticalrmm"
        exit 1
    fi
    
    # Vérifier l'environnement Python
    if [ ! -f "$PYTHON_BIN" ]; then
        log "ERROR" "Environnement Python non trouvé : $PYTHON_BIN"
        exit 1
    fi
    
    # Détecter l'URL API à partir de la configuration Django
    detect_api_url
}

detect_api_url() {
    log "INFO" "Détection de l'URL API..."
    
    # Essayer de lire depuis local_settings.py
    LOCAL_SETTINGS="$RMM_PATH/tacticalrmm/local_settings.py"
    if [ -f "$LOCAL_SETTINGS" ]; then
        # Chercher ALLOWED_HOSTS ou autres indicateurs d'URL
        if grep -q "ALLOWED_HOSTS" "$LOCAL_SETTINGS"; then
            ALLOWED_HOST=$(grep "ALLOWED_HOSTS" "$LOCAL_SETTINGS" | head -1 | grep -oE "'[^']*'" | head -1 | tr -d "'")
            if [ -n "$ALLOWED_HOST" ] && [ "$ALLOWED_HOST" != "*" ]; then
                DETECTED_API_URL="https://$ALLOWED_HOST"
                log "SUCCESS" "URL API détectée depuis ALLOWED_HOSTS : $DETECTED_API_URL"
                return
            fi
        fi
    fi
    
    # Essayer de lire depuis settings.py
    SETTINGS_FILE="$RMM_PATH/tacticalrmm/settings.py"
    if [ -f "$SETTINGS_FILE" ]; then
        if grep -q "ALLOWED_HOSTS" "$SETTINGS_FILE"; then
            ALLOWED_HOST=$(grep "ALLOWED_HOSTS" "$SETTINGS_FILE" | head -1 | grep -oE "'[^']*'" | head -1 | tr -d "'")
            if [ -n "$ALLOWED_HOST" ] && [ "$ALLOWED_HOST" != "*" ]; then
                DETECTED_API_URL="https://$ALLOWED_HOST"
                log "SUCCESS" "URL API détectée depuis settings.py : $DETECTED_API_URL"
                return
            fi
        fi
    fi
    
    # Dernier recours : utiliser le hostname système
    HOSTNAME=$(hostname -f 2>/dev/null || hostname)
    DETECTED_API_URL="https://$HOSTNAME"
    log "WARNING" "URL API estimée depuis hostname : $DETECTED_API_URL"
    log "WARNING" "Veuillez vérifier que cette URL est correcte et accessible"
}

detect_mesh_url() {
    log "INFO" "Détection de l'URL Mesh..."
    
    # Essayer de trouver la configuration Mesh existante
    MESH_CONFIG_FILE="$RMM_PATH/tacticalrmm/local_settings.py"
    if [ ! -f "$MESH_CONFIG_FILE" ]; then
        MESH_CONFIG_FILE="$RMM_PATH/tacticalrmm/settings.py"
    fi
    
    if [ -f "$MESH_CONFIG_FILE" ]; then
        # Chercher MESH_*_KEY ou configurations similaires
        if grep -q "MESH_" "$MESH_CONFIG_FILE"; then
            # Extraire le domaine Mesh si possible
            MESH_DOMAIN=$(grep -E "(MESH_.+_KEY|mesh_url)" "$MESH_CONFIG_FILE" | head -1 | grep -oE "https?://[^/]+" | head -1)
            if [ -n "$MESH_DOMAIN" ]; then
                DETECTED_MESH_URL="${MESH_DOMAIN}/meshagents?id=..."
                log "SUCCESS" "URL Mesh détectée : $DETECTED_MESH_URL"
                return
            fi
        fi
    fi
    
    # URL par défaut
    DETECTED_MESH_URL="https://mesh.votredomaine.com/meshagents?id=..."
    log "WARNING" "URL Mesh par défaut utilisée : $DETECTED_MESH_URL"
    log "WARNING" "Vous devrez configurer manuellement l'URL Mesh correcte"
}

check_existing_installation() {
    if [ "$FORCE_INSTALL" = true ]; then
        log "WARNING" "Installation forcée demandée - contournement de la vérification existante"
        return 0
    fi
    
    if [ -d "$RMM_PATH/linux_deployments" ]; then
        log "ERROR" "L'intégration Linux Deployments est déjà installée"
        log "INFO" "Utilisez --force pour réinstaller ou mettez à jour manuellement"
        exit 1
    fi
}

create_backup() {
    if [ "$BACKUP_ENABLED" = false ]; then
        log "INFO" "Sauvegarde désactivée (--no-backup)"
        return 0
    fi
    
    BACKUP_DIR="/root/tactical-rmm-backups/automated-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    log "STEP" "Création des sauvegardes..."
    
    # Sauvegarder settings.py
    if [ -f "$RMM_PATH/tacticalrmm/settings.py" ]; then
        cp "$RMM_PATH/tacticalrmm/settings.py" "$BACKUP_DIR/settings.py"
        log "SUCCESS" "settings.py sauvegardé"
    fi
    
    # Sauvegarder urls.py  
    if [ -f "$RMM_PATH/tacticalrmm/urls.py" ]; then
        cp "$RMM_PATH/tacticalrmm/urls.py" "$BACKUP_DIR/urls.py"
        log "SUCCESS" "urls.py sauvegardé"
    fi
    
    log "SUCCESS" "Sauvegardes créées dans : $BACKUP_DIR"
}

install_linux_deployments() {
    print_header "Installation de l'application linux_deployments"
    
    log "STEP" "Création du dossier..."
    mkdir -p "$RMM_PATH/linux_deployments"
    
    log "STEP" "Copie des fichiers backend..."
    cp "$SCRIPT_DIR/integration/backend/models.py" "$RMM_PATH/linux_deployments/"
    cp "$SCRIPT_DIR/integration/backend/views.py" "$RMM_PATH/linux_deployments/"
    cp "$SCRIPT_DIR/integration/backend/serializers.py" "$RMM_PATH/linux_deployments/"
    cp "$SCRIPT_DIR/integration/backend/urls.py" "$RMM_PATH/linux_deployments/"
    cp "$SCRIPT_DIR/integration/backend/admin.py" "$RMM_PATH/linux_deployments/"
    
    log "STEP" "Création de __init__.py..."
    touch "$RMM_PATH/linux_deployments/__init__.py"
    
    log "STEP" "Création de apps.py..."
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
    
    log "SUCCESS" "Application linux_deployments créée"
}

fix_imports() {
    print_header "Correction des imports Python"
    
    log "STEP" "Correction des imports dans views.py..."
    sed -i 's/from \.models import/from linux_deployments.models import/g' "$RMM_PATH/linux_deployments/views.py"
    sed -i 's/from \.serializers import/from linux_deployments.serializers import/g' "$RMM_PATH/linux_deployments/views.py"
    
    log "STEP" "Correction des imports dans serializers.py..."
    sed -i 's/from \.models import/from linux_deployments.models import/g' "$RMM_PATH/linux_deployments/serializers.py"
    
    log "STEP" "Correction des imports dans admin.py..."
    sed -i 's/from \.models import/from linux_deployments.models import/g' "$RMM_PATH/linux_deployments/admin.py"
    
    log "STEP" "Correction des imports dans urls.py..."
    sed -i 's/from \.views import/from linux_deployments.views import/g' "$RMM_PATH/linux_deployments/urls.py"
    
    log "SUCCESS" "Tous les imports corrigés"
}

set_permissions() {
    log "STEP" "Configuration des permissions..."
    chown -R tactical:tactical "$RMM_PATH/linux_deployments/"
    log "SUCCESS" "Permissions configurées (tactical:tactical)"
}

configure_django() {
    print_header "Configuration de Django"
    
    log "STEP" "Configuration INSTALLED_APPS..."
    if ! grep -q '"linux_deployments"' "$RMM_PATH/tacticalrmm/settings.py"; then
        if grep -q '"ee\.sso"' "$RMM_PATH/tacticalrmm/settings.py"; then
            sed -i '/"ee\.sso",/i\    "linux_deployments",' "$RMM_PATH/tacticalrmm/settings.py"
        else
            sed -i '/"apiv3",/i\    "linux_deployments",' "$RMM_PATH/tacticalrmm/settings.py"
        fi
        log "SUCCESS" "linux_deployments ajouté à INSTALLED_APPS"
    else
        log "WARNING" "linux_deployments déjà présent dans INSTALLED_APPS"
    fi
}

configure_urls() {
    print_header "Configuration des URLs"
    
    log "STEP" "Configuration des URLs..."
    if ! grep -q 'linux_deployments.urls' "$RMM_PATH/tacticalrmm/urls.py"; then
        # Ajouter après les URLs apiv3
        sed -i '/path("api\/v3\/", include("apiv3.urls")),/a\    path("api/v3/", include("linux_deployments.urls")),' "$RMM_PATH/tacticalrmm/urls.py"
        # Ajouter aussi l'URL publique
        sed -i '/path("api\/v3\/", include("apiv3.urls")),/a\    path("", include("linux_deployments.urls")),' "$RMM_PATH/tacticalrmm/urls.py"
        log "SUCCESS" "URLs linux_deployments configurées"
    else
        log "WARNING" "URLs linux_deployments déjà configurées"
    fi
}

run_migrations() {
    print_header "Migrations de base de données"
    
    log "STEP" "Création des migrations..."
    cd "$RMM_PATH"
    sudo -u tactical $PYTHON_BIN manage.py makemigrations linux_deployments
    
    log "STEP" "Application des migrations..."
    sudo -u tactical $PYTHON_BIN manage.py migrate linux_deployments
    
    log "STEP" "Vérification de la configuration Django..."
    if sudo -u tactical $PYTHON_BIN manage.py check; then
        log "SUCCESS" "Configuration Django OK"
    else
        log "ERROR" "Erreur de configuration Django"
        exit 1
    fi
}

restart_services() {
    print_header "Redémarrage des services"
    
    log "STEP" "Redémarrage de rmm.service..."
    systemctl restart rmm.service
    sleep 3
    
    log "STEP" "Vérification du statut du service..."
    if systemctl is-active --quiet rmm.service; then
        log "SUCCESS" "Service rmm.service actif"
    else
        log "ERROR" "Service rmm.service non actif"
        journalctl -u rmm.service -n 20 --no-pager >> "$LOG_FILE"
        exit 1
    fi
}

import_monitoring_scripts() {
    print_header "Importation des scripts de surveillance avancée"
    
    log "INFO" "Vérification de l'accès à la base de données Tactical RMM..."
    
    # Vérifier que nous pouvons accéder à Django
    if ! sudo -u tactical $PYTHON_BIN -c "import django; print('Django accessible')" > /dev/null 2>&1; then
        log "WARNING" "Django non accessible, importation des scripts ignorée"
        return 0
    fi
    
    # Créer le script d'importation temporaire
    IMPORT_SCRIPT="/tmp/import-monitoring-scripts.py"
    cat > "$IMPORT_SCRIPT" << 'EOF'
import os
import sys
import django
from pathlib import Path

# Ajouter le chemin de Tactical RMM
sys.path.append('/rmm/api/tacticalrmm')

# Configurer les paramètres Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tacticalrmm.settings')
django.setup()

from scripts.models import Script

def read_script_file(filepath):
    """Lire le contenu d'un fichier de script"""
    try:
        with open(filepath, 'r') as f:
            return f.read()
    except FileNotFoundError:
        return None

def import_script(name, filepath, category, supported_platforms=['linux']):
    """Importer un script dans la base de données"""
    content = read_script_file(filepath)
    if content is None:
        return False
    
    # Vérifier si le script existe déjà
    existing = Script.objects.filter(name=name).first()
    if existing:
        existing.script_body = content
        existing.category = category
        existing.supported_platforms = supported_platforms
        existing.shell = 'shell'
        existing.save()
    else:
        Script.objects.create(
            name=name,
            script_type='shell',
            shell='shell',
            category=category,
            script_body=content,
            supported_platforms=supported_platforms
        )
    
    return True

def main():
    """Importer tous les scripts de surveillance avancée"""
    tactical_rmm_path = Path("/home/debian/tactical-rmm")
    
    # Scripts système
    system_scripts = [
        ("Surveillance CPU", "scripts/system/check-cpu.sh", "System"),
        ("Surveillance Mémoire", "scripts/system/check-memory.sh", "System"),
        ("Surveillance Disque", "scripts/system/check-disk.sh", "System"),
        ("Surveillance Réseau", "scripts/system/check-network.sh", "System"),
        ("Surveillance Système Complète", "scripts/system/check-system.sh", "System"),
    ]
    
    # Scripts Docker
    docker_scripts = [
        ("Surveillance Docker", "scripts/docker/check-docker.sh", "Docker"),
    ]
    
def main():
    """Importer tous les scripts disponibles"""
    tactical_rmm_path = Path("/home/debian/tactical-rmm")
    
    # Scripts système
    system_scripts = [
        ("Surveillance CPU", "scripts/system/check-cpu.sh", "System"),
        ("Surveillance Mémoire", "scripts/system/check-memory.sh", "System"),
        ("Surveillance Disque", "scripts/system/check-disk.sh", "System"),
        ("Surveillance Réseau", "scripts/system/check-network.sh", "System"),
        ("Surveillance Système Complète", "scripts/system/check-system.sh", "System"),
    ]
    
    # Scripts Docker
    docker_scripts = [
        ("Surveillance Docker", "scripts/docker/check-docker.sh", "Docker"),
    ]
    
    # Scripts bases de données
    database_scripts = [
        ("Surveillance MySQL/MariaDB", "scripts/database/check-mysql.sh", "Database"),
        ("Surveillance PostgreSQL", "scripts/database/check-postgresql.sh", "Database"),
        ("Surveillance Bases de Données Complète", "scripts/database/check-database.sh", "Database"),
    ]
    
    # Scripts Plesk
    plesk_scripts = [
        ("Plesk - Surveillance complète", "scripts/plesk/plesk_surveillance_complete.sh", "Plesk"),
        ("Plesk - Vérification services", "scripts/plesk/plesk_check_services.sh", "Plesk"),
        ("Plesk - Vérification disque", "scripts/plesk/plesk_check_disk.sh", "Plesk"),
        ("Plesk - Vérification SSL", "scripts/plesk/plesk_check_ssl.sh", "Plesk"),
        ("Plesk - Vérification mail", "scripts/plesk/plesk_check_mail.sh", "Plesk"),
        ("Plesk - Vérification sauvegarde", "scripts/plesk/plesk_check_backup.sh", "Plesk"),
        ("Plesk - Vérification sécurité", "scripts/plesk/plesk_check_security.sh", "Plesk"),
        ("Plesk - Vérification Docker", "scripts/plesk/plesk_check_docker.sh", "Plesk"),
        ("Plesk - Vérification Docker Compose", "scripts/plesk/plesk_check_docker_compose.sh", "Plesk"),
        ("Plesk - Vérification tout", "scripts/plesk/plesk_check_all.sh", "Plesk"),
    ]
    
    # Scripts Synology
    synology_scripts = [
        ("Synology - Surveillance complète", "scripts/synology/synology_surveillance_complete.sh", "Synology"),
        ("Synology - Vérification tout", "scripts/synology/synology_check_all.sh", "Synology"),
        ("Synology - Vérification système", "scripts/synology/synology_check_system.sh", "Synology"),
        ("Synology - Vérification disques", "scripts/synology/synology_check_disks.sh", "Synology"),
        ("Synology - Vérification RAID", "scripts/synology/synology_check_raid.sh", "Synology"),
        ("Synology - Vérification services", "scripts/synology/synology_check_services.sh", "Synology"),
        ("Synology - Vérification sauvegarde", "scripts/synology/synology_check_backup.sh", "Synology"),
        ("Synology - Vérification HyperBackup", "scripts/synology/synology_check_hyperbackup.sh", "Synology"),
        ("Synology - Vérification sécurité", "scripts/synology/synology_check_security.sh", "Synology"),
    ]
    
    all_scripts = system_scripts + docker_scripts + database_scripts + plesk_scripts + synology_scripts
    
    for name, filepath, category in all_scripts:
        full_path = tactical_rmm_path / filepath
        import_script(name, str(full_path), category)

if __name__ == "__main__":
    main()
EOF
    
    # Exécuter l'importation
    log "STEP" "Importation des scripts de surveillance..."
    if cd "$RMM_PATH" && sudo -u tactical $PYTHON_BIN "$IMPORT_SCRIPT"; then
        log "SUCCESS" "Scripts de surveillance importés avec succès"
    else
        log "WARNING" "Échec de l'importation des scripts (continuation)"
    fi
    
    # Nettoyer le script temporaire
    rm -f "$IMPORT_SCRIPT"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --api-url)
                DETECTED_API_URL="$2"
                shift 2
                ;;
            --mesh-url)
                DETECTED_MESH_URL="$2"
                shift 2
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --no-backup)
                BACKUP_ENABLED=false
                shift
                ;;
            --quiet)
                QUIET_MODE=true
                shift
                ;;
            *)
                log "ERROR" "Option inconnue: $1"
                echo "Usage: $0 [--api-url URL] [--mesh-url URL] [--force] [--no-backup] [--quiet]"
                exit 1
                ;;
        esac
    done
}

show_completion_summary() {
    if [ "$QUIET_MODE" = true ]; then
        return
    fi
    
    clear
    echo -e "${GREEN}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          ✅  INSTALLATION AUTOMATISÉE RÉUSSIE !  ✅           ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    print_header "🎯 Résumé de l'installation"
    echo -e "${GREEN}✓ Application Django linux_deployments installée${NC}"
    echo -e "${GREEN}✓ Base de données migrée${NC}"
    echo -e "${GREEN}✓ Services redémarrés${NC}"
    echo ""
    
    if [ -n "$DETECTED_API_URL" ]; then
        echo -e "${CYAN}🌐 URL API détectée : ${GREEN}$DETECTED_API_URL${NC}"
    fi
    if [ -n "$DETECTED_MESH_URL" ]; then
        echo -e "${CYAN}🔗 URL Mesh détectée : ${GREEN}$DETECTED_MESH_URL${NC}"
    fi
    echo ""
    
    print_header "🚀 Prochaines étapes"
    echo "1. Accédez à l'Admin Django pour créer vos premiers déploiements"
    echo "2. Utilisez l'API pour automatiser la création de liens de déploiement"
    echo "3. Testez le téléchargement avec : curl -I $DETECTED_API_URL/clients/{uuid}/deploy/linux/"
    echo ""
    
    print_header "📚 Documentation"
    echo "Logs : $LOG_FILE"
    echo "Sauvegardes : /root/tactical-rmm-backups/"
}

# === MAIN ===

# Analyse des arguments
parse_arguments "$@"

# Banner initial
if [ "$QUIET_MODE" = false ]; then
    clear
    echo -e "${MAGENTA}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   🤖  TACTICAL RMM - INSTALLATION AUTOMATISÉE  🤖            ║
║                                                               ║
║   Installation sans interaction pour :                       ║
║   📍 rmm.selest.info                                          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
fi

log "INFO" "Démarrage de l'installation automatisée v$SCRIPT_VERSION"

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
    log "ERROR" "Ce script doit être exécuté en tant que root"
    echo "Utilisez: sudo $0"
    exit 1
fi

log "SUCCESS" "Privilèges root confirmés"

# Détection de l'environnement
detect_tactical_rmm

# Détection des URLs si non fournies
if [ -z "$DETECTED_API_URL" ] || [ "$DETECTED_API_URL" = "https://" ]; then
    detect_api_url
fi
if [ -z "$DETECTED_MESH_URL" ]; then
    detect_mesh_url
fi

# Vérification installation existante
check_existing_installation

# Création des sauvegardes
create_backup

# Installation principale
install_linux_deployments
fix_imports
set_permissions
configure_django
configure_urls
run_migrations
restart_services
import_monitoring_scripts

# Affichage du résumé
show_completion_summary

log "INFO" "Installation automatisée terminée avec succès"

exit 0