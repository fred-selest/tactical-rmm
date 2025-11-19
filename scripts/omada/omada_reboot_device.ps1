# Script: Redémarrer un équipement Omada
# Usage dans Tactical RMM: Exécuter sur un serveur avec accès au contrôleur Omada
# Redémarre un AP, Switch ou Gateway

param(
    [Parameter(Mandatory=$true)]
    [string]$OmadaUrl,

    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$Password,

    [Parameter(Mandatory=$true)]
    [string]$DeviceMac,           # Adresse MAC de l'équipement

    [ValidateSet("ap", "switch", "gateway")]
    [string]$DeviceType = "ap",

    [string]$SiteId = "Default"
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
Write-Output "REDEMARRAGE EQUIPEMENT OMADA"
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "=========================================="
Write-Output ""

# Authentification
$LoginBody = @{
    username = $Username
    password = $Password
} | ConvertTo-Json

try {
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

# Normaliser l'adresse MAC
$DeviceMac = $DeviceMac.ToUpper() -replace "[:-]", "-"

# Construire l'URL selon le type d'équipement
switch ($DeviceType) {
    "ap" {
        $RebootUrl = "$OmadaUrl/api/v2/sites/$TargetSiteId/eaps/$DeviceMac/reboot"
        $DeviceTypeName = "Point d'accès"
    }
    "switch" {
        $RebootUrl = "$OmadaUrl/api/v2/sites/$TargetSiteId/switches/$DeviceMac/reboot"
        $DeviceTypeName = "Switch"
    }
    "gateway" {
        $RebootUrl = "$OmadaUrl/api/v2/sites/$TargetSiteId/gateways/$DeviceMac/reboot"
        $DeviceTypeName = "Gateway"
    }
}

Write-Output "Type: $DeviceTypeName"
Write-Output "MAC: $DeviceMac"
Write-Output ""

# Exécuter le redémarrage
try {
    $Response = Invoke-RestMethod -Uri $RebootUrl -Method Post -Headers $Headers -WebSession $OmadaSession

    if ($Response.errorCode -eq 0) {
        Write-Output "[OK] Commande de redémarrage envoyée"
        Write-Output "L'équipement va redémarrer dans quelques secondes..."
    } else {
        Write-Error "Erreur: $($Response.msg)"
        exit 1
    }

} catch {
    Write-Error "ERREUR lors du redémarrage: $_"
    exit 1
}

Write-Output ""
Write-Output "=========================================="

# Déconnexion
try {
    Invoke-RestMethod -Uri "$OmadaUrl/api/v2/logout" -Method Post -Headers $Headers -WebSession $OmadaSession | Out-Null
} catch {}
