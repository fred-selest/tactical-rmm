# Script: Créer un groupe Active Directory
# Usage dans Tactical RMM: Exécuter sur le contrôleur de domaine
# Paramètres requis: GroupName
# Paramètres optionnels: Description, OU, GroupScope, GroupCategory

param(
    [Parameter(Mandatory=$true)]
    [string]$GroupName,

    [string]$Description = "",
    [string]$OU = "",
    [ValidateSet("Global", "DomainLocal", "Universal")]
    [string]$GroupScope = "Global",
    [ValidateSet("Security", "Distribution")]
    [string]$GroupCategory = "Security",
    [string]$Members = ""  # Utilisateurs séparés par des virgules
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Obtenir l'OU par défaut si non spécifiée
    if ([string]::IsNullOrEmpty($OU)) {
        $OU = (Get-ADDomain).UsersContainer
    }

    # Vérifier si le groupe existe déjà
    $ExistingGroup = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue
    if ($ExistingGroup) {
        Write-Error "ERREUR: Le groupe '$GroupName' existe déjà dans Active Directory"
        exit 1
    }

    # Paramètres du groupe
    $GroupParams = @{
        Name = $GroupName
        SamAccountName = $GroupName
        GroupScope = $GroupScope
        GroupCategory = $GroupCategory
        Path = $OU
    }

    if (-not [string]::IsNullOrEmpty($Description)) {
        $GroupParams.Description = $Description
    }

    # Créer le groupe
    New-ADGroup @GroupParams

    Write-Output "Groupe '$GroupName' créé avec succès"

    # Ajouter les membres si spécifiés
    if (-not [string]::IsNullOrEmpty($Members)) {
        $MemberList = $Members -split ','
        foreach ($Member in $MemberList) {
            $MemberName = $Member.Trim()
            try {
                Add-ADGroupMember -Identity $GroupName -Members $MemberName
                Write-Output "Membre ajouté: $MemberName"
            } catch {
                Write-Warning "Impossible d'ajouter '$MemberName': $_"
            }
        }
    }

    # Afficher le résumé
    $Group = Get-ADGroup -Identity $GroupName -Properties Description, Created
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "GROUPE CREE AVEC SUCCES"
    Write-Output "=========================================="
    Write-Output "Nom: $GroupName"
    Write-Output "Type: $GroupCategory"
    Write-Output "Étendue: $GroupScope"
    Write-Output "Description: $Description"
    Write-Output "OU: $OU"
    Write-Output "=========================================="

} catch {
    Write-Error "ERREUR lors de la création du groupe: $_"
    exit 1
}
