# Surveillance Docker - Tactical RMM

Scripts de monitoring pour les environnements Docker.

## Script disponible

### `check-docker.sh`
- Vérification de l'état du daemon Docker
- Surveillance des conteneurs (en cours, arrêtés, morts)
- Surveillance de l'utilisation de l'espace disque Docker
- Détection des images, volumes et réseaux orphelins
- Surveillance des ressources par conteneur (CPU, mémoire, réseau)

## Seuils par défaut

| Composant | Seuil | Action |
|-----------|-------|--------|
| Conteneurs arrêtés | > 0 | Alerte |
| Espace Docker | 85% | Alerte |

## Codes de sortie

- `0` : Tout va bien
- `1` : Alerte standard

## Dépendances

- **Docker** : Daemon Docker doit être installé et accessible
- **jq** : Pour le parsing JSON avancé (optionnel)

## Configuration

Le script utilise les credentials Docker par défaut. Assurez-vous que :
- Le daemon Docker est en cours d'exécution
- L'utilisateur a les permissions nécessaires (groupe docker)
- Les variables d'environnement Docker sont configurées si nécessaire