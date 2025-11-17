# Installation d'un agent Linux Tactical RMM (sans token de signature de code)

Cette méthode utilise le script communautaire [LinuxRMM-Script](https://github.com/netvolt/LinuxRMM-Script) pour installer un agent Linux sans nécessiter de token de signature de code.

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

### URL du Mesh (MESH_URL)
1. Connectez-vous à MeshCentral (`https://mesh.votredomaine.com`)
2. Allez dans **Mon serveur** → **Ajouter un agent**
3. Sélectionnez un groupe d'appareils
4. Choisissez **Linux 64-bit** (ID 6)
5. Copiez l'URL complète du lien de téléchargement

### URL de l'API (API_URL)
Votre URL API Tactical RMM : `https://api.votredomaine.com`

### Identifiant du client (CLIENT_ID) et du site (SITE_ID)
1. Dans Tactical RMM, survolez le nom du **Client** pour voir son identifiant
2. Survolez le nom du **Site** pour voir son identifiant

### Clé d'authentification (AUTH_KEY)
1. Dans Tactical RMM → **Agents** → **Installer un agent**
2. Sélectionnez n'importe quel système → **Manuel**
3. Copiez la valeur après `--auth`

### Type d'agent (AGENT_TYPE)
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
  'https://mesh.exemple.com/meshagents?id=ABC123DEF456&installflags=0&meshinstall=6' \
  'https://api.exemple.com' \
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
sudo ./rmmagent-linux.sh uninstall 'NOM_DOMAINE_MESH' 'ID_MESH'
```

## Dépannage

Si l'installation échoue :
- Vérifiez que tous les paramètres sont corrects
- Assurez-vous que les ports 443 sont ouverts
- Consultez les journaux : `journalctl -u tacticalagent`

## Références

- [LinuxRMM-Script sur GitHub](https://github.com/netvolt/LinuxRMM-Script)
- [Documentation Tactical RMM](https://docs.tacticalrmm.com/)
