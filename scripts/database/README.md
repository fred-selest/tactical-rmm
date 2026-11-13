# Surveillance Bases de Données - Tactical RMM

Scripts de monitoring pour les systèmes de bases de données MySQL/MariaDB et PostgreSQL.

## Scripts disponibles

### `check-mysql.sh`
- Surveillance de l'état du serveur MySQL/MariaDB
- Vérification des connexions et performance
- Surveillance de l'espace disque
- Détection des tables corrompues
- Surveillance de la réplication
- Détection des processus bloquants

### `check-postgresql.sh`
- Surveillance de l'état du serveur PostgreSQL
- Vérification des connexions et performance
- Surveillance de l'espace disque
- Détection des requêtes longues
- Surveillance des verrous bloquants
- Vérification de l'autovacuum

### `check-database.sh`
- Script complet qui détecte automatiquement les bases de données installées
- Exécute les vérifications appropriées pour chaque système trouvé

## Seuils par défaut

| Composant | Seuil | Action |
|-----------|-------|--------|
| Connexions | 80% | Alerte |
| Espace disque | 85% | Alerte |
| Requêtes lentes (MySQL) | 10/min | Alerte |
| Requêtes longues (PostgreSQL) | > 5min | Alerte |

## Codes de sortie

- `0` : Tout va bien
- `1` : Alerte standard

## Configuration

### MySQL/MariaDB
Le script utilise la configuration MySQL par défaut. Assurez-vous que :
- Le fichier `~/.my.cnf` est configuré avec les credentials appropriés, **OU**
- Les variables d'environnement sont définies :
  ```bash
  export MYSQL_HOST=localhost
  export MYSQL_USER=root
  export MYSQL_PASSWORD=votre_mot_de_passe
  ```

### PostgreSQL
Le script utilise la configuration PostgreSQL par défaut. Assurez-vous que :
- Le fichier `~/.pgpass` est configuré avec les credentials appropriés, **OU**
- Les variables d'environnement sont définies :
  ```bash
  export PGHOST=localhost
  export PGUSER=postgres
  export PGPASSWORD=votre_mot_de_passe
  ```

## Dépendances

- **mysql-client** : Pour MySQL/MariaDB
- **postgresql-client** : Pour PostgreSQL

Ces dépendances doivent être installées sur le système hôte.