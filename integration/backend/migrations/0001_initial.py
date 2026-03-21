# Migration initiale pour le modèle LinuxDeployment

import uuid
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='LinuxDeployment',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('uuid', models.UUIDField(default=uuid.uuid4, editable=False, unique=True)),
                ('client_id', models.IntegerField()),
                ('client_name', models.CharField(max_length=255)),
                ('site_id', models.IntegerField()),
                ('site_name', models.CharField(max_length=255)),
                ('agent_type', models.CharField(choices=[('server', 'Server'), ('workstation', 'Workstation')], default='server', max_length=20)),
                ('arch', models.CharField(choices=[('amd64', 'AMD64/x86_64'), ('arm64', 'ARM64'), ('386', 'i386')], default='amd64', max_length=20)),
                ('api_url', models.URLField(help_text="URL de l'API Tactical RMM")),
                ('mesh_url', models.URLField(help_text='URL du Mesh Agent')),
                ('auth_key', models.CharField(help_text="Clé d'authentification", max_length=255)),
                ('enable_ping', models.BooleanField(default=True)),
                ('enable_rdp', models.BooleanField(default=False)),
                ('install_mesh', models.BooleanField(default=True)),
                ('custom_script_url', models.URLField(blank=True, help_text="URL du script d'installation personnalisé", null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('expires_at', models.DateTimeField(help_text="Date d'expiration du lien de déploiement")),
                ('created_by', models.CharField(max_length=255)),
                ('download_count', models.IntegerField(default=0)),
                ('last_downloaded', models.DateTimeField(blank=True, null=True)),
                ('agents_installed', models.IntegerField(default=0)),
            ],
            options={
                'db_table': 'linux_deployments',
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='DeploymentLog',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('timestamp', models.DateTimeField(auto_now_add=True)),
                ('action', models.CharField(max_length=50)),
                ('ip_address', models.GenericIPAddressField(blank=True, null=True)),
                ('user_agent', models.TextField(blank=True)),
                ('hostname', models.CharField(blank=True, max_length=255)),
                ('error_message', models.TextField(blank=True)),
                ('deployment', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='logs', to='linux_deployments.linuxdeployment')),
            ],
            options={
                'db_table': 'deployment_logs',
                'ordering': ['-timestamp'],
            },
        ),
    ]
