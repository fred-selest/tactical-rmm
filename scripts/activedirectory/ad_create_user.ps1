# Script: Créer un utilisateur Active Directory
# Usage dans Tactical RMM: Exécuter sur le contrôleur de domaine
# Paramètres requis: Username, FirstName, LastName, Password
# Paramètres optionnels: OU, Email, Department, Title, Manager

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$FirstName,

    [Parameter(Mandatory=$true)]
    [string]$LastName,

    [Parameter(Mandatory=$true)]
    [string]$Password,

    [string]$OU = "",
    [string]$Email = "",
    [string]$Department = "",
    [string]$Title = "",
    [string]$Manager = "",
    [string]$Groups = ""  # Groupes séparés par des virgules
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Obtenir le domaine
    $Domain = (Get-ADDomain).DNSRoot
    $DefaultOU = (Get-ADDomain).UsersContainer

    if ([string]::IsNullOrEmpty($OU)) {
        $OU = $DefaultOU
    }

    # Vérifier si l'utilisateur existe déjà
    $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue
    if ($ExistingUser) {
        Write-Error "ERREUR: L'utilisateur '$Username' existe déjà dans Active Directory"
        exit 1
    }

    # Convertir le mot de passe
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

    # Paramètres de base
    $UserParams = @{
        Name = "$FirstName $LastName"
        GivenName = $FirstName
        Surname = $LastName
        SamAccountName = $Username
        UserPrincipalName = "$Username@$Domain"
        Path = $OU
        AccountPassword = $SecurePassword
        Enabled = $true
        ChangePasswordAtLogon = $true
    }

    # Ajouter les paramètres optionnels
    if (-not [string]::IsNullOrEmpty($Email)) {
        $UserParams.EmailAddress = $Email
    }
    if (-not [string]::IsNullOrEmpty($Department)) {
        $UserParams.Department = $Department
    }
    if (-not [string]::IsNullOrEmpty($Title)) {
        $UserParams.Title = $Title
    }

    # Créer l'utilisateur
    New-ADUser @UserParams

    # Définir le manager si spécifié
    if (-not [string]::IsNullOrEmpty($Manager)) {
        $ManagerUser = Get-ADUser -Filter "SamAccountName -eq '$Manager'" -ErrorAction SilentlyContinue
        if ($ManagerUser) {
            Set-ADUser -Identity $Username -Manager $ManagerUser
            Write-Output "Manager défini: $Manager"
        } else {
            Write-Warning "Manager '$Manager' non trouvé"
        }
    }

    # Ajouter aux groupes si spécifiés
    if (-not [string]::IsNullOrEmpty($Groups)) {
        $GroupList = $Groups -split ','
        foreach ($Group in $GroupList) {
            $GroupName = $Group.Trim()
            try {
                Add-ADGroupMember -Identity $GroupName -Members $Username
                Write-Output "Ajouté au groupe: $GroupName"
            } catch {
                Write-Warning "Impossible d'ajouter au groupe '$GroupName': $_"
            }
        }
    }

    # Afficher le résumé
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "UTILISATEUR CREE AVEC SUCCES"
    Write-Output "=========================================="
    Write-Output "Nom d'utilisateur: $Username"
    Write-Output "Nom complet: $FirstName $LastName"
    Write-Output "UPN: $Username@$Domain"
    Write-Output "OU: $OU"
    Write-Output "Email: $Email"
    Write-Output "Département: $Department"
    Write-Output "Titre: $Title"
    Write-Output "=========================================="

} catch {
    Write-Error "ERREUR lors de la création de l'utilisateur: $_"
    exit 1
}
