#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Déploiement de l'agent Tactical RMM via GPO ou partage réseau

.DESCRIPTION
    Ce script est conçu pour être déployé via GPO (Group Policy Object) ou
    SCCM/Intune pour installer l'agent Tactical RMM sur plusieurs postes Windows.

    Modes de déploiement :
    1. GPO Startup Script - S'exécute au démarrage de la machine
    2. GPO Logon Script  - S'exécute à la connexion utilisateur (non recommandé)
    3. SCCM/Intune       - Déploiement géré par SCCM ou Intune

.PARAMETER ApiUrl
    URL de l'API Tactical RMM

.PARAMETER ClientId
    ID du client dans Tactical RMM

.PARAMETER SiteId
    ID du site dans Tactical RMM

.PARAMETER AuthKey
    Clé d'authentification de l'agent

.PARAMETER AgentType
    Type d'agent : 'server' ou 'workstation' (défaut: workstation)

.PARAMETER SharePath
    Chemin UNC vers un partage réseau contenant l'installateur
    (optionnel, si l'installateur ne doit pas être téléchargé depuis Internet)
    Exemple: \\srv-dc01\Software\TacticalRMM\tactical-agent-setup.exe

.PARAMETER LogPath
    Chemin du fichier log (défaut: C:\Windows\Temp\tactical-gpo.log)

.EXAMPLE
    # Via GPO Startup Script
    .\windows_agent_deploy_gpo.ps1 `
        -ApiUrl "https://api.votredomaine.com" `
        -ClientId 1 -SiteId 2 `
        -AuthKey "votre-auth-key"

.EXAMPLE
    # Via partage réseau (sans accès Internet requis)
    .\windows_agent_deploy_gpo.ps1 `
        -ApiUrl "https://api.votredomaine.com" `
        -ClientId 1 -SiteId 2 `
        -AuthKey "votre-auth-key" `
        -SharePath "\\srv-dc01\Software\TacticalRMM\tactical-agent-setup.exe"

.NOTES
    Configuration GPO recommandée :
    - Computer Configuration > Policies > Windows Settings > Scripts > Startup
    - Délai GPO : Assurez-vous que la connectivité réseau est disponible avant exécution
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiUrl,

    [Parameter(Mandatory = $true)]
    [int]$ClientId,

    [Parameter(Mandatory = $true)]
    [int]$SiteId,

    [Parameter(Mandatory = $true)]
    [string]$AuthKey,

    [Parameter(Mandatory = $false)]
    [ValidateSet("server", "workstation")]
    [string]$AgentType = "workstation",

    [Parameter(Mandatory = $false)]
    [string]$SharePath = "",

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Windows\Temp\tactical-gpo.log"
)

# =========================================
# FONCTIONS
# =========================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] [$($env:COMPUTERNAME)] $Message"
    Add-Content -Path $LogPath -Value $entry -ErrorAction SilentlyContinue
    switch ($Level) {
        "ERROR" { Write-Host $entry -ForegroundColor Red }
        "WARN"  { Write-Host $entry -ForegroundColor Yellow }
        "OK"    { Write-Host $entry -ForegroundColor Green }
        default { Write-Host $entry }
    }
}

function Test-AgentInstalled {
    $service = Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue
    if ($service) { return $true }

    $paths = @(
        "C:\Program Files\TacticalAgent\tacticalrmm.exe",
        "C:\Program Files (x86)\TacticalAgent\tacticalrmm.exe"
    )
    return ($paths | Where-Object { Test-Path $_ }).Count -gt 0
}

function Wait-NetworkConnectivity {
    param([int]$TimeoutSeconds = 120)

    Write-Log "Attente de la connectivité réseau..."
    $elapsed = 0

    while ($elapsed -lt $TimeoutSeconds) {
        # Test connectivité DNS
        try {
            $null = Resolve-DnsName -Name $([System.Uri]::new($ApiUrl).Host) -ErrorAction Stop
            Write-Log "Connectivité réseau disponible" -Level "OK"
            return $true
        }
        catch {
            Write-Log "Attente réseau... ($elapsed/$TimeoutSeconds sec)"
            Start-Sleep -Seconds 10
            $elapsed += 10
        }
    }

    Write-Log "Timeout: connectivité réseau non disponible après $TimeoutSeconds secondes" -Level "ERROR"
    return $false
}

function Get-InstallerFromShare {
    param([string]$SharePath, [string]$Destination)

    Write-Log "Copie de l'installateur depuis le partage: $SharePath"

    if (-not (Test-Path $SharePath)) {
        Write-Log "Partage inaccessible: $SharePath" -Level "ERROR"
        return $false
    }

    try {
        Copy-Item -Path $SharePath -Destination $Destination -Force
        Write-Log "Installateur copié avec succès" -Level "OK"
        return $true
    }
    catch {
        Write-Log "Erreur de copie: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Download-Installer {
    param([string]$Url, [string]$Destination)

    Write-Log "Téléchargement de l'installateur..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $retries = 3
    for ($i = 1; $i -le $retries; $i++) {
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $Destination)

            if ((Test-Path $Destination) -and (Get-Item $Destination).Length -gt 1KB) {
                $size = (Get-Item $Destination).Length / 1MB
                Write-Log ("Téléchargement réussi: {0:F1} MB" -f $size) -Level "OK"
                return $true
            }
        }
        catch {
            Write-Log "Tentative $i/$retries échouée: $($_.Exception.Message)" -Level "WARN"
            if ($i -lt $retries) { Start-Sleep -Seconds (5 * $i) }
        }
    }

    Write-Log "Échec du téléchargement après $retries tentatives" -Level "ERROR"
    return $false
}

function Detect-AgentType {
    # Détection automatique du type d'agent selon le rôle Windows
    $roles = Get-WindowsFeature -ErrorAction SilentlyContinue | Where-Object { $_.Installed -eq $true }

    if ($roles | Where-Object { $_.Name -eq "AD-Domain-Services" }) {
        return "server"
    }
    if ($roles | Where-Object { $_.Name -in @("Web-Server", "MSSQL", "FileAndStorage-Services") }) {
        return "server"
    }

    # Sur serveur Windows mais sans rôle explicite
    $os = Get-WmiObject -Class Win32_OperatingSystem
    if ($os.Caption -like "*Server*") {
        return "server"
    }

    return "workstation"
}

function Write-EventLog-Entry {
    param([string]$Message, [string]$Type = "Information")

    try {
        $source = "TacticalRMM-Deploy"
        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            New-EventLog -LogName Application -Source $source -ErrorAction SilentlyContinue
        }
        Write-EventLog -LogName Application -Source $source -EventId 1000 `
            -EntryType $Type -Message $Message -ErrorAction SilentlyContinue
    }
    catch { }
}

# =========================================
# DÉBUT DU SCRIPT
# =========================================

Write-Log "=========================================="
Write-Log "DÉPLOIEMENT GPO - TACTICAL RMM AGENT"
Write-Log "=========================================="
Write-Log "Hostname : $($env:COMPUTERNAME)"
Write-Log "Domaine  : $($env:USERDOMAIN)"
Write-Log "API URL  : $ApiUrl"
Write-Log "Client   : $ClientId | Site: $SiteId"

# =========================================
# 1. VÉRIFIER SI DÉJÀ INSTALLÉ
# =========================================

if (Test-AgentInstalled) {
    Write-Log "L'agent est déjà installé sur ce poste. Aucune action nécessaire." -Level "OK"
    Write-EventLog-Entry "Tactical RMM Agent: déjà installé, aucune action." "Information"
    exit 0
}

Write-Log "Agent non installé. Démarrage du déploiement..."

# =========================================
# 2. ATTENDRE LA CONNECTIVITÉ RÉSEAU
# =========================================

if (-not (Wait-NetworkConnectivity -TimeoutSeconds 120)) {
    Write-Log "Impossible de continuer sans connectivité réseau" -Level "ERROR"
    Write-EventLog-Entry "Tactical RMM Agent: échec déploiement - pas de réseau." "Error"
    exit 1
}

# =========================================
# 3. AUTO-DÉTECTION DU TYPE D'AGENT
# =========================================

if ($AgentType -eq "workstation") {
    $detectedType = Detect-AgentType
    if ($detectedType -ne $AgentType) {
        Write-Log "Type d'agent auto-détecté: $detectedType (était: $AgentType)" -Level "WARN"
        $AgentType = $detectedType
    }
}

Write-Log "Type d'agent: $AgentType"

# =========================================
# 4. OBTENIR L'INSTALLATEUR
# =========================================

$arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "x86" }
$tempDir = "C:\Windows\Temp\tactical-gpo-$$"
$installerPath = "$tempDir\tactical-agent-setup.exe"

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$installerOK = $false

# Option 1: Copier depuis un partage réseau (préférable en environnement AD)
if ($SharePath -ne "") {
    $installerOK = Get-InstallerFromShare -SharePath $SharePath -Destination $installerPath
}

# Option 2: Télécharger depuis l'API
if (-not $installerOK) {
    $downloadUrl = "$ApiUrl/api/v3/agents/installer/?agent_type=$AgentType&client_id=$ClientId&site_id=$SiteId&arch=$arch&token=$AuthKey"
    $installerOK = Download-Installer -Url $downloadUrl -Destination $installerPath
}

if (-not $installerOK) {
    Write-Log "Impossible d'obtenir l'installateur" -Level "ERROR"
    Write-EventLog-Entry "Tactical RMM Agent: échec déploiement - installateur non disponible." "Error"
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# =========================================
# 5. INSTALLER L'AGENT
# =========================================

Write-Log "Installation silencieuse de l'agent..."
Write-EventLog-Entry "Tactical RMM Agent: démarrage de l'installation." "Information"

try {
    $process = Start-Process -FilePath $installerPath `
        -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/LOG=`"C:\Windows\Temp\tactical-inno-gpo.log`"" `
        -Wait -PassThru -ErrorAction Stop

    Write-Log "Code de retour: $($process.ExitCode)"
}
catch {
    Write-Log "Erreur d'installation: $($_.Exception.Message)" -Level "ERROR"
    Write-EventLog-Entry "Tactical RMM Agent: erreur installation - $($_.Exception.Message)." "Error"
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# =========================================
# 6. VÉRIFIER L'INSTALLATION
# =========================================

Start-Sleep -Seconds 10

if (Test-AgentInstalled) {
    Write-Log "DÉPLOIEMENT RÉUSSI" -Level "OK"
    Write-EventLog-Entry "Tactical RMM Agent: installation réussie sur $($env:COMPUTERNAME)." "Information"

    # Vérifier le service
    $service = Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Log "Service: $($service.Status)" -Level "OK"
    }
} else {
    Write-Log "DÉPLOIEMENT ÉCHOUÉ - Agent non détecté après installation" -Level "ERROR"
    Write-EventLog-Entry "Tactical RMM Agent: échec installation sur $($env:COMPUTERNAME)." "Error"

    # Afficher les logs Inno
    if (Test-Path "C:\Windows\Temp\tactical-inno-gpo.log") {
        Write-Log "--- Logs Inno Setup ---"
        Get-Content "C:\Windows\Temp\tactical-inno-gpo.log" -Tail 20 | ForEach-Object {
            Write-Log $_
        }
    }

    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Nettoyage
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Log "Nettoyage terminé"
Write-Log "Log de déploiement: $LogPath"
exit 0
