# Script: Lancer une analyse ESET
# Usage dans Tactical RMM: Exécuter sur les postes avec ESET
# Lance une analyse à la demande

param(
    [ValidateSet("Quick", "Full", "Custom")]
    [string]$ScanType = "Quick",

    [string]$CustomPath = "C:\"
)

$ErrorActionPreference = "Continue"

Write-Output "=========================================="
Write-Output "ANALYSE ESET"
Write-Output "Poste: $env:COMPUTERNAME"
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "Type: $ScanType"
Write-Output "=========================================="
Write-Output ""

# Trouver l'exécutable ESET
$ESETPath = @(
    "${env:ProgramFiles}\ESET\ESET Security\ecmd.exe",
    "${env:ProgramFiles}\ESET\ESET Endpoint Security\ecmd.exe",
    "${env:ProgramFiles}\ESET\ESET Endpoint Antivirus\ecmd.exe"
)

$ECMD = $null
foreach ($Path in $ESETPath) {
    if (Test-Path $Path) {
        $ECMD = $Path
        break
    }
}

if (-not $ECMD) {
    Write-Error "ERREUR: ESET ecmd.exe non trouvé"
    exit 1
}

# Définir les arguments selon le type d'analyse
switch ($ScanType) {
    "Quick" {
        $ScanArgs = "/scan /profile='Smart scan'"
        Write-Output "Analyse rapide des zones critiques..."
    }
    "Full" {
        $ScanArgs = "/scan /profile='In-depth scan'"
        Write-Output "Analyse complète du système..."
        Write-Output "(Cette opération peut prendre plusieurs heures)"
    }
    "Custom" {
        $ScanArgs = "/scan /target='$CustomPath'"
        Write-Output "Analyse personnalisée: $CustomPath"
    }
}

Write-Output ""

# Lancer l'analyse
$StartTime = Get-Date

try {
    Write-Output "Démarrage de l'analyse..."
    $ScanProcess = Start-Process -FilePath $ECMD -ArgumentList $ScanArgs -Wait -PassThru -NoNewWindow

    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime

    Write-Output ""
    Write-Output "Analyse terminée"
    Write-Output "Durée: $($Duration.Hours)h $($Duration.Minutes)m $($Duration.Seconds)s"
    Write-Output "Code de retour: $($ScanProcess.ExitCode)"

    if ($ScanProcess.ExitCode -eq 0) {
        Write-Output ""
        Write-Output "[OK] Aucune menace détectée"
    } elseif ($ScanProcess.ExitCode -eq 1) {
        Write-Output ""
        Write-Output "[ATTENTION] Menaces détectées et nettoyées"
    } elseif ($ScanProcess.ExitCode -eq 10) {
        Write-Output ""
        Write-Output "[ERREUR] Certains fichiers n'ont pas pu être analysés"
    } else {
        Write-Output ""
        Write-Output "[INFO] Analyse terminée avec code: $($ScanProcess.ExitCode)"
    }

} catch {
    Write-Error "ERREUR lors de l'analyse: $_"
    exit 1
}

Write-Output ""
Write-Output "=========================================="
