"""
Commande de gestion Django pour nettoyer les déploiements expirés.

Usage:
    python manage.py cleanup_expired_deployments
    python manage.py cleanup_expired_deployments --days 90
    python manage.py cleanup_expired_deployments --dry-run
"""
from __future__ import annotations

from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from ...models import LinuxDeployment, DeploymentLog


class Command(BaseCommand):
    help = "Supprime les déploiements Linux expirés et leurs logs associés"

    def add_arguments(self, parser) -> None:
        parser.add_argument(
            '--days',
            type=int,
            default=30,
            help="Nombre de jours après expiration avant suppression (défaut: 30)",
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help="Affiche ce qui serait supprimé sans effectuer la suppression",
        )

    def handle(self, *args, **options) -> None:
        days = options['days']
        dry_run = options['dry_run']
        cutoff_date = timezone.now() - timedelta(days=days)

        expired_deployments = LinuxDeployment.objects.filter(
            expires_at__lt=cutoff_date
        )
        count = expired_deployments.count()

        if count == 0:
            self.stdout.write(self.style.SUCCESS(
                "Aucun déploiement expiré à nettoyer."
            ))
            return

        if dry_run:
            self.stdout.write(self.style.WARNING(
                f"[DRY RUN] {count} déploiement(s) seraient supprimés "
                f"(expirés depuis plus de {days} jours)"
            ))
            for deployment in expired_deployments[:10]:
                self.stdout.write(
                    f"  - {deployment.uuid} | {deployment.client_name}/{deployment.site_name} "
                    f"| Expiré le {deployment.expires_at.strftime('%Y-%m-%d')}"
                )
            if count > 10:
                self.stdout.write(f"  ... et {count - 10} autres")
            return

        # Compter les logs associés
        log_count = DeploymentLog.objects.filter(
            deployment__in=expired_deployments
        ).count()

        # Supprimer (les logs sont supprimés en cascade grâce à on_delete=CASCADE)
        expired_deployments.delete()

        self.stdout.write(self.style.SUCCESS(
            f"{count} déploiement(s) et {log_count} log(s) supprimés "
            f"(expirés depuis plus de {days} jours)"
        ))
