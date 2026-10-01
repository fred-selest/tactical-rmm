#!/bin/bash
# Tests fonctionnels pour les correctifs de idempotence.
# Extrait insert_after_anchor/configure_urls/configure_django de
# install-automated.sh et les exerce sur des fichiers de test.
#
# Usage: bash .test-hardening.sh
# Aucun effet de bord : tout se passe dans un mktemp -d.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/install-automated.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
ko()   { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# --- Harnais minimal ---------------------------------------------------
LOG_FILE="$TMP/test.log"
log() { :; }
print_header() { :; }

# Extraction des trois fonctions sous test depuis le vrai script.
awk '/^insert_after_anchor\(\) \{/,/^\}/' "$SOURCE" >  "$TMP/func_anchor.sh"
awk '/^configure_urls\(\) \{/,/^\}/'      "$SOURCE" >> "$TMP/func_anchor.sh"
awk '/^configure_django\(\) \{/,/^\}/'     "$SOURCE" >> "$TMP/func_anchor.sh"

for f in func_anchor; do
  if ! bash -n "$TMP/$f.sh" 2>/dev/null; then
    printf '\033[31mExtraction impossible ou syntaxe invalide dans %s.sh\033[0m\n' "$f"
    exit 1
  fi
done
# shellcheck disable=SC1090
source "$TMP/func_anchor.sh"

RMM_PATH="$TMP/rmm"
mkdir -p "$RMM_PATH/tacticalrmm"

# --- Fabriques de test -------------------------------------------------
make_urls_standard() {
  cat > "$RMM_PATH/tacticalrmm/urls.py" <<'PY'
from django.urls import path, include
from . import views

urlpatterns = [
    path("api/v3/", include("apiv3.urls")),
    path("", include("core.urls")),
]
PY
}

make_urls_foreign_format() {
  # Formatage qui ne correspond PAS à l'ancre attendue.
  cat > "$RMM_PATH/tacticalrmm/urls.py" <<'PY'
from django.urls import path, include
urlpatterns = [
    path('api/v3/', include('apiv3.urls')),
]
PY
}

make_settings_ee_sso() {
  cat > "$RMM_PATH/tacticalrmm/settings.py" <<'PY'
INSTALLED_APPS = [
    "apiv3",
    "ee.sso",
    "scripts",
]
PY
}

make_settings_no_anchor() {
  # Aucun bloc INSTALLED_APPS, aucune entrée ee.sso ni apiv3 : plus aucune
  # ancre exploitable. L'ancien code loguait SUCCESS sans rien faire.
  cat > "$RMM_PATH/tacticalrmm/settings.py" <<'PY'
SECRET_KEY = "x"
ALLOWED_HOSTS = ["*"]
DATABASES = {}
PY
}

reset_rmm() { rm -rf "$RMM_PATH"; mkdir -p "$RMM_PATH/tacticalrmm"; }

# --- Test 1 : urls.py au format attendu, 1re exécution ----------------
printf '\n\033[1mTest 1 — configure_urls : insertion initiale\033[0m\n'
reset_rmm; make_urls_standard
if ( configure_urls ) 2>/dev/null; then
  if grep -qF 'path("api/v3/", include("linux_deployments.urls"))' "$RMM_PATH/tacticalrmm/urls.py" \
  && grep -qF 'path("", include("linux_deployments.urls"))' "$RMM_PATH/tacticalrmm/urls.py"; then
    ok "les deux URLs sont insérées"
  else
    ko "URL(s) manquante(s) après insertion"
  fi
else
  ko "configure_urls a échoué à tort"
fi

# --- Test 2 : idempotence ----------------------------------------------
printf '\n\033[1mTest 2 — configure_urls : idempotence (2e, 3e exécution)\033[0m\n'
BEFORE=$(md5sum "$RMM_PATH/tacticalrmm/urls.py" | awk '{print $1}')
( configure_urls ) 2>/dev/null
( configure_urls ) 2>/dev/null
AFTER=$(md5sum "$RMM_PATH/tacticalrmm/urls.py" | awk '{print $1}')
if [ "$BEFORE" = "$AFTER" ]; then
  ok "urls.py inchangé après réexécutions"
else
  ko "urls.py a été modifié à tort"
fi
NB=$(grep -cF 'include("linux_deployments.urls")' "$RMM_PATH/tacticalrmm/urls.py")
[ "$NB" -eq 2 ] && ok "exactement 2 inclusions linux_deployments" || ko "$NB inclusions (attendu 2)"

# --- Test 3 : ancre absente -> échec explicite, pas faux succès -------
printf '\n\033[1mTest 3 — configure_urls : ancre absente = échec bruyant\033[0m\n'
reset_rmm; make_urls_foreign_format
OUT=$( ( configure_urls ) 2>&1 ); RC=$?
if [ "$RC" -ne 0 ]; then
  ok "sortie non nulle (l'ancien code loguait 'SUCCESS' sans rien insérer)"
else
  ko "configure_urls a renvoyé 0 alors que l'ancre ne matche pas"
fi
if grep -qF 'linux_deployments' "$RMM_PATH/tacticalrmm/urls.py"; then
  ko "le fichier a été altéré alors que l'ancre était absente"
else
  ok "urls.py laissé intact"
fi

# --- Test 4 : settings.py avec ancre ee.sso ---------------------------
printf '\n\033[1mTest 4 — configure_django : ancre ee.sso\033[0m\n'
reset_rmm; make_settings_ee_sso
if ( configure_django ) 2>/dev/null && grep -qF '"linux_deployments"' "$RMM_PATH/tacticalrmm/settings.py"; then
  ok "linux_deployments ajouté à INSTALLED_APPS"
else
  ko "échec de l'ajout à INSTALLED_APPS"
fi
NB=$(grep -cF '"linux_deployments"' "$RMM_PATH/tacticalrmm/settings.py")
[ "$NB" -eq 1 ] && ok "une seule occurrence" || ko "$NB occurrences (doublon)"

# --- Test 5 : settings.py sans ancre connue ---------------------------
printf '\n\033[1mTest 5 — configure_django : aucune ancre = échec bruyant\033[0m\n'
reset_rmm; make_settings_no_anchor
OUT=$( ( configure_django ) 2>&1 ); RC=$?
if [ "$RC" -ne 0 ]; then
  ok "sortie non nulle (pas de faux succès)"
else
  ko "configure_django a renvoyé 0 sans ancre"
fi
grep -qF '"linux_deployments"' "$RMM_PATH/tacticalrmm/settings.py" \
  && ko "insertion fantôme" || ok "settings.py laissé intact"

# --- Test 6 : urls.py sans le fichier ----------------------------------
printf '\n\033[1mTest 6 — configure_urls : urls.py absent\033[0m\n'
reset_rmm
OUT=$( ( configure_urls ) 2>&1 ); RC=$?
[ "$RC" -ne 0 ] && ok "échec propre si urls.py est absent" || ko "pas d'erreur sur urls.py absent"

# --- Test 7 : urls.py déjà configuré avec un AUTRE formatage -----------
# Régression : un garde par ligne exacte réinsérait des doublons ici.
printf '\n\033[1mTest 7 — configure_urls : déjà configuré (guillemets simples) = pas de doublon\033[0m\n'
reset_rmm
cat > "$RMM_PATH/tacticalrmm/urls.py" <<'PY'
from django.urls import path, include
urlpatterns = [
    path("api/v3/", include("apiv3.urls")),
    path('api/v3/', include('linux_deployments.urls')),
    path('', include('linux_deployments.urls')),
]
PY
BEFORE=$(md5sum "$RMM_PATH/tacticalrmm/urls.py" | awk '{print $1}')
( configure_urls ) 2>/dev/null
AFTER=$(md5sum "$RMM_PATH/tacticalrmm/urls.py" | awk '{print $1}')
NB=$(grep -cF 'linux_deployments.urls' "$RMM_PATH/tacticalrmm/urls.py")
if [ "$BEFORE" = "$AFTER" ]; then ok "urls.py inchangé (aucune insertion)"; else ko "urls.py modifié alors qu'il était déjà configuré"; fi
[ "$NB" -eq 2 ] && ok "toujours 2 occurrences" || ko "$NB occurrences (doublons introduits)"

# --- Test 8 : configuration PARTIELLE -> échec, pas de doublon ---------
printf '\n\033[1mTest 8 — configure_urls : configuration partielle = échec bruyant\033[0m\n'
reset_rmm
cat > "$RMM_PATH/tacticalrmm/urls.py" <<'PY'
from django.urls import path, include
urlpatterns = [
    path("api/v3/", include("apiv3.urls")),
    path("api/v3/", include("linux_deployments.urls")),
]
PY
BEFORE=$(md5sum "$RMM_PATH/tacticalrmm/urls.py" | awk '{print $1}')
( configure_urls ) >/dev/null 2>&1; RC=$?
AFTER=$(md5sum "$RMM_PATH/tacticalrmm/urls.py" | awk '{print $1}')
[ "$RC" -ne 0 ] && ok "sortie non nulle sur config partielle" || ko "config partielle acceptée silencieusement"
[ "$BEFORE" = "$AFTER" ] && ok "urls.py laissé intact (pas de doublon)" || ko "urls.py altéré"

# --- Test 9 : settings.py en guillemets simples -----------------------
printf '\n\033[1mTest 9 — configure_django : déjà présent (guillemets simples)\033[0m\n'
reset_rmm
cat > "$RMM_PATH/tacticalrmm/settings.py" <<'PY'
INSTALLED_APPS = [
    "apiv3",
    'linux_deployments',
]
PY
BEFORE=$(md5sum "$RMM_PATH/tacticalrmm/settings.py" | awk '{print $1}')
( configure_django ) >/dev/null 2>&1
AFTER=$(md5sum "$RMM_PATH/tacticalrmm/settings.py" | awk '{print $1}')
NB=$(grep -cE "['\"]linux_deployments['\"]" "$RMM_PATH/tacticalrmm/settings.py")
if [ "$BEFORE" = "$AFTER" ]; then ok "settings.py inchangé"; else ko "settings.py modifié alors qu'il était déjà configuré"; fi
[ "$NB" -eq 1 ] && ok "toujours 1 occurrence" || ko "$NB occurrences (doublon)"

# --- Test 10 : ancre présente en MULTIPLE occurrences ------------------
printf '\n\033[1mTest 10 — insertion unique même si l’ancre apparaît 2 fois\033[0m\n'
reset_rmm
cat > "$RMM_PATH/tacticalrmm/urls.py" <<'PY'
from django.urls import path, include
urlpatterns = [
    path("api/v3/", include("apiv3.urls")),
    path("api/v3/", include("apiv3.urls")),
]
PY
( configure_urls ) >/dev/null 2>&1
NB=$(grep -cF 'linux_deployments.urls' "$RMM_PATH/tacticalrmm/urls.py")
[ "$NB" -eq 2 ] && ok "2 insertions (1 par URL attendue), pas 4" || ko "$NB insertions (doublon via ancre multiple)"

# --- Test 11 : ancre SANS virgule finale (dernier élément de la liste) --
printf '\n\033[1mTest 11 — ancre sans virgule finale : insertion ET virgule correctes\033[0m\n'
reset_rmm
cat > "$RMM_PATH/tacticalrmm/urls.py" <<'PY'
from django.urls import path, include
urlpatterns = [
    path("", include("core.urls")),
    path("api/v3/", include("apiv3.urls"))
]
PY
( configure_urls ) >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "pas d'abort sur urls.py valide sans virgule" || ko "abort (RC=$RC)"
NB=$(grep -cF 'linux_deployments.urls' "$RMM_PATH/tacticalrmm/urls.py")
[ "$NB" -eq 2 ] && ok "2 URLs insérées" || ko "$NB URLs insérées"
if python3 -c "import ast;ast.parse(open('$RMM_PATH/tacticalrmm/urls.py').read())" 2>/dev/null; then
  ok "urls.py reste du Python valide"
else
  ko "urls.py est devenu syntaxiquement INVALIDE"
fi

# --- Test 12 : même chose côté settings.py ------------------------------
printf '\n\033[1mTest 12 — INSTALLED_APPS en dernière position (virgule gérée)\033[0m\n'
reset_rmm
cat > "$RMM_PATH/tacticalrmm/settings.py" <<'PY'
INSTALLED_APPS = [
    "django.contrib.auth",
    "apiv3"
]
PY
( configure_django ) >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "insertion réussie" || ko "échec (RC=$RC)"
if python3 -c "import ast;ast.parse(open('$RMM_PATH/tacticalrmm/settings.py').read())" 2>/dev/null; then
  ok "settings.py reste du Python valide"
else
  ko "settings.py syntaxiquement INVALIDE"
fi

# --- Bilan -------------------------------------------------------------
printf '\n\033[1m%s\033[0m\n' "──────────────────────────────"
printf '  \033[32m%d passés\033[0m, ' "$PASS"
if [ "$FAIL" -gt 0 ]; then
  printf '\033[31m%d échecs\033[0m\n' "$FAIL"
  exit 1
fi
printf '\033[32m0 échec\033[0m\n'
exit 0
