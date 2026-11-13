# Tactical RMM - Guide de Développement pour Agents

Ce document fournit des informations essentielles pour les agents de codage IA travaillant dans le dépôt Tactical RMM. La base de code est principalement constituée de **scripts bash/shell** pour le déploiement et la surveillance des agents Linux, avec des composants **Python/Django** pour le backend serveur.

## Structure du Projet

```
tactical-rmm/
├── scripts/                    # Scripts de surveillance pour différentes plateformes
│   ├── plesk/                 # Scripts de surveillance serveur Plesk
│   ├── synology/             # Scripts de surveillance NAS Synology  
│   ├── windows/              # Scripts de surveillance Windows
│   ├── activedirectory/      # Surveillance Active Directory
│   ├── eset/                 # Surveillance antivirus ESET
│   ├── omada/                # Surveillance TP-Link Omada
│   ├── veeam/                # Surveillance sauvegarde Veeam
│   └── README.md            # Documentation des scripts
├── rmmagent-synology/        # Agent modifié pour Synology NAS
├── integration/              # Composants d'intégration
├── *.sh                      # Scripts principaux d'installation et utilitaires
└── *.md                      # Fichiers de documentation (français/anglais)
```

## Commandes de Build

### Aucun Système de Build Traditionnel
Ce dépôt n'utilise pas de systèmes de build traditionnels comme npm, pip ou make. Les scripts sont exécutables tels quels.

### Scripts d'Installation
- `./install-interactive-private.sh` - Installation interactive privée
- `./test-installation-private.sh` - Exécute les tests d'installation complets
- `./rmmagent-linux-ameliore.sh` - Installateur d'agent Linux amélioré

### Backend Serveur (Python/Django)
Les composants serveur sont situés dans `/rmm/api/tacticalrmm` ou `/opt/tacticalrmm/api/tacticalrmm` :

```bash
# Commandes de gestion Django
cd /opt/tacticalrmm/api/tacticalrmm
sudo -u tactical ./env/bin/python manage.py check
sudo -u tactical ./env/bin/python manage.py showmigrations linux_deployments
sudo -u tactical ./env/bin/python manage.py migrate
```

## Commandes de Test

### Exécution de Tous les Tests
```bash
# Exécute la suite de tests complète
./test-installation-private.sh
```

### Exécution de Tests Individuels
Comme il s'agit principalement d'un projet bash, le test des scripts individuels implique une exécution directe :

```bash
# Tester un script de surveillance spécifique
chmod +x scripts/plesk/plesk_check_disk.sh
./scripts/plesk/plesk_check_disk.sh

# Tester la validité syntaxique des fichiers Python
python -m py_compile chemin/vers/fichier.py

# Tester les imports de modèles Django
cd /opt/tacticalrmm/api/tacticalrmm
sudo -u tactical python -c "from linux_deployments.models import LinuxDeployment"
```

### Approche de Test Manuel
1. Exécuter les scripts directement avec les permissions appropriées
2. Vérifier les codes de sortie (0 = succès, non-nul = échec)
3. Vérifier le formatage de la sortie et les messages d'erreur
4. Valider les entrées de log dans `/var/log/tacticalrmm-install.log`

## Directives de Style de Code

### Scripts Bash/Shell

#### En-têtes de Fichier
Inclure toujours des en-têtes descriptifs :
```bash
#!/bin/bash
# Brève description du but du script
# Instructions d'utilisation si applicable
```

#### Variables
- Utiliser MAJUSCULES pour les constantes globales : `SEUIL=80`, `LOG_FILE="/var/log/..."`
- Utiliser minuscules pour les variables locales : `utilisation`, `missing`
- Préfixer les variables temporaires avec le contexte : `TMPDIR`, `agent_path`

#### Fonctions
- Utiliser des noms descriptifs avec underscores : `check_dependencies()`, `install_agent_synology()`
- Regrouper les fonctions liées sous des sections commentées : `# === FONCTIONS UTILITAIRES ===`
- Toujours inclure la gestion des erreurs et la journalisation

#### Gestion des Erreurs
- Utiliser des codes de sortie explicites : `exit 1` pour les erreurs, `exit 0` pour le succès
- Journaliser toutes les erreurs dans le fichier de log standard : `/var/log/tacticalrmm-install.log`
- Utiliser `set -e` avec précaution (souvent désactivé pour la gestion manuelle des erreurs)
- Toujours implémenter des traps de nettoyage : `trap cleanup EXIT`

#### Journalisation
- Utiliser une fonction de journalisation cohérente : `log "Message"`
- Inclure des timestamps : `[$(date '+%Y-%m-%d %H:%M:%S')]`
- Journaliser à la fois sur la console et dans le fichier en utilisant `tee -a "$LOG_FILE"`

#### Commentaires
- Écrire les commentaires en français pour la logique spécifique au français
- Utiliser l'anglais pour les commentaires techniques généraux
- Inclure des séparateurs de section : `# === NOM DE SECTION ===`
- Documenter la logique complexe et les cas particuliers

#### Formatage
- Utiliser une indentation de 4 espaces de manière cohérente
- Garder les lignes sous 80 caractères quand c'est possible
- Utiliser un espacement cohérent autour des opérateurs
- Regrouper les commandes liées avec des lignes vides

### Composants Python/Django

#### Imports
- Suivre les conventions Django pour les imports
- Regrouper les imports : bibliothèque standard, Django, tierces parties, locaux
- Utiliser des imports absolus dans le projet

#### Conventions de Nommage
- Classes : `PascalCase` (ex: `LinuxDeployment`)
- Fonctions/variables : `snake_case` (ex: `get_deployment_status`)
- Constantes : `MAJUSCULES_SNAKE_CASE` (ex: `MAX_RETRY_ATTEMPTS`)

#### Gestion des Erreurs
- Utiliser la hiérarchie d'exceptions de Django
- Journaliser les erreurs de manière appropriée avec le contexte
- Retourner des codes de statut HTTP significatifs dans les vues

#### Spécificités Django
- Suivre les bonnes pratiques des modèles Django
- Utiliser des sérialiseurs pour la transformation des données API
- Implémenter une authentification et des permissions appropriées
- Écrire des migrations pour les changements de base de données

## Langue et Localisation

### Support Bilingue
- Langue principale : **Français** (pour les messages utilisateur)
- Langue secondaire : **Anglais** (pour la documentation technique)
- Utiliser la détection de langue : `[ "$LANG" = "fr_FR" ] && echo "Français" || echo "English"`

### Fonctions de Messages
Implémenter des fonctions de messages bilingues :
```bash
function msg() {
    case $1 in
        install_start)
            [ "$LANG" = "fr_FR" ] && echo "Début de l'installation..." || echo "Starting installation..."
            ;;
    esac
}
```

## Bonnes Pratiques de Sécurité

### Gestion des Privilèges
- Toujours vérifier les privilèges root : fonction `check_root()`
- Réduire les privilèges quand c'est possible pour des opérations spécifiques
- Utiliser `sudo -u tactical` pour les opérations Django

### Validation des Entrées
- Valider tous les arguments des scripts
- Assainir les entrées utilisateur avant utilisation
- Vérifier l'existence et les permissions des fichiers avant les opérations

### Fichiers Temporaires
- Créer des répertoires temporaires avec des noms uniques : `TMPDIR="/tmp/tacticalrmm-$$"`
- Toujours nettoyer les fichiers temporaires dans les traps de sortie
- Définir les permissions appropriées sur les fichiers temporaires

### Opérations Réseau
- Utiliser HTTPS pour tous les téléchargements
- Valider les certificats SSL
- Implémenter des timeouts de téléchargement : `--timeout=60`

## Normes de Documentation

### Fichiers README
- Maintenir des versions française et anglaise quand c'est possible
- Utiliser des formats de tableaux cohérents pour la documentation
- Inclure des exemples clairs d'installation et d'utilisation

### Documentation Inline
- Documenter toutes les fonctions publiques avec des exemples d'utilisation
- Expliquer la logique complexe et les cas particuliers
- Inclure les informations de version dans les en-têtes

### Formatage Markdown
- Utiliser des niveaux de titres cohérents
- Formater les blocs de code avec la spécification appropriée du langage
- Utiliser des tableaux pour la présentation d'informations structurées

## Considérations Spécifiques à la Plateforme

### Synology DSM
- Détecter Synology via `/etc/synoinfo.conf`
- Gérer les différences de version DSM
- Utiliser les chemins appropriés : `/volume1/@appstore/tactical-rmm`
- Tenir compte du support systemd limité sur les anciennes versions DSM

### Linux Standard
- Supporter plusieurs gestionnaires de paquets : apt, yum, dnf, opkg, apk
- Gérer différents systèmes d'init (systemd vs autres)
- Tenir compte des différentes organisations de système de fichiers

### Support d'Architecture
- Supporter les architectures x86_64, i386, aarch64, armv6l
- Télécharger les binaires Go appropriés pour la compilation
- Gérer les dépendances spécifiques à l'architecture

## Attentes en Matière de Tests

### Couverture de Test Attendue
- Tous les scripts d'installation doivent gérer gracieusement les conditions d'erreur
- Les scripts de surveillance doivent retourner des codes de sortie appropriés
- Les composants Python doivent passer la commande `manage.py check` de Django
- Les migrations de base de données doivent être correctement versionnées

### Exigences de Validation
- Les scripts doivent fonctionner sur des installations propres
- Gérer automatiquement les dépendances manquantes
- Fournir des messages d'erreur clairs pour le dépannage
- Maintenir la compatibilité ascendante quand c'est possible

## Modèles Courants à Suivre

### Structure des Scripts
1. En-tête avec description et version
2. Définition des variables globales
3. Définition des fonctions utilitaires
4. Logique d'exécution principale avec analyse des arguments
5. Gestion du nettoyage et de la sortie

### Récupération d'Erreurs
- Implémenter des mécanismes de retour arrière pour les installations échouées
- Fournir des fonctionnalités de sauvegarde/restauration
- Permettre une nouvelle tentative sécurisée des opérations échouées

### Expérience Utilisateur
- Fournir des indicateurs de progression clairs
- Utiliser un codage de couleurs cohérent (vert=succès, rouge=erreur, jaune=avertissement)
- Offrir des étapes suivantes utiles après l'achèvement

## Variables d'Environnement

Variables d'environnement clés utilisées dans toute la base de code :
- `TACTICAL_LANG` : Préférence de langue (`fr_FR` ou `en_US`)
- `EUID` : ID utilisateur effectif pour la vérification des privilèges
- `ARCH` : Architecture système détectée
- `OS_TYPE` : Type de système d'exploitation (`synology`, `ubuntu`, `centos`, etc.)

## Gestion des Dépendances

### Résolution Automatique des Dépendances
Les scripts doivent détecter et installer automatiquement les dépendances manquantes :
- Identifier le gestionnaire de paquets (apt, yum, dnf, opkg, apk)
- Installer les paquets requis silencieusement
- Gérer gracieusement les conflits de dépendances

### Installation de Go
- Télécharger la version appropriée de Go pour l'architecture cible
- Installer temporairement si non présent au niveau système
- Nettoyer l'installation de Go après compilation si installé par le script

Ce guide garantit un code cohérent, maintenable et sécurisé dans tout l'écosystème Tactical RMM. Toujours privilégier la robustesse, la gestion claire des erreurs et des messages conviviaux dans toutes les implémentations.