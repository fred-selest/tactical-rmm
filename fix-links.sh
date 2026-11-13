#!/usr/bin/env bash
# fix-links.sh — répare les liens Markdown cassés vers les anciens noms
# de fichiers, antérieurs à la scission _PUBLIC / _PRIVATE du dépôt.
#
# Le dépôt a été scindé en variantes publiques et privées, et nettoyé, mais
# les liens pointaient encore vers les noms disparus. 24 liens cassés.
#
# Idempotent : relancé sur un dépôt déjà corrigé, il ne change rien.
# Lecture seule par défaut ; --apply écrit les fichiers.
set -euo pipefail
cd "$(dirname "$0")"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

# Cibles validées : INSTALLATION_GUIDE décrit « rmm.votre-domaine.com »
# (public), INSTALLATION_PRIVATE décrit « rmm.selest.info » (privé).
apply() {  # fichier ancien_cible nouvelle_cible ...
    local f="$1"
    [ -f "$f" ] || { echo "  ! absent, ignoré : $f"; return; }
    local n=0
    shift
    for pair in "$@"; do
        local old="${pair%%=>*}" new="${pair##*=>}"
        local c
        c=$(grep -cF "]($old)" "$f" || true)
        if [ "$c" -gt 0 ]; then
            n=$((n + c))
            if [ $APPLY -eq 1 ]; then
                python3 - "$f" "$old" "$new" <<'PY'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace('](' + old + ')', '](' + new + ')'))
PY
            fi
        fi
    done
    echo "  $f : $n lien(s)"
}

echo "Liens cassés à corriger :"
apply START_HERE_PUBLIC.md \
  "START_HERE.md=>START_HERE_PUBLIC.md" \
  "install-interactive.sh=>install-interactive-public.sh" \
  "INSTALLATION_RMM_SELEST_INFO.md=>INSTALLATION_GUIDE.md" \
  "GUIDE_UTILISATION_ADMIN.md=>GUIDE_UTILISATION_ADMIN_PUBLIC.md" \
  "test-installation.sh=>test-installation-public.sh"

apply START_HERE_PRIVATE.md \
  "START_HERE.md=>START_HERE_PRIVATE.md" \
  "install-interactive.sh=>install-interactive-private.sh" \
  "INSTALLATION_RMM_SELEST_INFO.md=>INSTALLATION_PRIVATE.md" \
  "GUIDE_UTILISATION_ADMIN.md=>GUIDE_UTILISATION_ADMIN_PRIVATE.md" \
  "test-installation.sh=>test-installation-private.sh" \
  "QUICK_INSTALL.md=>INSTALLATION_PRIVATE.md"

apply GUIDE_UTILISATION_ADMIN_PRIVATE.md \
  "QUICK_INSTALL.md=>INSTALLATION_PRIVATE.md" \
  "INSTALLATION_RMM_SELEST_INFO.md=>INSTALLATION_PRIVATE.md"

apply GUIDE_UTILISATION_ADMIN_PUBLIC.md \
  "INSTALLATION_RMM_SELEST_INFO.md=>INSTALLATION_GUIDE.md"

apply INSTALLATION_PRIVATE.md \
  "QUICK_INSTALL.md=>START_HERE_PRIVATE.md"

apply scripts/synology/README.md \
  "/SYNOLOGY_AGENT_INSTALL.md=>../../SYNOLOGY_AGENT_INSTALL.md"

if [ $APPLY -eq 0 ]; then
    echo
    echo "Simulation uniquement. Relancer avec --apply pour écrire."
    exit 0
fi
echo
echo "Fichiers écrits."
