#!/bin/bash
# Backup Tactical RMM -> kDrive (API REST Infomaniak)
# Remplace /home/debian/backup-rmm.sh (casse depuis le 16/05/2026 sur 4 niveaux)
#   1. cron sans droits d'ecriture sur /var/log
#   2. WebDAV kDrive supprime (kSuite Standard depuis le 08/07/2026) -> 403
#   3. aucun PAT Infomaniak sur le serveur
#   4. mot de passe PostgreSQL perime dans le script -> pg_dump echoue
#
# Dumps faits via le socket local en tant que 'postgres' : aucun mot de passe en clair.
# Secrets : PAT dans /root/.rmm-kdrive-token (600 root:root). Aucun secret dans ce script.
#
# Fichiers :
#   /usr/local/sbin/backup-rmm.sh   ce script (700 root:root)
#   /etc/backup-rmm.conf            identifiants kDrive + Telegram (600 root:root)
#   /root/.rmm-kdrive-token         PAT Infomaniak kDrive (600 root:root)
#   /var/log/backup-rmm.log         log (root:root 640)
#   /etc/cron.d/backup-rmm          crontab root (644 root:root)
#
# Contenu de l'archive : db/ (dumps -Fc), rmm/, mesh/, sys/ (letsencrypt, nginx,
# units systemd, /etc/conf.d, cron.d, logrotate.d, /usr/local/sbin, jail.local).

set -uo pipefail

# ---------------------------------------------------------------- configuration
# Les identifiants (drive, compte, dossier kDrive, discussion Telegram) sont
# propres a l'installation : ils vivent dans $CONF (600 root), pas ici.
# Modele : backup-rmm.conf.example.
CONF="${BACKUP_RMM_CONF:-/etc/backup-rmm.conf}"
DRIVE_ID=""
ACCOUNT_ID=""
DIR_ID=""
TELEGRAM_CHAT_ID=""
RETENTION_DAYS=30
API=https://api.infomaniak.com

TOKEN_FILE=/root/.rmm-kdrive-token
WORKDIR=/var/tmp/rmm-backup
PGBIN=/usr/bin/pg_dump
PGUSER=postgres

TELEGRAM_BOT_TOKEN_FILE=/root/.rmm-telegram-token

# ---------------------------------------------------------------- helpers
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

fail() {
    log "ECHEC : $*"
    notify "ECHEC" "$*"
    cleanup
    exit 1
}

# Les secrets ne passent JAMAIS en argument de curl (visibles par tout compte local
# via ps / /proc/<pid>/cmdline) : ils sont fournis par stdin en config curl (-K -).
kcurl() { printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" | curl -K - "$@"; }

notify() {
    local icon="$1" detail="$2"
    [ -r "$TELEGRAM_BOT_TOKEN_FILE" ] || return 0
    printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$(cat "$TELEGRAM_BOT_TOKEN_FILE")" | \
    curl -K - -sS --max-time 20 -X POST \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d "text=<b>Backup RMM — ${icon}</b>%0A📅 $(date '+%Y-%m-%d %H:%M')%0A📦 ${ARCHIVE_SIZE:-N/A}%0A${detail}" \
        >/dev/null 2>&1 || true
}

cleanup() { [ -n "${WORKDIR:-}" ] && rm -rf "$WORKDIR"; }

# ---------------------------------------------------------------- prerequisites
[ "$(id -u)" -eq 0 ] || { echo "Ce script doit tourner en root." >&2; exit 1; }
[ -f "$CONF" ] || fail "Configuration introuvable : $CONF (modele : backup-rmm.conf.example)"
# Le fichier est source en root : il doit appartenir a root et n'etre
# modifiable par personne d'autre.
case "$(stat -c '%u %A' "$CONF")" in
    "0 -rw-------"|"0 -r--------") ;;
    *) fail "Droits refuses sur $CONF ($(stat -c '%U %A' "$CONF")), attendu root 600" ;;
esac
# shellcheck source=/dev/null
. "$CONF"
for v in DRIVE_ID ACCOUNT_ID DIR_ID RETENTION_DAYS; do
    [[ "${!v}" =~ ^[0-9]+$ ]] || fail "$v absent ou non numerique dans $CONF"
done
[ -r "$TOKEN_FILE" ] || fail "PAT Infomaniak introuvable : $TOKEN_FILE"
TOKEN=$(cat "$TOKEN_FILE")
[ -n "$TOKEN" ] || fail "PAT Infomaniak vide"

# ---------------------------------------------------------------- dump des bases
STAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE_NAME="rmm-backup-${STAMP}.tar.gz"
WORKDIR=$(mktemp -d -p /var/tmp "rmm-backup-XXXXXX")
# nettoyage garanti meme en cas d'arret brutal (3,3 Go de fichiers temporaires)
trap 'rm -rf "$WORKDIR" /var/tmp/rmm-pgdump' EXIT
mkdir -p "$WORKDIR"/{db,rmm,mesh}

# pg_dump tourne en tant que 'postgres' : il ne peut pas ecrire dans un
# dossier root 700. On prepare donc un dossier dump lisible par postgres.
PGDUMP_DIR=/var/tmp/rmm-pgdump
rm -rf "$PGDUMP_DIR"
mkdir -p "$PGDUMP_DIR"
chown "$PGUSER" "$PGDUMP_DIR"
chmod 750 "$PGDUMP_DIR"

log "Dump PostgreSQL tacticalrmm..."
sudo -u "$PGUSER" "$PGBIN" -d tacticalrmm -Fc -f "$PGDUMP_DIR/tacticalrmm.dump" \
    || fail "pg_dump tacticalrmm a echoue"
DUMP_SIZE=$(stat -c%s "$PGDUMP_DIR/tacticalrmm.dump")
[ "$DUMP_SIZE" -gt 1000000 ] || fail "Dump tacticalrmm suspect ($DUMP_SIZE octets)"
log "  tacticalrmm.dump = $DUMP_SIZE octets"

log "Dump PostgreSQL meshcentral..."
sudo -u "$PGUSER" "$PGBIN" -d meshcentral -Fc -f "$PGDUMP_DIR/meshcentral.dump" \
    || log "  meshcentral dump ignore (base NeDB ou indisponible)"
[ -f "$PGDUMP_DIR/meshcentral.dump" ] && \
    log "  meshcentral.dump = $(stat -c%s "$PGDUMP_DIR/meshcentral.dump") octets"

# les dumps sont recopies dans l'arborescence de travail puis purges
mkdir -p "$WORKDIR/db"
cp -f "$PGDUMP_DIR/tacticalrmm.dump" "$WORKDIR/db/tacticalrmm.dump" || fail "Copie du dump tacticalrmm impossible"
[ -f "$PGDUMP_DIR/meshcentral.dump" ] && cp -f "$PGDUMP_DIR/meshcentral.dump" "$WORKDIR/db/meshcentral.dump"
rm -rf "$PGDUMP_DIR"

# ---------------------------------------------------------------- config + donnees
log "Copie /rmm (hors caches)..."
tar cf - -C /rmm \
    --exclude='./node_modules' --exclude='./api/env' --exclude='./api/tacticalrmm/env' \
    --exclude='__pycache__' --exclude='.git' --exclude='*.pyc' \
    . 2>"$WORKDIR/tar.err" | tar xf - -C "$WORKDIR/rmm/" \
    || log "  copie /rmm partielle : $(grep -v 'socket ignored' "$WORKDIR/tar.err" | head -3 | tr '\n' ' ')"
log "  /rmm = $(du -sh "$WORKDIR/rmm" | cut -f1)"

log "Copie /meshcentral (hors caches)..."
tar cf - -C /meshcentral \
    --exclude='./node_modules' --exclude='*.bak' \
    . 2>"$WORKDIR/tar.err" | tar xf - -C "$WORKDIR/mesh/" \
    || log "  copie /meshcentral partielle : $(grep -v 'socket ignored' "$WORKDIR/tar.err" | head -3 | tr '\n' ' ')"
log "  /meshcentral = $(du -sh "$WORKDIR/mesh" | cut -f1)"

# ---------------------------------------------------------------- config systeme
# Absente jusqu'au 14/11/2026 : certificats, vhosts nginx, units systemd, crons
# et scripts d'exploitation etaient perdus en cas de reinstallation du VPS.
# Memes reperes que /rmm/backup.sh officiel (certs/etc-letsencrypt.tar.gz,
# nginx/, systemd/, confd/) pour restaurer a la main en suivant /rmm/restore.sh.
log "Copie de la config systeme..."
SYS="$WORKDIR/sys"
mkdir -p "$SYS"/{certs,nginx,systemd,confd,cron,logrotate,sbin}
tar czf "$SYS/certs/etc-letsencrypt.tar.gz" -C /etc/letsencrypt . \
    || fail "Archive de /etc/letsencrypt impossible"
cp -a /etc/nginx/nginx.conf /etc/nginx/sites-available /etc/nginx/sites-enabled "$SYS/nginx/" \
    || fail "Copie de la config nginx impossible"
[ -d /etc/nginx/conf.d ] && cp -a /etc/nginx/conf.d "$SYS/nginx/"
for u in rmm daphne celery celerybeat nats nats-api meshcentral; do
    [ -f "/etc/systemd/system/$u.service" ] && cp -p "/etc/systemd/system/$u.service" "$SYS/systemd/"
done
[ -d /etc/conf.d ] && cp -a /etc/conf.d/. "$SYS/confd/"
cp -p /etc/cron.d/* "$SYS/cron/" 2>/dev/null
cp -p /etc/logrotate.d/* "$SYS/logrotate/" 2>/dev/null
cp -p /usr/local/sbin/* "$SYS/sbin/" 2>/dev/null
[ -f /etc/fail2ban/jail.local ] && cp -p /etc/fail2ban/jail.local "$SYS/"
log "  sys = $(du -sh "$SYS" | cut -f1), $(find "$SYS" -type f | wc -l) fichiers"

# ---------------------------------------------------------------- archive
log "Creation de l'archive ${ARCHIVE_NAME}..."
tar czf "$WORKDIR/$ARCHIVE_NAME" -C "$WORKDIR" db rmm mesh sys \
    || fail "Creation de l'archive echouee"

# Une archive produite sans erreur peut quand meme etre incomplete (copie
# partielle, dossier renomme lors d'une MAJ) : on verifie les pieces vitales.
log "Controle du contenu de l'archive..."
LISTING=$(tar tzf "$WORKDIR/$ARCHIVE_NAME") || fail "Archive illisible (tar tzf)"
for f in db/tacticalrmm.dump \
         rmm/api/tacticalrmm/tacticalrmm/local_settings.py \
         sys/certs/etc-letsencrypt.tar.gz \
         sys/nginx/nginx.conf \
         sys/systemd/rmm.service \
         sys/sbin/backup-rmm.sh; do
    grep -qxF "$f" <<<"$LISTING" || fail "Archive incomplete : $f absent"
done
log "  $(wc -l <<<"$LISTING") entrees, pieces vitales presentes"
ARCHIVE_SIZE=$(du -h "$WORKDIR/$ARCHIVE_NAME" | cut -f1)
ARCHIVE_BYTES=$(stat -c%s "$WORKDIR/$ARCHIVE_NAME")
log "  Taille : $ARCHIVE_SIZE ($ARCHIVE_BYTES octets)"

# ---------------------------------------------------------------- upload kDrive
log "Upload vers kDrive (API REST)..."
UPLOAD_URL="${API}/3/drive/${DRIVE_ID}/upload?directory_id=${DIR_ID}&file_name=${ARCHIVE_NAME}&total_size=${ARCHIVE_BYTES}&account_id=${ACCOUNT_ID}&conflict=rename"
HTTP=$(kcurl -sS --max-time 900 -o "$WORKDIR/upload_resp.json" -w '%{http_code}' \
    -X POST \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$WORKDIR/$ARCHIVE_NAME" \
    "$UPLOAD_URL")

if [ "$HTTP" != "200" ] && [ "$HTTP" != "201" ]; then
    fail "Upload kDrive HTTP $HTTP : $(head -c 300 "$WORKDIR/upload_resp.json")"
fi
log "  Upload HTTP $HTTP"

# ---------------------------------------------------------------- verification (listage)
log "Verification par listage du dossier kDrive..."
LIST=$(kcurl -sS --max-time 60 \
    "${API}/3/drive/${DRIVE_ID}/files/${DIR_ID}/files?account_id=${ACCOUNT_ID}&limit=200")
echo "$LIST" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d if isinstance(d, list) else d.get('data', d)
if isinstance(items, dict):
    items = items.get('data', items.get('files', []))
name = '${ARCHIVE_NAME}'
hit = [i for i in items if i.get('name') == name]
if not hit:
    print('ABSENT:' + name); sys.exit(1)
print('CONFIRME:' + name + ':' + str(hit[0].get('size')))
" > "$WORKDIR/verify.txt" 2>&1
VERIFY=$(cat "$WORKDIR/verify.txt")
case "$VERIFY" in
    CONFIRME:*) log "  Verification OK : $VERIFY" ;;
    *) fail "Archive non trouvee dans le listing kDrive ($VERIFY)" ;;
esac

# ---------------------------------------------------------------- purge retention
log "Purge des backups de plus de ${RETENTION_DAYS} jours..."
echo "$LIST" | python3 -c "
import sys, json
from datetime import datetime, timedelta, timezone
d = json.load(sys.stdin)
items = d if isinstance(d, list) else d.get('data', d)
if isinstance(items, dict):
    items = items.get('data', items.get('files', []))
cut = datetime.now(timezone.utc).timestamp() - ${RETENTION_DAYS}*86400
for i in items:
    n = i.get('name', '')
    if not n.startswith('rmm-backup-') or not n.endswith('.tar.gz'):
        continue
    ts = i.get('added_at') or i.get('created_at')
    if ts is None:
        continue
    try:
        dt = float(ts)                      # epoch (kDrive) ou ISO
    except (TypeError, ValueError):
        try:
            dt = datetime.fromisoformat(str(ts).replace('Z', '+00:00')).timestamp()
        except Exception:
            continue
    if dt < cut:
        print('PURGE:%s:%s' % (i.get('id'), n))
" | while IFS=: read -r _ fid fname; do
    [ -n "$fid" ] || continue
    log "  suppression $fname (id=$fid)"
    kcurl -sS --max-time 60 -o /dev/null -w "    delete HTTP %{http_code}\n" \
        -X DELETE \
        "${API}/2/drive/${DRIVE_ID}/files/${fid}?account_id=${ACCOUNT_ID}"
done

# ---------------------------------------------------------------- succes
rm -f "$WORKDIR/$ARCHIVE_NAME"
cleanup
log "Backup RMM SUCCESS."
notify "SUCCESS" "Archive ${ARCHIVE_NAME} (${ARCHIVE_SIZE}) uploadee et verifiee sur kDrive."
exit 0
