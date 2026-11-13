#!/usr/bin/env python3

import os
import sys
import django
from pathlib import Path

# Ajouter le chemin de Tactical RMM
sys.path.append('/rmm/api/tacticalrmm')

# Configurer les paramètres Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tacticalrmm.settings')
django.setup()

from scripts.models import Script

def read_script_file(filepath):
    """Lire le contenu d'un fichier de script"""
    try:
        with open(filepath, 'r') as f:
            return f.read()
    except FileNotFoundError:
        return None

def import_plesk_scripts():
    """Importer tous les scripts Plesk dans la base de données"""
    print("🚀 Importation des scripts Plesk...")
    
    tactical_rmm_path = Path("/home/debian/tactical-rmm")
    plesk_scripts = [
        ("Plesk - Surveillance complète", "scripts/plesk/plesk_surveillance_complete.sh"),
        ("Plesk - Vérification services", "scripts/plesk/plesk_check_services.sh"),
        ("Plesk - Vérification disque", "scripts/plesk/plesk_check_disk.sh"),
        ("Plesk - Vérification SSL", "scripts/plesk/plesk_check_ssl.sh"),
        ("Plesk - Vérification mail", "scripts/plesk/plesk_check_mail.sh"),
        ("Plesk - Vérification sauvegarde", "scripts/plesk/plesk_check_backup.sh"),
        ("Plesk - Vérification sécurité", "scripts/plesk/plesk_check_security.sh"),
        ("Plesk - Vérification Docker", "scripts/plesk/plesk_check_docker.sh"),
        ("Plesk - Vérification Docker Compose", "scripts/plesk/plesk_check_docker_compose.sh"),
        ("Plesk - Vérification tout", "scripts/plesk/plesk_check_all.sh"),
    ]
    
    success_count = 0
    
    for name, filepath in plesk_scripts:
        full_path = tactical_rmm_path / filepath
        content = read_script_file(str(full_path))
        
        if content is None:
            print(f"⚠️  Fichier non trouvé: {filepath}")
            continue
        
        # Vérifier si le script existe déjà
        existing = Script.objects.filter(name=name).first()
        if existing:
            print(f"🔄 Mise à jour du script existant: {name}")
            existing.script_body = content
            existing.category = "Plesk"
            existing.supported_platforms = ['linux']
            existing.shell = 'shell'
            existing.save()
        else:
            print(f"➕ Création du nouveau script: {name}")
            Script.objects.create(
                name=name,
                script_type='shell',
                shell='shell',
                category='Plesk',
                script_body=content,
                supported_platforms=['linux']
            )
        
        success_count += 1
    
    print(f"\n✅ {success_count} scripts Plesk importés avec succès!")

if __name__ == "__main__":
    import_plesk_scripts()