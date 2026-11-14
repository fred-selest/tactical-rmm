#!/bin/bash
# Watchdog PostgreSQL + redemarrage en cascade de MeshCentral.
# Lance chaque minute par /etc/cron.d/postgresql-watchdog.
#
# Silencieux tant que PostgreSQL repond. L'ancienne version (ligne cron
# unique) journalisait la sortie de pg_isready a chaque minute : 224 351
# lignes / 8,7 Mo sans rotation, pour un seul incident reel.
#
# Ne redemarre qu'apres 2 echecs a 10 s d'intervalle : un redemarrage en
# cours de PostgreSQL (mise a jour, maintenance) ne declenche pas de cascade.

LOG="${PG_WATCHDOG_LOG:-/var/log/postgresql-watchdog.log}"
PG_UNIT="${PG_UNIT:-postgresql@15-main}"
RETRY_DELAY="${PG_WATCHDOG_RETRY_DELAY:-10}"   # entre les 2 essais
RESTART_DELAY="${PG_WATCHDOG_RESTART_DELAY:-3}" # entre postgresql et meshcentral

ready() { pg_isready -q -h 127.0.0.1 -p 5432 -t 5; }

ready && exit 0
sleep "$RETRY_DELAY"
ready && exit 0

{
    echo "[$(date '+%F %T')] PostgreSQL ne repond pas (2 essais), redemarrage de $PG_UNIT puis meshcentral"
    systemctl restart "$PG_UNIT"
    sleep "$RESTART_DELAY"
    systemctl restart meshcentral
    if ready; then
        echo "[$(date '+%F %T')] PostgreSQL de nouveau disponible"
    else
        echo "[$(date '+%F %T')] ECHEC : PostgreSQL toujours indisponible apres redemarrage"
    fi
} >> "$LOG" 2>&1
