# Script: Désactiver un utilisateur Active Directory
# Usage dans Tactical RMM: Exécuter sur le contrôleur de domaine
# Paramètre requis: Username

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [switch]$MoveToDisabledOU,
    [string]$DisabledOU = ""
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Vérifier si l'utilisateur existe
    $User = Get-ADUser -Identity $Username -Properties Enabled, DistinguishedName -ErrorAction Stop

    if (-not $User.Enabled) {
        Write-Warning "L'utilisateur '$Username' est déjà désactivé"
        exit 0
    }

    # Désactiver le compte
    Disable-ADAccount -Identity $Username

    Write-Output "Compte '$Username' désactivé avec succès"

    # Déplacer vers l'OU des comptes désactivés si demandé
    if ($MoveToDisabledOU) {
        if ([string]::IsNullOrEmpty($DisabledOU)) {
            # Chercher une OU "Disabled" ou "Désactivés"
            $DisabledOU = Get-ADOrganizationalUnit -Filter 'Name -like "*Disabled*" -or Name -like "*Désactivé*"' | Select-Object -First 1 -ExpandProperty DistinguishedName
        }

        if (-not [string]::IsNullOrEmpty($DisabledOU)) {
            Move-ADObject -Identity $User.DistinguishedName -TargetPath $DisabledOU
            Write-Output "Utilisateur déplacé vers: $DisabledOU"
        } else {
            Write-Warning "OU des comptes désactivés non trouvée"
        }
    }

    # Afficher le résumé
    $UpdatedUser = Get-ADUser -Identity $Username -Properties Enabled, WhenChanged
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "COMPTE DESACTIVE"
    Write-Output "=========================================="
    Write-Output "Utilisateur: $Username"
    Write-Output "Statut: Désactivé"
    Write-Output "Date: $($UpdatedUser.WhenChanged)"
    Write-Output "=========================================="

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Error "ERREUR: L'utilisateur '$Username' n'existe pas dans Active Directory"
    exit 1
} catch {
    Write-Error "ERREUR lors de la désactivation: $_"
    exit 1
}
