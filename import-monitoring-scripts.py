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
        print(f"⚠️  Fichier non trouvé: {filepath}")
        return None

def import_script(name, filepath, category, supported_platforms=['linux']):
    """Importer un script dans la base de données"""
    content = read_script_file(filepath)
    if content is None:
        return False
    
    # Vérifier si le script existe déjà
    existing = Script.objects.filter(name=name).first()
    if existing:
        print(f"🔄 Mise à jour du script existant: {name}")
        existing.script_body = content
        existing.category = category
        existing.supported_platforms = supported_platforms
        existing.save()
    else:
        print(f"➕ Création du nouveau script: {name}")
        Script.objects.create(
            name=name,
            script_type='shell',
            category=category,
            script_body=content,
            supported_platforms=supported_platforms
        )
    
    return True

def main():
    """Importer tous les scripts de surveillance avancée"""
    print("🚀 Importation des scripts de surveillance avancée...")
    
    tactical_rmm_path = Path("/home/debian/tactical-rmm")
    
    # Scripts système
    system_scripts = [
        ("Surveillance CPU", "scripts/system/check-cpu.sh", "System"),
        ("Surveillance Mémoire", "scripts/system/check-memory.sh", "System"),
        ("Surveillance Disque", "scripts/system/check-disk.sh", "System"),
        ("Surveillance Réseau", "scripts/system/check-network.sh", "System"),
        ("Surveillance Système Complète", "scripts/system/check-system.sh", "System"),
    ]
    
    # Scripts Docker
    docker_scripts = [
        ("Surveillance Docker", "scripts/docker/check-docker.sh", "Docker"),
    ]
    
    # Scripts bases de données
    database_scripts = [
        ("Surveillance MySQL/MariaDB", "scripts/database/check-mysql.sh", "Database"),
        ("Surveillance PostgreSQL", "scripts/database/check-postgresql.sh", "Database"),
        ("Surveillance Bases de Données Complète", "scripts/database/check-database.sh", "Database"),
    ]
    
    all_scripts = system_scripts + docker_scripts + database_scripts
    
    success_count = 0
    total_count = len(all_scripts)
    
    for name, filepath, category in all_scripts:
        full_path = tactical_rmm_path / filepath
        if import_script(name, str(full_path), category):
            success_count += 1
    
    print(f"\n✅ {success_count}/{total_count} scripts importés avec succès!")
    print("Les scripts sont maintenant disponibles dans le Script Manager de Tactical RMM.")

if __name__ == "__main__":
    main()