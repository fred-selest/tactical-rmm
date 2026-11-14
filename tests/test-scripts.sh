#!/usr/bin/env bash
# =============================================================================
# test-scripts.sh — contrôle qualité des scripts shell du dépôt
#
# Exit 0 si tout passe, 1 sinon. Aucun `|| true` : un contrôle qui ne peut
# pas échouer ne contrôle rien.
#
# Chaque test correspond à un défaut réellement rencontré sur ce dépôt, pas à
# une bonne pratique théorique. La section Affectedé dit lequel.
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
PASS=0; FAIL=0; WARN=0

ok()   { PASS=$((PASS+1)); printf '  %s✓%s %s\n' "$GREEN" "$NC" "$1"; }
ko()   { FAIL=$((FAIL+1)); printf '  %s✗%s %s\n' "$RED" "$NC" "$1"; [ $# -gt 1 ] && printf '      %s\n' "$2"; }
warn() { WARN=$((WARN+1)); printf '  %s!%s %s\n' "$YELLOW" "$NC" "$1"; }
head_() { printf '\n\033[1m── %s\033[0m\n' "$1"; }

# Liste les scripts versionnés, hors git et hors tests eux-mêmes
mapfile -t SCRIPTS < <(git ls-files '*.sh' 2>/dev/null | grep -v '^\.github/')
[ ${#SCRIPTS[@]} -gt 0 ] || mapfile -t SCRIPTS < <(find . -name '*.sh' -not -path './.git/*')

# -----------------------------------------------------------------------------
head_ "1. Syntaxe (bash -n)"
# Affecté : diag-rmm.sh v1, apostrophe non fermée dans ${VAR:-defaut} (ligne 45),
# diagnostic mort dès la section 1.
for f in "${SCRIPTS[@]}"; do
    err=$(bash -n "$f" 2>&1)
    if [ $? -eq 0 ]; then ok "$f"; else ko "$f" "$err"; fi
done

# -----------------------------------------------------------------------------
head_ "2. Aucun script vide"
# Affecté : check-cpu.sh faisait 0 octet sur main, et le Script Manager
# l'exécutait en production sans rien détecter.
for f in "${SCRIPTS[@]}"; do
    size=$(wc -c < "$f" 2>/dev/null || echo 0)
    if [ "$size" -lt 40 ]; then
        ko "$f : $size octets" "un script vidé s'exécute sans rien faire et renvoie 0"
    else
        ok "$f ($size o)"
    fi
done

# -----------------------------------------------------------------------------
head_ "3. Shebang suivi de code réel"
# Affecté : un fichier réduit à son shebang passe shellcheck sans
# commentaire. Ce test ferme cette voie.
for f in "${SCRIPTS[@]}"; do
    lines=$(grep -cvE '^[[:space:]]*(#.*)?$' "$f" 2>/dev/null || echo 0)
    first=$(head -1 "$f")
    if [ ! "${first#\#!}" != "$first" ]; then
        warn "$f : pas de shebang"
    elif [ "$lines" -le 1 ]; then
        ko "$f : shebang seule, aucun code" "visible uniquement ici, pas par shellcheck"
    else
        ok "$f"
    fi
done

# -----------------------------------------------------------------------------
head_ "4. Apostrophes interdites dans \${VAR:-défaut}"
# Affecté : bug exact qui a tué diag-rmm.sh. Dans une expansion de paramètre,
# bash reprend ses règles de quoting : l'apostrophe ouvre une chaîne qui
# avale le } et file jusqu'à la fin du fichier.
found=0
for f in "${SCRIPTS[@]}"; do
    while IFS= read -r line; do
        if printf '%s' "$line" | grep -qE '\$\{[A-Za-z_][A-Za-z0-9_]*:-[^}]*'"'"'[^}]*\}'; then
            ko "$f" "apostrophe dans un \${VAR:-defaut} : $line"
            found=1
        fi
    done < "$f"
done
[ $found -eq 0 ] && ok "aucun \${VAR:-defaut} contenant une apostrophe"

# -----------------------------------------------------------------------------
head_ "5. Dépendances déclarées dans les scripts de supervision"
# Affecté : bc, column et ip utilisés sans être garantis. Sur une image
# minimale, les scripts produisaient un rapport cassé en sortant en 0.
# AGENTS.md impose la détection et l'installation des dépendances.
check_dependencies_present=0
grep -ql 'check_dependencies' scripts/lib/common.sh 2>/dev/null && check_dependencies_present=1

for cmd in bc column; do
    users=$(grep -lE "[|][[:space:]]*$cmd([[:space:]]|$)" scripts/system/*.sh 2>/dev/null)
    if [ -n "$users" ]; then
        if [ $check_dependencies_present -eq 1 ]; then
            warn "$cmd utilisé dans : $(basename -a $users | tr '\n' ' ')" "détecté par check_dependencies()"
        else
            ko "$cmd utilisé sans détection" "$(basename -a $users | tr '\n' ' ')"
        fi
    else
        ok "aucun usage direct de $cmd"
    fi
done

# -----------------------------------------------------------------------------
head_ "6. Exécution réelle des scripts de supervision"
# Le seul contrôle qui détecte une dépendance manquante à l'exécution.
# Les codes de sortie 0/1/2 sont normaux (0=ok, 1=alerte, 2=critique) ;
# ce qui compte est l'absence de « command not found ».
export LOG_DIR="${TMPDIR:-/tmp}/trmm-selftest-logs"
mkdir -p "$LOG_DIR"
for f in scripts/system/*.sh; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in *update*|*install*) continue;; esac
    out=$(timeout 25 bash "$f" 2>&1)
    if printf '%s' "$out" | grep -q "command not found"; then
        miss=$(printf '%s' "$out" | grep "command not found" | sed 's/.*: //' | sort -u | tr '\n' ' ')
        ko "$(basename "$f")" "commandes manquantes : $miss"
    else
        ok "$(basename "$f") — aucune commande manquante"
    fi
done

# -----------------------------------------------------------------------------
head_ "7. Python compilable"
for f in $(git ls-files '*.py' 2>/dev/null | head -20); do
    if python3 -m py_compile "$f" 2>/dev/null; then ok "$f"; else ko "$f" "échec de compilation"; fi
done

# -----------------------------------------------------------------------------
head_ "8. Assertions de durcissement"
if [ -f .test-hardening.sh ]; then
    res=$(bash .test-hardening.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    echo "$res" | grep -qE '[1-9][0-9]* passés, 0 échec' \
        && ok "$(echo "$res" | grep -oE '[0-9]+ passés, [0-9]+ échec')" \
        || ko "assertions de durcissement" "$(echo "$res" | tail -5)"
else
    warn ".test-hardening.sh absent"
fi

# -----------------------------------------------------------------------------
head_ "8b. Mise à jour agent : rmmagent-linux.sh check et wrappers"
# Affecté : tactical-agent-updater.sh lisait la version via un chemin
# impossible (/etc/tacticalagent/.version) et `rmmagent -v` : version
# « inconnue », recompilation à chaque passage. update-tactical-agent.sh
# cherchait un tactical.sh qui n'existe nulle part. Agents factices : le test
# ne dépend ni de root ni d'un agent installé.
_stub=$(mktemp -d)
_target=$(sed -n 's/^AGENT_REF="${TACTICAL_AGENT_REF:-v\([0-9.]*\)}"$/\1/p' rmmagent-linux.sh)
mkstub() {
    printf '#!/bin/sh\n[ "$1" = -version ] && echo "Tactical RMM Agent: %s"\nexit 0\n' "$1" > "$_stub/a-$1"
    chmod +x "$_stub/a-$1"
}
expect_rc() {   # libellé, code attendu, commande...
    local label=$1 want=$2; shift 2
    "$@" >/dev/null 2>&1; local got=$?
    if [ "$got" -eq "$want" ]; then ok "$label (code $got)"; else ko "$label" "code $got, attendu $want"; fi
}
if [ -z "$_target" ]; then
    ko "AGENT_REF épinglé introuvable dans rmmagent-linux.sh"
else
    mkstub 1.0.0; mkstub "$_target"; mkstub 99.0.0
    printf '#!/bin/sh\necho garbage\n' > "$_stub/a-bad"; chmod +x "$_stub/a-bad"
    expect_rc "check : agent ancien -> MAJ"        10 env TACTICAL_AGENT_PATH="$_stub/a-1.0.0" bash rmmagent-linux.sh check
    expect_rc "check : agent = $_target -> à jour"  0 env TACTICAL_AGENT_PATH="$_stub/a-$_target" bash rmmagent-linux.sh check
    expect_rc "check : agent plus récent -> à jour" 0 env TACTICAL_AGENT_PATH="$_stub/a-99.0.0" bash rmmagent-linux.sh check
    expect_rc "check : version illisible"            2 env TACTICAL_AGENT_PATH="$_stub/a-bad" bash rmmagent-linux.sh check
    expect_rc "check : chemin imposé absent"         2 env TACTICAL_AGENT_PATH="$_stub/absent" bash rmmagent-linux.sh check
    _u="env TACTICAL_UPDATER_CONF=$_stub/none TACTICAL_UPDATER_LOG=$_stub/u.log TACTICAL_UPDATER_LOCK=$_stub/u.lock UPDATE_SCRIPT=$PWD/rmmagent-linux.sh"
    expect_rc "updater --check : agent ancien"      10 $_u TACTICAL_AGENT_PATH="$_stub/a-1.0.0" bash scripts/linux/auto-update/tactical-agent-updater.sh --check
    expect_rc "updater --check : agent à jour"       0 $_u TACTICAL_AGENT_PATH="$_stub/a-$_target" bash scripts/linux/auto-update/tactical-agent-updater.sh --check
    expect_rc "update-tactical-agent --dry-run : à jour" 0 env TACTICAL_AGENT_PATH="$_stub/a-$_target" bash scripts/system/update-tactical-agent.sh --dry-run
    # Hors commentaires : les en-têtes documentent les anciens défauts.
    if grep -hvE '^[[:space:]]*#' scripts/linux/auto-update/tactical-agent-updater.sh \
            scripts/system/update-tactical-agent.sh \
        | grep -qE 'YOUR_USER|/etc/tacticalagent/\.version|tactical\.sh|curl -k|no-check-certificate'; then
        ko "chemins morts ou TLS désactivé encore présents dans les scripts de mise à jour"
    else
        ok "aucun chemin mort ni TLS désactivé dans les scripts de mise à jour"
    fi
fi
rm -rf "$_stub"

# -----------------------------------------------------------------------------
head_ "9. ShellCheck — pas de nouvel avertissement"
# Affecté : diag-rmm.sh v4Mergé triggers were caught by bash -n but SC1073
# flagged a [ -d x 2>/dev/null ] that works in bash and in dash. Faux positif.
#
# Donc pas de règle « zéro avertissement » : 61 existent et sont pour la
# plupart bénins, la suite serait rouge à jamais. Ni « zéro SC107x », ce serait
# faux par construction.
#
# Une référence figée : un nouvel avertissement échoue, les connus passent.
# Pour en accepter un : ajouter sa signature dans tests/.shellcheck-baseline,
# en expliquant pourquoi dans la PR.
if ! command -v shellcheck >/dev/null 2>&1; then
    warn "shellcheck absent, test sauté"
elif [ ! -f tests/.shellcheck-baseline ]; then
    ko "tests/.shellcheck-baseline absent" "sans référence, impossible de distinguer nouveau et connu"
else
    cur=$(mktemp)
    git ls-files '*.sh' | xargs shellcheck --severity=warning -f gcc 2>/dev/null \
        | sed 's|^\./||; s|:[0-9]*:[0-9]*:|:|' | sort > "$cur"
    nknown=$(grep -vc '^#' tests/.shellcheck-baseline)
    nnew=$(comm -23 "$cur" <(grep -v '^#' tests/.shellcheck-baseline | sort) | grep -c . || true)
    if [ "$nnew" -eq 0 ]; then
        ok "aucun nouvel avertissement ($nknown connus, acceptés)"
        printf '      %s\n' "$(sed -n '4,6p' tests/.shellcheck-baseline | sed 's/^# /      /')"
    else
        ko "$nnew nouvel(s) avertissement(s) shellcheck"
        comm -23 "$cur" <(grep -v '^#' tests/.shellcheck-baseline | sort) | sed 's/^/      /'
    fi
    rm -f "$cur"
fi

# -----------------------------------------------------------------------------
printf '\n\033[1m%s\033[0m\n' "────────────────────────────────────────────"
printf '  %s%d passés\033[0m   %s%d échecs\033[0m   %s%d avertissements\033[0m\n' \
    "$GREEN" "$PASS" "$RED" "$FAIL" "$YELLOW" "$WARN"
printf '  %s\033[0m\n\n' "────────────────────────────────────────────"

[ "$FAIL" -eq 0 ] || exit 1
exit 0
