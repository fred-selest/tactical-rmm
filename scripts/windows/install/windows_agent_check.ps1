#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Diagnostic de l'agent Tactical RMM sur Windows

.DESCRIPTION
    Affiche l'état complet de l'agent Tactical RMM installé sur la machine :
    service, version, configuration, connectivité, logs récents.

.PARAMETER ApiUrl
    URL de l'API Tactical RMM pour tester la connectivité (optionnel)

.PARAMETER ShowLogs
    Nombre de lignes de logs à afficher (défaut: 20)

.EXAMPLE
    .\windows_agent_check.ps1

.EXAMPLE
    .\windows_agent_check.ps1 -ApiUrl "https://api.votredomaine.com" -ShowLogs 50
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ApiUrl = "",

    [Parameter(Mandatory = $false)]
    [int]$ShowLogs = 20
)

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "--- $Title ---" -ForegroundColor Cyan
}

function Write-Status {
    param([string]$Label, [string]$Value, [bool]$OK = $true)
    $icon = if ($OK) { "[OK]" } else { "[!!]" }
    $color = if ($OK) { "Green" } else { "Red" }
    Write-Host ("{0,-6} {1,-30} {2}" -f $icon, $Label, $Value) -ForegroundColor $color
}

function Get-AgentVersion {
    $paths = @(
        "HKLM:\SOFTWARE\TacticalRMM",
        "HKLM:\SOFTWARE\WOW6432Node\TacticalRMM"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $ver = (Get-ItemProperty $path -ErrorAction SilentlyContinue).Version
            if ($ver) { return $ver }
        }
    }
    $apps = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Tactical*" }
    if ($apps) { return $apps[0].DisplayVersion }
    return "inconnue"
}

function Get-AgentConfig {
    $configPaths = @(
        "C:\Program Files\TacticalAgent\tacticalrmm.json",
        "C:\Program Files (x86)\TacticalAgent\tacticalrmm.json",
        "$env:ProgramData\TacticalRMM\tacticalrmm.json"
    )
    foreach ($path in $configPaths) {
        if (Test-Path $path) {
            try { return Get-Content $path | ConvertFrom-Json }
            catch { continue }
        }
    }
    return $null
}

# =========================================
# ENTÊTE
# =========================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor White
Write-Host "  DIAGNOSTIC AGENT TACTICAL RMM WINDOWS" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor White
Write-Host "  Serveur : $($env:COMPUTERNAME)" -ForegroundColor Gray
Write-Host "  Date    : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Gray
Write-Host "==========================================" -ForegroundColor White

# =========================================
# 1. SERVICE WINDOWS
# =========================================

Write-Section "SERVICE TACTICALRMM"

$service = Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue

if ($service) {
    $isRunning = ($service.Status -eq "Running")
    Write-Status "Service trouvé" "tacticalrmm" $true
    Write-Status "État" $service.Status.ToString() $isRunning
    Write-Status "Démarrage" $service.StartType.ToString() $true

    if ($isRunning) {
        $proc = Get-Process -Name "tacticalrmm" -ErrorAction SilentlyContinue
        if ($proc) {
            $uptime = (Get-Date) - $proc.StartTime
            Write-Status "Temps de fonctionnement" ("{0}j {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes) $true
            Write-Status "Utilisation CPU" ("{0:F1} %" -f $proc.CPU) $true
            Write-Status "Utilisation RAM" ("{0:F0} MB" -f ($proc.WorkingSet64 / 1MB)) $true
        }
    }
} else {
    Write-Host "[!!] Service 'tacticalrmm' NON TROUVÉ" -ForegroundColor Red
}

# =========================================
# 2. BINAIRE ET VERSION
# =========================================

Write-Section "INSTALLATION"

$agentBinPaths = @(
    "C:\Program Files\TacticalAgent\tacticalrmm.exe",
    "C:\Program Files (x86)\TacticalAgent\tacticalrmm.exe"
)
$agentBin = $agentBinPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($agentBin) {
    $binInfo = Get-Item $agentBin
    Write-Status "Binaire" $agentBin $true
    Write-Status "Taille" ("{0:F1} MB" -f ($binInfo.Length / 1MB)) $true
    Write-Status "Dernière modification" $binInfo.LastWriteTime.ToString("dd/MM/yyyy HH:mm") $true
} else {
    Write-Host "[!!] Binaire agent NON TROUVÉ" -ForegroundColor Red
}

$version = Get-AgentVersion
Write-Status "Version installée" $version $true

# =========================================
# 3. CONFIGURATION
# =========================================

Write-Section "CONFIGURATION"

$config = Get-AgentConfig
if ($config) {
    Write-Status "Fichier config" "OK" $true
    if ($config.apiurl) { Write-Status "API URL" $config.apiurl $true }
    if ($config.agent_id) { Write-Status "Agent ID" $config.agent_id $true }
    if ($config.client_id) { Write-Status "Client ID" $config.client_id.ToString() $true }
    if ($config.site_id) { Write-Status "Site ID" $config.site_id.ToString() $true }
    if ($config.hostname) { Write-Status "Hostname configuré" $config.hostname $true }
} else {
    Write-Host "[!!] Configuration NON TROUVÉE" -ForegroundColor Red
}

# Détection du répertoire de configuration
$configDirs = @(
    "C:\Program Files\TacticalAgent",
    "C:\Program Files (x86)\TacticalAgent",
    "$env:ProgramData\TacticalRMM"
)
foreach ($dir in $configDirs) {
    if (Test-Path $dir) {
        $files = Get-ChildItem $dir -ErrorAction SilentlyContinue
        Write-Host ("        Répertoire: {0} ({1} fichiers)" -f $dir, $files.Count) -ForegroundColor Gray
    }
}

# =========================================
# 4. CONNECTIVITÉ RÉSEAU
# =========================================

Write-Section "CONNECTIVITÉ"

# Utiliser l'API URL de la config ou celle fournie en paramètre
$testUrl = if ($ApiUrl) { $ApiUrl } elseif ($config -and $config.apiurl) { $config.apiurl } else { $null }

if ($testUrl) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Test ping API
    try {
        $response = Invoke-WebRequest -Uri "$testUrl/api/v3/ping/" -Method Get -TimeoutSec 10 -ErrorAction Stop
        Write-Status "API Tactical RMM" "$testUrl" $true
        Write-Status "Réponse HTTP" $response.StatusCode.ToString() ($response.StatusCode -eq 200)
    }
    catch {
        Write-Status "API Tactical RMM" "Inaccessible - $($_.Exception.Message)" $false
    }
} else {
    Write-Host "        Aucune URL API fournie pour le test de connectivité" -ForegroundColor Gray
    Write-Host "        Utilisez: -ApiUrl 'https://api.votredomaine.com'" -ForegroundColor Gray
}

# Test connectivité générale
$dnsCheck = Resolve-DnsName -Name "google.com" -ErrorAction SilentlyContinue
Write-Status "Connectivité Internet" (if ($dnsCheck) { "OK" } else { "Problème DNS" }) ($null -ne $dnsCheck)

# =========================================
# 5. MESH AGENT
# =========================================

Write-Section "MESH AGENT"

$meshPaths = @(
    "C:\Program Files\Mesh Agent",
    "C:\Program Files (x86)\Mesh Agent",
    "C:\Program Files\MeshCentral",
    "/opt/tacticalmesh"
)
$meshFound = $meshPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($meshFound) {
    Write-Status "Mesh Agent" $meshFound $true
} else {
    Write-Host "[!!] Mesh Agent NON TROUVÉ" -ForegroundColor Yellow
}

$meshService = Get-Service -Name "Mesh Agent" -ErrorAction SilentlyContinue
if ($meshService) {
    Write-Status "Service Mesh" $meshService.Status.ToString() ($meshService.Status -eq "Running")
} else {
    $meshService2 = Get-Service | Where-Object { $_.DisplayName -like "*Mesh*" } | Select-Object -First 1
    if ($meshService2) {
        Write-Status "Service Mesh" "$($meshService2.Name): $($meshService2.Status)" ($meshService2.Status -eq "Running")
    } else {
        Write-Host "[??] Service Mesh non détecté" -ForegroundColor Yellow
    }
}

# =========================================
# 6. LOGS RÉCENTS
# =========================================

Write-Section "LOGS RÉCENTS (Journal Windows)"

try {
    $events = Get-EventLog -LogName System -Source "tacticalrmm" -Newest $ShowLogs -ErrorAction SilentlyContinue
    if ($events) {
        foreach ($event in $events) {
            $color = switch ($event.EntryType) {
                "Error" { "Red" }
                "Warning" { "Yellow" }
                default { "Gray" }
            }
            Write-Host ("  [{0}] {1} - {2}" -f $event.TimeGenerated.ToString("dd/MM HH:mm"), $event.EntryType, $event.Message.Substring(0, [Math]::Min(80, $event.Message.Length))) -ForegroundColor $color
        }
    } else {
        Write-Host "  Aucun événement Tactical RMM dans le journal système" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  Impossible de lire les événements système" -ForegroundColor Gray
}

# Logs fichier si présents
$logFiles = @(
    "C:\Windows\Temp\tactical-install.log",
    "C:\Windows\Temp\tactical-update.log",
    "C:\Program Files\TacticalAgent\tactical.log"
)

foreach ($logFile in $logFiles) {
    if (Test-Path $logFile) {
        Write-Host ""
        Write-Host "  Fichier: $logFile" -ForegroundColor Cyan
        Get-Content $logFile -Tail 10 | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
    }
}

# =========================================
# 7. INFORMATIONS SYSTÈME
# =========================================

Write-Section "SYSTÈME"

$os = Get-WmiObject -Class Win32_OperatingSystem
$cs = Get-WmiObject -Class Win32_ComputerSystem

Write-Status "OS" "$($os.Caption) $($os.OSArchitecture)" $true
Write-Status "Build" $os.BuildNumber $true

$uptime = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)
Write-Status "Uptime" ("{0}j {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes) $true

$ram = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
$freeRam = [Math]::Round($os.FreePhysicalMemory / 1MB, 1)
Write-Status "RAM" ("{0:F1} GB total, {1:F1} MB libre" -f $ram, $freeRam) $true

# =========================================
# RÉSUMÉ
# =========================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor White

$serviceOK = ($service -and $service.Status -eq "Running")
$configOK = ($null -ne $config)
$binOK = ($null -ne $agentBin)

if ($serviceOK -and $configOK -and $binOK) {
    Write-Host "  ÉTAT GLOBAL: OPÉRATIONNEL" -ForegroundColor Green
} elseif ($service) {
    Write-Host "  ÉTAT GLOBAL: PARTIELLEMENT OPÉRATIONNEL" -ForegroundColor Yellow
    if (-not $serviceOK) { Write-Host "  → Service arrêté" -ForegroundColor Yellow }
    if (-not $configOK)  { Write-Host "  → Configuration manquante" -ForegroundColor Yellow }
    if (-not $binOK)     { Write-Host "  → Binaire introuvable" -ForegroundColor Yellow }
} else {
    Write-Host "  ÉTAT GLOBAL: NON INSTALLÉ" -ForegroundColor Red
    Write-Host "  → Utilisez windows_agent_install.ps1 pour installer" -ForegroundColor Red
}

Write-Host "==========================================" -ForegroundColor White
Write-Host ""
