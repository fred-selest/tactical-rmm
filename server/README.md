# Scripts d'exploitation du serveur Tactical RMM

Scripts déployés sur le serveur RMM lui-même (pas sur les agents). La version du dépôt est celle qui tourne en production.

| Fichier du dépôt | Emplacement sur le serveur | Droits |
|---|---|---|
| `backup-rmm.sh` | `/usr/local/sbin/backup-rmm.sh` | 700 root |
| `backup-rmm.conf.example` | `/etc/backup-rmm.conf` (à remplir) | **600 root**, obligatoire |
| `cron.d/backup-rmm` | `/etc/cron.d/backup-rmm` | 644 root |
| `postgresql-watchdog.sh` | `/usr/local/sbin/postgresql-watchdog.sh` | 755 root |
| `cron.d/postgresql-watchdog` | `/etc/cron.d/postgresql-watchdog` | 644 root |
| `logrotate.d/postgresql-watchdog` | `/etc/logrotate.d/postgresql-watchdog` | 644 root |
| `logrotate.d/tacticalrmm` | `/etc/logrotate.d/tacticalrmm` | 644 root |

## backup-rmm.sh : sauvegarde quotidienne vers kDrive

Tous les jours à 03:17, le script :
- fait un dump (`pg_dump -Fc`) des bases `tacticalrmm` et `meshcentral`, via le socket local, sans mot de passe ;
- copie `/rmm` et `/meshcentral` (hors `node_modules`, environnements Python et caches) ;
- ajoute la configuration système dans `sys/` : `/etc/letsencrypt`, nginx, les services systemd du RMM, `/etc/conf.d`, `cron.d`, `logrotate.d`, `/usr/local/sbin`, `jail.local` ;
- **contrôle le contenu de l'archive** (dump, `local_settings.py`, certificats, nginx, `rmm.service`) et s'arrête en erreur si une pièce manque ;
- envoie l'archive par l'API REST kDrive, vérifie sa présence dans le listing, purge au-delà de `RETENTION_DAYS` et notifie sur Telegram.

Secrets, jamais dans le dépôt ni en argument de `curl` (ils sont passés par stdin, `curl -K -`) :
- `/root/.rmm-kdrive-token` : PAT Infomaniak (scope kdrive), 600 root ;
- `/root/.rmm-telegram-token` : token du bot, 600 root (facultatif).

Installation :
```bash
install -m 700 -o root -g root backup-rmm.sh /usr/local/sbin/
install -m 600 -o root -g root backup-rmm.conf.example /etc/backup-rmm.conf   # puis le remplir
install -m 644 -o root -g root cron.d/backup-rmm /etc/cron.d/
/usr/local/sbin/backup-rmm.sh >> /var/log/backup-rmm.log 2>&1; tail /var/log/backup-rmm.log
```

La disposition de `sys/` reprend celle de `/rmm/backup.sh` officiel (`certs/etc-letsencrypt.tar.gz`, `nginx/`, `systemd/`, `confd/`), ce qui permet une restauration manuelle en suivant `/rmm/restore.sh`.

**Tester la restaurabilité**, pas seulement l'envoi : retélécharger l'archive (`GET /2/drive/<DRIVE_ID>/files/<id>/download`, avec `-L`), puis lancer `gzip -t`, `pg_restore --list` sur le dump, et comparer les certificats et la configuration avec la production.

## postgresql-watchdog.sh : relance de PostgreSQL et de MeshCentral

MeshCentral plante quand PostgreSQL tombe et ne repart pas seul. Lancé chaque minute, le watchdog :
- ne fait rien et n'écrit rien tant que `pg_isready` répond ;
- refait un essai après 10 s (`PG_WATCHDOG_RETRY_DELAY`), pour ne pas déclencher une cascade pendant un redémarrage volontaire ;
- si les deux essais échouent, redémarre `postgresql@15-main` (`PG_UNIT`) puis `meshcentral`, et écrit le résultat dans le journal.

L'ancienne version (une ligne cron) journalisait chaque minute : 224 351 lignes, sans rotation, pour un seul incident réel.

Les tests (`tests/test-scripts.sh`, section 8c) simulent la panne avec un faux `pg_isready` et un faux `systemctl`. Ils ne demandent ni root ni PostgreSQL.

## logrotate.d/tacticalrmm : rotation des journaux du RMM

Aucune rotation n'existait pour les journaux applicatifs : `trmm_debug.log` a atteint 2,5 Go entre août 2025 et novembre 2026. Le fichier en couvre maintenant deux familles :
- `trmm_debug.log`, `django_debug.log` et `/var/log/celery/*.log` : ils sont écrits par `tactical`, d'où `su tactical tactical` ;
- `access.log` et `error.log` : ils sont écrits par nginx (`www-data`), donc la rotation se fait en root. Avec `su tactical`, logrotate échoue en « Permission denied ».

Ces journaux tournent chaque semaine, ou dès 200 Mo, et 8 versions compressées sont gardées. `copytruncate` évite tout signal de réouverture aux processus Python et à nginx, au prix de quelques lignes perdues pendant la copie.

Si ce journal grossit vite, il faut chercher la cause : en novembre 2026, 698 tâches « planifiées » sans récurrence produisaient environ 570 erreurs `invalid task trigger type` toutes les 2 minutes.
