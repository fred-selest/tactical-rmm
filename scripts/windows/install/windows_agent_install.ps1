#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installation de l'agent Tactical RMM sur Windows

.DESCRIPTION
    Ce script installe l'agent Tactical RMM sur un poste ou serveur Windows.
    Il télécharge l'installateur depuis votre serveur Tactical RMM et l'exécute
    en mode silencieux avec les paramètres fournis.

.PARAMETER ApiUrl
    URL de l'API Tactical RMM (ex: https://api.votredomaine.com)

.PARAMETER ClientId
    ID du client dans Tactical RMM

.PARAMETER SiteId
    ID du site dans Tactical RMM

.PARAMETER AuthKey
    Clé d'authentification de l'agent

.PARAMETER AgentType
    Type d'agent : 'server' ou 'workstation' (défaut: workstation)

.PARAMETER ForceReinstall
    Forcer la réinstallation si l'agent est déjà installé

.PARAMETER LogPath
    Chemin du fichier log (défaut: C:\Windows\Temp\tactical-install.log)

.EXAMPLE
    .\windows_agent_install.ps1 `
        -ApiUrl "https://api.votredomaine.com" `
        -ClientId 1 `
        -SiteId 2 `
        -AuthKey "votre-auth-key-ici" `
        -AgentType "server"

.EXAMPLE
    # Installation silencieuse pour déploiement GPO
    .\windows_agent_install.ps1 -ApiUrl "https://api.votredomaine.com" `
        -ClientId 1 -SiteId 2 -AuthKey "votre-auth-key" -AgentType "workstation"

.NOTES
    Auteur   : Tactical RMM Admin
    Version  : 2.0
    Prérequis: PowerShell 5.1+, .NET 4.7.2+, Windows 8.1/Server 2012 R2+
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
    [switch]$ForceReinstall,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Windows\Temp\tactical-install.log"
)

# =========================================
# FONCTIONS
# =========================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $entry -ErrorAction SilentlyContinue
    switch ($Level) {
        "ERROR" { Write-Host $entry -ForegroundColor Red }
        "WARN"  { Write-Host $entry -ForegroundColor Yellow }
        "OK"    { Write-Host $entry -ForegroundColor Green }
        default { Write-Host $entry }
    }
}

function Test-AgentInstalled {
    $paths = @(
        "HKLM:\SOFTWARE\TacticalRMM",
        "C:\Program Files\TacticalAgent",
        "C:\Program Files (x86)\TacticalAgent"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) { return $true }
    }
    $service = Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue
    return ($null -ne $service)
}

function Get-Architecture {
    if ([Environment]::Is64BitOperatingSystem) { return "amd64" }
    else { return "x86" }
}

function Get-InstallerUrl {
    param([string]$ApiUrl, [string]$Arch)

    # Récupérer la dernière version disponible
    try {
        $versionUrl = "$ApiUrl/api/v3/agents/latestver/"
        $response = Invoke-RestMethod -Uri $versionUrl -Method Get -TimeoutSec 30 -ErrorAction Stop
        $version = $response.version
        Write-Log "Version agent disponible: $version"
        return "$ApiUrl/api/v3/agents/installer/?agent_type=$AgentType&client_id=$ClientId&site_id=$SiteId&arch=$Arch&token=$AuthKey"
    }
    catch {
        Write-Log "Impossible de récupérer la version via l'API, utilisation de l'URL directe" -Level "WARN"
        return "$ApiUrl/api/v3/agents/installer/?agent_type=$AgentType&client_id=$ClientId&site_id=$SiteId&arch=$Arch&token=$AuthKey"
    }
}

function Test-Prerequisites {
    Write-Log "Vérification des prérequis..."

    # Version Windows
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 6 -or ($osVersion.Major -eq 6 -and $osVersion.Minor -lt 2)) {
        Write-Log "Windows non supporté. Requis: Windows 8.1 / Server 2012 R2 minimum" -Level "ERROR"
        return $false
    }
    Write-Log "Windows version: $([System.Environment]::OSVersion.VersionString)" -Level "OK"

    # .NET Framework
    $dotNetKey = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
    if (Test-Path $dotNetKey) {
        $release = (Get-ItemProperty $dotNetKey).Release
        if ($release -ge 461808) {
            Write-Log ".NET Framework 4.7.2+ détecté" -Level "OK"
        } else {
            Write-Log ".NET Framework 4.7.2+ requis (actuel: $release)" -Level "WARN"
        }
    }

    # Connectivité API
    Write-Log "Test de connectivité vers $ApiUrl..."
    try {
        $response = Invoke-WebRequest -Uri "$ApiUrl/api/v3/ping/" -Method Get -TimeoutSec 10 -ErrorAction Stop
        Write-Log "Connectivité API: OK" -Level "OK"
    }
    catch {
        Write-Log "ATTENTION: API non accessible - $($_.Exception.Message)" -Level "WARN"
        Write-Log "L'installation continuera, mais vérifiez la connectivité réseau" -Level "WARN"
    }

    # Espace disque
    $drive = Split-Path -Qualifier "C:\Program Files"
    $disk = Get-PSDrive -Name ($drive.TrimEnd(':')) -ErrorAction SilentlyContinue
    if ($disk -and $disk.Free -lt 500MB) {
        Write-Log "Espace disque insuffisant sur C: (< 500 MB)" -Level "ERROR"
        return $false
    }
    Write-Log "Espace disque: OK" -Level "OK"

    return $true
}

function Download-Installer {
    param([string]$Url, [string]$Destination)

    Write-Log "Téléchargement de l'installateur..."

    # Configurer TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $Destination)

        if (-not (Test-Path $Destination) -or (Get-Item $Destination).Length -lt 1KB) {
            Write-Log "Fichier téléchargé invalide ou vide" -Level "ERROR"
            return $false
        }

        $size = (Get-Item $Destination).Length / 1MB
        Write-Log ("Installateur téléchargé: {0:F1} MB" -f $size) -Level "OK"
        return $true
    }
    catch {
        Write-Log "Erreur de téléchargement: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Install-Agent {
    param([string]$InstallerPath)

    Write-Log "Lancement de l'installation silencieuse..."

    $installArgs = @(
        "/VERYSILENT",
        "/SUPPRESSMSGBOXES",
        "/NORESTART",
        "/LOG=`"C:\Windows\Temp\tactical-inno.log`""
    )

    try {
        $process = Start-Process -FilePath $InstallerPath `
            -ArgumentList $installArgs `
            -Wait -PassThru -ErrorAction Stop

        if ($process.ExitCode -eq 0) {
            Write-Log "Installation terminée avec succès (code: 0)" -Level "OK"
            return $true
        }
        elseif ($process.ExitCode -eq 1) {
            Write-Log "Installation annulée par l'utilisateur (code: 1)" -Level "WARN"
            return $false
        }
        else {
            Write-Log "Code de retour inattendu: $($process.ExitCode)" -Level "WARN"
            # Vérifier quand même si l'agent est bien installé
            Start-Sleep -Seconds 5
            return (Test-AgentInstalled)
        }
    }
    catch {
        Write-Log "Erreur lors de l'installation: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Wait-AgentService {
    Write-Log "Attente du démarrage du service..."
    $timeout = 60
    $elapsed = 0

    while ($elapsed -lt $timeout) {
        $service = Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq "Running") {
            Write-Log "Service tacticalrmm démarré" -Level "OK"
            return $true
        }
        Start-Sleep -Seconds 3
        $elapsed += 3
    }

    Write-Log "Le service n'a pas démarré dans le délai imparti ($timeout sec)" -Level "WARN"
    return $false
}

# =========================================
# DÉBUT DU SCRIPT
# =========================================

Write-Log "=========================================="
Write-Log "INSTALLATION TACTICAL RMM AGENT WINDOWS"
Write-Log "=========================================="
Write-Log "Serveur  : $($env:COMPUTERNAME)"
Write-Log "API URL  : $ApiUrl"
Write-Log "Client   : $ClientId | Site: $SiteId"
Write-Log "Type     : $AgentType"

# Vérifier si déjà installé
if (Test-AgentInstalled) {
    if ($ForceReinstall) {
        Write-Log "Agent déjà installé. Réinstallation forcée..." -Level "WARN"
    }
    else {
        Write-Log "L'agent Tactical RMM est déjà installé." -Level "WARN"
        Write-Log "Utilisez -ForceReinstall pour réinstaller ou windows_agent_update.ps1 pour mettre à jour."
        exit 0
    }
}

# Prérequis
if (-not (Test-Prerequisites)) {
    Write-Log "Prérequis non satisfaits. Installation annulée." -Level "ERROR"
    exit 1
}

# Détection architecture
$arch = Get-Architecture
Write-Log "Architecture: $arch"

# Préparer le répertoire temporaire
$tempDir = "C:\Windows\Temp\tactical-install"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$installerPath = "$tempDir\tactical-agent-setup.exe"

# URL de l'installateur
$installerUrl = Get-InstallerUrl -ApiUrl $ApiUrl -Arch $arch

# Télécharger
if (-not (Download-Installer -Url $installerUrl -Destination $installerPath)) {
    Write-Log "Impossible de télécharger l'installateur. Arrêt." -Level "ERROR"
    exit 1
}

# Installer
if (-not (Install-Agent -InstallerPath $installerPath)) {
    Write-Log "L'installation a échoué." -Level "ERROR"
    # Afficher les logs Inno si disponibles
    if (Test-Path "C:\Windows\Temp\tactical-inno.log") {
        Write-Log "--- Logs Inno Setup ---"
        Get-Content "C:\Windows\Temp\tactical-inno.log" -Tail 20 | ForEach-Object { Write-Log $_ }
    }
    exit 1
}

# Attendre le service
Wait-AgentService | Out-Null

# Nettoyage
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Log "Fichiers temporaires supprimés"

# Résultat final
Write-Log "=========================================="
if (Test-AgentInstalled) {
    Write-Log "INSTALLATION RÉUSSIE" -Level "OK"
    Write-Log "L'agent apparaîtra sous peu dans l'interface Tactical RMM"
    $service = Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue
    if ($service) { Write-Log "Service: $($service.Status)" -Level "OK" }
} else {
    Write-Log "INSTALLATION ÉCHOUÉE - L'agent n'est pas détecté" -Level "ERROR"
    exit 1
}
Write-Log "Log: $LogPath"
Write-Log "=========================================="
