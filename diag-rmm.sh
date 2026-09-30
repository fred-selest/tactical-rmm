#!/usr/bin/env bash
# Diagnostic Tactical RMM + Mesh — lecture seule, ne modifie rien.
# Usage : sudo bash diag-rmm.sh
# Coller la sortie entière pour analyse.

echo "════════ 1. VERSION TRMM ════════"
RMM=/opt/tacticalrmm/api/tacticalrmm
PY=/opt/tacticalrmm/api/env/bin/python
[ -d "$RMM" ] || { RMM=/rmm/api/tacticalrmm; PY=/rmm/api/env/bin/python; }
[ -d "$RMM" ] && echo "  chemin: $RMM" || { echo "  TRMM introuvable"; exit 1; }
sudo -u tactical "$PY" "$RMM/manage.py" version 2>&1 | sed 's/^/  /'

echo "════════ 2. MESH CENTRAL ════════"
systemctl is-active meshcentral  2>/dev/null | sed 's/^/  meshcentral: /'
systemctl is-active mongod       2>/dev/null | sed 's/^/  mongod: /'
echo "  -- check_mesh --"
sudo -u tactical "$PY" "$RMM/manage.py" check_mesh 2>&1 | sed 's/^/  /'

echo "════════ 3. MESH DANS LA CONFIG ════════"
for f in "$RMM/tacticalrmm/local_settings.py" "$RMM/tacticalrmm/settings.py"; do
  [ -f "$f" ] || continue
  echo "  --- $f ---"
  grep -nE "MESH_|USE_EXTERNAL_MESH" "$f" | sed 's/^/  /' || echo "  (aucune variable MESH_)"
done

echo "════════ 4. AGENTS INSTALLÉS ════════"
sudo -u tactical "$PY" "$RMM/manage.py" shell -c "
from agents.models import Agent
for a in Agent.objects.all():
    m = a.mesh_node_id or 'AUCUN'
    print(f'  #{a.id} {a.hostname:25} {a.platform:12} mesh={m}')
" 2>&1 | grep -v '^$' | sed 's/^/  /'

echo "════════ 5. INVENTAIRE PAR PLATEFORME ════════"
sudo -u tactical "$PY" "$RMM/manage.py" shell -c "
from agents.models import Agent
for plat in ['windows','linux','macos']:
    n = Agent.objects.filter(platform=plat).count()
    w = Agent.objects.filter(platform=plat).exclude(mesh_node_id='').count()
    print(f'  {plat:10} total={n:3}  avec_mesh_node_id={w}')
" 2>&1 | grep -v '^$' | sed 's/^/  /'

echo "════════ 6. CETTE MACHINE EST-ELLE UN AGENT ? ════════"
echo "  systemd: $(ps --no-headers -o comm 1 2>/dev/null)"
echo "  DISPLAY : ${DISPLAY:-<vide, ok pour l'installateur>}"
ls -d /opt/tacticalagent /opt/tacticalmesh 2>/dev/null | sed 's/^/  présent: /' || echo "  /opt/tacticalagent et /opt/tacticalmesh absents (normal sur le serveur RMM)"

echo "════════ 7. DOMAINES NGINX ════════"
grep -rhE "server_name" /etc/nginx/sites-enabled/ 2>/dev/null | sed 's/^/  /' | head -8

echo "════════ 8. INSTALLATEUR LINUX AMONT ════════"
SCRIPT="$RMM/core/agent_linux.sh"
if [ -f "$SCRIPT" ]; then
  echo "  présent: $SCRIPT"
  grep -c "InstallMesh" "$SCRIPT" | sed 's/^/  occurrences de InstallMesh: /'
  grep -q "meshDLChange" "$SCRIPT" && echo "  meshDLChange présent (sera injecté par le serveur)"
else
  echo "  ABSENT: $SCRIPT"
fi
