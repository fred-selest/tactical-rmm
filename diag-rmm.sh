#!/usr/bin/env bash
# Diagnostic Tactical RMM + Mesh — lecture seule, ne modifie rien.
# Usage : sudo bash diag-rmm.sh
#
# v4 — corrections issues de l'exécution de la v3 sur le serveur de production :
#
#  1. MASQUAGE DES SECRETS. La v3 a affiché en clair le MESH_TOKEN_KEY, le
#     token d'authentification Mesh, l'identifiant de device et l'URL de
#     contrôle. Filtrés ici avant toute sortie.
#  2. Sections 4 et 5 cassées : le champ de l'Agent s'appelle « plat », pas
#     « platform ». Elles levaient AttributeError puis FieldError.
#  3. La v3 affichait « 4.2.30 » comme version de TRMM. C'est la version de
#     DJANGO : Django a un cas spécial non documenté, « manage.py version »
#     affiche django.get_version(). La commande correcte est get_config.
#
# NE PAS utiliser d'apostrophe dans un ${VAR:-defaut} : bash y reprend ses
# règles de quoting, le guillemet ouvre une chaîne qui avale le }.

sep() { printf '\n════════ %s ════════\n' "$1"; }

# --- Masquage ---------------------------------------------------------------
# Affiche $1 avec toute valeur sensible remplacée. Appliqué à TOUTE sortie
# contenant potentiellement un secret : rien ne doit sortir en clair.
#
# Le marqueur est [MASQUE] en ASCII et les règles sont ordonnées pour qu'aucune
# ne puisse remasquer la sortie d'une autre. Avec « MASQUÉ » accentué et la
# règle ?auth= placée après la règle auth=, la seconde regex retranchait le
# texte que la première venait d'écrire et laissait un caractère parasite.
redact() {
    sed -E \
        -e 's/(MESH_TOKEN_KEY[[:space:]]*=[[:space:]]*")[^"]*(")/\1[MASQUE]\2/gI' \
        -e 's/([?&]auth=)[A-Za-z0-9_@$.+/=-]+/\1[MASQUE]/g' \
        -e 's/((token|secret|key|password|passwd|pwd|auth)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?)[A-Za-z0-9_@$.+/=-]{8,}/\1[MASQUE]/gI' \
        -e 's/^([[:space:]]*[A-Za-z ]*(token|secret|key|id) ok:).*/\1 [MASQUE]/I' \
        -e 's/(device id|mesh id|deviceid)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_@$.+/=-]{8,}/\1: [MASQUE]/gI'
}

# --- Localisation de l'installation -----------------------------------------
sep "1. VERSION TRMM"
RMM=""
for cand in /opt/tacticalrmm/api/tacticalrmm /rmm/api/tacticalrmm; do
    if [ -f "$cand/manage.py" ]; then RMM="$cand"; break; fi
done
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

for d in /opt/tacticalrmm/api/tacticalrmm /rmm/api/tacticalrmm; do
    [ -d "$d" ] || continue
    printf '  %-34s manage.py=%s core/agent_linux.sh=%s\n' "$d" \
        "$([ -f "$d/manage.py" ] && echo OUI || echo non)" \
        "$([ -f "$d/core/agent_linux.sh" ] && echo OUI || echo non)"
done

# --- Interpréteur -----------------------------------------------------------
echo "  -- interpréteur --"
PY=""
SVC_PATH=""
if command -v systemctl >/dev/null 2>&1; then
    SVC_PATH=$(systemctl show rmm.service -p Environment --value 2>/dev/null \
        | tr ' ' '\n' | sed -n 's/^PATH=//p' | cut -d: -f1)
    [ -n "$SVC_PATH" ] && echo "  PATH rmm.service: $SVC_PATH"
fi
for cand in \
    ${SVC_PATH:+"$SVC_PATH/python"} ${SVC_PATH:+"$SVC_PATH/python3"} \
    "$RMM/../env/bin/python" "$RMM/../env/bin/python3" \
    /rmm/api/env/bin/python /rmm/api/env/bin/python3 \
    /opt/tacticalrmm/api/env/bin/python /usr/bin/python3 /usr/bin/python
do
    [ -x "$cand" ] && PY="$cand" && break
done
[ -n "$PY" ] && echo "  python: $PY  ($("$PY" -V 2>&1))" || echo "  AUCUN interpréteur python trouvé"

mm() {
    [ -z "$PY" ] && { echo "  (python introuvable)"; return 1; }
    [ -f "$RMM/manage.py" ] || { echo "  (manage.py absent)"; return 1; }
    local runner=()
    if [ "$(id -u)" -eq 0 ]; then
        if command -v sudo >/dev/null 2>&1 && id tactical >/dev/null 2>&1; then
            runner=(sudo -u tactical)
        else
            echo "  (exécution en root, sudo ou utilisateur tactical indisponible)"
        fi
    else
        echo "  (ATTENTION : lancé sans root)"
    fi
    "${runner[@]}" "$PY" "$RMM/manage.py" "$@" 2>&1 | sed 's/^/  /' | redact
    return 0
}

# Version : get_config, PAS « version ». « manage.py version » affiche la
# version de Django (cas spécial non documenté dans ManagementUtility.execute).
echo "  -- version (get_config, pas « version ») --"
mm get_config

# --- Services ---------------------------------------------------------------
sep "2. SERVICES ET MESH"
if command -v systemctl >/dev/null 2>&1; then
    for unit in rmm.service nginx meshcentral rqworker; do
        st=$(systemctl is-active "$unit" 2>/dev/null); rc=$?
        printf '  %-14s %s\n' "$unit" "$([ $rc -eq 0 ] && echo "${st:-active}" || echo "${st:-absent}")"
    done

    echo "  -- ports d'écoute --"
    (ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null) \
        | grep -E ':(80|443|4222|27017|6379|8000|8081|4430)\b' | sed 's/^/  /' \
        || echo "  (aucun port attendu trouvé)"

    # RQ worker : c'est lui qui exécute les tâches planifiées et les alertes.
    echo "  -- file d'attente RQ --"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl cat rqworker 2>/dev/null | grep -E "ExecStart" | sed 's/^/  /' || echo "  (unité rqworker absente)"
    fi
    if [ -d /var/run/rq ] || [ -d /var/lib/rq ]; then
        ls -la /var/run/rq /var/lib/rq 2>/dev/null | head -8 | sed 's/^/  /'
    fi
    "$PY" -c "
import redis
r = redis.Redis(host='127.0.0.1', port=6379, socket_connect_timeout=3)
for q in r.smembers('rq:queues'):
    print('  file:', q.decode() if isinstance(q, bytes) else q)
" 2>/dev/null || echo "  (interrogation Redis impossible)"
fi

echo "  -- check_mesh (sortie masquée) --"
mm check_mesh

# --- Base de données --------------------------------------------------------
sep "3. BASE DE DONNÉES"
# mongod inactif sans port 27017 : soit Mongo est ailleurs, soit c'est un
# défaut. On interroge la configuration réellement utilisée.
if [ -n "$PY" ]; then
    "${PY:-/usr/bin/python3}" - <<'PYDB' 2>&1 | sed 's/^/  /' | redact
try:
    from django.conf import settings
    db = settings.DATABASES.get("default", {})
    print("  moteur     :", db.get("ENGINE", "?"))
    h = db.get("HOST") or ""
    p = db.get("PORT") or ""
    if h:
        h = h.split("@")[-1]   # ne jamais afficher les identifiants
    print("  hôte       :", h or "(local)")
    print("  port       :", p or "(défaut)")
    from pymongo import MongoClient
    cli = MongoClient(serverSelectionTimeoutMS=4000)
    info = cli.server_info()
    print("  mongo      :", info.get("version", "?"))
    print("  serveurs   :", [s for s in cli.list_database_names()][:8])
except Exception as e:
    print("  erreur     :", type(e).__name__, str(e)[:200])
PYDB
fi

# --- Configuration Mesh (valeurs masquées) ----------------------------------
sep "4. CONFIGURATION MESH (valeurs masquées)"
for f in "$RMM/tacticalrmm/local_settings.py" "$RMM/tacticalrmm/settings.py"; do
    [ -f "$f" ] || continue
    echo "  --- $f ---"
    if grep -qE "MESH_|USE_EXTERNAL_MESH" "$f" 2>/dev/null; then
        grep -nE "MESH_|USE_EXTERNAL_MESH" "$f" | sed 's/^/  /' | redact
    else
        echo "  (aucune variable MESH_)"
    fi
done

# --- Agents -----------------------------------------------------------------
# v3 utilisait « platform ». Le champ réel s'appelle « plat » — la v3 levait
# AttributeError puis FieldError et n'affichait rien.
sep "5. AGENTS INSTALLÉS"
mm shell -c "
from agents.models import Agent
qs = Agent.objects.all()
print('  total :', qs.count())
for a in qs:
    print('  #%-4s %-28s %-11s mesh=%s' % (
        a.id, (a.hostname or '')[:28], a.plat or '?', 'OUI' if a.mesh_node_id else 'NON'))
" | grep -v '^  *$'

# --- Inventaire par plateforme ---------------------------------------------
sep "6. INVENTAIRE PAR PLATEFORME"
mm shell -c "
from agents.models import Agent
for p in ['windows', 'linux', 'macos']:
    n = Agent.objects.filter(plat=p).count()
    w = Agent.objects.filter(plat=p).exclude(mesh_node_id='').count()
    print('  %-10s total=%-4s avec_mesh=%s' % (p, n, w))
print('  ---')
from django.db.models import Count
for row in Agent.objects.values('plat').annotate(n=Count('id')):
    print('  vérif %-8s %s' % (row['plat'], row['n']))
"

# --- Cette machine ---------------------------------------------------------
sep "7. CETTE MACHINE EST-ELLE UN AGENT ?"
echo "  PID 1: $(ps -p 1 -o comm= 2>/dev/null || echo inconnu)"
echo "  DISPLAY: ${DISPLAY:-<non defini, ok pour installateur>}"
if [ -d /opt/tacticalagent ] || [ -d /opt/tacticalmesh ]; then
    ls -d /opt/tacticalagent /opt/tacticalmesh 2>/dev/null | sed 's/^/  present: /'
else
    echo "  /opt/tacticalagent et /opt/tacticalmesh absents (normal sur le serveur RMM)"
fi

# --- Domaines ---------------------------------------------------------------
sep "8. DOMAINES NGINX"
if [ -d /etc/nginx/sites-enabled ]; then
    grep -rhE "server_name" /etc/nginx/sites-enabled/ 2>/dev/null | sed 's/^/  /' | head -8
else
    echo "  /etc/nginx/sites-enabled absent"
fi

# --- Installateur Linux amont ----------------------------------------------
sep "9. INSTALLATEUR LINUX AMONT"
SCRIPT="$RMM/core/agent_linux.sh"
if [ -f "$SCRIPT" ]; then
    echo "  present: $SCRIPT"
    echo "  occurrences de InstallMesh: $(grep -c 'InstallMesh' "$SCRIPT")"
    grep -q 'meshDLChange' "$SCRIPT" \
        && echo "  meshDLChange present (injecte par le serveur a l install)" \
        || echo "  meshDLChange ABSENT de l installateur"
else
    echo "  ABSENT: $SCRIPT"
fi

# --- Versions ---------------------------------------------------------------
sep "10. VERSIONS"
mm shell -c "
from django.conf import settings
import django
print('  TRMM_VERSION    :', settings.TRMM_VERSION)
print('  LATEST_AGENT_VER:', settings.LATEST_AGENT_VER)
print('  MESH_VER        :', settings.MESH_VER)
print('  APP_VER         :', getattr(settings, 'APP_VER', '?'))
print('  WEB_VERSION     :', getattr(settings, 'WEB_VERSION', '?'))
print('  django          :', django.get_version())
"

sep "FIN DU DIAGNOSTIC"
echo "  Aucun secret n'est affiché : la sortie de check_mesh et les variables"
echo "  MESH_* passent par un filtre de masquage."
