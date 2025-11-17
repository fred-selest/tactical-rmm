# Installation d'un agent Linux Tactical RMM (sans code signing token)

Cette méthode utilise le script communautaire [LinuxRMM-Script](https://github.com/netvolt/LinuxRMM-Script) pour installer un agent Linux sans nécessiter de token de code signing.

## Prérequis

- Accès root sur le poste Linux client
- Accès à votre interface Tactical RMM et MeshCentral

## Étape 1 : Télécharger le script

Sur le poste Linux client :

```bash
wget https://raw.githubusercontent.com/netvolt/LinuxRMM-Script/main/rmmagent-linux.sh
chmod +x rmmagent-linux.sh
```

## Étape 2 : Récupérer les informations nécessaires

### MESH_URL
1. Connectez-vous à MeshCentral (`https://mesh.votredomaine.com`)
2. Allez dans **My Server** → **Add Agent**
3. Sélectionnez un groupe d'appareils
4. Choisissez **Linux 64-bit** (ID 6)
5. Copiez l'URL complète du lien de téléchargement

### API_URL
Votre URL API Tactical RMM : `https://api.votredomaine.com`

### CLIENT_ID et SITE_ID
1. Dans Tactical RMM, survolez le nom du **Client** pour voir son ID
2. Survolez le nom du **Site** pour voir son ID

### AUTH_KEY
1. Dans Tactical RMM → **Agents** → **Install Agent**
2. Sélectionnez n'importe quel OS → **Manual**
3. Copiez la valeur après `--auth`

### AGENT_TYPE
- `server` pour un serveur
- `workstation` pour un poste de travail

## Étape 3 : Exécuter l'installation

```bash
sudo ./rmmagent-linux.sh install \
  'MESH_URL' \
  'API_URL' \
  CLIENT_ID \
  SITE_ID \
  'AUTH_KEY' \
  AGENT_TYPE
```

## Exemple complet

```bash
sudo ./rmmagent-linux.sh install \
  'https://mesh.example.com/meshagents?id=ABC123DEF456&installflags=0&meshinstall=6' \
  'https://api.example.com' \
  1 \
  1 \
  '4ea7263d94c4973655c25c62e94663f2505656e98fb586b63ef3be30995f04ab' \
  server
```

## Notes importantes

- **Temps d'installation** : Plusieurs minutes (compilation de l'agent)
- **Guillemets** : Utilisez des guillemets simples `'...'` autour des paramètres
- **Vérification** : L'agent apparaîtra dans Tactical RMM une fois l'installation terminée

## Autres commandes

### Mise à jour de l'agent
```bash
sudo ./rmmagent-linux.sh update
```

### Désinstallation
```bash
sudo ./rmmagent-linux.sh uninstall 'MESH_FQDN' 'MESH_ID'
```

## Dépannage

Si l'installation échoue :
- Vérifiez que tous les paramètres sont corrects
- Assurez-vous que les ports 443 sont ouverts
- Consultez les logs : `journalctl -u tacticalagent`

## Références

- [LinuxRMM-Script GitHub](https://github.com/netvolt/LinuxRMM-Script)
- [Documentation Tactical RMM](https://docs.tacticalrmm.com/)
