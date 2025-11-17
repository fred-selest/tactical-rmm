# Scripts de surveillance Plesk pour Tactical RMM

Scripts Bash pour surveiller un serveur Plesk via Tactical RMM.

## Scripts disponibles

| Script | Description |
|--------|-------------|
| `plesk_check_all.sh` | Exécute toutes les vérifications |
| `plesk_check_services.sh` | État des services (Apache, MySQL, etc.) |
| `plesk_check_disk.sh` | Espace disque par abonnement |
| `plesk_check_ssl.sh` | Expiration des certificats SSL |
| `plesk_check_mail.sh` | File d'attente email |
| `plesk_check_backup.sh` | État des sauvegardes |
| `plesk_check_security.sh` | Fail2ban, tentatives connexion |

## Installation dans Tactical RMM

### Méthode 1 : Script individuel

1. Dans Tactical RMM → **Settings** → **Script Manager**
2. Cliquez sur **New**
3. Nom : `Plesk - Vérification SSL` (par exemple)
4. Type : `Shell`
5. Collez le contenu du script
6. Enregistrez

### Méthode 2 : Télécharger tous les scripts

Sur le serveur Plesk :

```bash
mkdir -p /opt/tacticalrmm/scripts
cd /opt/tacticalrmm/scripts
wget https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/plesk_check_all.sh
wget https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/plesk_check_services.sh
wget https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/plesk_check_disk.sh
wget https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/plesk_check_ssl.sh
wget https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/plesk_check_mail.sh
wget https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/plesk_check_backup.sh
wget https://raw.githubusercontent.com/fred-selest/tactical-rmm/main/scripts/plesk_check_security.sh
chmod +x *.sh
```

## Configuration des alertes

### Créer une tâche automatisée

1. Dans Tactical RMM → Sélectionnez l'agent Plesk
2. **Tasks** → **Add Task**
3. Configurez :
   - Nom : `Surveillance Plesk`
   - Type : `Script`
   - Script : Sélectionnez votre script
   - Planification : Toutes les heures (ou selon besoin)

### Configurer les alertes

1. **Settings** → **Automation Manager**
2. **Policies** → Créez une nouvelle politique
3. Ajoutez une condition sur le code de retour du script
4. Si code ≠ 0 → Envoyer une alerte

## Codes de retour

- `0` : Tout est OK
- `1` : Alerte détectée (vérifiez la sortie)

## Personnalisation

### Modifier les seuils

Dans chaque script, modifiez les variables en haut :

```bash
# plesk_check_ssl.sh
JOURS_ALERTE=30    # Alerte si certificat expire dans moins de X jours

# plesk_check_disk.sh
SEUIL=80           # Alerte si utilisation disque > X%

# plesk_check_mail.sh
SEUIL=100          # Alerte si file email > X messages

# plesk_check_backup.sh
JOURS_MAX=7        # Alerte si sauvegarde > X jours
```

## Exemples de sortie

### Services OK
```
[OK] Plesk (psa)
[OK] Nginx (nginx)
[OK] MariaDB (mariadb)
[OK] PHP-FPM (45 processus)
```

### Alerte SSL
```
[ALERTE] example.com - Expire dans 5 jours
[OK] autresite.com - Expire dans 89 jours
```

## Dépannage

Si un script ne fonctionne pas :

```bash
# Tester manuellement
bash -x /opt/tacticalrmm/scripts/plesk_check_services.sh

# Vérifier les permissions
chmod +x /opt/tacticalrmm/scripts/*.sh

# Vérifier l'accès Plesk
plesk bin --help
```
