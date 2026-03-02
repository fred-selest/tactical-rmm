<template>
  <q-dialog v-model="showDialog" persistent>
    <q-card style="min-width: 800px;">
      <!-- En-tête -->
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6">Installation de l'agent Linux</div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <!-- Contenu principal -->
      <q-card-section>
        <q-stepper v-model="step" vertical color="primary" animated>

          <!-- Étape 1: Sélection Client/Site -->
          <q-step
            :name="1"
            title="Sélection du client et du site"
            icon="business"
            :done="step > 1"
          >
            <q-select
              v-model="selectedClient"
              :options="clients"
              option-value="id"
              option-label="name"
              label="Client"
              filled
              class="q-mb-md"
              @update:model-value="loadSites"
            />

            <q-select
              v-model="selectedSite"
              :options="sites"
              option-value="id"
              option-label="name"
              label="Site"
              filled
              :disable="!selectedClient"
            />

            <q-stepper-navigation>
              <q-btn
                @click="step = 2"
                color="primary"
                label="Suivant"
                :disable="!selectedSite"
              />
            </q-stepper-navigation>
          </q-step>

          <!-- Étape 2: Configuration de l'agent -->
          <q-step
            :name="2"
            title="Configuration de l'agent"
            icon="settings"
            :done="step > 2"
          >
            <div class="row q-col-gutter-md">
              <div class="col-6">
                <q-select
                  v-model="agentConfig.agent_type"
                  :options="agentTypes"
                  label="Type d'agent"
                  filled
                />
              </div>

              <div class="col-6">
                <q-select
                  v-model="agentConfig.arch"
                  :options="architectures"
                  label="Architecture"
                  filled
                />
              </div>

              <div class="col-12">
                <q-input
                  v-model.number="agentConfig.expires_days"
                  type="number"
                  label="Expiration (jours)"
                  filled
                  min="1"
                  max="365"
                />
              </div>

              <div class="col-12">
                <q-toggle
                  v-model="agentConfig.enable_ping"
                  label="Activer le ping"
                />
                <q-toggle
                  v-model="agentConfig.install_mesh"
                  label="Installer Mesh Agent"
                  class="q-ml-md"
                />
              </div>
            </div>

            <q-stepper-navigation>
              <q-btn
                @click="createDeployment"
                color="primary"
                label="Créer le déploiement"
                :loading="creating"
              />
              <q-btn
                @click="step = 1"
                flat
                color="primary"
                label="Retour"
                class="q-ml-sm"
              />
            </q-stepper-navigation>
          </q-step>

          <!-- Étape 3: Instructions d'installation -->
          <q-step
            :name="3"
            title="Instructions d'installation"
            icon="download"
          >
            <div v-if="deployment">
              <!-- Statut -->
              <q-banner class="bg-positive text-white q-mb-md" rounded>
                <template v-slot:avatar>
                  <q-icon name="check_circle" />
                </template>
                Déploiement créé avec succès !
              </q-banner>

              <!-- Informations -->
              <div class="q-mb-md">
                <div class="text-subtitle2">Informations du déploiement</div>
                <q-list bordered separator>
                  <q-item>
                    <q-item-section>
                      <q-item-label caption>UUID</q-item-label>
                      <q-item-label>{{ deployment.uuid }}</q-item-label>
                    </q-item-section>
                  </q-item>
                  <q-item>
                    <q-item-section>
                      <q-item-label caption>Expire le</q-item-label>
                      <q-item-label>{{ formatDate(deployment.expires_at) }}</q-item-label>
                    </q-item-section>
                  </q-item>
                  <q-item>
                    <q-item-section>
                      <q-item-label caption>Type / Architecture</q-item-label>
                      <q-item-label>{{ deployment.agent_type }} / {{ deployment.arch }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </div>

              <!-- URL de déploiement -->
              <div class="q-mb-md">
                <div class="text-subtitle2 q-mb-sm">URL de déploiement</div>
                <q-input
                  :model-value="deployment.deployment_url"
                  filled
                  readonly
                >
                  <template v-slot:append>
                    <q-btn
                      icon="content_copy"
                      flat
                      round
                      dense
                      @click="copyToClipboard(deployment.deployment_url, 'URL copiée !')"
                    />
                  </template>
                </q-input>
              </div>

              <!-- Commande d'installation -->
              <div class="q-mb-md">
                <div class="text-subtitle2 q-mb-sm">Commande d'installation</div>
                <q-card flat bordered>
                  <q-card-section>
                    <pre class="q-ma-none" style="overflow-x: auto;">{{ deployment.install_command }}</pre>
                  </q-card-section>
                  <q-separator />
                  <q-card-actions align="right">
                    <q-btn
                      icon="content_copy"
                      label="Copier la commande"
                      color="primary"
                      flat
                      @click="copyToClipboard(deployment.install_command, 'Commande copiée !')"
                    />
                  </q-card-actions>
                </q-card>
              </div>

              <!-- Instructions détaillées -->
              <q-expansion-item
                icon="info"
                label="Instructions détaillées"
                class="q-mb-md"
              >
                <q-card>
                  <q-card-section>
                    <div class="text-subtitle2 q-mb-sm">Étapes d'installation :</div>
                    <ol class="q-pl-md">
                      <li>Connectez-vous en SSH au serveur Linux cible</li>
                      <li>Exécutez la commande ci-dessus en tant que root (ou avec sudo)</li>
                      <li>Le script téléchargera et installera automatiquement l'agent</li>
                      <li>L'agent apparaîtra dans le dashboard dans quelques minutes</li>
                    </ol>

                    <div class="text-subtitle2 q-mt-md q-mb-sm">Prérequis :</div>
                    <ul class="q-pl-md">
                      <li>Accès root ou sudo sur le serveur</li>
                      <li>Connexion Internet pour télécharger les packages</li>
                      <li>Ports sortants 443 (HTTPS) et selon configuration Mesh</li>
                    </ul>

                    <div class="text-subtitle2 q-mt-md q-mb-sm">Systèmes supportés :</div>
                    <ul class="q-pl-md">
                      <li>Debian 10+, Ubuntu 18.04+</li>
                      <li>CentOS 7+, Rocky Linux 8+, AlmaLinux 8+</li>
                      <li>Fedora 30+</li>
                      <li>Arch Linux (latest)</li>
                      <li>Synology DSM 7.0+</li>
                    </ul>
                  </q-card-section>
                </q-card>
              </q-expansion-item>

              <!-- QR Code (optionnel) -->
              <div v-if="showQRCode" class="q-mb-md text-center">
                <div class="text-subtitle2 q-mb-sm">QR Code pour mobile</div>
                <qrcode-vue
                  :value="deployment.deployment_url"
                  :size="200"
                  level="H"
                />
              </div>
            </div>

            <q-stepper-navigation>
              <q-btn
                @click="createAnother"
                color="primary"
                label="Créer un autre déploiement"
                outline
              />
              <q-btn
                @click="close"
                flat
                color="primary"
                label="Fermer"
                class="q-ml-sm"
              />
            </q-stepper-navigation>
          </q-step>
        </q-stepper>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script>
import { ref, computed } from 'vue'
import { useQuasar, copyToClipboard } from 'quasar'
import { api } from 'boot/axios'

export default {
  name: 'LinuxDeploymentManager',

  setup() {
    const $q = useQuasar()

    // État
    const showDialog = ref(false)
    const step = ref(1)
    const creating = ref(false)
    const showQRCode = ref(false)

    // Données
    const clients = ref([])
    const sites = ref([])
    const selectedClient = ref(null)
    const selectedSite = ref(null)
    const deployment = ref(null)

    // Configuration de l'agent
    const agentConfig = ref({
      agent_type: 'server',
      arch: 'amd64',
      expires_days: 30,
      enable_ping: true,
      enable_rdp: false,
      install_mesh: true,
      custom_script_url: ''
    })

    // Options
    const agentTypes = [
      { label: 'Server', value: 'server' },
      { label: 'Workstation', value: 'workstation' }
    ]

    const architectures = [
      { label: 'AMD64 / x86_64', value: 'amd64' },
      { label: 'ARM64', value: 'arm64' },
      { label: 'i386 (32-bit)', value: '386' }
    ]

    // Méthodes
    const open = async () => {
      showDialog.value = true
      await loadClients()
    }

    const close = () => {
      showDialog.value = false
      reset()
    }

    const reset = () => {
      step.value = 1
      selectedClient.value = null
      selectedSite.value = null
      deployment.value = null
      agentConfig.value = {
        agent_type: 'server',
        arch: 'amd64',
        expires_days: 30,
        enable_ping: true,
        enable_rdp: false,
        install_mesh: true,
        custom_script_url: ''
      }
    }

    const loadClients = async () => {
      try {
        const response = await api.get('/clients/')
        clients.value = response.data
      } catch (error) {
        $q.notify({
          type: 'negative',
          message: 'Erreur lors du chargement des clients'
        })
      }
    }

    const loadSites = async () => {
      if (!selectedClient.value) {
        sites.value = []
        return
      }

      try {
        const response = await api.get(`/clients/${selectedClient.value.id}/sites/`)
        sites.value = response.data
      } catch (error) {
        $q.notify({
          type: 'negative',
          message: 'Erreur lors du chargement des sites'
        })
      }
    }

    const createDeployment = async () => {
      creating.value = true

      try {
        const payload = {
          client_id: selectedClient.value.id,
          client_name: selectedClient.value.name,
          site_id: selectedSite.value.id,
          site_name: selectedSite.value.name,
          ...agentConfig.value
        }

        const response = await api.post('/api/v3/linux-deployments/create/', payload)
        deployment.value = response.data

        $q.notify({
          type: 'positive',
          message: 'Déploiement créé avec succès'
        })

        step.value = 3
      } catch (error) {
        $q.notify({
          type: 'negative',
          message: 'Erreur lors de la création du déploiement: ' + (error.response?.data?.error || error.message)
        })
      } finally {
        creating.value = false
      }
    }

    const createAnother = () => {
      reset()
    }

    const copyToClipboard = (text, message) => {
      copyToClipboard(text)
        .then(() => {
          $q.notify({
            type: 'positive',
            message: message || 'Copié dans le presse-papiers'
          })
        })
        .catch(() => {
          $q.notify({
            type: 'negative',
            message: 'Erreur lors de la copie'
          })
        })
    }

    const formatDate = (dateString) => {
      return new Date(dateString).toLocaleString('fr-FR', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      })
    }

    return {
      // État
      showDialog,
      step,
      creating,
      showQRCode,

      // Données
      clients,
      sites,
      selectedClient,
      selectedSite,
      deployment,
      agentConfig,

      // Options
      agentTypes,
      architectures,

      // Méthodes
      open,
      close,
      loadSites,
      createDeployment,
      createAnother,
      copyToClipboard,
      formatDate,
    }
  }
}
</script>

<style scoped>
pre {
  background-color: #f5f5f5;
  padding: 12px;
  border-radius: 4px;
  font-family: 'Courier New', monospace;
  font-size: 13px;
  line-height: 1.5;
  white-space: pre-wrap;
  word-wrap: break-word;
}
</style>
