# Scripts Omada pour Tactical RMM

Scripts PowerShell pour surveiller et gérer les équipements TP-Link Omada.

## Scripts disponibles

| Script | Description |
|--------|-------------|
| `omada_check_status.ps1` | Surveillance complète du réseau Omada |
| `omada_list_clients.ps1` | Liste détaillée des clients connectés |
| `omada_reboot_device.ps1` | Redémarrer un équipement (AP, Switch, Gateway) |

## Prérequis

- Contrôleur Omada (Software Controller, Hardware Controller ou Cloud)
- Compte administrateur Omada
- Accès réseau au contrôleur depuis l'agent Tactical RMM

## Installation dans Tactical RMM

1. **Settings** > **Script Manager** > **New Script**
2. Nom : `Omada - Surveillance réseau`
3. Type : **PowerShell**
4. Coller le contenu du script
5. Sauvegarder

## Configuration

### Paramètres requis

| Paramètre | Description | Exemple |
|-----------|-------------|---------|
| `-OmadaUrl` | URL du contrôleur Omada | `https://omada.domaine.com` |
| `-Username` | Utilisateur administrateur | `admin` |
| `-Password` | Mot de passe | `MotDePasse123` |

### Paramètres optionnels

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| `-SiteId` | Nom ou ID du site | `Default` |

## Utilisation

### Surveillance du réseau

```powershell
.\omada_check_status.ps1 -OmadaUrl "https://192.168.1.100:8043" -Username "admin" -Password "password"
```

**Vérifie :**
- État du contrôleur (version, CPU, mémoire)
- Équipements (APs, Switches, Gateways)
- Clients connectés (WiFi et filaire)
- Réseaux WiFi (SSID)
- Alertes actives

### Liste des clients

```powershell
# Tous les clients
.\omada_list_clients.ps1 -OmadaUrl "https://omada.domaine.com" -Username "admin" -Password "password"

# Clients WiFi uniquement
.\omada_list_clients.ps1 ... -WifiOnly

# Clients filaires uniquement
.\omada_list_clients.ps1 ... -WiredOnly
```

### Redémarrer un équipement

```powershell
# Redémarrer un point d'accès
.\omada_reboot_device.ps1 -OmadaUrl "https://omada.domaine.com" -Username "admin" -Password "password" -DeviceMac "AA-BB-CC-DD-EE-FF" -DeviceType "ap"

# Redémarrer un switch
.\omada_reboot_device.ps1 ... -DeviceMac "AA-BB-CC-DD-EE-FF" -DeviceType "switch"

# Redémarrer une gateway
.\omada_reboot_device.ps1 ... -DeviceMac "AA-BB-CC-DD-EE-FF" -DeviceType "gateway"
```

## Automatisation recommandée

### Surveillance périodique

1. **Automation** > **Checks** > **Add Check**
2. Script : Omada - Surveillance réseau
3. Arguments : `-OmadaUrl "https://..." -Username "admin" -Password "..."`
4. Schedule : Toutes les 15 minutes
5. Condition : Code de sortie ≠ 0
6. Alerte : Email

### Tâche planifiée

1. **Automation** > **Tasks** > **Add Task**
2. Script : Omada - Surveillance réseau
3. Schedule : Toutes les heures
4. Action : Email avec rapport

## Sécurité

### Stockage des identifiants

Pour éviter d'exposer les mots de passe, utilisez les **Script Arguments** de Tactical RMM :

1. Créer une variable globale dans Tactical RMM
2. Référencer avec `{{global.omada_password}}`

### Certificats SSL

Les scripts acceptent les certificats auto-signés (courant pour les contrôleurs locaux).

### Compte dédié

Créez un compte Omada dédié à la surveillance avec droits en lecture seule si possible.

## Compatibilité

| Version Omada | Supportée |
|---------------|-----------|
| Omada Controller 5.x | ✅ |
| Omada Controller 4.x | ✅ |
| Omada Cloud | ✅ |
| OC200/OC300 | ✅ |

## Exemple de sortie

### Surveillance réseau

```
==========================================
SURVEILLANCE OMADA CONTROLLER
Contrôleur: https://192.168.1.100:8043
==========================================

--- INFORMATIONS CONTROLEUR ---
Version: 5.9.31
Modèle: Omada Software Controller
Uptime: 45.2 heures
CPU: 12%
Mémoire: 45%

--- SITES ---
Default: 25 clients

--- EQUIPEMENTS ---

Points d'accès:
[OK] AP-Bureau - EAP245
   IP: 192.168.1.10 | Clients: 12 | Canal: 6
   CPU: 15% | Mémoire: 32%

[OK] AP-Entrepot - EAP225
   IP: 192.168.1.11 | Clients: 8 | Canal: 11
   CPU: 10% | Mémoire: 28%

Switches:
[OK] Switch-Principal - TL-SG2428P
   IP: 192.168.1.2 | Ports: 28

--- CLIENTS CONNECTES ---
Total: 25
WiFi: 20
Filaire: 5

Top 5 clients (trafic):
  PC-Compta - 245.5 MB
  Serveur-NAS - 180.2 MB
  ...

--- ALERTES ---
[OK] Aucune alerte

==========================================
RESUME
==========================================
[OK] Tous les équipements sont en ligne
Clients connectés: 25
==========================================
```

## Dépannage

### Erreur de connexion

1. Vérifier l'URL du contrôleur (inclure le port si nécessaire)
2. Vérifier les identifiants
3. Tester l'accès depuis le serveur : `Test-NetConnection -ComputerName IP -Port 8043`

### Équipements non listés

- Vérifier que les équipements sont adoptés dans le contrôleur
- Vérifier le site sélectionné

### Certificat SSL

Les scripts ignorent automatiquement les erreurs de certificat. Si problème persistant :

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

## API Omada

Les scripts utilisent l'API REST Omada v2. Documentation disponible dans le contrôleur :
`https://votre-controleur/swagger`

## Ressources

- [TP-Link Omada](https://www.tp-link.com/fr/omada-sdn/)
- [Documentation API](https://www.tp-link.com/us/support/faq/3231/)
