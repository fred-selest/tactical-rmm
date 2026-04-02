#!/usr/bin/env python3

import os
import sys
import django
import uuid
from pathlib import Path

# Ajouter le chemin de Tactical RMM
sys.path.append('/rmm/api/tacticalrmm')

# Configurer les paramètres Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tacticalrmm.settings')
django.setup()

from scripts.models import Script

def generate_filename(script_name, category):
    """Générer un nom de fichier à partir du nom du script"""
    # Supprimer les caractères spéciaux et espaces
    clean_name = script_name.replace(" ", "_").replace("-", "_")
    clean_name = "".join(c for c in clean_name if c.isalnum() or c in "_")
    
    # Ajouter le préfixe selon la catégorie
    if category.lower() == "plesk":
        prefix = "Plesk_"
    elif category.lower() == "synology":
        prefix = "Synology_"
    elif category.lower() == "system":
        prefix = "Linux_"
    elif category.lower() == "docker":
        prefix = "Docker_"
    elif category.lower() == "database":
        prefix = "DB_"
    else:
        prefix = "Custom_"
    
    return f"{prefix}{clean_name}.sh"

def fix_script_guids():
    """Ajouter GUID et filename aux scripts manquants"""
    print("🔧 Correction des GUID et filenames pour les scripts...")
    
    # Trouver tous les scripts builtin sans guid
    scripts_to_fix = Script.objects.filter(
        script_type='builtin',
        guid__isnull=True
    )
    
    print(f"Scripts à corriger: {scripts_to_fix.count()}")
    
    fixed_count = 0
    
    for script in scripts_to_fix:
        if not script.guid:
            script.guid = str(uuid.uuid4())
            script.filename = generate_filename(script.name, script.category)
            script.save()
            print(f"✅ {script.name} → {script.filename}")
            fixed_count += 1
    
    print(f"\n✅ {fixed_count} scripts corrigés avec succès!")

if __name__ == "__main__":
    fix_script_guids()