# Script: Surveillance complète Windows Server
# Usage dans Tactical RMM: Exécuter sur les serveurs Windows
# Génère un rapport complet de l'état du serveur

$ErrorActionPreference = "Continue"

Write-Output "=========================================="
Write-Output "SURVEILLANCE WINDOWS SERVER"
Write-Output "Serveur: $env:COMPUTERNAME"
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "=========================================="
Write-Output ""

# ============================================
# INFORMATIONS SYSTÈME
# ============================================
Write-Output "--- INFORMATIONS SYSTEME ---"

$OS = Get-CimInstance Win32_OperatingSystem
$CS = Get-CimInstance Win32_ComputerSystem
$Uptime = (Get-Date) - $OS.LastBootUpTime

Write-Output "OS: $($OS.Caption) $($OS.Version)"
Write-Output "Architecture: $($OS.OSArchitecture)"
Write-Output "Domaine: $($CS.Domain)"
Write-Output "Modèle: $($CS.Manufacturer) $($CS.Model)"
Write-Output "Uptime: $($Uptime.Days) jours $($Uptime.Hours)h $($Uptime.Minutes)m"
Write-Output ""

# ============================================
# CPU
# ============================================
Write-Output "--- CPU ---"

$CPU = Get-CimInstance Win32_Processor
$CPULoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

Write-Output "Processeur: $($CPU.Name)"
Write-Output "Coeurs: $($CPU.NumberOfCores) (Threads: $($CPU.NumberOfLogicalProcessors))"
Write-Output "Utilisation: $CPULoad%"

if ($CPULoad -gt 90) {
    Write-Output "[ALERTE] Charge CPU élevée!"
} elseif ($CPULoad -gt 70) {
    Write-Output "[ATTENTION] Charge CPU importante"
} else {
    Write-Output "[OK] Charge CPU normale"
}
Write-Output ""

# ============================================
# MÉMOIRE
# ============================================
Write-Output "--- MEMOIRE ---"

$TotalRAM = [math]::Round($OS.TotalVisibleMemorySize / 1MB, 2)
$FreeRAM = [math]::Round($OS.FreePhysicalMemory / 1MB, 2)
$UsedRAM = $TotalRAM - $FreeRAM
$RAMPercent = [math]::Round(($UsedRAM / $TotalRAM) * 100, 1)

Write-Output "Total: $TotalRAM GB"
Write-Output "Utilisé: $UsedRAM GB ($RAMPercent%)"
Write-Output "Libre: $FreeRAM GB"

if ($RAMPercent -gt 90) {
    Write-Output "[ALERTE] Mémoire critique!"
} elseif ($RAMPercent -gt 80) {
    Write-Output "[ATTENTION] Mémoire élevée"
} else {
    Write-Output "[OK] Mémoire normale"
}
Write-Output ""

# ============================================
# DISQUES
# ============================================
Write-Output "--- DISQUES ---"

$Disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
$DiskAlert = $false

foreach ($Disk in $Disks) {
    $Total = [math]::Round($Disk.Size / 1GB, 2)
    $Free = [math]::Round($Disk.FreeSpace / 1GB, 2)
    $Used = $Total - $Free
    $Percent = [math]::Round(($Used / $Total) * 100, 1)

    $Status = "[OK]"
    if ($Percent -gt 90) {
        $Status = "[ALERTE]"
        $DiskAlert = $true
    } elseif ($Percent -gt 80) {
        $Status = "[ATTENTION]"
    }

    Write-Output "$($Disk.DeviceID) $Status $Used/$Total GB ($Percent%) - Libre: $Free GB"
}
Write-Output ""

# ============================================
# SERVICES CRITIQUES
# ============================================
Write-Output "--- SERVICES CRITIQUES ---"

$CriticalServices = @(
    "W32Time",      # Temps Windows
    "Dnscache",     # Client DNS
    "EventLog",     # Journal d'événements
    "PlugPlay",     # Plug-and-Play
    "Spooler",      # Spouleur d'impression
    "WinRM",        # Gestion à distance
    "LanmanServer", # Serveur (partages)
    "LanmanWorkstation", # Station de travail
    "MSSQLSERVER",  # SQL Server (si installé)
    "W3SVC",        # IIS (si installé)
    "NTDS",         # AD DS (si DC)
    "DNS",          # DNS Server (si DC)
    "DFSR",         # Réplication DFS
    "Netlogon"      # Netlogon (si DC)
)

$ServiceErrors = 0
foreach ($ServiceName in $CriticalServices) {
    $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($Service) {
        if ($Service.Status -eq "Running") {
            Write-Output "[OK] $($Service.DisplayName)"
        } else {
            Write-Output "[ERREUR] $($Service.DisplayName) - $($Service.Status)"
            $ServiceErrors++
        }
    }
}

if ($ServiceErrors -eq 0) {
    Write-Output "Tous les services critiques sont en cours d'exécution"
}
Write-Output ""

# ============================================
# ÉVÉNEMENTS CRITIQUES
# ============================================
Write-Output "--- EVENEMENTS CRITIQUES (24h) ---"

$Yesterday = (Get-Date).AddDays(-1)

# Événements système critiques
$SystemErrors = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Level = 1,2  # Critical, Error
    StartTime = $Yesterday
} -ErrorAction SilentlyContinue | Select-Object -First 10

if ($SystemErrors) {
    Write-Output "Erreurs système: $($SystemErrors.Count)"
    foreach ($Event in $SystemErrors | Select-Object -First 5) {
        Write-Output "  [$($Event.TimeCreated.ToString('HH:mm'))] $($Event.Message.Substring(0, [Math]::Min(80, $Event.Message.Length)))..."
    }
} else {
    Write-Output "[OK] Aucune erreur système critique"
}

# Événements application critiques
$AppErrors = Get-WinEvent -FilterHashtable @{
    LogName = 'Application'
    Level = 1,2
    StartTime = $Yesterday
} -ErrorAction SilentlyContinue | Select-Object -First 10

if ($AppErrors) {
    Write-Output "Erreurs application: $($AppErrors.Count)"
} else {
    Write-Output "[OK] Aucune erreur application critique"
}
Write-Output ""

# ============================================
# MISES À JOUR WINDOWS
# ============================================
Write-Output "--- MISES A JOUR WINDOWS ---"

try {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    $Updates = $UpdateSearcher.Search("IsInstalled=0 and IsHidden=0").Updates

    if ($Updates.Count -gt 0) {
        $Critical = ($Updates | Where-Object { $_.MsrcSeverity -eq "Critical" }).Count
        $Important = ($Updates | Where-Object { $_.MsrcSeverity -eq "Important" }).Count

        Write-Output "Mises à jour en attente: $($Updates.Count)"
        Write-Output "  Critiques: $Critical"
        Write-Output "  Importantes: $Important"

        if ($Critical -gt 0) {
            Write-Output "[ALERTE] Mises à jour critiques en attente!"
        }
    } else {
        Write-Output "[OK] Système à jour"
    }
} catch {
    Write-Output "Impossible de vérifier les mises à jour"
}
Write-Output ""

# ============================================
# CONNEXIONS RÉSEAU
# ============================================
Write-Output "--- CONNEXIONS RESEAU ---"

$Connections = Get-NetTCPConnection -State Established | Group-Object RemoteAddress | Sort-Object Count -Descending | Select-Object -First 10

Write-Output "Connexions établies: $((Get-NetTCPConnection -State Established).Count)"
Write-Output "Ports en écoute: $((Get-NetTCPConnection -State Listen).Count)"
Write-Output ""
Write-Output "Top 5 connexions par IP distante:"
foreach ($Conn in $Connections | Select-Object -First 5) {
    Write-Output "  $($Conn.Name): $($Conn.Count) connexions"
}
Write-Output ""

# ============================================
# CERTIFICATS SSL
# ============================================
Write-Output "--- CERTIFICATS SSL ---"

$Certs = Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue
$ExpiringCerts = $Certs | Where-Object { $_.NotAfter -lt (Get-Date).AddDays(30) -and $_.NotAfter -gt (Get-Date) }
$ExpiredCerts = $Certs | Where-Object { $_.NotAfter -lt (Get-Date) }

if ($ExpiredCerts) {
    Write-Output "[ERREUR] Certificats expirés: $($ExpiredCerts.Count)"
    foreach ($Cert in $ExpiredCerts) {
        Write-Output "  - $($Cert.Subject) (expiré le $($Cert.NotAfter.ToString('yyyy-MM-dd')))"
    }
}

if ($ExpiringCerts) {
    Write-Output "[ATTENTION] Certificats expirant dans 30 jours: $($ExpiringCerts.Count)"
    foreach ($Cert in $ExpiringCerts) {
        Write-Output "  - $($Cert.Subject) (expire le $($Cert.NotAfter.ToString('yyyy-MM-dd')))"
    }
}

if (-not $ExpiredCerts -and -not $ExpiringCerts) {
    Write-Output "[OK] Tous les certificats sont valides"
}
Write-Output ""

# ============================================
# TÂCHES PLANIFIÉES EN ERREUR
# ============================================
Write-Output "--- TACHES PLANIFIEES ---"

$FailedTasks = Get-ScheduledTask | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue |
    Where-Object { $_.LastTaskResult -ne 0 -and $_.LastTaskResult -ne 267009 } |
    Select-Object -First 10

if ($FailedTasks) {
    Write-Output "[ATTENTION] Tâches en erreur:"
    foreach ($Task in $FailedTasks) {
        $TaskName = (Get-ScheduledTask | Where-Object { $_.TaskName -eq $Task.TaskName }).TaskName
        Write-Output "  - $TaskName (Code: $($Task.LastTaskResult))"
    }
} else {
    Write-Output "[OK] Aucune tâche en erreur"
}
Write-Output ""

# ============================================
# RÉSUMÉ
# ============================================
Write-Output "=========================================="
Write-Output "RESUME"
Write-Output "=========================================="

$Alerts = @()
if ($CPULoad -gt 90) { $Alerts += "CPU critique" }
if ($RAMPercent -gt 90) { $Alerts += "Mémoire critique" }
if ($DiskAlert) { $Alerts += "Disque critique" }
if ($ServiceErrors -gt 0) { $Alerts += "Services arrêtés" }
if ($ExpiredCerts) { $Alerts += "Certificats expirés" }

if ($Alerts.Count -gt 0) {
    Write-Output "ALERTES: $($Alerts -join ', ')"
} else {
    Write-Output "Aucune alerte critique"
}

Write-Output ""
Write-Output "CPU: $CPULoad% | RAM: $RAMPercent% | Services OK: $($CriticalServices.Count - $ServiceErrors)/$($CriticalServices.Count)"
Write-Output "=========================================="
