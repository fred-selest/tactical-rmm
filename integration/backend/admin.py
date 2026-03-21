"""
Admin Django pour l'intégration de déploiement Linux
À intégrer dans: api/tacticalrmm/clients/admin.py
"""
from __future__ import annotations

from datetime import timedelta

from django.contrib import admin
from django.http import HttpRequest, HttpResponse
from django.db.models import QuerySet
from django.utils.html import format_html
from django.urls import reverse

from .export import export_deployments_csv, export_deployments_json
from .models import LinuxDeployment, DeploymentLog


@admin.register(LinuxDeployment)
class LinuxDeploymentAdmin(admin.ModelAdmin):
    """
    Interface d'administration pour les déploiements Linux
    """
    list_display = [
        'uuid_short',
        'client_name',
        'site_name',
        'agent_type',
        'arch',
        'status_badge',
        'download_count',
        'agents_installed',
        'created_at',
        'expires_at',
        'actions_links',
    ]

    list_filter = [
        'agent_type',
        'arch',
        'created_at',
        'expires_at',
    ]

    search_fields = [
        'uuid',
        'client_name',
        'site_name',
        'created_by',
    ]

    readonly_fields = [
        'uuid',
        'created_at',
        'download_count',
        'last_downloaded',
        'agents_installed',
        'deployment_url_display',
        'install_command_display',
    ]

    fieldsets = (
        ('Identification', {
            'fields': ('uuid', 'deployment_url_display')
        }),
        ('Client/Site', {
            'fields': ('client_id', 'client_name', 'site_id', 'site_name')
        }),
        ('Configuration Agent', {
            'fields': ('agent_type', 'arch', 'enable_ping', 'enable_rdp', 'install_mesh')
        }),
        ('URLs et Authentification', {
            'fields': ('api_url', 'mesh_url', 'auth_key')
        }),
        ('Options Avancées', {
            'fields': ('custom_script_url',),
            'classes': ('collapse',)
        }),
        ('Métadonnées', {
            'fields': ('created_by', 'created_at', 'expires_at')
        }),
        ('Statistiques', {
            'fields': ('download_count', 'last_downloaded', 'agents_installed')
        }),
        ('Commande d\'installation', {
            'fields': ('install_command_display',),
            'classes': ('collapse',)
        }),
    )

    actions = ['extend_expiration', 'export_csv', 'export_json']

    def uuid_short(self, obj: LinuxDeployment) -> str:
        """Affiche un UUID raccourci"""
        return f"{str(obj.uuid)[:8]}..."
    uuid_short.short_description = "UUID"

    def status_badge(self, obj: LinuxDeployment) -> str:
        """Affiche un badge de statut"""
        if obj.is_expired():
            return format_html(
                '<span style="background-color: #dc3545; color: white; padding: 3px 10px; border-radius: 3px;">Expiré</span>'
            )
        return format_html(
            '<span style="background-color: #28a745; color: white; padding: 3px 10px; border-radius: 3px;">Actif</span>'
        )
    status_badge.short_description = "Statut"

    def deployment_url_display(self, obj: LinuxDeployment) -> str:
        """Affiche l'URL de déploiement avec un bouton copier"""
        url = f"{obj.api_url}/clients/{obj.uuid}/deploy/linux/"
        return format_html(
            '<div style="margin-bottom: 10px;">'
            '<input type="text" value="{}" id="deployment-url-{}" style="width: 100%; padding: 5px;" readonly>'
            '<button onclick="navigator.clipboard.writeText(document.getElementById(\'deployment-url-{}\').value); '
            'alert(\'URL copiée !\');" style="margin-top: 5px; padding: 5px 15px; cursor: pointer;">Copier l\'URL</button>'
            '</div>',
            url, obj.uuid, obj.uuid
        )
    deployment_url_display.short_description = "URL de déploiement"

    def install_command_display(self, obj: LinuxDeployment) -> str:
        """Affiche la commande d'installation avec un bouton copier"""
        command = obj.get_install_command()
        return format_html(
            '<div style="margin-bottom: 10px;">'
            '<textarea id="install-command-{}" style="width: 100%; height: 80px; padding: 5px; font-family: monospace;" readonly>{}</textarea>'
            '<button onclick="navigator.clipboard.writeText(document.getElementById(\'install-command-{}\').value); '
            'alert(\'Commande copiée !\');" style="margin-top: 5px; padding: 5px 15px; cursor: pointer;">Copier la commande</button>'
            '</div>',
            obj.uuid, command, obj.uuid
        )
    install_command_display.short_description = "Commande d'installation"

    def actions_links(self, obj: LinuxDeployment) -> str:
        """Affiche des liens d'action rapides"""
        logs_url = reverse('admin:clients_deploymentlog_changelist') + f'?deployment__uuid={obj.uuid}'
        return format_html(
            '<a href="{}" class="button">Voir les logs</a>',
            logs_url
        )
    actions_links.short_description = "Actions"

    def get_queryset(self, request: HttpRequest) -> QuerySet:
        """Optimise les requêtes"""
        qs = super().get_queryset(request)
        return qs.select_related()

    # --- Actions admin ---

    @admin.action(description="Prolonger l'expiration de 30 jours")
    def extend_expiration(self, request: HttpRequest, queryset: QuerySet) -> None:
        """Prolonge l'expiration des déploiements sélectionnés de 30 jours"""
        for deployment in queryset:
            deployment.expires_at = deployment.expires_at + timedelta(days=30)
            deployment.save(update_fields=['expires_at'])

        self.message_user(
            request,
            f"{queryset.count()} déploiement(s) prolongé(s) de 30 jours."
        )

    @admin.action(description="Exporter en CSV")
    def export_csv(self, request: HttpRequest, queryset: QuerySet) -> HttpResponse:
        """Exporte les déploiements sélectionnés en CSV"""
        return export_deployments_csv(queryset)

    @admin.action(description="Exporter en JSON")
    def export_json(self, request: HttpRequest, queryset: QuerySet) -> HttpResponse:
        """Exporte les déploiements sélectionnés en JSON"""
        return export_deployments_json(queryset)


@admin.register(DeploymentLog)
class DeploymentLogAdmin(admin.ModelAdmin):
    """
    Interface d'administration pour les logs de déploiement
    """
    list_display = [
        'timestamp',
        'deployment_link',
        'action',
        'hostname',
        'ip_address',
        'has_error',
    ]

    list_filter = [
        'action',
        'timestamp',
    ]

    search_fields = [
        'deployment__uuid',
        'hostname',
        'ip_address',
        'error_message',
    ]

    readonly_fields = [
        'deployment',
        'timestamp',
        'action',
        'ip_address',
        'user_agent',
        'hostname',
        'error_message',
    ]

    fieldsets = (
        ('Déploiement', {
            'fields': ('deployment', 'timestamp', 'action')
        }),
        ('Informations Client', {
            'fields': ('hostname', 'ip_address', 'user_agent')
        }),
        ('Erreur', {
            'fields': ('error_message',),
            'classes': ('collapse',)
        }),
    )

    def has_add_permission(self, request: HttpRequest) -> bool:
        """Empêche la création manuelle de logs"""
        return False

    def has_delete_permission(self, request: HttpRequest, obj=None) -> bool:
        """Empêche la suppression de logs"""
        return False

    def deployment_link(self, obj: DeploymentLog) -> str:
        """Affiche un lien vers le déploiement"""
        url = reverse('admin:clients_linuxdeployment_change', args=[obj.deployment.pk])
        return format_html('<a href="{}">{}</a>', url, obj.deployment.uuid)
    deployment_link.short_description = "Déploiement"

    def has_error(self, obj: DeploymentLog) -> str:
        """Indique si le log contient une erreur"""
        if obj.error_message:
            return format_html(
                '<span style="color: red; font-weight: bold;">✗</span>'
            )
        return format_html(
            '<span style="color: green; font-weight: bold;">✓</span>'
        )
    has_error.short_description = "Statut"

    def get_queryset(self, request: HttpRequest) -> QuerySet:
        """Optimise les requêtes"""
        qs = super().get_queryset(request)
        return qs.select_related('deployment')
