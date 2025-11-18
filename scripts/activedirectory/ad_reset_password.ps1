# Script: Réinitialiser le mot de passe d'un utilisateur AD
# Usage dans Tactical RMM: Exécuter sur le contrôleur de domaine
# Paramètres requis: Username, NewPassword

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$NewPassword,

    [switch]$MustChangePassword = $true,
    [switch]$UnlockAccount = $true
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Vérifier si l'utilisateur existe
    $User = Get-ADUser -Identity $Username -Properties LockedOut, Enabled -ErrorAction Stop

    # Convertir le mot de passe
    $SecurePassword = ConvertTo-SecureString $NewPassword -AsPlainText -Force

    # Réinitialiser le mot de passe
    Set-ADAccountPassword -Identity $Username -Reset -NewPassword $SecurePassword

    Write-Output "Mot de passe réinitialisé pour '$Username'"

    # Forcer le changement au prochain login
    if ($MustChangePassword) {
        Set-ADUser -Identity $Username -ChangePasswordAtLogon $true
        Write-Output "L'utilisateur devra changer son mot de passe à la prochaine connexion"
    }

    # Déverrouiller le compte si demandé
    if ($UnlockAccount -and $User.LockedOut) {
        Unlock-ADAccount -Identity $Username
        Write-Output "Compte déverrouillé"
    }

    # Activer le compte s'il était désactivé
    if (-not $User.Enabled) {
        Enable-ADAccount -Identity $Username
        Write-Output "Compte réactivé"
    }

    # Afficher le résumé
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "MOT DE PASSE REINITIALISE"
    Write-Output "=========================================="
    Write-Output "Utilisateur: $Username"
    Write-Output "Changement requis: $MustChangePassword"
    Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "=========================================="

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Error "ERREUR: L'utilisateur '$Username' n'existe pas dans Active Directory"
    exit 1
} catch {
    Write-Error "ERREUR lors de la réinitialisation: $_"
    exit 1
}
