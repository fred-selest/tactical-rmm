# Script: Inventaire complet Active Directory
# Usage dans Tactical RMM: Exécuter sur le contrôleur de domaine
# Génère un rapport complet de l'état de l'AD

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    $Domain = Get-ADDomain
    $Forest = Get-ADForest

    Write-Output "=========================================="
    Write-Output "INVENTAIRE ACTIVE DIRECTORY"
    Write-Output "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "=========================================="
    Write-Output ""

    # Informations du domaine
    Write-Output "--- INFORMATIONS DOMAINE ---"
    Write-Output "Domaine: $($Domain.DNSRoot)"
    Write-Output "NetBIOS: $($Domain.NetBIOSName)"
    Write-Output "Forêt: $($Forest.Name)"
    Write-Output "Niveau fonctionnel domaine: $($Domain.DomainMode)"
    Write-Output "Niveau fonctionnel forêt: $($Forest.ForestMode)"
    Write-Output ""

    # Contrôleurs de domaine
    Write-Output "--- CONTROLEURS DE DOMAINE ---"
    $DCs = Get-ADDomainController -Filter *
    foreach ($DC in $DCs) {
        $Status = if (Test-Connection -ComputerName $DC.HostName -Count 1 -Quiet) { "En ligne" } else { "Hors ligne" }
        Write-Output "$($DC.Name) - $($DC.IPv4Address) - $Status"
        Write-Output "  Rôles FSMO: $($DC.OperationMasterRoles -join ', ')"
    }
    Write-Output ""

    # Statistiques utilisateurs
    Write-Output "--- STATISTIQUES UTILISATEURS ---"
    $AllUsers = Get-ADUser -Filter * -Properties Enabled, LockedOut, PasswordExpired, LastLogonDate

    $TotalUsers = $AllUsers.Count
    $EnabledUsers = ($AllUsers | Where-Object { $_.Enabled }).Count
    $DisabledUsers = ($AllUsers | Where-Object { -not $_.Enabled }).Count
    $LockedUsers = ($AllUsers | Where-Object { $_.LockedOut }).Count
    $ExpiredPwd = ($AllUsers | Where-Object { $_.PasswordExpired }).Count

    # Utilisateurs inactifs (90 jours)
    $InactiveDate = (Get-Date).AddDays(-90)
    $InactiveUsers = ($AllUsers | Where-Object {
        $_.LastLogonDate -lt $InactiveDate -or $_.LastLogonDate -eq $null
    }).Count

    Write-Output "Total utilisateurs: $TotalUsers"
    Write-Output "Actifs: $EnabledUsers"
    Write-Output "Désactivés: $DisabledUsers"
    Write-Output "Verrouillés: $LockedUsers"
    Write-Output "Mot de passe expiré: $ExpiredPwd"
    Write-Output "Inactifs (90+ jours): $InactiveUsers"
    Write-Output ""

    # Statistiques ordinateurs
    Write-Output "--- STATISTIQUES ORDINATEURS ---"
    $AllComputers = Get-ADComputer -Filter * -Properties Enabled, LastLogonDate, OperatingSystem

    $TotalComputers = $AllComputers.Count
    $EnabledComputers = ($AllComputers | Where-Object { $_.Enabled }).Count
    $Servers = ($AllComputers | Where-Object { $_.OperatingSystem -like "*Server*" }).Count
    $Workstations = $TotalComputers - $Servers

    Write-Output "Total ordinateurs: $TotalComputers"
    Write-Output "Actifs: $EnabledComputers"
    Write-Output "Serveurs: $Servers"
    Write-Output "Postes de travail: $Workstations"
    Write-Output ""

    # Statistiques groupes
    Write-Output "--- STATISTIQUES GROUPES ---"
    $AllGroups = Get-ADGroup -Filter *
    $SecurityGroups = ($AllGroups | Where-Object { $_.GroupCategory -eq 'Security' }).Count
    $DistributionGroups = ($AllGroups | Where-Object { $_.GroupCategory -eq 'Distribution' }).Count

    Write-Output "Total groupes: $($AllGroups.Count)"
    Write-Output "Groupes de sécurité: $SecurityGroups"
    Write-Output "Groupes de distribution: $DistributionGroups"
    Write-Output ""

    # Unités d'organisation
    Write-Output "--- UNITES D'ORGANISATION ---"
    $OUs = Get-ADOrganizationalUnit -Filter * | Sort-Object DistinguishedName
    Write-Output "Total OUs: $($OUs.Count)"
    foreach ($OU in $OUs | Select-Object -First 20) {
        Write-Output "  $($OU.Name)"
    }
    if ($OUs.Count -gt 20) {
        Write-Output "  ... et $($OUs.Count - 20) autres"
    }
    Write-Output ""

    # Utilisateurs verrouillés (détail)
    if ($LockedUsers -gt 0) {
        Write-Output "--- UTILISATEURS VERROUILLES ---"
        $LockedList = $AllUsers | Where-Object { $_.LockedOut }
        foreach ($User in $LockedList) {
            Write-Output "  $($User.SamAccountName) - $($User.Name)"
        }
        Write-Output ""
    }

    # Mots de passe expirés (détail)
    if ($ExpiredPwd -gt 0) {
        Write-Output "--- MOTS DE PASSE EXPIRES ---"
        $ExpiredList = $AllUsers | Where-Object { $_.PasswordExpired } | Select-Object -First 10
        foreach ($User in $ExpiredList) {
            Write-Output "  $($User.SamAccountName) - $($User.Name)"
        }
        if ($ExpiredPwd -gt 10) {
            Write-Output "  ... et $($ExpiredPwd - 10) autres"
        }
        Write-Output ""
    }

    Write-Output "=========================================="
    Write-Output "FIN DE L'INVENTAIRE"
    Write-Output "=========================================="

} catch {
    Write-Error "ERREUR lors de l'inventaire: $_"
    exit 1
}
