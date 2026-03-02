# Installation de l'agent Tactical RMM sur Windows

Scripts PowerShell pour installer, mettre à jour, diagnostiquer et désinstaller l'agent Tactical RMM sur des postes et serveurs Windows.

## Scripts disponibles

| Script | Description |
|--------|-------------|
| `windows_agent_install.ps1` | Installation complète de l'agent |
| `windows_agent_update.ps1` | Mise à jour de l'agent (avec rollback automatique) |
| `windows_agent_check.ps1` | Diagnostic complet de l'état de l'agent |
| `windows_agent_deploy_gpo.ps1` | Déploiement automatisé via GPO ou SCCM |
| `windows_agent_uninstall.ps1` | Désinstallation propre de l'agent |

## Prérequis

- Windows 8.1 / Server 2012 R2 ou version ultérieure
- PowerShell 5.1 ou supérieur
- .NET Framework 4.7.2 ou supérieur
- Droits administrateur locaux
- Connectivité vers votre serveur Tactical RMM

## Utilisation

### 1. Installation

```powershell
# Activer l'exécution des scripts PowerShell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Installation sur un serveur
.\windows_agent_install.ps1 `
    -ApiUrl "https://api.votredomaine.com" `
    -ClientId 1 `
    -SiteId 2 `
    -AuthKey "votre-auth-key-ici" `
    -AgentType "server"

# Installation sur un poste de travail
.\windows_agent_install.ps1 `
    -ApiUrl "https://api.votredomaine.com" `
    -ClientId 1 `
    -SiteId 2 `
    -AuthKey "votre-auth-key-ici" `
    -AgentType "workstation"
```

**Paramètres disponibles :**

| Paramètre | Obligatoire | Description |
|-----------|-------------|-------------|
| `-ApiUrl` | Oui | URL API Tactical RMM (`https://api.votredomaine.com`) |
| `-ClientId` | Oui | ID du client dans Tactical RMM |
| `-SiteId` | Oui | ID du site dans Tactical RMM |
| `-AuthKey` | Oui | Clé d'authentification de l'agent |
| `-AgentType` | Non | `server` ou `workstation` (défaut: `workstation`) |
| `-ForceReinstall` | Non | Forcer la réinstallation si déjà installé |
| `-LogPath` | Non | Chemin du fichier log |

**Où trouver les paramètres :**
1. Ouvrir l'interface Tactical RMM
2. **Clients** > Sélectionner votre client > **Sites**
3. Cliquer sur **Deploy Agent**
4. Les valeurs ApiUrl, ClientId, SiteId et AuthKey sont affichées

---

### 2. Vérification / Diagnostic

```powershell
# Vérifier l'état de l'agent
.\windows_agent_check.ps1

# Avec test de connectivité vers l'API
.\windows_agent_check.ps1 -ApiUrl "https://api.votredomaine.com"

# Afficher plus de logs
.\windows_agent_check.ps1 -ApiUrl "https://api.votredomaine.com" -ShowLogs 50
```

**Exemple de sortie :**
```
==========================================
  DIAGNOSTIC AGENT TACTICAL RMM WINDOWS
==========================================
  Serveur : SRV-DC01
  Date    : 18/12/2025 14:30:00
==========================================

--- SERVICE TACTICALRMM ---
[OK]   Service trouvé          tacticalrmm
[OK]   État                    Running
[OK]   Démarrage               Automatic
[OK]   Temps de fonctionnement 2j 4h 15m

--- INSTALLATION ---
[OK]   Binaire                 C:\Program Files\TacticalAgent\tacticalrmm.exe
[OK]   Taille                  25.3 MB
[OK]   Version installée       2.5.0

--- CONFIGURATION ---
[OK]   Fichier config          OK
[OK]   API URL                 https://api.votredomaine.com
[OK]   Client ID               1

--- CONNECTIVITÉ ---
[OK]   API Tactical RMM        https://api.votredomaine.com
[OK]   Réponse HTTP            200

--- ÉTAT GLOBAL: OPÉRATIONNEL ---
```

---

### 3. Mise à jour

```powershell
# Mise à jour standard
.\windows_agent_update.ps1 -ApiUrl "https://api.votredomaine.com"

# Forcer la mise à jour même si même version
.\windows_agent_update.ps1 -ApiUrl "https://api.votredomaine.com" -ForceUpdate
```

**Fonctionnalités de mise à jour :**
- Détection automatique de la version courante
- Comparaison avec la version distante
- Sauvegarde de la configuration avant mise à jour
- **Rollback automatique** si la mise à jour échoue
- Redémarrage du service après mise à jour

---

### 4. Déploiement via GPO (Active Directory)

#### Configuration de la GPO

1. Ouvrir **Group Policy Management** sur le contrôleur de domaine
2. Créer une nouvelle GPO : `Tactical RMM - Agent Deploy`
3. Lier la GPO à l'OU contenant les postes cibles
4. Modifier la GPO :
   - **Computer Configuration** > **Policies** > **Windows Settings** > **Scripts** > **Startup**
5. Ajouter un script PowerShell :

```
Script: \\srv-dc01\sysvol\votredomaine.com\scripts\windows_agent_deploy_gpo.ps1
Paramètres:
  -ApiUrl "https://api.votredomaine.com"
  -ClientId 1
  -SiteId 2
  -AuthKey "votre-auth-key"
  -AgentType "workstation"
```

#### Via un partage réseau (sans Internet)

Si les postes n'ont pas accès direct à Internet, pré-télécharger l'installateur :

```powershell
# 1. Télécharger l'installateur sur le serveur
Invoke-WebRequest -Uri "https://api.votredomaine.com/api/v3/agents/installer/?agent_type=workstation&client_id=1&site_id=2&arch=amd64&token=VOTRE_AUTH_KEY" `
    -OutFile "\\srv-dc01\Software\TacticalRMM\tactical-agent-setup.exe"

# 2. Déployer avec SharePath
.\windows_agent_deploy_gpo.ps1 `
    -ApiUrl "https://api.votredomaine.com" `
    -ClientId 1 -SiteId 2 `
    -AuthKey "votre-auth-key" `
    -SharePath "\\srv-dc01\Software\TacticalRMM\tactical-agent-setup.exe"
```

#### Comportement du script GPO

- ✅ Vérifie si l'agent est déjà installé (ne réinstalle pas)
- ✅ Attend la connectivité réseau (jusqu'à 2 minutes)
- ✅ Auto-détecte le type d'agent (server/workstation)
- ✅ 3 tentatives de téléchargement avec backoff
- ✅ Écrit dans le journal d'événements Windows (Application > TacticalRMM-Deploy)
- ✅ Logs dans `C:\Windows\Temp\tactical-gpo.log`

#### Vérifier le déploiement depuis le DC

```powershell
# Vérifier les postes qui ont l'agent installé
$computers = Get-ADComputer -Filter * -SearchBase "OU=Workstations,DC=votredomaine,DC=com"
foreach ($pc in $computers) {
    $result = Invoke-Command -ComputerName $pc.Name -ScriptBlock {
        Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue
    } -ErrorAction SilentlyContinue

    if ($result -and $result.Status -eq "Running") {
        Write-Host "$($pc.Name): OK" -ForegroundColor Green
    } else {
        Write-Host "$($pc.Name): NON INSTALLÉ" -ForegroundColor Red
    }
}
```

---

### 5. Désinstallation

```powershell
# Désinstallation complète (agent + Mesh)
.\windows_agent_uninstall.ps1

# Désinstallation sans supprimer Mesh
.\windows_agent_uninstall.ps1 -RemoveMesh:$false

# Conserver les logs
.\windows_agent_uninstall.ps1 -KeepLogs

# Avec FQDN Mesh pour désinstallation propre
.\windows_agent_uninstall.ps1 -MeshFqdn "mesh.votredomaine.com"
```

---

## Déploiement en ligne de commande (One-liner)

Pour une installation rapide depuis l'interface Tactical RMM, utilisez la commande générée automatiquement :

1. Dans Tactical RMM : **Agents** > **Install Agent** > **Windows**
2. Sélectionner **PowerShell** comme méthode
3. Copier la commande générée

Ou utiliser ce template :

```powershell
# Template one-liner
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `
$url = "https://api.votredomaine.com/api/v3/agents/installer/?agent_type=workstation&client_id=1&site_id=2&arch=amd64&token=VOTRE_AUTH_KEY"; `
$out = "$env:TEMP\tactical-setup.exe"; `
(New-Object System.Net.WebClient).DownloadFile($url, $out); `
Start-Process $out -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait; `
Remove-Item $out -Force
```

---

## Fichiers de logs

| Fichier | Description |
|---------|-------------|
| `C:\Windows\Temp\tactical-install.log` | Log d'installation |
| `C:\Windows\Temp\tactical-update.log` | Log de mise à jour |
| `C:\Windows\Temp\tactical-uninstall.log` | Log de désinstallation |
| `C:\Windows\Temp\tactical-gpo.log` | Log de déploiement GPO |
| `C:\Windows\Temp\tactical-inno.log` | Log interne Inno Setup |

---

## Dépannage

### L'agent n'apparaît pas dans Tactical RMM

```powershell
# 1. Vérifier le service
Get-Service tacticalrmm

# 2. Consulter les logs
.\windows_agent_check.ps1 -ApiUrl "https://api.votredomaine.com"

# 3. Tester la connectivité
Invoke-WebRequest -Uri "https://api.votredomaine.com/api/v3/ping/" -Method Get

# 4. Redémarrer le service
Restart-Service tacticalrmm
```

### Erreur "ExecutionPolicy"

```powershell
# Autoriser l'exécution temporairement
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

### Erreur lors du téléchargement

```powershell
# Forcer TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Tester l'accès à l'URL manuellement
Invoke-WebRequest -Uri "https://api.votredomaine.com/api/v3/ping/" -Verbose
```

### L'agent démarre mais se reconnecte en boucle

Vérifier les ports firewall requis :
- **443** (HTTPS) vers votre serveur API
- **443** (HTTPS) vers votre serveur Mesh

```powershell
# Tester les ports
Test-NetConnection -ComputerName "api.votredomaine.com" -Port 443
Test-NetConnection -ComputerName "mesh.votredomaine.com" -Port 443
```

---

## Ports et firewall

| Port | Protocole | Direction | Destination | Requis pour |
|------|-----------|-----------|-------------|-------------|
| 443 | HTTPS | Sortant | api.votredomaine.com | API Tactical RMM |
| 443 | HTTPS | Sortant | mesh.votredomaine.com | Mesh Agent / Accès à distance |

---

## Versions Windows supportées

| Version | Support |
|---------|---------|
| Windows 11 | ✅ |
| Windows 10 | ✅ |
| Windows 8.1 | ✅ |
| Windows Server 2022 | ✅ |
| Windows Server 2019 | ✅ |
| Windows Server 2016 | ✅ |
| Windows Server 2012 R2 | ✅ |
| Windows Server 2012 | ⚠️ Limité |
| Windows 7 / Server 2008 | ❌ Non supporté |
