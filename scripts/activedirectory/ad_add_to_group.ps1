# Script: Ajouter un utilisateur à un groupe AD
# Usage dans Tactical RMM: Exécuter sur le contrôleur de domaine
# Paramètres requis: Username, GroupName

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$GroupName
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Vérifier si l'utilisateur existe
    $User = Get-ADUser -Identity $Username -ErrorAction Stop

    # Vérifier si le groupe existe
    $Group = Get-ADGroup -Identity $GroupName -ErrorAction Stop

    # Vérifier si l'utilisateur est déjà membre
    $IsMember = Get-ADGroupMember -Identity $GroupName | Where-Object { $_.SamAccountName -eq $Username }

    if ($IsMember) {
        Write-Warning "L'utilisateur '$Username' est déjà membre du groupe '$GroupName'"
        exit 0
    }

    # Ajouter l'utilisateur au groupe
    Add-ADGroupMember -Identity $GroupName -Members $Username

    # Lister les groupes de l'utilisateur
    $UserGroups = Get-ADPrincipalGroupMembership -Identity $Username | Select-Object -ExpandProperty Name

    Write-Output ""
    Write-Output "=========================================="
    Write-Output "UTILISATEUR AJOUTE AU GROUPE"
    Write-Output "=========================================="
    Write-Output "Utilisateur: $Username"
    Write-Output "Groupe: $GroupName"
    Write-Output ""
    Write-Output "Groupes actuels de l'utilisateur:"
    foreach ($G in $UserGroups | Sort-Object) {
        Write-Output "  - $G"
    }
    Write-Output "=========================================="

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Error "ERREUR: L'utilisateur '$Username' ou le groupe '$GroupName' n'existe pas"
    exit 1
} catch {
    Write-Error "ERREUR lors de l'ajout au groupe: $_"
    exit 1
}
