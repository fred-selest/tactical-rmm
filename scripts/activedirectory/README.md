# Scripts Active Directory pour Tactical RMM

Scripts PowerShell pour gérer Active Directory depuis Tactical RMM.

## Prérequis

- Agent Tactical RMM installé sur le **contrôleur de domaine**
- Module PowerShell `ActiveDirectory` (installé par défaut sur les DC)
- Droits administrateur AD pour l'agent

## Scripts disponibles

| Script | Description |
|--------|-------------|
| `ad_create_user.ps1` | Créer un nouvel utilisateur |
| `ad_disable_user.ps1` | Désactiver un compte |
| `ad_reset_password.ps1` | Réinitialiser un mot de passe |
| `ad_unlock_account.ps1` | Déverrouiller un compte |
| `ad_delete_user.ps1` | Supprimer un utilisateur |
| `ad_list_users.ps1` | Lister les utilisateurs |
| `ad_add_to_group.ps1` | Ajouter à un groupe |
| `ad_create_group.ps1` | Créer un groupe |
| `ad_inventory.ps1` | Inventaire complet AD |

## Installation dans Tactical RMM

### Méthode 1: Script Manager

1. **Settings** > **Script Manager** > **New Script**
2. Nom: ex. "AD - Créer utilisateur"
3. Type: **PowerShell**
4. Coller le contenu du script
5. Sauvegarder

### Méthode 2: Téléchargement direct

```powershell
# Sur le contrôleur de domaine
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/activedirectory/ad_create_user.ps1" -OutFile "C:\Scripts\ad_create_user.ps1"
```

## Utilisation des scripts

### Créer un utilisateur

```powershell
# Paramètres requis
-Username "jdupont"
-FirstName "Jean"
-LastName "Dupont"
-Password "MotDePasse123!"

# Paramètres optionnels
-OU "OU=Utilisateurs,DC=domaine,DC=local"
-Email "jdupont@domaine.com"
-Department "Informatique"
-Title "Technicien"
-Manager "mmartin"
-Groups "IT-Support,VPN-Users"
```

**Depuis Tactical RMM:**
1. Sélectionner l'agent du DC
2. **Run Script** > Choisir "AD - Créer utilisateur"
3. Arguments: `-Username jdupont -FirstName Jean -LastName Dupont -Password "MotDePasse123!"`

### Désactiver un utilisateur

```powershell
-Username "jdupont"

# Optionnel: déplacer vers OU des désactivés
-MoveToDisabledOU
-DisabledOU "OU=Désactivés,DC=domaine,DC=local"
```

### Réinitialiser un mot de passe

```powershell
-Username "jdupont"
-NewPassword "NouveauMdP456!"

# Options
-MustChangePassword $true   # Forcer changement au login
-UnlockAccount $true        # Déverrouiller le compte
```

### Déverrouiller un compte

```powershell
-Username "jdupont"
```

### Supprimer un utilisateur

```powershell
# Prévisualisation (sans suppression)
-Username "jdupont"

# Suppression effective
-Username "jdupont" -Confirm
```

### Lister les utilisateurs

```powershell
# Tous les utilisateurs
(aucun paramètre)

# Filtrer par OU
-OU "OU=Paris,DC=domaine,DC=local"

# Filtrer par nom
-Filter "*dupont*"

# Uniquement désactivés
-DisabledOnly

# Uniquement verrouillés
-LockedOnly

# Inactifs depuis X jours
-InactiveDays 90
```

### Ajouter à un groupe

```powershell
-Username "jdupont"
-GroupName "VPN-Users"
```

### Créer un groupe

```powershell
-GroupName "Projet-Alpha"
-Description "Équipe projet Alpha"
-GroupScope "Global"           # Global, DomainLocal, Universal
-GroupCategory "Security"      # Security, Distribution
-Members "jdupont,mmartin"     # Membres initiaux
```

### Inventaire AD

Aucun paramètre requis. Génère un rapport complet avec:
- Informations domaine/forêt
- Contrôleurs de domaine
- Statistiques utilisateurs
- Statistiques ordinateurs
- Statistiques groupes
- Liste des OUs
- Comptes verrouillés
- Mots de passe expirés

## Exemples d'automatisation

### Tâche planifiée: Rapport hebdomadaire

1. **Automation** > **Tasks** > **Add Task**
2. Script: "AD - Inventaire"
3. Schedule: Chaque lundi à 8h
4. Action sur résultat: Email au support

### Alerte: Comptes verrouillés

1. **Automation** > **Checks** > **Add Check**
2. Type: Script Check
3. Script: "AD - Lister utilisateurs"
4. Arguments: `-LockedOnly`
5. Condition: Si sortie contient "VERROUILLE"
6. Action: Alerte + Email

### Workflow: Onboarding employé

Créer un script combiné:

```powershell
param(
    [string]$Username,
    [string]$FirstName,
    [string]$LastName,
    [string]$Department
)

# 1. Créer l'utilisateur
.\ad_create_user.ps1 -Username $Username -FirstName $FirstName -LastName $LastName -Password "Welcome123!" -Department $Department

# 2. Ajouter aux groupes standards
.\ad_add_to_group.ps1 -Username $Username -GroupName "Domain Users"
.\ad_add_to_group.ps1 -Username $Username -GroupName "VPN-Users"

# 3. Ajouter au groupe du département
.\ad_add_to_group.ps1 -Username $Username -GroupName "$Department-Users"
```

## Sécurité

### Bonnes pratiques

1. **Limiter les accès** - Seuls les admins peuvent exécuter ces scripts
2. **Auditer** - Activer les logs dans Tactical RMM
3. **Mots de passe** - Ne jamais stocker en clair dans les scripts
4. **Principe du moindre privilège** - L'agent doit avoir uniquement les droits nécessaires

### Permissions requises

L'agent Tactical RMM doit fonctionner avec un compte ayant:
- Droits de création/modification d'utilisateurs
- Droits de gestion des groupes
- Accès aux OUs cibles

### Configuration du service agent

```powershell
# Configurer le service pour utiliser un compte AD dédié
sc.exe config "tacticalagent" obj= "DOMAINE\svc-tactical" password= "MotDePasse"
```

## Dépannage

### Erreur: Module ActiveDirectory non trouvé

```powershell
# Installer les outils RSAT (sur serveur)
Install-WindowsFeature RSAT-AD-PowerShell

# Ou sur Windows 10/11
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

### Erreur: Accès refusé

- Vérifier que le service agent tourne avec un compte ayant les droits AD
- Vérifier les délégations sur les OUs

### Erreur: Utilisateur non trouvé

- Vérifier l'orthographe du SamAccountName
- Vérifier que l'utilisateur existe: `Get-ADUser -Identity username`

## Ressources

- [Documentation Tactical RMM](https://docs.tacticalrmm.com/)
- [Cmdlets Active Directory](https://docs.microsoft.com/en-us/powershell/module/activedirectory/)
- [Bonnes pratiques AD](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/)
