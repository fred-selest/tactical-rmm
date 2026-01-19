# Intégration Frontend Vue.js - Déploiement Agent Linux

Ce dossier contient les composants Vue.js à intégrer dans le projet frontend de Tactical RMM.

## Structure des fichiers

```
frontend/
├── LinuxDeploymentManager.vue    # Modal de création de déploiement
├── LinuxDeploymentList.vue       # Liste et gestion des déploiements
├── api-client.js                 # Client API (optionnel)
└── README.md                     # Ce fichier
```

## Composants

### LinuxDeploymentManager.vue

Modal en 3 étapes pour créer un nouveau déploiement Linux :

1. **Sélection Client/Site** : Choix du client et du site cible
2. **Configuration** : Type d'agent, architecture, options
3. **Instructions** : Affichage de l'URL et de la commande d'installation

**Fonctionnalités** :
- Création de déploiement via API
- Copie automatique de l'URL et de la commande
- Instructions détaillées
- QR Code optionnel

### LinuxDeploymentList.vue

Page de gestion des déploiements existants :

**Fonctionnalités** :
- Liste de tous les déploiements
- Statistiques (total, actifs, téléchargements, installations)
- Filtres (recherche, statut, type d'agent)
- Actions (voir détails, copier URL/commande, supprimer)
- Actualisation en temps réel

## Installation dans Tactical RMM Web

### 1. Cloner le repository principal

```bash
git clone https://github.com/amidaware/tacticalrmm-web.git
cd tacticalrmm-web
```

### 2. Copier les composants

Copier les fichiers `.vue` dans le dossier des composants :

```bash
cp LinuxDeploymentManager.vue src/components/modals/agents/
cp LinuxDeploymentList.vue src/components/agents/
```

### 3. Créer le client API (optionnel)

Créer un fichier `src/api/linux-deployments.js` :

```javascript
import { api } from 'boot/axios'

export default {
  // Créer un déploiement
  create(data) {
    return api.post('/api/v3/linux-deployments/create/', data)
  },

  // Lister les déploiements
  list(params = {}) {
    return api.get('/api/v3/linux-deployments/', { params })
  },

  // Obtenir un déploiement
  get(uuid) {
    return api.get(`/api/v3/linux-deployments/${uuid}/`)
  },

  // Supprimer un déploiement
  delete(uuid) {
    return api.delete(`/api/v3/linux-deployments/${uuid}/`)
  },

  // Statistiques
  stats() {
    return api.get('/api/v3/linux-deployments/stats/')
  }
}
```

### 4. Ajouter les routes

Dans `src/router/routes.js` :

```javascript
{
  path: '/agents/linux-deployments',
  name: 'linux-deployments',
  component: () => import('components/agents/LinuxDeploymentList.vue'),
  meta: {
    requiresAuth: true,
    title: 'Déploiements Linux'
  }
}
```

### 5. Ajouter au menu de navigation

Dans le fichier de navigation (généralement `src/layouts/MainLayout.vue`) :

```javascript
{
  label: 'Déploiements Linux',
  icon: 'dns',
  to: '/agents/linux-deployments'
}
```

Ou l'ajouter dans le menu "Agents" existant :

```javascript
{
  label: 'Agents',
  icon: 'computer',
  children: [
    {
      label: 'Liste des agents',
      icon: 'list',
      to: '/agents'
    },
    {
      label: 'Installation Windows',
      icon: 'windows',
      to: '/agents/install/windows'
    },
    {
      label: 'Installation Linux',  // ← NOUVEAU
      icon: 'terminal',
      to: '/agents/linux-deployments'
    }
  ]
}
```

### 6. Intégration dans un composant existant

Si vous voulez intégrer le bouton dans un composant existant :

```vue
<template>
  <div>
    <!-- Autres contenus -->

    <q-btn
      color="primary"
      icon="download"
      label="Installer agent Linux"
      @click="$refs.linuxDeployment.open()"
    />

    <!-- Modal de déploiement -->
    <linux-deployment-manager ref="linuxDeployment" />
  </div>
</template>

<script>
import LinuxDeploymentManager from 'components/modals/agents/LinuxDeploymentManager.vue'

export default {
  components: {
    LinuxDeploymentManager
  }
}
</script>
```

## Dépendances

Les composants utilisent Quasar Framework et nécessitent :

- **Quasar Framework** >= 2.0
- **Vue 3** >= 3.0
- **Axios** pour les appels API

### Plugins Quasar requis

Dans `quasar.conf.js`, assurez-vous que ces plugins sont activés :

```javascript
framework: {
  plugins: [
    'Notify',
    'Dialog',
    'copyToClipboard'
  ]
}
```

### Composants Quasar utilisés

```javascript
framework: {
  components: [
    'QDialog',
    'QCard',
    'QCardSection',
    'QCardActions',
    'QStepper',
    'QStep',
    'QStepperNavigation',
    'QSelect',
    'QInput',
    'QToggle',
    'QBtn',
    'QTable',
    'QTd',
    'QBadge',
    'QChip',
    'QList',
    'QItem',
    'QItemSection',
    'QItemLabel',
    'QMenu',
    'QSeparator',
    'QBanner',
    'QExpansionItem',
    'QIcon',
    'QSpace'
  ]
}
```

## Personnalisation

### Thème et couleurs

Les composants utilisent les couleurs par défaut de Quasar. Vous pouvez les personnaliser dans `src/css/quasar.variables.scss` :

```scss
$primary: #027be3;
$secondary: #26a69a;
$positive: #21ba45;
$negative: #c10015;
```

### Langue

Les composants sont en français. Pour changer la langue, modifiez les labels dans les fichiers `.vue`.

### Icônes

Par défaut, les composants utilisent Material Icons. Pour changer :

```javascript
// quasar.conf.js
framework: {
  iconSet: 'material-icons' // ou 'fontawesome-v6', 'mdi-v6', etc.
}
```

## API attendue

Les composants s'attendent à ces endpoints :

### Backend

- `GET /clients/` - Liste des clients
- `GET /clients/{id}/sites/` - Sites d'un client
- `POST /api/v3/linux-deployments/create/` - Créer un déploiement
- `GET /api/v3/linux-deployments/` - Lister les déploiements
- `GET /api/v3/linux-deployments/{uuid}/` - Détails d'un déploiement
- `DELETE /api/v3/linux-deployments/{uuid}/` - Supprimer un déploiement
- `GET /api/v3/linux-deployments/stats/` - Statistiques

### Format des réponses

Voir les serializers Django dans `integration/backend/serializers.py`.

## Tests

Pour tester les composants en développement :

```bash
# Mode développement
npm run dev

# Build pour production
npm run build

# Tests unitaires
npm run test:unit

# Tests E2E
npm run test:e2e
```

## Exemple d'utilisation complète

```vue
<!-- Page de gestion des agents -->
<template>
  <q-page padding>
    <!-- Tabs pour Windows/Linux -->
    <q-tabs v-model="tab" class="q-mb-md">
      <q-tab name="windows" label="Windows" icon="windows" />
      <q-tab name="linux" label="Linux" icon="terminal" />
    </q-tabs>

    <q-tab-panels v-model="tab">
      <!-- Panel Windows existant -->
      <q-tab-panel name="windows">
        <!-- Contenu existant -->
      </q-tab-panel>

      <!-- Panel Linux - NOUVEAU -->
      <q-tab-panel name="linux">
        <linux-deployment-list />
      </q-tab-panel>
    </q-tab-panels>
  </q-page>
</template>

<script>
import { ref } from 'vue'
import LinuxDeploymentList from 'components/agents/LinuxDeploymentList.vue'

export default {
  components: {
    LinuxDeploymentList
  },
  setup() {
    const tab = ref('windows')
    return { tab }
  }
}
</script>
```

## Screenshots et démos

### Modal de création

1. **Étape 1** : Sélection du client et du site
2. **Étape 2** : Configuration de l'agent (type, architecture, options)
3. **Étape 3** : Affichage de l'URL et de la commande d'installation

### Liste des déploiements

- Tableau avec statut, client/site, configuration, statistiques
- Filtres et recherche
- Actions rapides (copier, supprimer, détails)
- Statistiques globales en haut

## Support et contribution

Pour toute question ou amélioration :

1. Créer une issue sur GitHub
2. Soumettre une pull request
3. Contacter l'équipe de développement

## License

Même licence que Tactical RMM (AGPL-3.0)
