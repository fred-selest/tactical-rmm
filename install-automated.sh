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
BACKUP_ROOT="/root/tactical-rmm-backups"
ROLLBACK_ARMED=false
ROLLBACK_DIR=""
BACKUP_RETENTION_DAYS="${TACTICAL_BACKUP_RETENTION_DAYS:-14}"
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

    BACKUP_DIR="$BACKUP_ROOT/automated-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    # Rétention : sans purge, /root/tactical-rmm-backups/ grossit à chaque
    # exécution et contient maintenant une copie complète de linux_deployments/.
    log "STEP" "Purge des sauvegardes de plus de ${BACKUP_RETENTION_DAYS} jours..."
    if [ -d "$BACKUP_ROOT" ]; then
        find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime "+$BACKUP_RETENTION_DAYS" \
            -exec rm -rf {} + 2>/dev/null || true
        LEFT=$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        log "INFO" "Sauvegardes conservées : $LEFT"
    fi

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

    # Sauvegarder l'application linux_deployments (elle est écrasée à chaque install)
    if [ -d "$RMM_PATH/linux_deployments" ]; then
        cp -a "$RMM_PATH/linux_deployments" "$BACKUP_DIR/linux_deployments"
        log "SUCCESS" "linux_deployments/ sauvegardé"
    fi

    # Sauvegarde de la base avant migrations : les migrations sont
    # irréversibles, une sauvegarde fichier seule ne permet pas de revenir
    # en arrière sur le schéma. Best-effort : on ne bloque pas l'install.
    if command -v pg_dump >/dev/null 2>&1; then
        DB_FILE="$BACKUP_DIR/db-$(date +%Y%m%d-%H%M%S).sql.gz"
        if sudo -u postgres pg_dump tactical > "$DB_FILE" 2>/dev/null \
           || pg_dump -d tactical > "$DB_FILE" 2>/dev/null; then
            gzip -f "$DB_FILE" 2>/dev/null || true
            log "SUCCESS" "Base sauvegardée : $DB_FILE"
        else
            rm -f "$DB_FILE"
            log "WARNING" "Sauvegarde de la base impossible (pg_dump)"
        fi
    else
        log "WARNING" "pg_dump absent : pas de sauvegarde de la base"
    fi

    # Script de restauration.
    #
    # Heredoc QUOTÉ ('EOF') : tout est évalué à l'exécution de RESTORE.sh, pas
    # à la génération. Avec <<EOF non quoté, ${BASH_SOURCE[0]} valait
    # install-automated.sh au moment de la génération, BACKUP_DIR pointait
    # donc sur le dépôt au lieu du backup, et le script annonçait
    # « Restauration terminée » sans rien restaurer.
    #
    # RMM_PATH est le seul truc propre à l'hôte : on l'injecte après coup.
    cat > "$BACKUP_DIR/RESTORE.sh" <<'RESTORE_EOF'
#!/bin/bash
# Restaure l'état sauvegardé de l'intégration Linux Deployments.
set -u
RMM_PATH="__RMM_PATH__"
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail=0

if [ -f "$BACKUP_DIR/settings.py" ]; then
    cp "$BACKUP_DIR/settings.py" "$RMM_PATH/tacticalrmm/settings.py" \
        && echo "settings.py restauré" || { echo "ÉCHEC settings.py"; fail=1; }
else
    echo "ABSENT $BACKUP_DIR/settings.py"; fail=1
fi

if [ -f "$BACKUP_DIR/urls.py" ]; then
    cp "$BACKUP_DIR/urls.py" "$RMM_PATH/tacticalrmm/urls.py" \
        && echo "urls.py restauré" || { echo "ÉCHEC urls.py"; fail=1; }
else
    echo "ABSENT $BACKUP_DIR/urls.py"; fail=1
fi

if [ -d "$BACKUP_DIR/linux_deployments" ]; then
    rm -rf "$RMM_PATH/linux_deployments"
    cp -a "$BACKUP_DIR/linux_deployments" "$RMM_PATH/linux_deployments" \
        && echo "linux_deployments/ restauré" || { echo "ÉCHEC linux_deployments"; fail=1; }
else
    echo "ABSENT $BACKUP_DIR/linux_deployments (rien à restaurer)"; fail=1
fi

systemctl restart rmm.service || { echo "ÉCHEC redémarrage rmm.service"; fail=1; }

if [ "$fail" -eq 0 ]; then
    echo "Restauration terminée."
else
    echo "Restauration INCOMPLÈTE — vérifier manuellement $RMM_PATH"
fi
exit "$fail"
RESTORE_EOF
    sed -i "s|__RMM_PATH__|${RMM_PATH}|" "$BACKUP_DIR/RESTORE.sh"
    chmod +x "$BACKUP_DIR/RESTORE.sh"

    # Auto-test : on vérifie que le script généré pointe bien sur le backup.
    if grep -q "__RMM_PATH__" "$BACKUP_DIR/RESTORE.sh"; then
        log "ERROR" "RESTORE.sh mal généré (RMM_PATH non substitué)"
        exit 1
    fi
    if ! bash -n "$BACKUP_DIR/RESTORE.sh"; then
        log "ERROR" "RESTORE.sh contient une erreur de syntaxe"
        exit 1
    fi
    log "SUCCESS" "Script de restauration créé et vérifié : $BACKUP_DIR/RESTORE.sh"

    # Arme le rollback : tant que le service n'a pas été redémarré avec le
    # nouveau code, un échec doit tout remettre en l'état.
    ROLLBACK_ARMED=true
    ROLLBACK_DIR="$BACKUP_DIR"

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

insert_after_anchor() {
    # Insère une ligne après la PREMIÈRE ligne machant une ancre (ERE).
    # Retourne 0 SEULEMENT si le fichier a réellement changé.
    #
    # Trois pièges corrigés ici :
    #  - un sed qui ne matche rien renvoie 0 : on ne peut pas se fier à son code
    #    de sortie, d'où la comparaison md5 avant/après ;
    #  - `/ancre/a` insère après CHAQUE occurrence, ce qui créait des doublons
    #    quand l'ancre apparaissait plusieurs fois ;
    #  - faire passer la regex par le délimiteur / de sed casse dès qu'elle
    #    contient un slash. On localise la ligne via grep -m1, puis on insère
    #    par numéro de ligne.
    local file="$1" anchor="$2" line="$3"
    local before after lineno anchor_line
    if [ ! -f "$file" ]; then
        return 1
    fi
    lineno=$(grep -n -m1 -E "$anchor" "$file" 2>/dev/null | cut -d: -f1)
    if [ -z "$lineno" ]; then
        return 1
    fi
    before=$(md5sum "$file" | awk '{print $1}')

    # Si la ligne d'ancre est une entrée de liste sans virgule finale
    # (par exemple le dernier path(...) d'un urlpatterns), insérer après elle
    # produirait un fichier syntaxiquement invalide. On la virgule d'abord.
    # Seules les lignes terminant par un appel fermé sont concernées : une
    # ligne d'ouverture (INSTALLED_APPS = [) ne doit surtout pas être
    # virgulée.
    anchor_line=$(sed -n "${lineno}p" "$file" | sed 's/[[:space:]]*$//')
    case "$anchor_line" in
        *,|*,]*) : ;;
        *")"|*")]"*) sed -i "${lineno}s/\$/,/" "$file" ;;
        *) : ;;
    esac

    sed -i "${lineno}a\\${line}" "$file"
    after=$(md5sum "$file" | awk '{print $1}')
    [ "$before" != "$after" ]
}

configure_django() {
    print_header "Configuration de Django"

    log "STEP" "Configuration INSTALLED_APPS..."
    local settings_file="$RMM_PATH/tacticalrmm/settings.py"
    local found
    found=$(grep -cE "['\"]linux_deployments['\"]" "$settings_file" || true)

    if [ "$found" -eq 0 ]; then
        # Ancre sur l'OUVERTURE du bloc INSTALLED_APPS, pas sur une entrée.
        # Chercher "apiv3" ou "ee.sso" pouvait matcher une autre liste du
        # fichier et y insérer l'application au mauvais endroit.
        if insert_after_anchor "$settings_file" 'INSTALLED_APPS[[:space:]]*=[[:space:]]*\[' \
            '    "linux_deployments",'; then
            log "SUCCESS" "linux_deployments ajouté à INSTALLED_APPS"
        elif insert_after_anchor "$settings_file" '"ee\.sso",' '    "linux_deployments",' \
          || insert_after_anchor "$settings_file" '"apiv3",' '    "linux_deployments",'; then
            log "SUCCESS" "linux_deployments ajouté à INSTALLED_APPS (ancre de repli)"
        else
            log "ERROR" "Impossible d'insérer \"linux_deployments\" dans INSTALLED_APPS."
            log "ERROR" "Aucune ancre trouvée (INSTALLED_APPS = [ / ee.sso / apiv3)."
            exit 1
        fi
        found=$(grep -cE "['\"]linux_deployments['\"]" "$settings_file" || true)
    elif [ "$found" -gt 1 ]; then
        log "ERROR" "linux_deployments apparaît $found fois dans INSTALLED_APPS (doublon ?)"
        exit 1
    else
        log "INFO" "linux_deployments déjà présent dans INSTALLED_APPS"
    fi
}

configure_urls() {
    print_header "Configuration des URLs"

    local urls_file="$RMM_PATH/tacticalrmm/urls.py"
    local expected=2
    local found

    if [ ! -f "$urls_file" ]; then
        log "ERROR" "urls.py introuvable : $urls_file"
        exit 1
    fi

    # On compte les occurrences plutôt que de comparer des lignes exactes.
    # Un garde par ligne exacte réinsérait des doublons sur un urls.py déjà
    # configuré avec un autre formatage (guillemets simples, espaces).
    found=$(grep -cF 'linux_deployments.urls' "$urls_file" || true)

    if [ "$found" -eq 0 ]; then
        log "STEP" "Aucune URL linux_deployments : insertion..."
        if insert_after_anchor "$urls_file" 'path\("api/v3/", include\("apiv3\.urls"\)\),?' \
            '    path("api/v3/", include("linux_deployments.urls")),'; then
            log "SUCCESS" "URL /api/v3/ linux_deployments ajoutée"
        else
            log "ERROR" "Ancre 'path(\"api/v3/\", include(\"apiv3.urls\")),' introuvable dans urls.py."
            log "ERROR" "Adapter l'ancre dans configure_urls, ou ajouter manuellement :"
            log "ERROR" "    path(\"api/v3/\", include(\"linux_deployments.urls\")),"
            exit 1
        fi

        if insert_after_anchor "$urls_file" 'path\("api/v3/", include\("apiv3\.urls"\)\),?' \
            '    path("", include("linux_deployments.urls")),'; then
            log "SUCCESS" "URL publique linux_deployments ajoutée"
        else
            log "ERROR" "Impossible d'insérer l'URL publique linux_deployments dans urls.py."
            log "ERROR" "Sans elle, /clients/{uuid}/deploy/linux/ ne fonctionnera pas."
            exit 1
        fi

        found=$(grep -cF 'linux_deployments.urls' "$urls_file" || true)
    elif [ "$found" -ge "$expected" ]; then
        log "INFO" "URLs linux_deployments déjà configurées ($found occurrence(s))"
    else
        # Ni 0 ni 2 : configuration ambiguë. Insérer créerait un doublon,
        # ne rien faire laisserait l'intégration à moitié câblée.
        log "ERROR" "Configuration partielle détectée dans urls.py : $found occurrence(s) de"
        log "ERROR" "'linux_deployments.urls', $expected attendues. Insertion automatique abandonnée"
        log "ERROR" "pour éviter un doublon. À vérifier manuellement dans : $urls_file"
        exit 1
    fi

    # Vérification finale
    if [ "$found" -ge "$expected" ]; then
        log "SUCCESS" "URLs linux_deployments configurées et vérifiées ($found occurrence(s))"
    else
        log "ERROR" "Vérification finale échouée : $found occurrence(s), $expected attendues"
        exit 1
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

    if ! sudo -u tactical $PYTHON_BIN -c "import django; print('Django accessible')" > /dev/null 2>&1; then
        log "WARNING" "Django non accessible, importation des scripts ignorée"
        return 0
    fi

    # Délègue à l'importeur canonique du dépôt. Ce script était auparavant
    # régénéré dans /tmp via un heredoc : la copie avait divergé (scripts
    # Synology absents), si bien que les deux chemins n'importaient pas le
    # même jeu de scripts.
    local importer="$SCRIPT_DIR/import-monitoring-scripts.py"
    if [ ! -f "$importer" ]; then
        log "ERROR" "Importeur introuvable : $importer"
        return 1
    fi

    log "STEP" "Importation des scripts de surveillance..."
    local out
    out=$(cd "$RMM_PATH" && sudo -u tactical $PYTHON_BIN "$importer" "$SCRIPT_DIR" "$RMM_PATH" 2>&1) || true
    printf '%s\n' "$out" >> "$LOG_FILE"

    local line imported missing
    line=$(printf '%s\n' "$out" | grep '^RESULTAT_IMPORT ' | tail -1)
    if [ -n "$line" ]; then
        imported=$(printf '%s' "$line" | awk '{print $2}')
        missing=$(printf '%s' "$line" | awk '{print $3}')
        if [ "${missing:-0}" -gt 0 ]; then
            log "WARNING" "$imported scripts importés, $missing introuvables sur le disque :"
            printf '%s\n' "$out" | grep '^MANQUANT ' | sed 's/^MANQUANT /  - /' | while read -r m; do
                log "WARNING" "$m"
            done
            return 1
        fi
        log "SUCCESS" "$imported scripts de surveillance importés"
    else
        log "ERROR" "L'importeur n'a pas produit de compte rendu. Échec de l'import."
        printf '%s\n' "$out" | tail -10 | while read -r l; do
            log "ERROR" "$l"
        done
        return 1
    fi
}

# === GESTION DE L'ECHEC ===
#
# Sans cela, un exit 1 apres install_linux_deployments laissait les modeles
# remplaces sur disque sans que run_migrations n'ait applique le schema, ni
# restart_services n'ait recharge le service. On restaure automatiquement
# depuis la sauvegarde prise en debut de run.
on_exit() {
    EXIT_CODE=$?
    if [ "$EXIT_CODE" -ne 0 ] && [ "$ROLLBACK_ARMED" = true ]; then
        log "ERROR" "Échec (code $EXIT_CODE) — restauration automatique depuis $ROLLBACK_DIR"
        if ! "$ROLLBACK_DIR/RESTORE.sh"; then
            log "ERROR" "Restauration automatique incomplète. À traiter manuellement."
        fi
    fi
    # exit et non return : sans cela le trap masquait l'échec et le script
    # sortait quand même en 0, ce qui annulait la détection côté appelant.
    exit "$EXIT_CODE"
}
trap on_exit EXIT

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

    clear 2>/dev/null || true
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
    clear 2>/dev/null || true
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

# Le nouveau code est charge et le service est actif : plus de rollback
# automatique, un echec ulterieur ne doit pas tout annuler.
ROLLBACK_ARMED=false

# L'import des scripts de surveillance est fait APRÈS le redémarrage : un
# échec ici ne doit pas laisser l'installation dans un état ambigu. On le
# mémorise et on le remonte explicitement plutôt que d'annoncer un succès.
IMPORT_FAILED=false
import_monitoring_scripts || IMPORT_FAILED=true

# Affichage du résumé
show_completion_summary

if [ "$IMPORT_FAILED" = true ]; then
    print_header "⚠️  Installation terminée, importation des scripts en échec"
    log "ERROR" "L'intégration linux_deployments est installée et le service est actif,"
    log "ERROR" "mais les scripts de surveillance n'ont pas été importés en base."
    log "ERROR" "Relancer manuellement :"
    log "ERROR" "    sudo -u tactical $PYTHON_BIN $SCRIPT_DIR/import-monitoring-scripts.py $SCRIPT_DIR $RMM_PATH"
    exit 1
fi

log "INFO" "Installation automatisée terminée avec succès"

exit 0
