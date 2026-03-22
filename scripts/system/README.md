# Surveillance Système - Tactical RMM

Scripts de monitoring avancé pour les performances système génériques.

## Scripts disponibles

### `check-cpu.sh`
- Surveillance de l'utilisation CPU
- Surveillance de la charge système (1m, 5m, 15m)
- Détection d'utilisation CPU persistante élevée
- Affichage des processus consommateurs de CPU
- Surveillance de la température CPU (si disponible)

### `check-memory.sh`
- Surveillance de l'utilisation mémoire
- Surveillance de l'utilisation swap
- Affichage des processus consommateurs de mémoire
- Détection de la pression mémoire (kernel 4.15+)

### `check-disk.sh`
- Surveillance de l'espace disque par partition
- Surveillance de l'utilisation des inodes
- Détection des répertoires volumineux
- Statistiques E/S disque (nécessite sysstat)

### `check-network.sh`
- Surveillance de la connectivité réseau
- Test de latence vers serveurs DNS
- Vérification de la résolution DNS
- Statistiques des interfaces réseau
- Surveillance des connexions établies

### `check-system.sh`
- Script complet qui exécute toutes les vérifications
- Retourne un statut global combiné
- Idéal pour les alertes globales

## Seuils par défaut

| Composant | Seuil | Action |
|-----------|-------|--------|
| CPU | 80% | Alerte |
| CPU persistant | >80% pendant 5min | Alerte critique |
| Mémoire | 85% | Alerte |
| Swap | 50% | Alerte |
| Disque | 85% | Alerte |
| Inodes | 90% | Alerte |
| Latence réseau | 100ms | Alerte |

## Codes de sortie

- `0` : Tout va bien
- `1` : Alerte standard
- `2` : Alerte critique

## Installation

Les scripts sont automatiquement inclus dans l'installation Tactical RMM et peuvent être utilisés directement via l'interface de surveillance.

## Personnalisation

Les seuils peuvent être modifiés directement dans chaque script :
- `SEUIL_CPU` dans `check-cpu.sh`
- `SEUIL_MEMOIRE` et `SEUIL_SWAP` dans `check-memory.sh`
- `SEUIL_ESPACE` et `SEUIL_INODES` dans `check-disk.sh`
- `SEUIL_PING` dans `check-network.sh`

## Dépendances

- **sysstat** : Pour les statistiques E/S disque (`iostat`)
- **lm-sensors** : Pour la température CPU (`sensors`)
- **lsof** : Pour la surveillance des connexions réseau

Ces dépendances sont optionnelles et les scripts fonctionnent même si elles ne sont pas installées.