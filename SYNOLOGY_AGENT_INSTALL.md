# Installation de l'agent Tactical RMM sur NAS Synology

Guide pour installer l'agent Tactical RMM sur un NAS Synology (DSM 6 et DSM 7).

## Prérequis

- NAS Synology avec DSM 6.x ou 7.x
- Accès administrateur
- SSH activé sur le NAS

## Étape 1 : Activer SSH sur le NAS

1. Connectez-vous à DSM (interface web)
2. Allez dans **Panneau de configuration** → **Terminal & SNMP**
3. Cochez **Activer le service SSH**
4. Port par défaut : 22
5. Cliquez sur **Appliquer**

## Étape 2 : Se connecter en SSH

```bash
ssh admin@IP_DU_NAS
```

Remplacez `admin` par votre nom d'utilisateur et `IP_DU_NAS` par l'adresse IP du NAS.

**Note** : Sur DSM 7, utilisez `sudo -i` pour passer en root.

## Étape 3 : Récupérer les informations nécessaires

Depuis votre **Tactical RMM** :

### URL du Mesh (MESH_URL)
1. Connectez-vous à MeshCentral (`https://mesh.votredomaine.com`)
2. **My Server** → **Add Agent**
3. Sélectionnez un groupe
4. Choisissez **Linux 64-bit** (ID 6)
5. Copiez l'URL complète

### Clé d'authentification (AUTH_KEY)
1. Tactical RMM → **Agents** → **Install Agent**
2. Sélectionnez **Windows** → **Manual**
3. Copiez la valeur après `--auth`

### CLIENT_ID et SITE_ID
Survolez le nom du Client et du Site dans le dashboard pour voir leurs IDs.

## Étape 4 : Installer l'agent

### Sur DSM 7 (recommandé)

```bash
# Passer en root
sudo -i

# Télécharger le script
cd /tmp
wget https://raw.githubusercontent.com/netvolt/LinuxRMM-Script/main/rmmagent-linux.sh
chmod +x rmmagent-linux.sh

# Installer l'agent
./rmmagent-linux.sh install \
  'MESH_URL' \
  'https://api.votredomaine.com' \
  CLIENT_ID \
  SITE_ID \
  'AUTH_KEY' \
  server
```

### Sur DSM 6

```bash
# Passer en root
sudo -i

# Télécharger le script
cd /tmp
wget https://raw.githubusercontent.com/netvolt/LinuxRMM-Script/main/rmmagent-linux.sh
chmod +x rmmagent-linux.sh

# Installer l'agent
./rmmagent-linux.sh install \
  'MESH_URL' \
  'https://api.votredomaine.com' \
  CLIENT_ID \
  SITE_ID \
  'AUTH_KEY' \
  server
```

## Exemple complet avec votredomaine.com

```bash
sudo -i
cd /tmp
wget https://raw.githubusercontent.com/netvolt/LinuxRMM-Script/main/rmmagent-linux.sh
chmod +x rmmagent-linux.sh

./rmmagent-linux.sh install \
  'https://mesh.votredomaine.com/meshagents?id=6' \
  'https://api.votredomaine.com' \
  1 \
  1 \
  '4ea7263d94c4973655c25c62e94663f2505656e98fb586b63ef3be30995f04ab' \
  server
```

## Étape 5 : Vérifier l'installation

```bash
# Vérifier que l'agent tourne
systemctl status tacticalagent

# Voir les logs
journalctl -u tacticalagent -f
```

L'agent devrait apparaître dans Tactical RMM sous quelques minutes.

## Étape 6 : Installer les scripts de surveillance

```bash
mkdir -p /opt/tacticalrmm/scripts
cd /opt/tacticalrmm/scripts

for script in synology_check_all synology_check_system synology_check_disks synology_check_raid synology_check_services synology_check_backup synology_check_security; do
  wget "https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/${script}.sh"
done

chmod +x *.sh
```

## Configuration post-installation

### Ajouter les scripts dans Tactical RMM

1. **Settings** → **Script Manager** → **New**
2. Type : `Shell`
3. Collez le contenu du script souhaité
4. Enregistrez

### Créer une tâche de surveillance

1. Sélectionnez l'agent Synology
2. **Tasks** → **Add Task**
3. Script : `synology_check_all.sh`
4. Planification : Toutes les heures

## Problèmes connus

### DSM 7 : Permissions

Sur DSM 7, certaines commandes nécessitent des privilèges root. Assurez-vous d'exécuter les scripts avec `sudo` ou de configurer l'agent pour qu'il s'exécute en tant que root.

### Go non installé

Le script compile l'agent, ce qui nécessite Go. Si Go n'est pas installé :

```bash
# Sur Synology, installer via le Community Package
# Ou télécharger manuellement
cd /tmp
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
```

### Persistance après redémarrage

Assurez-vous que le service est activé :

```bash
systemctl enable tacticalagent
systemctl enable meshagent
```

### Pare-feu Synology

Vérifiez que le port 443 sortant est ouvert dans le pare-feu DSM.

## Mise à jour de l'agent

```bash
cd /tmp
./rmmagent-linux.sh update
```

## Désinstallation

```bash
cd /tmp
./rmmagent-linux.sh uninstall 'mesh.votredomaine.com' 'MESH_ID'

# Supprimer les scripts
rm -rf /opt/tacticalrmm
```

## Architecture supportée

| Modèle Synology | Architecture | Support |
|-----------------|--------------|---------|
| DS220+, DS420+, DS920+ | x86_64 | Oui |
| DS218, DS418 | ARM64 | Oui (ID 26) |
| DS220j, DS420j | ARM32 | Limité |

Pour les modèles ARM, utilisez l'ID approprié pour le Mesh Agent :
- ARM 64-bit : ID 26 ou 32
- ARM 32-bit : ID 25 ou 27

## Vérification de l'architecture

```bash
uname -m
```

- `x86_64` → Linux 64-bit (ID 6)
- `aarch64` → ARM 64-bit (ID 26)
- `armv7l` → ARM 32-bit (ID 25)
