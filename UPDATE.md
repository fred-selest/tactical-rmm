# Système de Mise à Jour Tactical RMM

Ce document explique comment maintenir votre installation Tactical RMM à jour avec les dernières fonctionnalités et scripts de surveillance.

## 📦 Scripts de Mise à Jour

### `update-tactical-rmm.sh`
Script principal de mise à jour qui synchronise votre installation avec le dépôt GitHub.

**Usage :**
```bash
sudo ./update-tactical-rmm.sh [options]
```

**Options :**
- `--force` : Forcer la mise à jour même si déjà à jour
- `--scripts-only` : Mettre à jour uniquement les scripts de surveillance
- `--full` : Mise à jour complète (par défaut)
- `--quiet` : Mode silencieux

### `setup-auto-update.sh`
Configure une mise à jour automatique via cron.

**Usage :**
```bash
sudo ./setup-auto-update.sh [options]
```

**Options :**
- `--daily` : Mise à jour quotidienne (par défaut)
- `--weekly` : Mise à jour hebdomadaire  
- `--disable` : Désactiver la mise à jour automatique

## 🔧 Exemples d'Utilisation

### Mise à jour manuelle complète
```bash
cd /home/debian/tactical-rmm
sudo ./update-tactical-rmm.sh
```

### Mise à jour des scripts uniquement
```bash
cd /home/debian/tactical-rmm  
sudo ./update-tactical-rmm.sh --scripts-only
```

### Configuration de la mise à jour automatique quotidienne
```bash
cd /home/debian/tactical-rmm
sudo ./setup-auto-update.sh --daily
```

### Configuration de la mise à jour automatique hebdomadaire
```bash
cd /home/debian/tactical-rmm
sudo ./setup-auto-update.sh --weekly
```

### Désactivation de la mise à jour automatique
```bash
cd /home/debian/tactical-rmm
sudo ./setup-auto-update.sh --disable
```

## 📋 Ce que la mise à jour inclut

### Mise à jour complète (`--full`)
- Synchronisation du dépôt Git
- Mise à jour de l'intégration Linux Deployments
- Importation des nouveaux scripts de surveillance
- Application des nouvelles fonctionnalités

### Mise à jour des scripts uniquement (`--scripts-only`)
- Téléchargement des derniers scripts de surveillance
- Mise à jour dans la base de données Tactical RMM
- Pas de modification de l'intégration existante

## 📝 Fichiers de Log

- **Mise à jour manuelle** : `/var/log/tacticalrmm-update.log`
- **Mise à jour automatique** : `/var/log/tacticalrmm-auto-update.log`

## ⚠️ Précautions

- **Sauvegardes** : L'installation automatisée crée des sauvegardes avant toute modification
- **Modifications locales** : Si vous avez modifié localement des fichiers, utilisez `--force` pour ignorer les avertissements
- **Permissions** : Les scripts doivent être exécutés en tant que root

## 🔄 Processus de Mise à Jour

1. **Vérification** : Le script vérifie s'il y a des nouvelles versions disponibles
2. **Téléchargement** : Récupère les derniers fichiers depuis GitHub
3. **Installation** : Met à jour l'intégration et les scripts
4. **Validation** : Vérifie que tout fonctionne correctement
5. **Notification** : Affiche le résultat de la mise à jour

## 🎯 Avantages

- **Automatisation** : Pas besoin d'intervention manuelle
- **Sécurité** : Toujours à jour avec les dernières corrections de sécurité
- **Nouvelles fonctionnalités** : Accès immédiat aux nouvelles fonctionnalités
- **Scripts de surveillance** : Toujours les dernières versions des scripts de monitoring
- **Flexibilité** : Choix entre mise à jour manuelle ou automatique

## ❓ Dépannage

### Problème : "Modifications locales détectées"
**Solution** : Utilisez l'option `--force` ou sauvegardez vos modifications avant la mise à jour.

### Problème : Scripts non mis à jour dans l'interface
**Solution** : Vérifiez que le service Tactical RMM est actif et réessayez la mise à jour.

### Problème : Erreurs de permission
**Solution** : Assurez-vous d'exécuter les scripts avec `sudo`.

---

Avec ce système de mise à jour, votre installation Tactical RMM restera toujours à jour avec les dernières fonctionnalités et améliorations de la communauté !