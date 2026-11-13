# Scripts Omada pour Tactical RMM

Scripts PowerShell pour surveiller et gérer les équipements TP-Link Omada.

## 🆕 Nouveauté - Support Omada v6

Le script **`omada_check_status_v6.ps1`** supporte les dernières versions d'Omada Controller :

| Version | Authentification | Script recommandé |
|---------|------------------|-------------------|
| **Omada v6.x** | OAuth 2.0 (Client ID/Secret) | `omada_check_status_v6.ps1` |
| **Omada v5.x** | Username/Password | `omada_check_status_v6.ps1` |
| **Omada v4.x** | Username/Password | `omada_check_status.ps1` |

## Scripts disponibles

| Script | Description | Version |
|--------|-------------|---------|
| `omada_check_status_v6.ps1` | 🆕 Surveillance complète (API v6 + v2) | **Recommandé** |
| `omada_check_status.ps1` | Surveillance complète (API v2 legacy) | v4/v5 |
| `omada_list_clients.ps1` | Liste détaillée des clients connectés | v4/v5 |
| `omada_reboot_device.ps1` | Redémarrer un équipement (AP, Switch, Gateway) | v4/v5 |

## Prérequis

- Contrôleur Omada (Software Controller, Hardware Controller ou Cloud)
- Compte administrateur Omada
- Accès réseau au contrôleur depuis l'agent Tactical RMM

## Installation dans Tactical RMM

1. **Settings** > **Script Manager** > **New Script**
2. Nom : `Omada - Surveillance réseau (v6)`
3. Type : **PowerShell**
4. Coller le contenu du script `omada_check_status_v6.ps1`
5. Sauvegarder

---

## 🔐 Configuration API v6 (Recommandé)

### Étape 1 : Créer une application API dans Omada

1. Connectez-vous à votre contrôleur Omada v6
2. Allez dans **Settings** → **Platform Integration** → **Open API**
3. Cliquez sur **Create Application**
4. Remplissez :
   - **Name :** `Tactical RMM`
   - **Description :** `Surveillance réseau`
5. Notez les informations générées :
   - **Client ID**
   - **Client Secret**

### Étape 2 : Paramètres du script

| Paramètre | Description | Exemple |
|-----------|-------------|---------|
| `-OmadaUrl` | URL du contrôleur Omada | `https://192.168.1.100:8043` |
| `-ClientId` | Client ID (créé à l'étape 1) | `abc123...` |
| `-ClientSecret` | Client Secret (créé à l'étape 1) | `xyz789...` |

### Étape 3 : Exemple d'utilisation

```powershell
.\omada_check_status_v6.ps1 `
  -OmadaUrl "https://192.168.1.100:8043" `
  -ClientId "votre_client_id" `
  -ClientSecret "votre_client_secret"
```

---

## 🔑 Configuration API v2 (Legacy - Omada v4/v5)

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

### Exemple d'utilisation

```powershell
.\omada_check_status_v6.ps1 `
  -OmadaUrl "https://192.168.1.100:8043" `
  -Username "admin" `
  -Password "password"
```

## Automatisation recommandée

### Surveillance périodique

1. **Automation** > **Checks** > **Add Check**
2. Script : Omada - Surveillance réseau (v6)
3. Arguments : `-OmadaUrl "https://..." -ClientId "..." -ClientSecret "..."`
4. Schedule : Toutes les 15 minutes
5. Condition : Code de sortie ≠ 0
6. Alerte : Email

### Tâche planifiée

1. **Automation** > **Tasks** > **Add Task**
2. Script : Omada - Surveillance réseau (v6)
3. Schedule : Toutes les heures
4. Action : Email avec rapport

## Sécurité

### Stockage des identifiants

**API v6 (Recommandé) :**
- Les tokens OAuth 2.0 expirent automatiquement
- Utiliser les **Script Arguments** de Tactical RMM
- Créer des variables globales :
  - `omada_url` = `https://192.168.1.100:8043`
  - `omada_client_id` = `xxx`
  - `omada_client_secret` = `xxx`

**API v2 (Legacy) :**
- Créer une variable globale : `{{global.omada_password}}`
- Utiliser un compte dédié avec droits en lecture seule

### Certificats SSL

Les scripts acceptent les certificats auto-signés (courant pour les contrôleurs locaux).

### Compte dédié

Créez un compte Omada dédié à la surveillance avec droits en lecture seule si possible.

## Compatibilité

| Version Omada | Authentification | Supportée |
|---------------|------------------|-----------|
| Omada Controller 6.x | OAuth 2.0 | ✅ |
| Omada Controller 5.x | Username/Password | ✅ |
| Omada Controller 4.x | Username/Password | ✅ |
| Omada Cloud | OAuth 2.0 | ✅ |
| OC200/OC300 | Username/Password | ✅ |

## Exemple de sortie

### Surveillance réseau

```
==========================================
SURVEILLANCE OMADA CONTROLLER v6
Contrôleur: https://192.168.1.100:8043
Date: 2026-04-02 15:30:00
==========================================

--- Authentification API v6 (OAuth 2.0) ---
[OK] Connexion API v6 réussie
Token expires in: 7200 secondes
Version API: v6

--- INFORMATIONS CONTROLEUR ---
Version: 6.1.0
Modèle: Omada Software Controller
Uptime: 125.3 heures
CPU: 8%
Mémoire: 32%

--- SITES ---
Default: 42 clients

--- EQUIPEMENTS ---

Points d'accès:
[OK] AP-Bureau - EAP610
   IP: 192.168.1.10 | MAC: AA-BB-CC-DD-EE-FF
   Clients: 18 | Canal: 6
   CPU: 12% | Mémoire: 28%

[OK] AP-Entrepot - EAP660 HD
   IP: 192.168.1.11 | MAC: AA-BB-CC-DD-EE-00
   Clients: 24 | Canal: 11
   CPU: 15% | Mémoire: 35%

Switches:
[OK] Switch-Principal - S3400-24T4X
   IP: 192.168.1.2 | MAC: AA-BB-CC-DD-EE-11
   Ports: 24

Gateways:
[OK] Gateway-Principal - ER7212PC
   IP: 192.168.1.1 | MAC: AA-BB-CC-DD-EE-22
   CPU: 5% | Mémoire: 42%

Résumé équipements: 4/4 en ligne

--- CLIENTS CONNECTES ---
Total: 42
WiFi: 35
Filaire: 7

Top 5 clients (trafic):
  PC-Compta - 512.8 MB (Filaire)
  iPhone-Sarah - 245.2 MB (WiFi)
  ...

--- RESEAUX WIFI (SSID) ---
[Actif] Entreprise
   Sécurité: WPA3 | VLAN: 10
[Actif] Invites
   Sécurité: WPA2 | VLAN: 20
[Désactivé] Test

--- ALERTES ---
[OK] Aucune alerte

==========================================
RESUME
==========================================
[OK] Tous les équipements sont en ligne (4/4)
Clients connectés: 42
==========================================
```

## Dépannage

### Erreur de connexion API v6

1. Vérifier que l'application API est créée dans Omada v6
2. Vérifier le Client ID et Client Secret
3. Vérifier l'URL du contrôleur (inclure le port)
4. Tester l'accès depuis le serveur : `Test-NetConnection -ComputerName IP -Port 8043`

### Erreur de connexion API v2

1. Vérifier l'URL du contrôleur
2. Vérifier les identifiants username/password
3. Tester la connectivité réseau

### Équipements non listés

- Vérifier que les équipements sont adoptés dans le contrôleur
- Vérifier le site sélectionné
- Vérifier que les équipements sont en ligne (status = 14)

### Certificat SSL

Les scripts ignorent automatiquement les erreurs de certificat.

## API Omada

### API v6 (OAuth 2.0)
- **Token :** `/api/v2/oauth/token`
- **Devices :** `/api/v6/sites/{siteId}/eaps`, `/api/v6/sites/{siteId}/switches`, `/api/v6/sites/{siteId}/gateways`
- **Clients :** `/api/v6/sites/{siteId}/clients`
- **Alerts :** `/api/v6/sites/{siteId}/alerts`

### API v2 (Legacy)
- **Login :** `/api/v2/login`
- **Devices :** `/api/v2/sites/{siteId}/eaps`, `/api/v2/sites/{siteId}/switches`, `/api/v2/sites/{siteId}/gateways`
- **Clients :** `/api/v2/sites/{siteId}/clients`
- **Alerts :** `/api/v2/sites/{siteId}/alerts`

Documentation complète dans le contrôleur : `https://votre-controleur/swagger`

## Ressources

- [TP-Link Omada](https://www.tp-link.com/fr/omada-sdn/)
- [Documentation API v6](https://support.omadanetworks.com/en/document/109315/)
- [Guide de mise à jour v6](https://support.omadanetworks.com/en/document/109470/)
