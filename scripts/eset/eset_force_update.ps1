# Script: Forcer la mise à jour ESET
# Usage dans Tactical RMM: Exécuter sur les postes avec ESET
# Force une mise à jour immédiate des signatures

$ErrorActionPreference = "Continue"

Write-Output "=========================================="
Write-Output "MISE A JOUR ESET"
Write-Output "Poste: $env:COMPUTERNAME"
Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
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

Write-Output "Exécutable ESET: $ECMD"
Write-Output ""

# Lancer la mise à jour
Write-Output "Lancement de la mise à jour..."
Write-Output ""

try {
    $UpdateProcess = Start-Process -FilePath $ECMD -ArgumentList "/update" -Wait -PassThru -NoNewWindow

    if ($UpdateProcess.ExitCode -eq 0) {
        Write-Output "[OK] Mise à jour lancée avec succès"
    } else {
        Write-Output "[ATTENTION] Code de retour: $($UpdateProcess.ExitCode)"
    }
} catch {
    Write-Error "ERREUR lors de la mise à jour: $_"
    exit 1
}

# Attendre que la mise à jour se termine
Write-Output ""
Write-Output "Vérification de la mise à jour..."
Start-Sleep -Seconds 10

# Vérifier la nouvelle version
$SigPath = "${env:ProgramData}\ESET\ESET Security\Updfiles"
if (Test-Path $SigPath) {
    $SigDate = (Get-Item $SigPath).LastWriteTime
    Write-Output ""
    Write-Output "Base de signatures: $($SigDate.ToString('yyyy-MM-dd HH:mm'))"
}

Write-Output ""
Write-Output "=========================================="
Write-Output "Mise à jour terminée"
Write-Output "=========================================="
