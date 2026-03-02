# Generated migration for adding signing tokens to LinuxDeployment model

from django.db import migrations, models
import secrets


def generate_default_tokens(apps, schema_editor):
    """
    Génère des tokens par défaut pour les déploiements existants
    """
    LinuxDeployment = apps.get_model('linux_deployments', 'LinuxDeployment')

    for deployment in LinuxDeployment.objects.all():
        deployment.signing_token = secrets.token_urlsafe(48)
        deployment.one_time_token = secrets.token_urlsafe(48)
        deployment.signature_secret = secrets.token_urlsafe(96)
        deployment.save(update_fields=['signing_token', 'one_time_token', 'signature_secret'])


class Migration(migrations.Migration):

    dependencies = [
        ('linux_deployments', '0001_initial'),  # Modifier selon votre première migration
    ]

    operations = [
        migrations.AddField(
            model_name='linuxdeployment',
            name='signing_token',
            field=models.CharField(
                default='',
                help_text='Token HMAC pour signer les URLs de déploiement',
                max_length=64,
                unique=False,  # Temporairement False pour la migration
            ),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='linuxdeployment',
            name='one_time_token',
            field=models.CharField(
                default='',
                help_text="Token unique qui expire après la première installation",
                max_length=64,
                unique=False,  # Temporairement False pour la migration
            ),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='linuxdeployment',
            name='signature_secret',
            field=models.CharField(
                default='',
                help_text='Secret pour générer et valider les signatures HMAC',
                max_length=128,
            ),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='linuxdeployment',
            name='token_used',
            field=models.BooleanField(
                default=False,
                help_text="Indique si le one-time token a déjà été utilisé",
            ),
        ),
        migrations.AddField(
            model_name='linuxdeployment',
            name='token_used_at',
            field=models.DateTimeField(
                blank=True,
                help_text="Date et heure d'utilisation du token",
                null=True,
            ),
        ),
        # Générer les tokens pour les déploiements existants
        migrations.RunPython(generate_default_tokens, migrations.RunPython.noop),
        # Maintenant on peut ajouter la contrainte unique
        migrations.AlterField(
            model_name='linuxdeployment',
            name='signing_token',
            field=models.CharField(
                help_text='Token HMAC pour signer les URLs de déploiement',
                max_length=64,
                unique=True,
            ),
        ),
        migrations.AlterField(
            model_name='linuxdeployment',
            name='one_time_token',
            field=models.CharField(
                help_text="Token unique qui expire après la première installation",
                max_length=64,
                unique=True,
            ),
        ),
    ]
