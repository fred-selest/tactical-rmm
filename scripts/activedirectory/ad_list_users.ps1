# Script: Lister les utilisateurs Active Directory
# Usage dans Tactical RMM: Exécuter sur le contrôleur de domaine
# Paramètres optionnels: OU, Filter, Disabled, Locked

param(
    [string]$OU = "",
    [string]$Filter = "*",
    [switch]$DisabledOnly,
    [switch]$LockedOnly,
    [switch]$ExpiredOnly,
    [int]$InactiveDays = 0
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Construire le filtre
    $ADFilter = "Name -like '$Filter'"

    if ($DisabledOnly) {
        $ADFilter += " -and Enabled -eq `$false"
    }

    # Paramètres de recherche
    $SearchParams = @{
        Filter = $ADFilter
        Properties = @('Enabled', 'LockedOut', 'LastLogonDate', 'PasswordExpired',
                      'PasswordLastSet', 'Created', 'Department', 'Title', 'EmailAddress',
                      'AccountExpirationDate', 'Description')
    }

    if (-not [string]::IsNullOrEmpty($OU)) {
        $SearchParams.SearchBase = $OU
    }

    # Récupérer les utilisateurs
    $Users = Get-ADUser @SearchParams

    # Appliquer les filtres supplémentaires
    if ($LockedOnly) {
        $Users = $Users | Where-Object { $_.LockedOut -eq $true }
    }

    if ($ExpiredOnly) {
        $Users = $Users | Where-Object { $_.PasswordExpired -eq $true }
    }

    if ($InactiveDays -gt 0) {
        $CutoffDate = (Get-Date).AddDays(-$InactiveDays)
        $Users = $Users | Where-Object {
            $_.LastLogonDate -lt $CutoffDate -or $_.LastLogonDate -eq $null
        }
    }

    # Afficher les résultats
    Write-Output "=========================================="
    Write-Output "LISTE DES UTILISATEURS AD"
    Write-Output "=========================================="
    Write-Output "Total: $($Users.Count) utilisateur(s)"
    Write-Output ""

    foreach ($User in $Users | Sort-Object Name) {
        $Status = if ($User.Enabled) { "Actif" } else { "Désactivé" }
        $Locked = if ($User.LockedOut) { " [VERROUILLE]" } else { "" }
        $LastLogon = if ($User.LastLogonDate) { $User.LastLogonDate.ToString("yyyy-MM-dd") } else { "Jamais" }

        Write-Output "-------------------------------------------"
        Write-Output "Nom: $($User.Name)"
        Write-Output "Login: $($User.SamAccountName)"
        Write-Output "Email: $($User.EmailAddress)"
        Write-Output "Département: $($User.Department)"
        Write-Output "Titre: $($User.Title)"
        Write-Output "Statut: $Status$Locked"
        Write-Output "Dernière connexion: $LastLogon"
        Write-Output "Mot de passe défini: $(if($User.PasswordLastSet){$User.PasswordLastSet.ToString('yyyy-MM-dd')}else{'Jamais'})"
    }

    Write-Output ""
    Write-Output "=========================================="

    # Statistiques
    $EnabledCount = ($Users | Where-Object { $_.Enabled }).Count
    $DisabledCount = ($Users | Where-Object { -not $_.Enabled }).Count
    $LockedCount = ($Users | Where-Object { $_.LockedOut }).Count

    Write-Output "STATISTIQUES"
    Write-Output "Actifs: $EnabledCount"
    Write-Output "Désactivés: $DisabledCount"
    Write-Output "Verrouillés: $LockedCount"
    Write-Output "=========================================="

} catch {
    Write-Error "ERREUR lors de la liste des utilisateurs: $_"
    exit 1
}
