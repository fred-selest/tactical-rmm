# rmmagent modifié pour Synology

Agent Tactical RMM modifié pour remonter correctement le matériel des NAS
Synology : l'agent standard affiche « Unknown Unknown » pour les disques et un
numéro de série générique.

## Ce que change le patch

`synology.patch` modifie uniquement `agent/agent_unix.go`. Chaque ajout ne
s'active que si `/etc/synoinfo.conf` existe : aucun effet sur les autres Linux.

| Donnée | Agent standard | Agent modifié |
|---|---|---|
| Disques | `Unknown Unknown` | modèle, type HDD/SSD, bus, S/N (via `smartctl -i`) |
| Modèle | générique | `Synology DS218+ (DSM 7.4-90080)` (`synoinfo.conf` + `/etc.defaults/VERSION`) |
| Numéro de série | `n/a` / `Default string` | `/proc/sys/kernel/syno_serial` |
| Adresses IP | parfois vides | repli sur `ip addr` |

Patch d'origine écrit sur v2.9.1, rebasé sur **v2.12.0** le 14/11/2026. Les
2 morceaux « nushell asset name » de la version 2.9.1 ont été abandonnés :
l'amont les contient depuis la v2.10.

## Compiler

Sur une machine Linux avec Go ≥ 1.20 et `patch`, **pas sur le NAS** :

```bash
cd rmmagent-synology
./build.sh            # tag épinglé dans ../rmmagent-linux.sh (= version du serveur RMM)
./build.sh v2.12.0    # ou un tag explicite
```

Résultat : `dist/rmmagent-synology-v2.12.0-linux-amd64` + `.sha256`. Le
script s'arrête si le patch ne s'applique plus exactement (`--fuzz=0`), si le binaire n'annonce pas la
bonne version, ou si le correctif est absent du binaire.

Le binaire n'est plus versionné dans le dépôt (retiré en mars 2026, 11 Mo) :
l'ancienne URL `raw.githubusercontent.com/.../rmmagent-synology/rmmagent-synology`
renvoie 404.

## Installer

**IMPORTANT** : l'agent doit être installé sur `/volume1` : la partition
système `/dev/md0` ne fait que 2,3 Go.

```bash
scp dist/rmmagent-synology-v2.12.0-linux-amd64 admin@nas:/volume1/rmmagent/rmmagent.new
# sur le NAS, en root :
mkdir -p /volume1/rmmagent
mv /volume1/rmmagent/rmmagent.new /volume1/rmmagent/rmmagent
chmod 755 /volume1/rmmagent/rmmagent
ln -sf /volume1/rmmagent/rmmagent /usr/local/bin/rmmagent
```

Le service `tacticalagent` lance `/usr/local/bin/rmmagent -m svc`.

## Mettre à jour

Trois méthodes, de la plus simple à la plus manuelle :

1. **Depuis le serveur RMM (recommandé)**. Publier le binaire sous une URL
   HTTPS, puis envoyer `agentupdate` par NATS. L'agent télécharge, remplace
   `/volume1/rmmagent/rmmagent` (le lien est résolu) et redémarre le service.
   Procédure validée le 14/11/2026 (2.9.1 → 2.12.0).
2. **Avec `rmmagent-linux.sh`**, sur le NAS :
   ```bash
   TACTICAL_AGENT_BINARY=/volume1/rmmagent/rmmagent.new ./rmmagent-linux.sh update
   ```
   Le script vérifie la version, remplace le binaire et redémarre le service,
   avec retour arrière en cas d'échec. Sans `TACTICAL_AGENT_BINARY`, il refuse
   de compiler un agent standard sur un Synology.
3. **À la main** :
   ```bash
   systemctl stop tacticalagent
   cp -p /volume1/rmmagent/rmmagent /volume1/rmmagent/rmmagent.bak
   mv /volume1/rmmagent/rmmagent.new /volume1/rmmagent/rmmagent && chmod 755 /volume1/rmmagent/rmmagent
   systemctl start tacticalagent
   ```

## Vérifier

```bash
/usr/local/bin/rmmagent -version     # Tactical RMM Agent: 2.12.0
systemctl is-active tacticalagent
```

Dans Tactical RMM, ouvrir l'agent puis **Inventory > Hardware Details** : les
disques doivent afficher le modèle et le S/N.

## Restaurer l'agent original

```bash
systemctl stop tacticalagent
rm -f /usr/local/bin/rmmagent /volume1/rmmagent/rmmagent
# puis réinstaller l'agent officiel
```

## Notes

- `smartctl` est présent par défaut sur DSM.
- Le systemd de DSM est ancien (pas de `systemctl show --value`) et le NAS n'a
  ni `pgrep` ni `strings` : en tenir compte dans les scripts lancés depuis le RMM.
