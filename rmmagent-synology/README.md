# rmmagent modifié pour Synology

Agent Tactical RMM modifié pour afficher correctement les informations des disques sur les NAS Synology.

## Problème résolu

L'agent standard utilise la bibliothèque `ghw` qui ne détecte pas correctement les disques sur Synology, affichant "Unknown Unknown" dans Hardware Details.

Cette version modifiée utilise `smartctl` pour obtenir les vraies informations des disques (modèle, fabricant, numéro de série) lorsque `ghw` échoue.

## Modification apportée

Fichier modifié : `agent/agent_unix.go`

La fonction `GetWMIInfo()` a été modifiée pour :
1. Détecter si on est sur un Synology (via `/etc/synoinfo.conf`)
2. Si le modèle ou le fabricant est "unknown", exécuter `smartctl -i /dev/diskX`
3. Parser la sortie pour extraire le modèle, le fabricant et le numéro de série

## Installation sur Synology

**IMPORTANT** : L'agent doit être installé sur `/volume1` pour éviter de remplir la partition système `/dev/md0` (seulement 2.3 Go).

### 1. Arrêter l'agent actuel (si existant)

```bash
/usr/local/bin/rmmagent -m rpc stop 2>/dev/null
```

### 2. Créer le dossier sur /volume1

```bash
mkdir -p /volume1/rmmagent
```

### 3. Télécharger l'agent sur /volume1

```bash
wget -O /volume1/rmmagent/rmmagent https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/rmmagent-synology/rmmagent-synology
chmod +x /volume1/rmmagent/rmmagent
```

### 4. Créer le lien symbolique

```bash
# Supprimer l'ancien agent si présent
rm -f /usr/local/bin/rmmagent

# Créer le lien symbolique
ln -s /volume1/rmmagent/rmmagent /usr/local/bin/rmmagent
```

### 5. Démarrer l'agent

```bash
/usr/local/bin/rmmagent -m rpc start
```

### 6. Vérifier

Dans Tactical RMM :
1. Sélectionner l'agent Synology
2. Aller dans **Inventory** > **Hardware Details**
3. Les disques devraient maintenant afficher le modèle et le numéro de série

## Mise à jour de l'agent

```bash
/usr/local/bin/rmmagent -m rpc stop
wget -O /volume1/rmmagent/rmmagent https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/rmmagent-synology/rmmagent-synology
chmod +x /volume1/rmmagent/rmmagent
/usr/local/bin/rmmagent -m rpc start
```

## Restaurer l'agent original

```bash
/usr/local/bin/rmmagent -m rpc stop
rm -f /usr/local/bin/rmmagent /volume1/rmmagent/rmmagent
# Réinstaller l'agent officiel via LinuxRMM-Script
```

## Compilation depuis les sources

Si vous souhaitez recompiler l'agent vous-même :

```bash
# Cloner le dépôt officiel
git clone https://github.com/amidaware/rmmagent.git
cd rmmagent

# Appliquer la modification (voir agent_unix.go dans ce dossier)
# ou copier le fichier modifié
cp /chemin/vers/agent_unix.go agent/agent_unix.go

# Compiler pour linux/amd64
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o rmmagent-synology -ldflags "-s -w" .
```

## Notes

- Cette modification est spécifique aux NAS Synology
- `smartctl` doit être disponible sur le NAS (installé par défaut)
- La modification n'affecte pas le fonctionnement sur les autres systèmes Linux
