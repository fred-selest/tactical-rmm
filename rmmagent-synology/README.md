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

### 1. Arrêter l'agent actuel

```bash
/usr/local/bin/rmmagent -m rpc stop
```

### 2. Sauvegarder l'agent original

```bash
cp /usr/local/bin/rmmagent /usr/local/bin/rmmagent.original
```

### 3. Copier le nouvel agent

Depuis votre poste :

```bash
scp rmmagent-synology root@<IP_NAS>:/usr/local/bin/rmmagent
```

Ou directement sur le NAS :

```bash
wget -O /usr/local/bin/rmmagent https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/rmmagent-synology/rmmagent-synology
chmod +x /usr/local/bin/rmmagent
```

### 4. Redémarrer l'agent

```bash
/usr/local/bin/rmmagent -m rpc start
```

### 5. Vérifier

Dans Tactical RMM :
1. Sélectionner l'agent Synology
2. Aller dans **Inventory** > **Hardware Details**
3. Les disques devraient maintenant afficher le modèle et le numéro de série

## Restaurer l'agent original

```bash
/usr/local/bin/rmmagent -m rpc stop
cp /usr/local/bin/rmmagent.original /usr/local/bin/rmmagent
/usr/local/bin/rmmagent -m rpc start
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
