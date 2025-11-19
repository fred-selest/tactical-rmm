# Script: Lister les clients Omada
# Usage dans Tactical RMM: Exécuter sur un serveur avec accès au contrôleur Omada
# Liste tous les clients connectés avec détails

param(
    [Parameter(Mandatory=$true)]
    [string]$OmadaUrl,

    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$Password,

    [string]$SiteId = "Default",
    [switch]$WifiOnly,
    [switch]$WiredOnly
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
Write-Output "CLIENTS OMADA"
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "=========================================="
Write-Output ""

# Authentification
$LoginUrl = "$OmadaUrl/api/v2/login"
$LoginBody = @{
    username = $Username
    password = $Password
} | ConvertTo-Json

try {
    # Essayer d'abord l'API moderne
    $InfoResponse = Invoke-RestMethod -Uri "$OmadaUrl/api/info" -Method Get -SessionVariable OmadaSession -ErrorAction SilentlyContinue
    if ($InfoResponse.result.omadacId) {
        $OmadaUrl = "$OmadaUrl/$($InfoResponse.result.omadacId)"
    }

    $LoginResponse = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/login" -Method Post -Body $LoginBody -ContentType "application/json" -WebSession $OmadaSession
    $Token = $LoginResponse.result.token

} catch {
    Write-Error "ERREUR de connexion: $_"
    exit 1
}

$Headers = @{ "Csrf-Token" = $Token }

# Obtenir le site ID
$Sites = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/sites" -Method Get -Headers $Headers -WebSession $OmadaSession
$TargetSiteId = $Sites.result.data[0].id

foreach ($Site in $Sites.result.data) {
    if ($Site.name -eq $SiteId -or $Site.id -eq $SiteId) {
        $TargetSiteId = $Site.id
        break
    }
}

# Récupérer les clients
$Clients = Invoke-RestMethod -Uri "$OmadaUrl/api/v2/sites/$TargetSiteId/clients?limit=1000" -Method Get -Headers $Headers -WebSession $OmadaSession

$ClientList = $Clients.result.data

# Filtrer si nécessaire
if ($WifiOnly) {
    $ClientList = $ClientList | Where-Object { $_.wireless -eq $true }
}
if ($WiredOnly) {
    $ClientList = $ClientList | Where-Object { $_.wireless -eq $false }
}

# Afficher les clients
Write-Output "Total: $($ClientList.Count) client(s)"
Write-Output ""

foreach ($Client in $ClientList | Sort-Object -Property name) {
    $Name = if ($Client.name) { $Client.name } else { "Sans nom" }
    $Type = if ($Client.wireless) { "WiFi" } else { "Filaire" }
    $ConnectTime = [DateTimeOffset]::FromUnixTimeMilliseconds($Client.lastSeen).LocalDateTime

    Write-Output "-------------------------------------------"
    Write-Output "Nom: $Name"
    Write-Output "MAC: $($Client.mac)"
    Write-Output "IP: $($Client.ip)"
    Write-Output "Type: $Type"

    if ($Client.wireless) {
        Write-Output "SSID: $($Client.ssid)"
        Write-Output "Signal: $($Client.rssi) dBm"
        Write-Output "AP: $($Client.apName)"
    } else {
        Write-Output "Switch: $($Client.switchName)"
        Write-Output "Port: $($Client.switchPort)"
    }

    $DownMB = [math]::Round($Client.downPackets * 1500 / 1MB, 2)
    $UpMB = [math]::Round($Client.upPackets * 1500 / 1MB, 2)
    Write-Output "Trafic: Down $DownMB MB / Up $UpMB MB"
    Write-Output "Dernière activité: $($ConnectTime.ToString('yyyy-MM-dd HH:mm'))"
}

Write-Output ""
Write-Output "=========================================="

# Déconnexion
try {
    Invoke-RestMethod -Uri "$OmadaUrl/api/v2/logout" -Method Post -Headers $Headers -WebSession $OmadaSession | Out-Null
} catch {}
