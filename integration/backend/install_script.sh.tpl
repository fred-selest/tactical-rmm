#!/bin/bash
#
# Script d'installation automatique de l'agent Tactical RMM pour Linux
# Généré automatiquement - Ne pas modifier
#
# Client: {{CLIENT_NAME_COMMENT}}
# Site: {{SITE_NAME_COMMENT}}
# Type: {{AGENT_TYPE_COMMENT}}
# Architecture: {{ARCH_COMMENT}}
# Date d'expiration: {{EXPIRES_AT}}
#

set -euo pipefail

CLIENT_NAME={{CLIENT_NAME}}
SITE_NAME={{SITE_NAME}}
AGENT_TYPE={{AGENT_TYPE}}
BASE_SCRIPT_URL={{BASE_SCRIPT_URL}}
MESH_URL={{MESH_URL}}
API_URL={{API_URL}}
CLIENT_ID={{CLIENT_ID}}
SITE_ID={{SITE_ID}}
AUTH_KEY={{AUTH_KEY}}
CALLBACK_URL={{CALLBACK_URL}}
ONE_TIME_TOKEN={{ONE_TIME_TOKEN}}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

printf '%b\n' "${GREEN}========================================${NC}"
printf '%b\n' "${GREEN}Installation de l'agent Tactical RMM${NC}"
printf '%b\n' "${GREEN}========================================${NC}"
printf '\nClient: %s\nSite: %s\nType: %s\n\n' "$CLIENT_NAME" "$SITE_NAME" "$AGENT_TYPE"

if [ "$EUID" -ne 0 ]; then
    printf '%b\n' "${RED}Ce script doit être exécuté en tant que root${NC}"
    echo "Utilisez: sudo $0"
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
INSTALLER="$WORKDIR/rmmagent-install.sh"

notify() {
    curl -fsS -X POST "$CALLBACK_URL" \
        --data-urlencode "hostname=$(hostname)" \
        --data-urlencode "status=$1" \
        --data-urlencode "one_time_token=$ONE_TIME_TOKEN" >/dev/null || true
}

printf '%b\n' "${YELLOW}Téléchargement du script d'installation...${NC}"
if ! wget -q "$BASE_SCRIPT_URL" -O "$INSTALLER"; then
    printf '%b\n' "${RED}Erreur: Impossible de télécharger le script d'installation${NC}"
    notify failed
    exit 1
fi
chmod 700 "$INSTALLER"

printf '%b\n' "${YELLOW}Installation de l'agent...${NC}"
if "$INSTALLER" install "$MESH_URL" "$API_URL" "$CLIENT_ID" "$SITE_ID" "$AUTH_KEY" "$AGENT_TYPE"; then
    printf '%b\n' "${GREEN}Installation terminée avec succès !${NC}"
    notify success
    echo ""
    echo "L'agent devrait apparaître dans le dashboard dans quelques instants."
    printf 'Vérifiez dans: %s > %s\n' "$CLIENT_NAME" "$SITE_NAME"
else
    printf '%b\n' "${RED}Erreur lors de l'installation${NC}"
    notify failed
    exit 1
fi

echo ""
printf '%b\n' "${GREEN}========================================${NC}"
printf '%b\n' "${GREEN}Installation terminée${NC}"
printf '%b\n' "${GREEN}========================================${NC}"
