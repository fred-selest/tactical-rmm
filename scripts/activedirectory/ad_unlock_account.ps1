# Script: Déverrouiller un compte utilisateur AD
# Usage dans Tactical RMM: Exécuter sur le contrôleur de domaine
# Paramètre requis: Username

param(
    [Parameter(Mandatory=$true)]
    [string]$Username
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Vérifier si l'utilisateur existe
    $User = Get-ADUser -Identity $Username -Properties LockedOut, Enabled, BadLogonCount, LastBadPasswordAttempt -ErrorAction Stop

    if (-not $User.LockedOut) {
        Write-Output "Le compte '$Username' n'est pas verrouillé"
        Write-Output "Tentatives échouées: $($User.BadLogonCount)"
        exit 0
    }

    # Déverrouiller le compte
    Unlock-ADAccount -Identity $Username

    Write-Output ""
    Write-Output "=========================================="
    Write-Output "COMPTE DEVERROUILLE"
    Write-Output "=========================================="
    Write-Output "Utilisateur: $Username"
    Write-Output "Nom: $($User.Name)"
    Write-Output "Dernière tentative échouée: $($User.LastBadPasswordAttempt)"
    Write-Output "Statut: Déverrouillé"
    Write-Output "=========================================="

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Error "ERREUR: L'utilisateur '$Username' n'existe pas dans Active Directory"
    exit 1
} catch {
    Write-Error "ERREUR lors du déverrouillage: $_"
    exit 1
}
