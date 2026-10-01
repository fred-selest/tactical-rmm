#!/usr/bin/env bash
# Diagnostic Tactical RMM + Mesh — lecture seule, ne modifie rien.
# Usage : sudo bash diag-rmm.sh
# Coller la sortie entière pour analyse.
#
# v3 : la v2 sélectionnait l'installation sur la seule existence du
# répertoire. Or /opt/tacticalrmm existe SANS manage.py : il gagne à tort,
# /rmm n'est jamais essayé, et les sections 4, 5, 8 et 9 sortent vides.

# NE PAS utiliser d'apostrophe dans un ${VAR:-defaut} : bash y reprend ses
# règles de quoting, le guillemet ouvre une chaîne qui avale le } et file
# jusqu'à la fin du fichier.

sep() { printf '\n════════ %s ════════\n' "$1"; }

# --- Localisation de l'installation -----------------------------------------
sep "1. VERSION TRMM"
RMM=""
for cand in /opt/tacticalrmm/api/tacticalrmm /rmm/api/tacticalrmm; do
    if [ -f "$cand/manage.py" ]; then RMM="$cand"; break; fi
done
# Repli : le dossier existe mais manage.py est ailleurs
if [ -z "$RMM" ]; then
    for cand in /opt/tacticalrmm/api/tacticalrmm /rmm/api/tacticalrmm; do
        [ -d "$cand" ] && RMM="$cand" && break
    done
    [ -n "$RMM" ] && echo "  ATTENTION: manage.py introuvable sous $RMM"
fi
if [ -z "$RMM" ]; then
    echo "  TRMM introuvable (cherché dans /opt/tacticalrmm et /rmm)"
    exit 1
fi
echo "  chemin retenu: $RMM"

# Ce qui existe réellement dans chaque arborescence : sans cela, impossible de
# savoir pourquoi un chemin l'emporte sur l'autre.
for d in /opt/tacticalrmm/api/tacticalrmm /rmm/api/tacticalrmm; do
    [ -d "$d" ] || continue
    printf '  %-34s manage.py=%s core/agent_linux.sh=%s\n' "$d" \
        "$([ -f "$d/manage.py" ] && echo OUI || echo non)" \
        "$([ -f "$d/core/agent_linux.sh" ] && echo OUI || echo non)"
done

# --- Localisation de l'interpréteur ----------------------------------------
echo "  -- interpréteur --"
PY=""
# Le PATH du service est l'information la plus fiable : c'est lui que le
# serveur utilise réellement pour lancer l'API.
SVC_PATH=""
if command -v systemctl >/dev/null 2>&1; then
    SVC_PATH=$(systemctl show rmm.service -p Environment --value 2>/dev/null \
        | tr ' ' '\n' | sed -n 's/^PATH=//p' | cut -d: -f1)
    [ -n "$SVC_PATH" ] && echo "  PATH rmm.service: $SVC_PATH"
fi

for cand in \
    ${SVC_PATH:+"$SVC_PATH/python"} \
    ${SVC_PATH:+"$SVC_PATH/python3"} \
    "$RMM/../env/bin/python" \
    "$RMM/../env/bin/python3" \
    /rmm/api/env/bin/python \
    /rmm/api/env/bin/python3 \
    /opt/tacticalrmm/api/env/bin/python \
    /usr/bin/python3 \
    /usr/bin/python
do
    if [ -x "$cand" ]; then PY="$cand"; break; fi
done
if [ -n "$PY" ]; then
    echo "  python: $PY  ($("$PY" -V 2>&1))"
else
    echo "  AUCUN interpréteur python trouvé"
fi

mm() {
    [ -z "$PY" ] && { echo "  (python introuvable, section ignorée)"; return 1; }
    [ -f "$RMM/manage.py" ] || { echo "  (manage.py absent de $RMM)"; return 1; }
    # manage.py veut la base de production : on bascule sous l'utilisateur
    # tactical quand on le peut. sudo peut être absent, et le script peut
    # être lancé sans root par erreur.
    local runner=()
    if [ "$(id -u)" -eq 0 ]; then
        if command -v sudo >/dev/null 2>&1 && id tactical >/dev/null 2>&1; then
            runner=(sudo -u tactical)
        else
            echo "  (sudo ou utilisateur tactical indisponible, exécution en root)"
        fi
    else
        echo "  (ATTENTION : lancé sans root, certains fichiers peuvent être illisibles)"
    fi
    "${runner[@]}" "$PY" "$RMM/manage.py" "$@" 2>&1 | sed 's/^/  /'
    return 0
}

echo "  -- version --"
mm version

# --- Mesh -------------------------------------------------------------------
sep "2. MESH CENTRAL"
if command -v systemctl >/dev/null 2>&1; then
    for unit in meshcentral mongod; do
        # is-active affiche "inactive" ET renvoie !=0 : sans ce cas, le
        # "|| echo absent" s'ajoute en doublon sous la vraie valeur.
        st=$(systemctl is-active "$unit" 2>/dev/null); rc=$?
        printf '  %s: %s\n' "$unit" "$([ $rc -eq 0 ] && echo "${st:-active}" || echo "${st:-absent}")"
    done
    echo "  -- services rmm --"
    for unit in rmm.service nginx rqworker; do
        st=$(systemctl is-active "$unit" 2>/dev/null); rc=$?
        printf '  %s: %s\n' "$unit" "$([ $rc -eq 0 ] && echo "${st:-active}" || echo "${st:-absent}")"
    done
    echo "  -- ports --"
    (ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null) \
        | grep -E ':(80|443|8000|8081|4222|27017|6379)\b' \
        | sed 's/^/  /' || echo "  (aucun port attendu trouvé)"

    # mongod inactif sans port 27017 peut etre normal (conteneur, service
    # renomme, Mongo externe) ou un vrai defaut. On distingue les deux.
    echo "  -- mongo --"
    for ms in mongod mongodb mongo; do
        st=$(systemctl is-active "$ms" 2>/dev/null); rc=$?
        [ $rc -eq 0 ] && echo "  service $ms: ${st:-active}"
    done
    if ss -tln 2>/dev/null | grep -q ':27017'; then
        echo "  port 27017: en ecoute"
    else
        echo "  port 27017: AUCUN service en ecoute"
    fi
    for cf in /etc/mongod.conf /opt/tacticalrmm/api/mongo.conf /rmm/api/mongo.conf; do
        [ -f "$cf" ] && echo "  config: $cf"
    done
    grep -rhn 'MONGODB\|MONGO_' "$RMM/tacticalrmm/settings.py" 2>/dev/null | sed 's/^/  /'
else
    echo "  systemctl absent"
fi
echo "  -- check_mesh --"
mm check_mesh

# --- Configuration Mesh -----------------------------------------------------
sep "3. MESH DANS LA CONFIG"
for f in "$RMM/tacticalrmm/local_settings.py" "$RMM/tacticalrmm/settings.py"; do
    [ -f "$f" ] || continue
    echo "  --- $f ---"
    if grep -qE "MESH_|USE_EXTERNAL_MESH" "$f" 2>/dev/null; then
        grep -nE "MESH_|USE_EXTERNAL_MESH" "$f" | sed 's/^/  /'
    else
        echo "  (aucune variable MESH_)"
    fi
done

# --- Agents -----------------------------------------------------------------
sep "4. AGENTS INSTALLÉS"
mm shell -c "
from agents.models import Agent
for a in Agent.objects.all():
    m = a.mesh_node_id or 'AUCUN'
    print('  #%s %-25s %-12s mesh=%s' % (a.id, a.hostname, a.platform, m))
" | grep -v '^$'

# --- Inventaire par plateforme ---------------------------------------------
sep "5. INVENTAIRE PAR PLATEFORME"
mm shell -c "
from agents.models import Agent
for plat in ['windows','linux','macos']:
    n = Agent.objects.filter(platform=plat).count()
    w = Agent.objects.filter(platform=plat).exclude(mesh_node_id='').count()
    print('  %-10s total=%3s  avec_mesh_node_id=%s' % (plat, n, w))
" | grep -v '^$'

# --- Cette machine ---------------------------------------------------------
sep "6. CETTE MACHINE EST-ELLE UN AGENT ?"
echo "  PID 1: $(ps -p 1 -o comm= 2>/dev/null || echo inconnu)"
echo "  DISPLAY: ${DISPLAY:-<non defini, ok pour installateur>}"
if [ -d /opt/tacticalagent ] || [ -d /opt/tacticalmesh ]; then
    ls -d /opt/tacticalagent /opt/tacticalmesh 2>/dev/null | sed 's/^/  present: /'
else
    echo "  /opt/tacticalagent et /opt/tacticalmesh absents (normal sur le serveur RMM)"
fi

# --- Domaines ---------------------------------------------------------------
sep "7. DOMAINES NGINX"
if [ -d /etc/nginx/sites-enabled ]; then
    grep -rhE "server_name" /etc/nginx/sites-enabled/ 2>/dev/null | sed 's/^/  /' | head -8
else
    echo "  /etc/nginx/sites-enabled absent"
fi

# --- Installateur Linux amont ----------------------------------------------
sep "8. INSTALLATEUR LINUX AMONT"
SCRIPT="$RMM/core/agent_linux.sh"
if [ -f "$SCRIPT" ]; then
    echo "  present: $SCRIPT"
    echo "  occurrences de InstallMesh: $(grep -c 'InstallMesh' "$SCRIPT")"
    if grep -q 'meshDLChange' "$SCRIPT"; then
        echo "  meshDLChange present (injecte par le serveur a l install)"
    else
        echo "  meshDLChange ABSENT de l installateur"
    fi
else
    echo "  ABSENT: $SCRIPT"
fi

# --- Version agent attendue par le serveur ---------------------------------
sep "9. VERSION AGENT ATTENDUE"
mm shell -c "
from django.conf import settings
print('  LATEST_AGENT_VER:', settings.LATEST_AGENT_VER)
print('  MESH_VER        :', settings.MESH_VER)
print('  TRMM_VERSION    :', settings.TRMM_VERSION)
"

sep "FIN DU DIAGNOSTIC"
