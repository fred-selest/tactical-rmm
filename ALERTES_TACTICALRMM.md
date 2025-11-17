# Configuration des alertes automatiques Tactical RMM

Guide pour configurer les alertes automatiques basées sur les scripts de surveillance Plesk et Docker.

## Étape 1 : Importer les scripts

### Dans Tactical RMM

1. **Settings** → **Script Manager** → **New**
2. Configurez :
   - **Nom** : `Plesk - Surveillance complète`
   - **Description** : `Vérifie services, disque, SSL, email, backup, sécurité`
   - **Type** : `Shell`
   - **Code de retour par défaut** : `0`
   - **Code de retour en erreur** : `1`
3. Collez le contenu du script `plesk_check_all.sh`
4. **Save**

Répétez pour chaque script que vous souhaitez utiliser.

## Étape 2 : Créer les tâches automatisées

### Sur un agent Plesk

1. Sélectionnez l'agent dans Tactical RMM
2. **Tasks** → **Add Task**
3. Configurez :
   - **Nom** : `Surveillance Plesk horaire`
   - **Type** : `Scheduled`
   - **Script** : Sélectionnez votre script
   - **Planification** :
     - Type : `Daily`
     - Interval : `1 hour` (ou selon besoin)
4. **Conditions** :
   - **Alert on failure** : Coché
   - **Alert severity** : `Error`
5. **Save**

### Tâches recommandées

| Script | Fréquence | Priorité |
|--------|-----------|----------|
| `plesk_check_services.sh` | Toutes les 5 min | Haute |
| `plesk_check_docker.sh` | Toutes les 15 min | Haute |
| `plesk_check_disk.sh` | Toutes les heures | Moyenne |
| `plesk_check_ssl.sh` | Une fois par jour | Basse |
| `plesk_check_mail.sh` | Toutes les 30 min | Moyenne |
| `plesk_check_backup.sh` | Une fois par jour | Moyenne |
| `plesk_check_security.sh` | Toutes les heures | Haute |

## Étape 3 : Configurer les politiques d'alerte

### Créer une politique

1. **Settings** → **Automation Manager**
2. **Policies** → **Add Policy**
3. Configurez :
   - **Nom** : `Alertes serveur Plesk`
   - **Description** : `Alertes pour les serveurs Plesk`

### Ajouter des conditions

1. Dans la politique, cliquez sur **Add Check**
2. Type : **Script Check**
3. Script : Sélectionnez votre script
4. **Failure condition** : `Exit code != 0`
5. **Alert severity** : `Error` ou `Warning`

## Étape 4 : Configurer les notifications

### Email

1. **Settings** → **Global Settings** → **Email Alerts**
2. Configurez votre serveur SMTP :
   - **From** : `alertes@votredomaine.com`
   - **Host** : `smtp.votredomaine.com`
   - **Port** : `587`
   - **TLS** : Activé
3. **Recipients** : Ajoutez les emails des administrateurs

### SMS (optionnel)

1. **Settings** → **Global Settings** → **SMS Alerts**
2. Configurez Twilio ou autre fournisseur

### Webhook (Discord, Slack, Teams)

1. **Settings** → **Global Settings** → **Webhooks**
2. **Add Webhook** :
   - **Nom** : `Discord Alertes`
   - **URL** : `https://discord.com/api/webhooks/...`
   - **Method** : `POST`

#### Exemple payload Discord

```json
{
  "content": "**Alerte Tactical RMM**",
  "embeds": [{
    "title": "{{alert.severity}}: {{alert.message}}",
    "description": "Agent: {{agent.hostname}}\nScript: {{script.name}}",
    "color": 15158332
  }]
}
```

## Étape 5 : Tester les alertes

### Test manuel

1. Sélectionnez l'agent
2. **Run Script** → Choisissez un script
3. Vérifiez la sortie et le code de retour

### Forcer une alerte

Modifiez temporairement un seuil dans le script pour déclencher une alerte :

```bash
# Dans plesk_check_disk.sh
SEUIL=1  # Au lieu de 80
```

## Exemples de configuration

### Alerte critique : Service arrêté

- **Script** : `plesk_check_services.sh`
- **Fréquence** : 5 minutes
- **Sévérité** : Critical
- **Action** : Email + SMS

### Alerte moyenne : Espace disque

- **Script** : `plesk_check_disk.sh`
- **Fréquence** : 1 heure
- **Sévérité** : Warning
- **Action** : Email

### Alerte info : Certificat expire bientôt

- **Script** : `plesk_check_ssl.sh`
- **Fréquence** : 1 jour
- **Sévérité** : Info
- **Action** : Email

## Bonnes pratiques

1. **Ne pas surcharger** : Évitez les vérifications trop fréquentes
2. **Prioriser** : Services critiques = alertes immédiates
3. **Grouper** : Utilisez `plesk_check_all.sh` pour une vue globale
4. **Documenter** : Notez les seuils personnalisés
5. **Tester** : Validez les alertes avant la mise en production

## Dépannage

### Les alertes ne s'envoient pas

1. Vérifiez la configuration SMTP : **Settings** → **Email Alerts** → **Test**
2. Vérifiez les logs : **Logs** → **Debug Log**
3. Assurez-vous que l'agent est en ligne

### Trop d'alertes

1. Augmentez les seuils dans les scripts
2. Réduisez la fréquence des vérifications
3. Utilisez des conditions de réactivation (cooldown)

### Script timeout

1. Augmentez le timeout : **Script Manager** → Éditez le script → **Timeout**
2. Par défaut : 120 secondes
3. Pour Docker : 300 secondes recommandées
