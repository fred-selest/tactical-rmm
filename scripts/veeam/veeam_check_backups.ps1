# Script: Surveillance des sauvegardes Veeam
# Usage dans Tactical RMM: Exécuter sur le serveur Veeam
# Vérifie l'état des jobs de sauvegarde

param(
    [int]$WarningHours = 24,     # Alerte si backup > X heures
    [int]$CriticalHours = 48    # Critique si backup > X heures
)

$ErrorActionPreference = "Continue"

Write-Output "=========================================="
Write-Output "SURVEILLANCE VEEAM BACKUP"
Write-Output "Serveur: $env:COMPUTERNAME"
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "=========================================="
Write-Output ""

# Vérifier que Veeam est installé
try {
    Add-PSSnapin VeeamPSSnapin -ErrorAction Stop
} catch {
    Write-Error "ERREUR: Veeam PowerShell Snapin non disponible"
    Write-Output "Assurez-vous que Veeam Backup & Replication est installé"
    exit 1
}

# ============================================
# ÉTAT GÉNÉRAL VEEAM
# ============================================
Write-Output "--- ETAT GENERAL ---"

try {
    $VeeamServer = Get-VBRServer -Type Local
    Write-Output "Serveur Veeam: $($VeeamServer.Name)"

    $License = Get-VBRInstalledLicense
    Write-Output "Licence: $($License.Edition)"
    Write-Output "Expiration: $($License.ExpirationDate.ToString('yyyy-MM-dd'))"

    if ($License.ExpirationDate -lt (Get-Date).AddDays(30)) {
        Write-Output "[ATTENTION] Licence expire dans moins de 30 jours!"
    }
} catch {
    Write-Output "Impossible de récupérer les informations serveur"
}
Write-Output ""

# ============================================
# JOBS DE SAUVEGARDE
# ============================================
Write-Output "--- JOBS DE SAUVEGARDE ---"

$Jobs = Get-VBRJob
$JobResults = @()
$FailedJobs = 0
$WarningJobs = 0

foreach ($Job in $Jobs) {
    $LastSession = Get-VBRBackupSession -Job $Job | Sort-Object EndTime -Descending | Select-Object -First 1

    if ($LastSession) {
        $Status = $LastSession.Result
        $EndTime = $LastSession.EndTime
        $Duration = $LastSession.EndTime - $LastSession.CreationTime
        $HoursSince = [math]::Round(((Get-Date) - $EndTime).TotalHours, 1)

        # Déterminer le niveau d'alerte
        $AlertLevel = "[OK]"
        if ($Status -eq "Failed") {
            $AlertLevel = "[ERREUR]"
            $FailedJobs++
        } elseif ($Status -eq "Warning") {
            $AlertLevel = "[ATTENTION]"
            $WarningJobs++
        } elseif ($HoursSince -gt $CriticalHours) {
            $AlertLevel = "[CRITIQUE]"
            $FailedJobs++
        } elseif ($HoursSince -gt $WarningHours) {
            $AlertLevel = "[ATTENTION]"
            $WarningJobs++
        }

        Write-Output "$AlertLevel $($Job.Name)"
        Write-Output "   Statut: $Status"
        Write-Output "   Dernière exécution: $($EndTime.ToString('yyyy-MM-dd HH:mm'))"
        Write-Output "   Durée: $($Duration.Hours)h $($Duration.Minutes)m"
        Write-Output "   Il y a: $HoursSince heures"
        Write-Output ""

        $JobResults += [PSCustomObject]@{
            Name = $Job.Name
            Status = $Status
            LastRun = $EndTime
            HoursSince = $HoursSince
            Duration = $Duration
        }
    } else {
        Write-Output "[ATTENTION] $($Job.Name) - Jamais exécuté"
        $WarningJobs++
    }
}

# ============================================
# JOBS DE RÉPLICATION
# ============================================
Write-Output "--- JOBS DE REPLICATION ---"

$ReplicaJobs = Get-VBRJob -WarningAction SilentlyContinue | Where-Object { $_.JobType -eq "Replica" }

if ($ReplicaJobs) {
    foreach ($Job in $ReplicaJobs) {
        $LastSession = Get-VBRBackupSession -Job $Job | Sort-Object EndTime -Descending | Select-Object -First 1

        if ($LastSession) {
            $Status = if ($LastSession.Result -eq "Success") { "[OK]" } else { "[ERREUR]" }
            Write-Output "$Status $($Job.Name) - $($LastSession.EndTime.ToString('yyyy-MM-dd HH:mm'))"
        }
    }
} else {
    Write-Output "Aucun job de réplication configuré"
}
Write-Output ""

# ============================================
# REPOSITORIES
# ============================================
Write-Output "--- REPOSITORIES ---"

$Repos = Get-VBRBackupRepository

foreach ($Repo in $Repos) {
    $Info = $Repo.GetContainer()

    if ($Info) {
        $Total = [math]::Round($Info.CachedTotalSpace.InGigabytes, 2)
        $Free = [math]::Round($Info.CachedFreeSpace.InGigabytes, 2)
        $Used = $Total - $Free
        $Percent = [math]::Round(($Used / $Total) * 100, 1)

        $Status = "[OK]"
        if ($Percent -gt 90) {
            $Status = "[CRITIQUE]"
        } elseif ($Percent -gt 80) {
            $Status = "[ATTENTION]"
        }

        Write-Output "$Status $($Repo.Name)"
        Write-Output "   Espace: $Used/$Total GB ($Percent%)"
        Write-Output "   Libre: $Free GB"
    } else {
        Write-Output "[INFO] $($Repo.Name) - Impossible de récupérer l'espace"
    }
}
Write-Output ""

# ============================================
# SESSIONS EN COURS
# ============================================
Write-Output "--- SESSIONS EN COURS ---"

$RunningSessions = Get-VBRBackupSession | Where-Object { $_.State -eq "Working" }

if ($RunningSessions) {
    foreach ($Session in $RunningSessions) {
        $Duration = (Get-Date) - $Session.CreationTime
        Write-Output "[EN COURS] $($Session.JobName)"
        Write-Output "   Démarré: $($Session.CreationTime.ToString('yyyy-MM-dd HH:mm'))"
        Write-Output "   Durée: $($Duration.Hours)h $($Duration.Minutes)m"
        Write-Output "   Progression: $($Session.Progress)%"
    }
} else {
    Write-Output "Aucune sauvegarde en cours"
}
Write-Output ""

# ============================================
# TAPES (si configuré)
# ============================================
$TapeJobs = Get-VBRTapeJob -ErrorAction SilentlyContinue

if ($TapeJobs) {
    Write-Output "--- JOBS TAPE ---"
    foreach ($Job in $TapeJobs) {
        $LastSession = Get-VBRTapeJobSession -Job $Job | Sort-Object EndTime -Descending | Select-Object -First 1
        if ($LastSession) {
            $Status = if ($LastSession.Result -eq "Success") { "[OK]" } else { "[ERREUR]" }
            Write-Output "$Status $($Job.Name) - $($LastSession.EndTime.ToString('yyyy-MM-dd HH:mm'))"
        }
    }
    Write-Output ""
}

# ============================================
# ALERTES VEEAM
# ============================================
Write-Output "--- ALERTES SYSTEME ---"

$Alerts = Get-VBRServerAlert -ErrorAction SilentlyContinue

if ($Alerts) {
    Write-Output "Alertes actives: $($Alerts.Count)"
    foreach ($Alert in $Alerts | Select-Object -First 5) {
        Write-Output "  [$($Alert.Status)] $($Alert.Message)"
    }
} else {
    Write-Output "[OK] Aucune alerte système"
}
Write-Output ""

# ============================================
# RÉSUMÉ
# ============================================
Write-Output "=========================================="
Write-Output "RESUME"
Write-Output "=========================================="

$TotalJobs = $Jobs.Count
$SuccessJobs = $TotalJobs - $FailedJobs - $WarningJobs

Write-Output "Jobs totaux: $TotalJobs"
Write-Output "Succès: $SuccessJobs"
Write-Output "Avertissements: $WarningJobs"
Write-Output "Échecs: $FailedJobs"

if ($FailedJobs -gt 0) {
    Write-Output ""
    Write-Output "[ALERTE] $FailedJobs job(s) en échec ou critique!"
    exit 1
} elseif ($WarningJobs -gt 0) {
    Write-Output ""
    Write-Output "[ATTENTION] $WarningJobs job(s) avec avertissement"
}

Write-Output "=========================================="
