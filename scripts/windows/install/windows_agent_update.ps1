#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Mise à jour de l'agent Tactical RMM sur Windows

.DESCRIPTION
    Ce script met à jour l'agent Tactical RMM vers la dernière version disponible.
    Il sauvegarde la configuration existante, télécharge le nouvel agent, et
    restaure automatiquement en cas d'échec.

.PARAMETER ApiUrl
    URL de l'API Tactical RMM (ex: https://api.votredomaine.com)

.PARAMETER ForceUpdate
    Forcer la mise à jour même si la version est identique

.PARAMETER LogPath
    Chemin du fichier log (défaut: C:\Windows\Temp\tactical-update.log)

.EXAMPLE
    .\windows_agent_update.ps1 -ApiUrl "https://api.votredomaine.com"

.EXAMPLE
    .\windows_agent_update.ps1 -ApiUrl "https://api.votredomaine.com" -ForceUpdate

.NOTES
    La configuration de l'agent (client, site, auth) est conservée lors de la mise à jour.
    Un rollback automatique est effectué si la mise à jour échoue.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiUrl,

    [Parameter(Mandatory = $false)]
    [switch]$ForceUpdate,

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Windows\Temp\tactical-update.log"
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

function Get-AgentVersion {
    # Chercher la version dans le registre
    $registryPaths = @(
        "HKLM:\SOFTWARE\TacticalRMM",
        "HKLM:\SOFTWARE\WOW6432Node\TacticalRMM"
    )
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $ver = (Get-ItemProperty $path -ErrorAction SilentlyContinue).Version
            if ($ver) { return $ver }
        }
    }

    # Chercher dans les Programs installés
    $apps = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Tactical*" }

    if ($apps) { return $apps[0].DisplayVersion }

    return $null
}

function Get-LatestVersion {
    param([string]$ApiUrl)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-RestMethod -Uri "$ApiUrl/api/v3/agents/latestver/" -Method Get -TimeoutSec 15
        return $response.version
    }
    catch {
        Write-Log "Impossible de récupérer la version distante: $($_.Exception.Message)" -Level "WARN"
        return $null
    }
}

function Get-AgentConfig {
    # Lire la configuration depuis le fichier de config de l'agent
    $configPaths = @(
        "C:\Program Files\TacticalAgent\tacticalrmm.json",
        "C:\Program Files (x86)\TacticalAgent\tacticalrmm.json",
        "$env:ProgramData\TacticalRMM\tacticalrmm.json"
    )

    foreach ($path in $configPaths) {
        if (Test-Path $path) {
            try {
                $config = Get-Content $path | ConvertFrom-Json
                return @{
                    ApiUrl   = $config.apiurl
                    AgentId  = $config.agent_id
                    AuthKey  = $config.auth_token
                    ConfigPath = $path
                }
            }
            catch { continue }
        }
    }
    return $null
}

function Backup-AgentConfig {
    param([string]$BackupDir)

    Write-Log "Sauvegarde de la configuration..."
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

    $configPaths = @(
        "C:\Program Files\TacticalAgent",
        "C:\Program Files (x86)\TacticalAgent",
        "$env:ProgramData\TacticalRMM"
    )

    $backupSuccess = $false
    foreach ($path in $configPaths) {
        if (Test-Path $path) {
            $destName = $path -replace '[:\\]', '_'
            $dest = Join-Path $BackupDir $destName
            Copy-Item -Path $path -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Sauvegardé: $path -> $dest"
            $backupSuccess = $true
        }
    }

    return $backupSuccess
}

function Stop-AgentService {
    Write-Log "Arrêt du service tacticalrmm..."
    $service = Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Stop-Service -Name "tacticalrmm" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3

        $service.Refresh()
        if ($service.Status -ne "Stopped") {
            # Forcer l'arrêt
            $proc = Get-Process -Name "tacticalrmm" -ErrorAction SilentlyContinue
            if ($proc) { Stop-Process -Id $proc.Id -Force }
            Start-Sleep -Seconds 2
        }
        Write-Log "Service arrêté" -Level "OK"
    }
    else {
        Write-Log "Service déjà arrêté ou inexistant" -Level "WARN"
    }
}

function Start-AgentService {
    Write-Log "Démarrage du service tacticalrmm..."
    Start-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5

    $service = Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Write-Log "Service démarré avec succès" -Level "OK"
        return $true
    }

    Write-Log "Échec du démarrage du service" -Level "ERROR"
    return $false
}

function Download-Update {
    param([string]$Url, [string]$Destination)

    Write-Log "Téléchargement de la mise à jour..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $Destination)

        if (-not (Test-Path $Destination) -or (Get-Item $Destination).Length -lt 1KB) {
            Write-Log "Fichier téléchargé invalide" -Level "ERROR"
            return $false
        }

        $size = (Get-Item $Destination).Length / 1MB
        Write-Log ("Mise à jour téléchargée: {0:F1} MB" -f $size) -Level "OK"
        return $true
    }
    catch {
        Write-Log "Erreur de téléchargement: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Restore-AgentConfig {
    param([string]$BackupDir)

    Write-Log "Restauration de la configuration depuis la sauvegarde..." -Level "WARN"

    $items = Get-ChildItem -Path $BackupDir -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        # Reconstituer le chemin original
        $originalPath = $item.Name -replace '_', ':'
        # Simplification: restaurer les fichiers de config connus
        if ($item.Name -like "*TacticalAgent*") {
            $dest = "C:\Program Files\TacticalAgent"
            Copy-Item -Path $item.FullName -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
        }
        elseif ($item.Name -like "*TacticalRMM*") {
            $dest = "$env:ProgramData\TacticalRMM"
            Copy-Item -Path $item.FullName -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# =========================================
# DÉBUT DU SCRIPT
# =========================================

Write-Log "=========================================="
Write-Log "MISE À JOUR TACTICAL RMM AGENT WINDOWS"
Write-Log "=========================================="
Write-Log "Serveur: $($env:COMPUTERNAME)"
Write-Log "API URL: $ApiUrl"

# Vérifier que l'agent est installé
$service = Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Log "L'agent Tactical RMM n'est pas installé sur ce poste." -Level "ERROR"
    Write-Log "Utilisez windows_agent_install.ps1 pour l'installer."
    exit 1
}

# Versions
$currentVersion = Get-AgentVersion
$latestVersion = Get-LatestVersion -ApiUrl $ApiUrl

Write-Log "Version actuelle : $($currentVersion ?? 'inconnue')"
Write-Log "Version distante : $($latestVersion ?? 'inconnue')"

# Comparer les versions
if ($currentVersion -and $latestVersion -and $currentVersion -eq $latestVersion -and -not $ForceUpdate) {
    Write-Log "L'agent est déjà à jour (version $currentVersion)" -Level "OK"
    exit 0
}

# Détecter architecture
$arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "x86" }
Write-Log "Architecture: $arch"

# Lire la config actuelle pour récupérer l'auth key
$agentConfig = Get-AgentConfig
$authKey = ""
if ($agentConfig -and $agentConfig.AuthKey) {
    $authKey = $agentConfig.AuthKey
    Write-Log "Configuration agent récupérée" -Level "OK"
} else {
    Write-Log "ATTENTION: Impossible de lire la configuration de l'agent." -Level "WARN"
    Write-Log "La mise à jour via l'installateur complet sera utilisée."
}

# Préparer le répertoire temporaire
$tempDir = "C:\Windows\Temp\tactical-update"
$backupDir = "C:\Windows\Temp\tactical-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$installerPath = "$tempDir\tactical-agent-update.exe"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Sauvegarder la configuration
Backup-AgentConfig -BackupDir $backupDir

# URL de mise à jour
# Note: si on a l'auth key, on peut récupérer l'installateur personnalisé
# Sinon, l'agent se met à jour lui-même via la commande interne
if ($authKey) {
    $updateUrl = "$ApiUrl/api/v3/agents/installer/?agent_type=workstation&arch=$arch&token=$authKey"
} else {
    Write-Log "Tentative de mise à jour via la commande interne de l'agent..."

    # L'agent Tactical RMM peut se mettre à jour lui-même
    $agentBin = @(
        "C:\Program Files\TacticalAgent\tacticalrmm.exe",
        "C:\Program Files (x86)\TacticalAgent\tacticalrmm.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($agentBin) {
        $result = & $agentBin -m update 2>&1
        Write-Log "Résultat: $result"

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Mise à jour via l'agent réussie" -Level "OK"
        } else {
            Write-Log "Échec de la mise à jour via l'agent" -Level "ERROR"
            exit 1
        }
    } else {
        Write-Log "Binaire agent introuvable et pas d'auth key disponible" -Level "ERROR"
        exit 1
    }

    exit 0
}

# Télécharger l'installateur de mise à jour
if (-not (Download-Update -Url $updateUrl -Destination $installerPath)) {
    Write-Log "Impossible de télécharger la mise à jour" -Level "ERROR"
    exit 1
}

# Arrêter le service
Stop-AgentService

# Lancer la mise à jour
Write-Log "Application de la mise à jour..."
try {
    $process = Start-Process -FilePath $installerPath `
        -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" `
        -Wait -PassThru -ErrorAction Stop

    Write-Log "Code de retour installateur: $($process.ExitCode)"

    if ($process.ExitCode -ne 0) {
        Write-Log "L'installateur a retourné un code d'erreur: $($process.ExitCode)" -Level "WARN"
    }
}
catch {
    Write-Log "Erreur lors de la mise à jour: $($_.Exception.Message)" -Level "ERROR"

    # Tentative de rollback
    Write-Log "Rollback en cours..." -Level "WARN"
    Restore-AgentConfig -BackupDir $backupDir
    Start-AgentService
    exit 1
}

# Démarrer le service
if (-not (Start-AgentService)) {
    Write-Log "Service non démarré après mise à jour. Tentative de rollback..." -Level "ERROR"
    Restore-AgentConfig -BackupDir $backupDir
    Start-AgentService
    exit 1
}

# Vérification post-mise à jour
Start-Sleep -Seconds 5
$newVersion = Get-AgentVersion
Write-Log "Nouvelle version installée: $($newVersion ?? 'inconnue')"

# Nettoyage
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $backupDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Log "Fichiers temporaires supprimés"

Write-Log "=========================================="
Write-Log "MISE À JOUR TERMINÉE AVEC SUCCÈS" -Level "OK"
Write-Log "Version: $currentVersion -> $newVersion"
Write-Log "Log: $LogPath"
Write-Log "=========================================="
