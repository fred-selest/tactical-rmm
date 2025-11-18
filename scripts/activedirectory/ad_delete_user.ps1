# Script: Supprimer un utilisateur Active Directory
# Usage dans Tactical RMM: Exécuter sur le contrôleur de domaine
# Paramètre requis: Username
# ATTENTION: Cette action est irréversible!

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [switch]$Confirm = $false
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Vérifier si l'utilisateur existe
    $User = Get-ADUser -Identity $Username -Properties MemberOf, Created, Description -ErrorAction Stop

    # Afficher les informations avant suppression
    Write-Output "=========================================="
    Write-Output "ATTENTION: SUPPRESSION D'UTILISATEUR"
    Write-Output "=========================================="
    Write-Output "Utilisateur: $($User.SamAccountName)"
    Write-Output "Nom: $($User.Name)"
    Write-Output "Créé le: $($User.Created)"
    Write-Output "Description: $($User.Description)"
    Write-Output ""
    Write-Output "Groupes:"
    $Groups = Get-ADPrincipalGroupMembership -Identity $Username | Select-Object -ExpandProperty Name
    foreach ($G in $Groups) {
        Write-Output "  - $G"
    }
    Write-Output ""

    if (-not $Confirm) {
        Write-Warning "Pour confirmer la suppression, ajoutez le paramètre -Confirm"
        Write-Output "Commande: .\ad_delete_user.ps1 -Username $Username -Confirm"
        exit 0
    }

    # Supprimer l'utilisateur
    Remove-ADUser -Identity $Username -Confirm:$false

    Write-Output "=========================================="
    Write-Output "UTILISATEUR SUPPRIME"
    Write-Output "=========================================="
    Write-Output "L'utilisateur '$Username' a été supprimé définitivement"
    Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "=========================================="

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Error "ERREUR: L'utilisateur '$Username' n'existe pas dans Active Directory"
    exit 1
} catch {
    Write-Error "ERREUR lors de la suppression: $_"
    exit 1
}
