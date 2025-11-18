# Script: Surveillance ESET Endpoint Security
# Usage dans Tactical RMM: Exécuter sur les postes avec ESET
# Vérifie l'état de protection et les menaces détectées

$ErrorActionPreference = "Continue"

Write-Output "=========================================="
Write-Output "SURVEILLANCE ESET ENDPOINT"
Write-Output "Poste: $env:COMPUTERNAME"
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "=========================================="
Write-Output ""

# Chemins possibles pour ESET
$ESETPath = @(
    "${env:ProgramFiles}\ESET\ESET Security\ecmd.exe",
    "${env:ProgramFiles}\ESET\ESET Endpoint Security\ecmd.exe",
    "${env:ProgramFiles}\ESET\ESET Endpoint Antivirus\ecmd.exe",
    "${env:ProgramFiles(x86)}\ESET\ESET Security\ecmd.exe",
    "${env:ProgramFiles(x86)}\ESET\ESET Endpoint Security\ecmd.exe"
)

$ECMD = $null
foreach ($Path in $ESETPath) {
    if (Test-Path $Path) {
        $ECMD = $Path
        break
    }
}

# Vérifier si ESET est installé
if (-not $ECMD) {
    # Essayer via le service
    $ESETService = Get-Service -Name "ekrn" -ErrorAction SilentlyContinue
    if (-not $ESETService) {
        Write-Error "ERREUR: ESET n'est pas installé sur ce poste"
        exit 1
    }
}

# ============================================
# INFORMATIONS PRODUIT
# ============================================
Write-Output "--- INFORMATIONS PRODUIT ---"

# Récupérer les infos via le registre
$ESETReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\ESET\ESET Security\CurrentVersion\Info" -ErrorAction SilentlyContinue
if (-not $ESETReg) {
    $ESETReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\ESET\ESET Security\CurrentVersion\Info" -ErrorAction SilentlyContinue
}

if ($ESETReg) {
    Write-Output "Produit: $($ESETReg.ProductName)"
    Write-Output "Version: $($ESETReg.ProductVersion)"
} else {
    # Essayer via WMI
    $ESETProduct = Get-WmiObject -Namespace "root\ESET" -Class ESET_Product -ErrorAction SilentlyContinue
    if ($ESETProduct) {
        Write-Output "Produit: $($ESETProduct.ProductName)"
        Write-Output "Version: $($ESETProduct.ProductVersion)"
    }
}
Write-Output ""

# ============================================
# ÉTAT DES MODULES
# ============================================
Write-Output "--- ETAT DES MODULES ---"

# Vérifier via WMI
$Modules = Get-WmiObject -Namespace "root\ESET" -Class ESET_Module -ErrorAction SilentlyContinue

if ($Modules) {
    foreach ($Module in $Modules) {
        $Status = if ($Module.Enabled) { "[OK]" } else { "[DESACTIVE]" }
        Write-Output "$Status $($Module.Name)"
    }
} else {
    # Vérifier les services ESET
    $Services = @(
        @{Name="ekrn"; Display="ESET Service"},
        @{Name="EHttpSrv"; Display="ESET HTTP Server"},
        @{Name="epfw"; Display="ESET Personal Firewall"}
    )

    foreach ($Svc in $Services) {
        $Service = Get-Service -Name $Svc.Name -ErrorAction SilentlyContinue
        if ($Service) {
            $Status = if ($Service.Status -eq "Running") { "[OK]" } else { "[ERREUR]" }
            Write-Output "$Status $($Svc.Display) - $($Service.Status)"
        }
    }
}
Write-Output ""

# ============================================
# ÉTAT DE LA PROTECTION
# ============================================
Write-Output "--- ETAT DE LA PROTECTION ---"

$ProtectionStatus = Get-WmiObject -Namespace "root\ESET" -Class ESET_Status -ErrorAction SilentlyContinue

if ($ProtectionStatus) {
    # Protection temps réel
    if ($ProtectionStatus.RealtimeStatus -eq 0) {
        Write-Output "[OK] Protection temps réel active"
    } else {
        Write-Output "[ERREUR] Protection temps réel inactive!"
    }

    # Firewall
    if ($null -ne $ProtectionStatus.FirewallStatus) {
        if ($ProtectionStatus.FirewallStatus -eq 0) {
            Write-Output "[OK] Pare-feu actif"
        } else {
            Write-Output "[ATTENTION] Pare-feu inactif"
        }
    }
} else {
    # Vérifier via le registre
    $Protection = Get-ItemProperty -Path "HKLM:\SOFTWARE\ESET\ESET Security\CurrentVersion\Plugins\01000101\Settings" -ErrorAction SilentlyContinue
    if ($Protection) {
        $RTStatus = if ($Protection.Amon_status -eq 1) { "[OK]" } else { "[ERREUR]" }
        Write-Output "$RTStatus Protection temps réel"
    }
}
Write-Output ""

# ============================================
# MISES À JOUR
# ============================================
Write-Output "--- MISES A JOUR ---"

$UpdateInfo = Get-WmiObject -Namespace "root\ESET" -Class ESET_ModuleInfo -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*Update*" -or $_.Name -like "*Engine*" }

if ($UpdateInfo) {
    foreach ($Info in $UpdateInfo) {
        Write-Output "$($Info.Name): $($Info.Version)"
        if ($Info.LastUpdate) {
            $LastUpdate = [DateTime]::FromFileTime($Info.LastUpdate)
            $DaysSince = ((Get-Date) - $LastUpdate).Days

            if ($DaysSince -gt 7) {
                Write-Output "  [ATTENTION] Dernière mise à jour: $($LastUpdate.ToString('yyyy-MM-dd')) ($DaysSince jours)"
            } else {
                Write-Output "  [OK] Dernière mise à jour: $($LastUpdate.ToString('yyyy-MM-dd'))"
            }
        }
    }
} else {
    # Vérifier la date de la base de signatures
    $SigPath = "${env:ProgramData}\ESET\ESET Security\Updfiles"
    if (Test-Path $SigPath) {
        $SigDate = (Get-Item $SigPath).LastWriteTime
        $DaysSince = ((Get-Date) - $SigDate).Days

        if ($DaysSince -gt 7) {
            Write-Output "[ATTENTION] Base de signatures: $($SigDate.ToString('yyyy-MM-dd')) ($DaysSince jours)"
        } else {
            Write-Output "[OK] Base de signatures: $($SigDate.ToString('yyyy-MM-dd'))"
        }
    }
}
Write-Output ""

# ============================================
# MENACES DÉTECTÉES
# ============================================
Write-Output "--- MENACES DETECTEES (30 derniers jours) ---"

$ThirtyDaysAgo = (Get-Date).AddDays(-30)

# Vérifier via WMI
$Threats = Get-WmiObject -Namespace "root\ESET" -Class ESET_Threat -ErrorAction SilentlyContinue |
    Where-Object { [DateTime]::FromFileTime($_.Timestamp) -gt $ThirtyDaysAgo }

if ($Threats) {
    $ThreatCount = ($Threats | Measure-Object).Count
    Write-Output "Menaces détectées: $ThreatCount"
    Write-Output ""

    foreach ($Threat in $Threats | Select-Object -First 10) {
        $ThreatTime = [DateTime]::FromFileTime($Threat.Timestamp)
        Write-Output "[$($ThreatTime.ToString('yyyy-MM-dd HH:mm'))] $($Threat.ThreatName)"
        Write-Output "   Fichier: $($Threat.ObjectUri)"
        Write-Output "   Action: $($Threat.ActionTaken)"
        Write-Output ""
    }
} else {
    # Vérifier les logs ESET
    $LogPath = "${env:ProgramData}\ESET\ESET Security\Logs\virlog.dat"
    if (Test-Path $LogPath) {
        $LogSize = (Get-Item $LogPath).Length
        if ($LogSize -gt 0) {
            Write-Output "Log des menaces présent ($([math]::Round($LogSize/1KB, 2)) KB)"
        } else {
            Write-Output "[OK] Aucune menace détectée"
        }
    } else {
        Write-Output "[OK] Aucune menace détectée"
    }
}
Write-Output ""

# ============================================
# ANALYSES RÉCENTES
# ============================================
Write-Output "--- ANALYSES RECENTES ---"

$Scans = Get-WmiObject -Namespace "root\ESET" -Class ESET_Scan -ErrorAction SilentlyContinue |
    Sort-Object -Property StartTime -Descending | Select-Object -First 5

if ($Scans) {
    foreach ($Scan in $Scans) {
        $StartTime = [DateTime]::FromFileTime($Scan.StartTime)
        $Duration = if ($Scan.Duration) { "$($Scan.Duration) sec" } else { "N/A" }

        Write-Output "$($Scan.ScanName)"
        Write-Output "   Date: $($StartTime.ToString('yyyy-MM-dd HH:mm'))"
        Write-Output "   Objets analysés: $($Scan.ScannedObjects)"
        Write-Output "   Menaces: $($Scan.Threats)"
        Write-Output ""
    }
} else {
    Write-Output "Aucune analyse récente trouvée"
}
Write-Output ""

# ============================================
# LICENCE
# ============================================
Write-Output "--- LICENCE ---"

$License = Get-WmiObject -Namespace "root\ESET" -Class ESET_License -ErrorAction SilentlyContinue

if ($License) {
    Write-Output "Type: $($License.LicenseType)"

    if ($License.ExpirationDate) {
        $ExpDate = [DateTime]::FromFileTime($License.ExpirationDate)
        $DaysLeft = ($ExpDate - (Get-Date)).Days

        if ($DaysLeft -lt 0) {
            Write-Output "[ERREUR] Licence expirée depuis $([Math]::Abs($DaysLeft)) jours!"
        } elseif ($DaysLeft -lt 30) {
            Write-Output "[ATTENTION] Expire le: $($ExpDate.ToString('yyyy-MM-dd')) ($DaysLeft jours restants)"
        } else {
            Write-Output "[OK] Expire le: $($ExpDate.ToString('yyyy-MM-dd')) ($DaysLeft jours restants)"
        }
    }
} else {
    # Vérifier via le registre
    $LicReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\ESET\ESET Security\CurrentVersion\License" -ErrorAction SilentlyContinue
    if ($LicReg) {
        Write-Output "Licence trouvée dans le registre"
    }
}
Write-Output ""

# ============================================
# RÉSUMÉ
# ============================================
Write-Output "=========================================="
Write-Output "RESUME"
Write-Output "=========================================="

$Alerts = @()

# Vérifier la protection temps réel
$RTService = Get-Service -Name "ekrn" -ErrorAction SilentlyContinue
if ($RTService -and $RTService.Status -ne "Running") {
    $Alerts += "Service ESET arrêté"
}

# Vérifier les menaces
if ($Threats -and ($Threats | Measure-Object).Count -gt 0) {
    $Alerts += "$($Threats.Count) menace(s) détectée(s)"
}

if ($Alerts.Count -gt 0) {
    Write-Output "ALERTES:"
    foreach ($Alert in $Alerts) {
        Write-Output "  - $Alert"
    }
} else {
    Write-Output "[OK] Protection ESET fonctionnelle"
}

Write-Output "=========================================="
