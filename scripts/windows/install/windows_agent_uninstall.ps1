#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Désinstallation de l'agent Tactical RMM sur Windows

.DESCRIPTION
    Désinstalle proprement l'agent Tactical RMM et le Mesh Agent.
    Supprime les services, binaires, configurations et entrées de registre.

.PARAMETER KeepLogs
    Conserver les fichiers de logs après désinstallation

.PARAMETER RemoveMesh
    Supprimer également le Mesh Agent (défaut: $true)

.PARAMETER MeshFqdn
    FQDN du serveur Mesh pour la désinstallation correcte
    (ex: mesh.votredomaine.com)

.PARAMETER LogPath
    Chemin du fichier log (défaut: C:\Windows\Temp\tactical-uninstall.log)

.EXAMPLE
    .\windows_agent_uninstall.ps1

.EXAMPLE
    .\windows_agent_uninstall.ps1 -KeepLogs -MeshFqdn "mesh.votredomaine.com"
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$KeepLogs,

    [Parameter(Mandatory = $false)]
    [bool]$RemoveMesh = $true,

    [Parameter(Mandatory = $false)]
    [string]$MeshFqdn = "",

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Windows\Temp\tactical-uninstall.log"
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

function Stop-AndRemoveService {
    param([string]$ServiceName)

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Log "Service '$ServiceName' non trouvé (déjà supprimé ?)" -Level "WARN"
        return
    }

    # Arrêter
    if ($service.Status -ne "Stopped") {
        Write-Log "Arrêt du service $ServiceName..."
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3

        # Tuer le processus si toujours actif
        $proc = Get-Process -Name $ServiceName -ErrorAction SilentlyContinue
        if ($proc) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            Write-Log "Processus $ServiceName terminé de force" -Level "WARN"
        }
    }

    # Supprimer le service
    try {
        & sc.exe delete $ServiceName | Out-Null
        Write-Log "Service $ServiceName supprimé" -Level "OK"
    }
    catch {
        Write-Log "Erreur suppression service $ServiceName : $($_.Exception.Message)" -Level "WARN"
    }
}

function Remove-Directory {
    param([string]$Path)

    if (Test-Path $Path) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Log "Supprimé: $Path" -Level "OK"
        }
        catch {
            # Essayer avec robocopy pour vider puis supprimer
            $emptyDir = "C:\Windows\Temp\empty_$$"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
            & robocopy $emptyDir $Path /MIR /NFL /NDL /NJH /NJS | Out-Null
            Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $emptyDir -Force -ErrorAction SilentlyContinue
            Write-Log "Supprimé (forçage): $Path" -Level "OK"
        }
    }
}

function Remove-RegistryKeys {
    $keys = @(
        "HKLM:\SOFTWARE\TacticalRMM",
        "HKLM:\SOFTWARE\WOW6432Node\TacticalRMM",
        "HKLM:\SYSTEM\CurrentControlSet\Services\tacticalrmm"
    )

    foreach ($key in $keys) {
        if (Test-Path $key) {
            try {
                Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
                Write-Log "Clé registre supprimée: $key" -Level "OK"
            }
            catch {
                Write-Log "Erreur suppression registre $key : $($_.Exception.Message)" -Level "WARN"
            }
        }
    }
}

function Uninstall-ViaAddRemove {
    # Utiliser l'uninstalleur officiel si disponible
    $uninstallers = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Tactical*" }

    if (-not $uninstallers) {
        $uninstallers = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
            -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Tactical*" }
    }

    if ($uninstallers) {
        foreach ($app in $uninstallers) {
            Write-Log "Désinstallation via Add/Remove: $($app.DisplayName) $($app.DisplayVersion)"
            if ($app.UninstallString) {
                $uninstallCmd = $app.UninstallString
                # Rendre silencieux
                $uninstallCmd = $uninstallCmd -replace '/I', '/X'

                try {
                    Start-Process -FilePath "cmd.exe" `
                        -ArgumentList "/c $uninstallCmd /VERYSILENT /SUPPRESSMSGBOXES /NORESTART" `
                        -Wait -ErrorAction Stop
                    Write-Log "Désinstallation via Add/Remove terminée" -Level "OK"
                    return $true
                }
                catch {
                    Write-Log "Erreur désinstallation Add/Remove: $($_.Exception.Message)" -Level "WARN"
                }
            }
        }
    }
    return $false
}

function Uninstall-MeshAgent {
    Write-Log "Désinstallation de Mesh Agent..."

    # Option 1: Via le programme de désinstallation Mesh
    $meshUninstallers = @(
        "C:\Program Files\Mesh Agent\MeshAgent.exe",
        "C:\Program Files (x86)\Mesh Agent\MeshAgent.exe"
    )

    foreach ($meshBin in $meshUninstallers) {
        if (Test-Path $meshBin) {
            Write-Log "Désinstallation Mesh via: $meshBin"
            try {
                $proc = Start-Process -FilePath $meshBin -ArgumentList "-fulluninstall" -Wait -PassThru
                Write-Log "Code retour Mesh uninstall: $($proc.ExitCode)"
                Start-Sleep -Seconds 5
                break
            }
            catch {
                Write-Log "Erreur: $($_.Exception.Message)" -Level "WARN"
            }
        }
    }

    # Option 2: Via le script de désinstallation depuis le serveur Mesh
    if ($MeshFqdn -ne "") {
        Write-Log "Téléchargement du script de désinstallation Mesh depuis $MeshFqdn..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $meshUninstallScript = "C:\Windows\Temp\mesh-uninstall-$$.ps1"
        try {
            Invoke-WebRequest -Uri "https://$MeshFqdn/meshagents?script=1" `
                -OutFile $meshUninstallScript -TimeoutSec 30 -ErrorAction Stop
            Write-Log "Script Mesh téléchargé"
        }
        catch {
            Write-Log "Impossible de télécharger le script Mesh: $($_.Exception.Message)" -Level "WARN"
        }
    }

    # Suppression des répertoires Mesh
    $meshPaths = @(
        "C:\Program Files\Mesh Agent",
        "C:\Program Files (x86)\Mesh Agent",
        "C:\ProgramData\Mesh Agent",
        "/opt/tacticalmesh"
    )

    foreach ($path in $meshPaths) {
        Remove-Directory -Path $path
    }

    # Supprimer les services Mesh
    $meshServices = @("Mesh Agent", "meshagent")
    foreach ($svc in $meshServices) {
        Stop-AndRemoveService -ServiceName $svc
    }

    Write-Log "Mesh Agent désinstallé" -Level "OK"
}

# =========================================
# DÉBUT DU SCRIPT
# =========================================

Write-Log "=========================================="
Write-Log "DÉSINSTALLATION TACTICAL RMM AGENT WINDOWS"
Write-Log "=========================================="
Write-Log "Serveur: $($env:COMPUTERNAME)"

# =========================================
# 1. TENTER L'UNINSTALLER OFFICIEL D'ABORD
# =========================================

Write-Log "Recherche de l'uninstaller officiel..."
$officialUninstall = Uninstall-ViaAddRemove

if ($officialUninstall) {
    Write-Log "Désinstallation via l'uninstaller officiel effectuée"
} else {
    Write-Log "Uninstaller officiel non disponible, désinstallation manuelle..."
}

# =========================================
# 2. ARRÊTER ET SUPPRIMER LE SERVICE
# =========================================

Write-Log "Suppression du service tacticalrmm..."
Stop-AndRemoveService -ServiceName "tacticalrmm"

# =========================================
# 3. SUPPRIMER LES BINAIRES ET FICHIERS
# =========================================

Write-Log "Suppression des fichiers..."

$filesToRemove = @(
    "C:\Program Files\TacticalAgent",
    "C:\Program Files (x86)\TacticalAgent",
    "C:\ProgramData\TacticalRMM",
    "$env:ProgramData\TacticalRMM"
)

foreach ($path in $filesToRemove) {
    Remove-Directory -Path $path
}

# Supprimer les liens symboliques ou binaires dans les chemins standards
$binaries = @(
    "C:\Windows\System32\tacticalrmm.exe",
    "C:\Windows\SysWOW64\tacticalrmm.exe"
)
foreach ($bin in $binaries) {
    if (Test-Path $bin) {
        Remove-Item -Path $bin -Force -ErrorAction SilentlyContinue
        Write-Log "Supprimé: $bin" -Level "OK"
    }
}

# Configuration de l'agent
$configPaths = @(
    "C:\ProgramData\tacticalrmm",
    "$env:APPDATA\tacticalrmm",
    "C:\etc\tacticalagent"
)
foreach ($path in $configPaths) {
    Remove-Directory -Path $path
}

# =========================================
# 4. NETTOYER LE REGISTRE
# =========================================

Write-Log "Nettoyage du registre..."
Remove-RegistryKeys

# =========================================
# 5. DÉSINSTALLER MESH AGENT
# =========================================

if ($RemoveMesh) {
    Uninstall-MeshAgent
} else {
    Write-Log "Mesh Agent conservé (-RemoveMesh:$false)"
}

# =========================================
# 6. NETTOYAGE DES LOGS (OPTIONNEL)
# =========================================

if (-not $KeepLogs) {
    $logFiles = @(
        "C:\Windows\Temp\tactical-install.log",
        "C:\Windows\Temp\tactical-update.log",
        "C:\Windows\Temp\tactical-inno.log",
        "C:\Windows\Temp\tactical-gpo.log"
    )
    foreach ($log in $logFiles) {
        if (Test-Path $log) {
            Remove-Item -Path $log -Force -ErrorAction SilentlyContinue
            Write-Log "Log supprimé: $log"
        }
    }
} else {
    Write-Log "Fichiers de logs conservés (-KeepLogs)"
}

# =========================================
# RÉSULTAT FINAL
# =========================================

Write-Log "=========================================="

# Vérifier qu'il ne reste rien
$remaining = @(
    (Get-Service -Name "tacticalrmm" -ErrorAction SilentlyContinue),
    (Test-Path "C:\Program Files\TacticalAgent"),
    (Test-Path "C:\Program Files (x86)\TacticalAgent")
)

if ($remaining -contains $true -or $remaining | Where-Object { $_ -ne $null -and $_ -ne $false }) {
    Write-Log "ATTENTION: Des éléments résiduels ont été détectés. Redémarrage recommandé." -Level "WARN"
} else {
    Write-Log "DÉSINSTALLATION COMPLÈTE ET RÉUSSIE" -Level "OK"
}

Write-Log "Un redémarrage peut être nécessaire pour finaliser la suppression."
Write-Log "=========================================="
