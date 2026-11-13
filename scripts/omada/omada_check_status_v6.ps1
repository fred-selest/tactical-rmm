# Script: Surveillance Omada Controller v6
# Compatible Omada Controller v5.x et v6.x
# Usage dans Tactical RMM: Exécuter sur un serveur avec accès au contrôleur Omada

param(
    [Parameter(Mandatory=$true)]
    [string]$OmadaUrl,          # URL du contrôleur (ex: https://omada.domaine.com:8043)

    [Parameter(Mandatory=$false)]
    [string]$ClientId,          # Client ID (API v6 - recommandé)

    [Parameter(Mandatory=$false)]
    [string]$ClientSecret,      # Client Secret (API v6 - recommandé)

    [Parameter(Mandatory=$false)]
    [string]$Username,          # Utilisateur Omada (API v2 - legacy)

    [Parameter(Mandatory=$false)]
    [string]$Password,          # Mot de passe (API v2 - legacy)

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
Write-Output "SURVEILLANCE OMADA CONTROLLER v6"
Write-Output "Contrôleur: $OmadaUrl"
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "=========================================="
Write-Output ""

# ============================================
# AUTHENTIFICATION
# ============================================

$ApiVersion = ""
$OmadaSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$Headers = @{}

# === MODE 1: API v6 (OAuth 2.0 - Client Credentials) ===
if ($ClientId -and $ClientSecret) {
    Write-Output "--- Authentification API v6 (OAuth 2.0) ---"

    try {
        # Étape 1: Obtenir le token d'accès
        $TokenUrl = "$OmadaUrl/api/v2/oauth/token"
        $TokenBody = @{
            grant_type = "client_credentials"
            client_id = $ClientId
            client_secret = $ClientSecret
        }

        $TokenResponse = Invoke-RestMethod -Uri $TokenUrl -Method Post -Body $TokenBody -ContentType "application/x-www-form-urlencoded" -WebSession $OmadaSession

        if ($TokenResponse.access_token) {
            $AccessToken = $TokenResponse.access_token
            $ApiVersion = "v6"
            $Headers = @{
                "Authorization" = "AccessToken $AccessToken"
                "Content-Type"  = "application/json"
            }
            Write-Output "[OK] Connexion API v6 réussie"
            Write-Output "Token expires in: $($TokenResponse.expires_in) secondes"
        } else {
            throw "Token non reçu"
        }

    } catch {
        Write-Output "Échec API v6: $_"
        Write-Output "Tentative API v2 (legacy)..."
        Write-Output ""
    }
}

# === MODE 2: API v2 (Legacy - Username/Password) ===
if (-not $ApiVersion -and $Username -and $Password) {
    Write-Output "--- Authentification API v2 (Legacy) ---"

    try {
        # Détecter la version du contrôleur
        $InfoUrl = "$OmadaUrl/api/info"
        $InfoResponse = $null

        try {
            $InfoResponse = Invoke-RestMethod -Uri $InfoUrl -Method Get -WebSession $OmadaSession -ErrorAction SilentlyContinue
        } catch {}

        if ($InfoResponse -and $InfoResponse.result) {
            # API v4/v5/v6 avec context path
            $OmadaId = $InfoResponse.result.omadacId
            $BaseApiUrl = "$OmadaUrl/$OmadaId/api/v2"
            Write-Output "Contrôleur détecté: API avec context '$OmadaId'"
        } else {
            # API v2 standard
            $BaseApiUrl = "$OmadaUrl/api/v2"
        }

        # Login
        $LoginUrl = "$BaseApiUrl/login"
        $LoginBody = @{
            username = $Username
            password = $Password
        } | ConvertTo-Json

        $LoginResponse = Invoke-RestMethod -Uri $LoginUrl -Method Post -Body $LoginBody -ContentType "application/json" -WebSession $OmadaSession

        if ($LoginResponse.errorCode -ne 0) {
            throw "Échec de connexion: $($LoginResponse.msg)"
        }

        $ApiVersion = "v2"
        $CsrfToken = $LoginResponse.result.token
        $Headers = @{
            "Csrf-Token"   = $CsrfToken
            "Content-Type" = "application/json"
        }
        $OmadaUrl = $BaseApiUrl

        Write-Output "[OK] Connexion API v2 réussie"

    } catch {
        Write-Error "ERREUR de connexion: $_"
        exit 1
    }
} elseif (-not $ApiVersion) {
    Write-Error "ERREUR: Fournissez soit ClientId/ClientSecret (API v6) soit Username/Password (API v2)"
    exit 1
}

Write-Output "Version API: $ApiVersion"
Write-Output ""

# ============================================
# INFORMATIONS CONTRÔLEUR
# ============================================
Write-Output "--- INFORMATIONS CONTROLEUR ---"

try {
    if ($ApiVersion -eq "v6") {
        $ControllerInfo = Invoke-RestMethod -Uri "$OmadaUrl/api/v6/maintenance/controllerStatus" -Method Get -Headers $Headers -WebSession $OmadaSession
    } else {
        $ControllerInfo = Invoke-RestMethod -Uri "$OmadaUrl/maintenance/controllerStatus" -Method Get -Headers $Headers -WebSession $OmadaSession
    }

    if ($ControllerInfo.result) {
        $Info = $ControllerInfo.result
        Write-Output "Version: $($Info.controllerVersion)"
        Write-Output "Modèle: $($Info.model)"

        if ($Info.uptime) {
            $UptimeHours = [math]::Round($Info.uptime / 3600, 1)
            Write-Output "Uptime: $UptimeHours heures"
        }

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

$TargetSiteId = ""

try {
    if ($ApiVersion -eq "v6") {
        $Sites = Invoke-RestMethod -Uri "$OmadaUrl/api/v6/sites" -Method Get -Headers $Headers -WebSession $OmadaSession
    } else {
        $Sites = Invoke-RestMethod -Uri "$OmadaUrl/sites" -Method Get -Headers $Headers -WebSession $OmadaSession
    }

    foreach ($Site in $Sites.result.data) {
        $ClientCount = $Site.connectedNum
        Write-Output "$($Site.name): $ClientCount clients"

        if ($Site.name -eq $SiteId -or $Site.id -eq $SiteId) {
            $TargetSiteId = $Site.id
        }
    }

    if (-not $TargetSiteId -and $Sites.result.data.Count -gt 0) {
        $TargetSiteId = $Sites.result.data[0].id
        Write-Output "Site sélectionné: $($Sites.result.data[0].name) (défaut)"
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
$TotalDevices = 0
$OnlineDevices = 0

if ($ApiVersion -eq "v6") {
    $ApiBase = "$OmadaUrl/api/v6/sites/$TargetSiteId"
} else {
    $ApiBase = "$OmadaUrl/sites/$TargetSiteId"
}

# Points d'accès
try {
    $APs = Invoke-RestMethod -Uri "$ApiBase/eaps" -Method Get -Headers $Headers -WebSession $OmadaSession

    if ($APs.result.data) {
        Write-Output ""
        Write-Output "Points d'accès:"
        foreach ($AP in $APs.result.data) {
            $TotalDevices++
            # Status 14 = connecté, autre = déconnecté
            $Status = if ($AP.status -eq 14) { "[OK]" } else { "[HORS LIGNE]"; $DeviceAlerts++ }
            $Clients = $AP.clientNum
            $OnlineDevices++

            Write-Output "$Status $($AP.name) - $($AP.model)"
            Write-Output "   IP: $($AP.ip) | MAC: $($AP.mac)"
            Write-Output "   Clients: $Clients | Canal: $($AP.channel)"

            if ($AP.cpuUtil) {
                Write-Output "   CPU: $($AP.cpuUtil)% | Mémoire: $($AP.memUtil)%"
            }
        }
    }
} catch {
    Write-Output "Impossible de récupérer les points d'accès: $_"
}

# Switches
try {
    $Switches = Invoke-RestMethod -Uri "$ApiBase/switches" -Method Get -Headers $Headers -WebSession $OmadaSession

    if ($Switches.result.data) {
        Write-Output ""
        Write-Output "Switches:"
        foreach ($Switch in $Switches.result.data) {
            $TotalDevices++
            $Status = if ($Switch.status -eq 14) { "[OK]" } else { "[HORS LIGNE]"; $DeviceAlerts++ }
            $OnlineDevices++

            Write-Output "$Status $($Switch.name) - $($Switch.model)"
            Write-Output "   IP: $($Switch.ip) | MAC: $($Switch.mac)"
            Write-Output "   Ports: $($Switch.portNum)"

            if ($Switch.cpuUtil) {
                Write-Output "   CPU: $($Switch.cpuUtil)% | Mémoire: $($Switch.memUtil)%"
            }
        }
    }
} catch {
    Write-Output "Impossible de récupérer les switches: $_"
}

# Gateways
try {
    $Gateways = Invoke-RestMethod -Uri "$ApiBase/gateways" -Method Get -Headers $Headers -WebSession $OmadaSession

    if ($Gateways.result.data) {
        Write-Output ""
        Write-Output "Gateways:"
        foreach ($GW in $Gateways.result.data) {
            $TotalDevices++
            $Status = if ($GW.status -eq 14) { "[OK]" } else { "[HORS LIGNE]"; $DeviceAlerts++ }
            $OnlineDevices++

            Write-Output "$Status $($GW.name) - $($GW.model)"
            Write-Output "   IP: $($GW.ip) | MAC: $($GW.mac)"

            if ($GW.cpuUtil) {
                Write-Output "   CPU: $($GW.cpuUtil)% | Mémoire: $($GW.memUtil)%"
            }
        }
    }
} catch {
    Write-Output "Impossible de récupérer les gateways: $_"
}

Write-Output ""
Write-Output "Résumé équipements: $OnlineDevices/$TotalDevices en ligne"

Write-Output ""

# ============================================
# CLIENTS CONNECTÉS
# ============================================
Write-Output "--- CLIENTS CONNECTES ---"

try {
    $Clients = Invoke-RestMethod -Uri "$ApiBase/clients?limit=500" -Method Get -Headers $Headers -WebSession $OmadaSession

    $TotalClients = $Clients.result.totalRows
    $WifiClients = ($Clients.result.data | Where-Object { $_.wireless -eq $true }).Count
    $WiredClients = $TotalClients - $WifiClients

    Write-Output "Total: $TotalClients"
    Write-Output "WiFi: $WifiClients"
    Write-Output "Filaire: $WiredClients"

    # Top 5 clients par bande passante
    if ($Clients.result.data.Count -gt 0) {
        Write-Output ""
        Write-Output "Top 5 clients (trafic):"
        $TopClients = $Clients.result.data | Sort-Object -Property activity -Descending | Select-Object -First 5

        foreach ($Client in $TopClients) {
            $Traffic = [math]::Round($Client.activity / 1MB, 2)
            $Name = if ($Client.name -and $Client.name -ne "") { $Client.name } else { $Client.mac }
            $ConnType = if ($Client.wireless) { "WiFi" } else { "Filaire" }
            Write-Output "  $Name - $Traffic MB ($ConnType)"
        }
    }

} catch {
    Write-Output "Impossible de récupérer les clients: $_"
}

Write-Output ""

# ============================================
# RÉSEAUX WIFI
# ============================================
Write-Output "--- RESEAUX WIFI (SSID) ---"

try {
    $WLANs = Invoke-RestMethod -Uri "$ApiBase/setting/wlans" -Method Get -Headers $Headers -WebSession $OmadaSession

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
    $Alerts = Invoke-RestMethod -Uri "$ApiBase/alerts?limit=10" -Method Get -Headers $Headers -WebSession $OmadaSession

    if ($Alerts.result.data -and $Alerts.result.data.Count -gt 0) {
        Write-Output "Alertes récentes:"
        foreach ($Alert in $Alerts.result.data | Select-Object -First 5) {
            # Convertir timestamp (peut être en ms ou secondes)
            try {
                if ($Alert.time -gt 1000000000000) {
                    $AlertTime = [DateTimeOffset]::FromUnixTimeMilliseconds($Alert.time).LocalDateTime
                } else {
                    $AlertTime = [DateTimeOffset]::FromUnixTimeSeconds($Alert.time).LocalDateTime
                }
            } catch {
                $AlertTime = "Inconnue"
            }
            Write-Output "  [$AlertTime] $($Alert.msg)"
        }
    } else {
        Write-Output "[OK] Aucune alerte"
    }
} catch {
    Write-Output "Impossible de récupérer les alertes: $_"
}

Write-Output ""

# ============================================
# RÉSUMÉ
# ============================================
Write-Output "=========================================="
Write-Output "RESUME"
Write-Output "=========================================="

$ExitCode = 0

if ($DeviceAlerts -gt 0) {
    Write-Output "[ALERTE] $DeviceAlerts équipement(s) hors ligne!"
    $ExitCode = 1
} else {
    Write-Output "[OK] Tous les équipements sont en ligne ($OnlineDevices/$TotalDevices)"
}

Write-Output "Clients connectés: $TotalClients"
Write-Output "=========================================="

# Déconnexion (nettoyage session)
try {
    if ($ApiVersion -eq "v6") {
        Invoke-RestMethod -Uri "$OmadaUrl/api/v6/logout" -Method Post -Headers $Headers -WebSession $OmadaSession | Out-Null
    } else {
        Invoke-RestMethod -Uri "$OmadaUrl/logout" -Method Post -Headers $Headers -WebSession $OmadaSession | Out-Null
    }
} catch {}

exit $ExitCode
