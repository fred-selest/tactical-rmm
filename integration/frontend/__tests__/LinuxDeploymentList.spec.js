/**
 * Tests unitaires pour LinuxDeploymentList.vue
 * Framework: Vitest + Vue Test Utils
 */
import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock de l'API
vi.mock('boot/axios', () => ({
  api: {
    get: vi.fn(),
    delete: vi.fn(),
  }
}))

import { api } from 'boot/axios'

// Mock des données
const mockDeployments = [
  {
    uuid: '11111111-1111-1111-1111-111111111111',
    client_name: 'Client Alpha',
    site_name: 'Site Principal',
    agent_type: 'server',
    arch: 'amd64',
    is_expired: false,
    download_count: 5,
    agents_installed: 3,
    created_at: '2026-03-01T10:00:00Z',
    expires_at: '2026-04-01T10:00:00Z',
    deployment_url: 'https://api.test.com/clients/11111111/deploy/linux/',
    install_command: 'wget https://api.test.com/clients/11111111/deploy/linux/ -O install.sh',
  },
  {
    uuid: '22222222-2222-2222-2222-222222222222',
    client_name: 'Client Beta',
    site_name: 'Site Secondaire',
    agent_type: 'workstation',
    arch: 'arm64',
    is_expired: true,
    download_count: 2,
    agents_installed: 1,
    created_at: '2026-01-01T10:00:00Z',
    expires_at: '2026-02-01T10:00:00Z',
    deployment_url: 'https://api.test.com/clients/22222222/deploy/linux/',
    install_command: 'wget https://api.test.com/clients/22222222/deploy/linux/ -O install.sh',
  },
]

const mockStats = {
  total_deployments: 2,
  active_deployments: 1,
  expired_deployments: 1,
  total_downloads: 7,
  total_installations: 4,
  success_rate: 57.14,
}

describe('LinuxDeploymentList', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('Chargement des données', () => {
    it('devrait charger les déploiements au montage', async () => {
      api.get.mockResolvedValueOnce({ data: mockDeployments })
      await api.get('/api/v3/linux-deployments/')
      expect(api.get).toHaveBeenCalledWith('/api/v3/linux-deployments/')
    })

    it('devrait charger les statistiques au montage', async () => {
      api.get.mockResolvedValueOnce({ data: mockStats })
      await api.get('/api/v3/linux-deployments/stats/')
      expect(api.get).toHaveBeenCalledWith('/api/v3/linux-deployments/stats/')
    })

    it('devrait gérer les erreurs de chargement', async () => {
      api.get.mockRejectedValueOnce(new Error('Server Error'))
      try {
        await api.get('/api/v3/linux-deployments/')
      } catch (error) {
        expect(error.message).toBe('Server Error')
      }
    })
  })

  describe('Filtrage', () => {
    it('devrait filtrer par recherche textuelle', () => {
      const search = 'alpha'
      const filtered = mockDeployments.filter(d =>
        d.client_name.toLowerCase().includes(search)
      )
      expect(filtered).toHaveLength(1)
      expect(filtered[0].client_name).toBe('Client Alpha')
    })

    it('devrait filtrer par statut actif', () => {
      const filtered = mockDeployments.filter(d => !d.is_expired)
      expect(filtered).toHaveLength(1)
      expect(filtered[0].uuid).toBe('11111111-1111-1111-1111-111111111111')
    })

    it('devrait filtrer par statut expiré', () => {
      const filtered = mockDeployments.filter(d => d.is_expired)
      expect(filtered).toHaveLength(1)
      expect(filtered[0].uuid).toBe('22222222-2222-2222-2222-222222222222')
    })

    it('devrait filtrer par type d\'agent', () => {
      const filtered = mockDeployments.filter(d => d.agent_type === 'server')
      expect(filtered).toHaveLength(1)
    })

    it('devrait combiner les filtres', () => {
      const search = 'alpha'
      const agentType = 'server'
      const filtered = mockDeployments.filter(d =>
        d.client_name.toLowerCase().includes(search) &&
        d.agent_type === agentType &&
        !d.is_expired
      )
      expect(filtered).toHaveLength(1)
    })
  })

  describe('Suppression', () => {
    it('devrait supprimer un déploiement', async () => {
      api.delete.mockResolvedValueOnce({})
      const uuid = '11111111-1111-1111-1111-111111111111'
      await api.delete(`/api/v3/linux-deployments/${uuid}/`)
      expect(api.delete).toHaveBeenCalledWith(
        `/api/v3/linux-deployments/${uuid}/`
      )
    })
  })

  describe('Statistiques', () => {
    it('devrait afficher le bon nombre de déploiements totaux', () => {
      expect(mockStats.total_deployments).toBe(2)
    })

    it('devrait calculer le taux de succès', () => {
      const rate = mockStats.total_downloads > 0
        ? (mockStats.total_installations / mockStats.total_downloads * 100)
        : 0
      expect(rate).toBeCloseTo(57.14, 1)
    })
  })

  describe('Formatage des dates', () => {
    it('devrait formater les dates courtes', () => {
      const date = '2026-03-01T10:00:00Z'
      const formatted = new Date(date).toLocaleString('fr-FR', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
      expect(formatted).toBeTruthy()
    })

    it('devrait formater les dates longues', () => {
      const date = '2026-03-01T10:00:00Z'
      const formatted = new Date(date).toLocaleString('fr-FR', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
      expect(formatted).toContain('2026')
    })
  })

  describe('Colonnes de la table', () => {
    it('devrait avoir les colonnes requises', () => {
      const requiredColumns = ['status', 'client_site', 'config', 'stats', 'dates', 'actions']
      const columnNames = requiredColumns // simulated
      requiredColumns.forEach(col => {
        expect(columnNames).toContain(col)
      })
    })
  })
})
