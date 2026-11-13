#!/usr/bin/env python3

import os
import sys
import django
import unicodedata

# Ajouter le chemin de Tactical RMM
sys.path.append('/rmm/api/tacticalrmm')

# Configurer les paramètres Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tacticalrmm.settings')
django.setup()

from scripts.models import Script

def remove_accents(input_str):
    """Supprimer les accents d'une chaîne"""
    nfkd_form = unicodedata.normalize('NFKD', input_str)
    return "".join([c for c in nfkd_form if not unicodedata.combining(c)])

def generate_clean_filename(script_name, category):
    """Générer un nom de fichier propre sans caractères spéciaux"""
    # Supprimer les accents
    clean_name = remove_accents(script_name)
    # Remplacer les espaces et caractères spéciaux par underscores
    clean_name = "".join(c if c.isalnum() or c in " _-" else "_" for c in clean_name)
    clean_name = clean_name.replace(" ", "_").replace("-", "_")
    clean_name = "_".join(filter(None, clean_name.split("_")))  # Supprimer les underscores multiples
    
    # Ajouter le préfixe selon la catégorie
    category_prefixes = {
        "plesk": "Plesk",
        "synology": "Synology", 
        "system": "Linux",
        "docker": "Docker",
        "database": "DB"
    }
    
    prefix = category_prefixes.get(category.lower(), "Custom")
    return f"{prefix}_{clean_name}.sh"

def fix_filenames():
    """Corriger les noms de fichiers pour supprimer les caractères spéciaux"""
    print("🔧 Correction des noms de fichiers...")
    
    scripts_to_fix = Script.objects.filter(
        script_type='builtin',
        guid__isnull=False
    )
    
    # Filtrer les scripts qui ont des caractères non ASCII dans le filename
    final_scripts = []
    for script in scripts_to_fix:
        if script.filename and any(ord(c) > 127 for c in script.filename):
            final_scripts.append(script)
    
    print(f"Scripts à corriger: {len(final_scripts)}")
    
    fixed_count = 0
    
    for script in scripts_to_fix:
        old_filename = script.filename
        new_filename = generate_clean_filename(script.name, script.category)
        
        if old_filename != new_filename:
            script.filename = new_filename
            script.save()
            print(f"✅ {old_filename} → {new_filename}")
            fixed_count += 1
    
    print(f"\n✅ {fixed_count} noms de fichiers corrigés!")

if __name__ == "__main__":
    fix_filenames()