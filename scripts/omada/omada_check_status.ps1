# Script: Surveillance Omada Controller
# Usage dans Tactical RMM: Exécuter sur un serveur avec accès au contrôleur Omada
# Vérifie l'état du réseau, des équipements et des clients

param(
    [Parameter(Mandatory=$true)]
    [string]$OmadaUrl,          # URL du contrôleur (ex: https://omada.domaine.com)

    [Parameter(Mandatory=$true)]
    [string]$Username,          # Utilisateur Omada

    [Parameter(Mandatory=$true)]
    [string]$Password,          # Mot de passe

    [string]$SiteId = "Default" # Site Omada (défaut: Default)
)

$ErrorActionPreference = "Continue"

# Ignorer les certificats auto-signés
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Output "=========================================="
Write-Output "SURVEILLANCE OMADA CONTROLLER"
Write-Output "Contrôleur: $OmadaUrl"
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "=========================================="
Write-Output ""

# ============================================
# AUTHENTIFICATION
# ============================================

$LoginUrl = "$OmadaUrl/api/v2/login"
$LoginBody = @{
    username = $Username
    password = $Password
} | ConvertTo-Json

try {
    $LoginResponse = Invoke-RestMethod -Uri $LoginUrl -Method Post -Body $LoginBody -ContentType "application/json" -SessionVariable OmadaSession

    if ($LoginResponse.errorCode -ne 0) {
        Write-Error "Échec de connexion: $($LoginResponse.msg)"
        exit 1
    }

    $Token = $LoginResponse.result.token
    Write-Output "[OK] Connexion au contrôleur réussie"

} catch {
    # Essayer l'ancienne API (Omada Controller v4)
    try {
        $LoginUrl = "$OmadaUrl/api/info"
        $InfoResponse = Invoke-RestMethod -Uri $LoginUrl -Method Get -SessionVariable OmadaSession

        $LoginUrl = "$OmadaUrl/$($InfoResponse.result.omadacId)/api/v2/login"
        $LoginResponse = Invoke-RestMethod -Uri $LoginUrl -Method Post -Body $LoginBody -ContentType "application/json" -WebSession $OmadaSession

        $Token = $LoginResponse.result.token
        $OmadaUrl = "$OmadaUrl/$($InfoResponse.result.omadacId)"
        Write-Output "[OK] Connexion au contrôleur réussie (API v4)"

    } catch {
        Write-Error "ERREUR de connexion: $_"
        exit 1
    }
}

$Headers = @{
    "Csrf-Token" = $Token
}

Write-Output ""

# ============================================
# INFORMATIONS CONTRÔLEUR
# ============================================
Write-Output "--- INFORMATIONS CONTROLEUR ---"

try {
    $ControllerInfo = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/maintenance/controllerStatus" -Method Get -Headers $Headers -WebSession $OmadaSession

    if ($ControllerInfo.result) {
        $Info = $ControllerInfo.result
        Write-Output "Version: $($Info.controllerVersion)"
        Write-Output "Modèle: $($Info.model)"
        Write-Output "Uptime: $([math]::Round($Info.uptime / 3600, 1)) heures"

        # CPU et mémoire du contrôleur
        if ($Info.cpuUsage) {
            Write-Output "CPU: $($Info.cpuUsage)%"
        }
        if ($Info.memUsage) {
            Write-Output "Mémoire: $($Info.memUsage)%"
        }
    }
} catch {
    Write-Output "Impossible de récupérer les infos du contrôleur"
}

Write-Output ""

# ============================================
# LISTE DES SITES
# ============================================
Write-Output "--- SITES ---"

try {
    $Sites = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/sites" -Method Get -Headers $Headers -WebSession $OmadaSession

    $TargetSiteId = $null
    foreach ($Site in $Sites.result.data) {
        $ClientCount = $Site.connectedNum
        Write-Output "$($Site.name): $ClientCount clients"

        if ($Site.name -eq $SiteId -or $Site.id -eq $SiteId) {
            $TargetSiteId = $Site.id
        }
    }

    if (-not $TargetSiteId -and $Sites.result.data.Count -gt 0) {
        $TargetSiteId = $Sites.result.data[0].id
    }

} catch {
    Write-Output "Impossible de récupérer la liste des sites"
    exit 1
}

Write-Output ""

# ============================================
# ÉQUIPEMENTS (APs, Switches, Gateways)
# ============================================
Write-Output "--- EQUIPEMENTS ---"

$DeviceAlerts = 0

# Points d'accès
try {
    $APs = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/sites/$TargetSiteId/eaps" -Method Get -Headers $Headers -WebSession $OmadaSession

    if ($APs.result.data) {
        Write-Output ""
        Write-Output "Points d'accès:"
        foreach ($AP in $APs.result.data) {
            $Status = if ($AP.status -eq 14) { "[OK]" } else { "[HORS LIGNE]"; $DeviceAlerts++ }
            $Clients = $AP.clientNum

            Write-Output "$Status $($AP.name) - $($AP.model)"
            Write-Output "   IP: $($AP.ip) | Clients: $Clients | Canal: $($AP.channel)"

            if ($AP.cpuUtil) {
                Write-Output "   CPU: $($AP.cpuUtil)% | Mémoire: $($AP.memUtil)%"
            }
        }
    }
} catch {
    Write-Output "Impossible de récupérer les points d'accès"
}

# Switches
try {
    $Switches = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/sites/$TargetSiteId/switches" -Method Get -Headers $Headers -WebSession $OmadaSession

    if ($Switches.result.data) {
        Write-Output ""
        Write-Output "Switches:"
        foreach ($Switch in $Switches.result.data) {
            $Status = if ($Switch.status -eq 14) { "[OK]" } else { "[HORS LIGNE]"; $DeviceAlerts++ }

            Write-Output "$Status $($Switch.name) - $($Switch.model)"
            Write-Output "   IP: $($Switch.ip) | Ports: $($Switch.portNum)"
        }
    }
} catch {
    Write-Output "Impossible de récupérer les switches"
}

# Gateways
try {
    $Gateways = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/sites/$TargetSiteId/gateways" -Method Get -Headers $Headers -WebSession $OmadaSession

    if ($Gateways.result.data) {
        Write-Output ""
        Write-Output "Gateways:"
        foreach ($GW in $Gateways.result.data) {
            $Status = if ($GW.status -eq 14) { "[OK]" } else { "[HORS LIGNE]"; $DeviceAlerts++ }

            Write-Output "$Status $($GW.name) - $($GW.model)"
            Write-Output "   IP: $($GW.ip)"

            if ($GW.cpuUtil) {
                Write-Output "   CPU: $($GW.cpuUtil)% | Mémoire: $($GW.memUtil)%"
            }
        }
    }
} catch {
    Write-Output "Impossible de récupérer les gateways"
}

Write-Output ""

# ============================================
# CLIENTS CONNECTÉS
# ============================================
Write-Output "--- CLIENTS CONNECTES ---"

try {
    $Clients = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/sites/$TargetSiteId/clients?limit=500" -Method Get -Headers $Headers -WebSession $OmadaSession

    $TotalClients = $Clients.result.totalRows
    $WifiClients = ($Clients.result.data | Where-Object { $_.wireless -eq $true }).Count
    $WiredClients = $TotalClients - $WifiClients

    Write-Output "Total: $TotalClients"
    Write-Output "WiFi: $WifiClients"
    Write-Output "Filaire: $WiredClients"

    # Top 5 clients par bande passante
    Write-Output ""
    Write-Output "Top 5 clients (trafic):"
    $TopClients = $Clients.result.data | Sort-Object -Property activity -Descending | Select-Object -First 5

    foreach ($Client in $TopClients) {
        $Traffic = [math]::Round($Client.activity / 1MB, 2)
        $Name = if ($Client.name) { $Client.name } else { $Client.mac }
        Write-Output "  $Name - $Traffic MB"
    }

} catch {
    Write-Output "Impossible de récupérer les clients"
}

Write-Output ""

# ============================================
# RÉSEAUX WIFI
# ============================================
Write-Output "--- RESEAUX WIFI (SSID) ---"

try {
    $WLANs = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/sites/$TargetSiteId/setting/wlans" -Method Get -Headers $Headers -WebSession $OmadaSession

    if ($WLANs.result.data) {
        foreach ($WLAN in $WLANs.result.data) {
            $Status = if ($WLAN.enable) { "[Actif]" } else { "[Désactivé]" }
            $Security = $WLAN.security

            Write-Output "$Status $($WLAN.name)"
            Write-Output "   Sécurité: $Security | VLAN: $($WLAN.vlanId)"
        }
    }
} catch {
    Write-Output "Impossible de récupérer les réseaux WiFi"
}

Write-Output ""

# ============================================
# ALERTES
# ============================================
Write-Output "--- ALERTES ---"

try {
    $Alerts = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/sites/$TargetSiteId/alerts?limit=10" -Method Get -Headers $Headers -WebSession $OmadaSession

    if ($Alerts.result.data -and $Alerts.result.data.Count -gt 0) {
        Write-Output "Alertes récentes:"
        foreach ($Alert in $Alerts.result.data | Select-Object -First 5) {
            $AlertTime = [DateTimeOffset]::FromUnixTimeMilliseconds($Alert.time).LocalDateTime
            Write-Output "  [$($AlertTime.ToString('MM-dd HH:mm'))] $($Alert.msg)"
        }
    } else {
        Write-Output "[OK] Aucune alerte"
    }
} catch {
    Write-Output "Impossible de récupérer les alertes"
}

Write-Output ""

# ============================================
# RÉSUMÉ
# ============================================
Write-Output "=========================================="
Write-Output "RESUME"
Write-Output "=========================================="

if ($DeviceAlerts -gt 0) {
    Write-Output "[ALERTE] $DeviceAlerts équipement(s) hors ligne!"
    exit 1
} else {
    Write-Output "[OK] Tous les équipements sont en ligne"
}

Write-Output "Clients connectés: $TotalClients"
Write-Output "=========================================="

# Déconnexion
try {
    Invoke-RestMethod -Uri "$OmadaUrl/api/v2/logout" -Method Post -Headers $Headers -WebSession $OmadaSession | Out-Null
} catch {}
