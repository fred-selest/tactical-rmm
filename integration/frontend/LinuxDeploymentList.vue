<template>
  <div class="q-pa-md">
    <!-- En-tête -->
    <div class="row items-center q-mb-md">
      <div class="col">
        <div class="text-h5">Déploiements Linux</div>
        <div class="text-subtitle2 text-grey-7">Gérez les liens d'installation de l'agent Linux</div>
      </div>
      <div class="col-auto">
        <q-btn
          color="primary"
          icon="add"
          label="Nouveau déploiement"
          @click="openDeploymentManager"
        />
      </div>
    </div>

    <!-- Statistiques -->
    <div class="row q-col-gutter-md q-mb-md">
      <div class="col-12 col-md-3">
        <q-card>
          <q-card-section>
            <div class="text-h6">{{ stats.total_deployments }}</div>
            <div class="text-subtitle2 text-grey-7">Déploiements totaux</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-md-3">
        <q-card>
          <q-card-section>
            <div class="text-h6 text-positive">{{ stats.active_deployments }}</div>
            <div class="text-subtitle2 text-grey-7">Actifs</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-md-3">
        <q-card>
          <q-card-section>
            <div class="text-h6">{{ stats.total_downloads }}</div>
            <div class="text-subtitle2 text-grey-7">Téléchargements</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-md-3">
        <q-card>
          <q-card-section>
            <div class="text-h6">{{ stats.total_installations }}</div>
            <div class="text-subtitle2 text-grey-7">Installations réussies</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Filtres -->
    <q-card flat bordered class="q-mb-md">
      <q-card-section>
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-4">
            <q-input
              v-model="filter.search"
              label="Rechercher"
              outlined
              dense
              clearable
            >
              <template v-slot:prepend>
                <q-icon name="search" />
              </template>
            </q-input>
          </div>
          <div class="col-12 col-md-3">
            <q-select
              v-model="filter.status"
              :options="statusOptions"
              label="Statut"
              outlined
              dense
              clearable
            />
          </div>
          <div class="col-12 col-md-3">
            <q-select
              v-model="filter.agent_type"
              :options="['server', 'workstation']"
              label="Type d'agent"
              outlined
              dense
              clearable
            />
          </div>
          <div class="col-12 col-md-2">
            <q-btn
              color="primary"
              icon="refresh"
              label="Actualiser"
              outline
              @click="loadDeployments"
              class="full-width"
            />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Table des déploiements -->
    <q-table
      :rows="filteredDeployments"
      :columns="columns"
      row-key="uuid"
      :loading="loading"
      :pagination="pagination"
      @request="onRequest"
      flat
      bordered
    >
      <!-- Status -->
      <template v-slot:body-cell-status="props">
        <q-td :props="props">
          <q-badge
            :color="props.row.is_expired ? 'negative' : 'positive'"
            :label="props.row.is_expired ? 'Expiré' : 'Actif'"
          />
        </q-td>
      </template>

      <!-- Client/Site -->
      <template v-slot:body-cell-client_site="props">
        <q-td :props="props">
          <div>{{ props.row.client_name }}</div>
          <div class="text-caption text-grey-7">{{ props.row.site_name }}</div>
        </q-td>
      </template>

      <!-- Config -->
      <template v-slot:body-cell-config="props">
        <q-td :props="props">
          <div>
            <q-chip size="sm" dense>{{ props.row.agent_type }}</q-chip>
            <q-chip size="sm" dense>{{ props.row.arch }}</q-chip>
          </div>
        </q-td>
      </template>

      <!-- Statistiques -->
      <template v-slot:body-cell-stats="props">
        <q-td :props="props">
          <div class="text-caption">
            <div>Téléchargements: {{ props.row.download_count }}</div>
            <div>Installations: {{ props.row.agents_installed }}</div>
          </div>
        </q-td>
      </template>

      <!-- Dates -->
      <template v-slot:body-cell-dates="props">
        <q-td :props="props">
          <div class="text-caption">
            <div>Créé: {{ formatDate(props.row.created_at, true) }}</div>
            <div>Expire: {{ formatDate(props.row.expires_at, true) }}</div>
          </div>
        </q-td>
      </template>

      <!-- Actions -->
      <template v-slot:body-cell-actions="props">
        <q-td :props="props">
          <q-btn
            flat
            round
            dense
            icon="more_vert"
            @click="showActionsMenu(props.row, $event)"
          >
            <q-menu>
              <q-list style="min-width: 200px">
                <q-item clickable @click="viewDetails(props.row)">
                  <q-item-section avatar>
                    <q-icon name="visibility" />
                  </q-item-section>
                  <q-item-section>Voir les détails</q-item-section>
                </q-item>

                <q-item clickable @click="copyDeploymentUrl(props.row)">
                  <q-item-section avatar>
                    <q-icon name="link" />
                  </q-item-section>
                  <q-item-section>Copier l'URL</q-item-section>
                </q-item>

                <q-item clickable @click="copyInstallCommand(props.row)">
                  <q-item-section avatar>
                    <q-icon name="terminal" />
                  </q-item-section>
                  <q-item-section>Copier la commande</q-item-section>
                </q-item>

                <q-separator />

                <q-item
                  clickable
                  @click="deleteDeployment(props.row)"
                  class="text-negative"
                >
                  <q-item-section avatar>
                    <q-icon name="delete" color="negative" />
                  </q-item-section>
                  <q-item-section>Supprimer</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>
        </q-td>
      </template>
    </q-table>

    <!-- Dialog de détails -->
    <q-dialog v-model="showDetailsDialog">
      <q-card style="min-width: 600px;">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">Détails du déploiement</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section v-if="selectedDeployment">
          <q-list bordered separator>
            <q-item>
              <q-item-section>
                <q-item-label caption>UUID</q-item-label>
                <q-item-label>{{ selectedDeployment.uuid }}</q-item-label>
              </q-item-section>
            </q-item>

            <q-item>
              <q-item-section>
                <q-item-label caption>Client / Site</q-item-label>
                <q-item-label>{{ selectedDeployment.client_name }} / {{ selectedDeployment.site_name }}</q-item-label>
              </q-item-section>
            </q-item>

            <q-item>
              <q-item-section>
                <q-item-label caption>Configuration</q-item-label>
                <q-item-label>{{ selectedDeployment.agent_type }} - {{ selectedDeployment.arch }}</q-item-label>
              </q-item-section>
            </q-item>

            <q-item>
              <q-item-section>
                <q-item-label caption>URL de déploiement</q-item-label>
                <q-item-label class="text-primary">
                  <a :href="selectedDeployment.deployment_url" target="_blank">
                    {{ selectedDeployment.deployment_url }}
                  </a>
                </q-item-label>
              </q-item-section>
            </q-item>

            <q-item>
              <q-item-section>
                <q-item-label caption>Commande d'installation</q-item-label>
                <pre class="q-mt-sm">{{ selectedDeployment.install_command }}</pre>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Composant de gestion -->
    <linux-deployment-manager ref="deploymentManager" @created="loadDeployments" />
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { useQuasar, copyToClipboard } from 'quasar'
import { api } from 'boot/axios'
import LinuxDeploymentManager from './LinuxDeploymentManager.vue'

export default {
  name: 'LinuxDeploymentList',

  components: {
    LinuxDeploymentManager
  },

  setup() {
    const $q = useQuasar()

    // État
    const loading = ref(false)
    const deployments = ref([])
    const stats = ref({
      total_deployments: 0,
      active_deployments: 0,
      total_downloads: 0,
      total_installations: 0
    })

    const filter = ref({
      search: '',
      status: null,
      agent_type: null
    })

    const pagination = ref({
      page: 1,
      rowsPerPage: 10,
      rowsNumber: 0
    })

    const showDetailsDialog = ref(false)
    const selectedDeployment = ref(null)
    const deploymentManager = ref(null)

    // Options
    const statusOptions = ['Actif', 'Expiré']

    // Colonnes de la table
    const columns = [
      {
        name: 'status',
        label: 'Statut',
        align: 'center',
        field: 'is_expired',
        sortable: true
      },
      {
        name: 'client_site',
        label: 'Client / Site',
        align: 'left',
        field: 'client_name',
        sortable: true
      },
      {
        name: 'config',
        label: 'Configuration',
        align: 'left',
        field: 'agent_type'
      },
      {
        name: 'stats',
        label: 'Statistiques',
        align: 'left'
      },
      {
        name: 'dates',
        label: 'Dates',
        align: 'left',
        field: 'created_at',
        sortable: true
      },
      {
        name: 'actions',
        label: 'Actions',
        align: 'center'
      }
    ]

    // Computed
    const filteredDeployments = computed(() => {
      let result = deployments.value

      // Filtre de recherche
      if (filter.value.search) {
        const search = filter.value.search.toLowerCase()
        result = result.filter(d =>
          d.client_name.toLowerCase().includes(search) ||
          d.site_name.toLowerCase().includes(search) ||
          d.uuid.toLowerCase().includes(search)
        )
      }

      // Filtre de statut
      if (filter.value.status === 'Actif') {
        result = result.filter(d => !d.is_expired)
      } else if (filter.value.status === 'Expiré') {
        result = result.filter(d => d.is_expired)
      }

      // Filtre de type d'agent
      if (filter.value.agent_type) {
        result = result.filter(d => d.agent_type === filter.value.agent_type)
      }

      return result
    })

    // Méthodes
    const loadDeployments = async () => {
      loading.value = true
      try {
        const response = await api.get('/api/v3/linux-deployments/')
        deployments.value = response.data
        pagination.value.rowsNumber = response.data.length
      } catch (error) {
        $q.notify({
          type: 'negative',
          message: 'Erreur lors du chargement des déploiements'
        })
      } finally {
        loading.value = false
      }
    }

    const loadStats = async () => {
      try {
        const response = await api.get('/api/v3/linux-deployments/stats/')
        stats.value = response.data
      } catch (error) {
        console.error('Erreur lors du chargement des statistiques:', error)
      }
    }

    const onRequest = (props) => {
      pagination.value = props.pagination
      loadDeployments()
    }

    const openDeploymentManager = () => {
      deploymentManager.value.open()
    }

    const viewDetails = (deployment) => {
      selectedDeployment.value = deployment
      showDetailsDialog.value = true
    }

    const copyDeploymentUrl = (deployment) => {
      copyToClipboard(deployment.deployment_url)
        .then(() => {
          $q.notify({
            type: 'positive',
            message: 'URL copiée dans le presse-papiers'
          })
        })
    }

    const copyInstallCommand = (deployment) => {
      copyToClipboard(deployment.install_command)
        .then(() => {
          $q.notify({
            type: 'positive',
            message: 'Commande copiée dans le presse-papiers'
          })
        })
    }

    const deleteDeployment = (deployment) => {
      $q.dialog({
        title: 'Confirmer la suppression',
        message: `Êtes-vous sûr de vouloir supprimer ce déploiement ?`,
        cancel: true,
        persistent: true
      }).onOk(async () => {
        try {
          await api.delete(`/api/v3/linux-deployments/${deployment.uuid}/`)
          $q.notify({
            type: 'positive',
            message: 'Déploiement supprimé'
          })
          loadDeployments()
          loadStats()
        } catch (error) {
          $q.notify({
            type: 'negative',
            message: 'Erreur lors de la suppression'
          })
        }
      })
    }

    const formatDate = (dateString, short = false) => {
      const options = short
        ? { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }
        : { year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' }

      return new Date(dateString).toLocaleString('fr-FR', options)
    }

    // Lifecycle
    onMounted(() => {
      loadDeployments()
      loadStats()
    })

    return {
      // État
      loading,
      deployments,
      stats,
      filter,
      pagination,
      showDetailsDialog,
      selectedDeployment,
      deploymentManager,

      // Options
      statusOptions,
      columns,

      // Computed
      filteredDeployments,

      // Méthodes
      loadDeployments,
      onRequest,
      openDeploymentManager,
      viewDetails,
      copyDeploymentUrl,
      copyInstallCommand,
      deleteDeployment,
      formatDate,
    }
  }
}
</script>

<style scoped>
pre {
  background-color: #f5f5f5;
  padding: 8px;
  border-radius: 4px;
  font-family: 'Courier New', monospace;
  font-size: 12px;
  overflow-x: auto;
}
</style>
