#!/usr/bin/env python3

import os
import sys
import django

# Ajouter le chemin de Tactical RMM
sys.path.append('/rmm/api/tacticalrmm')

# Configurer les paramètres Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tacticalrmm.settings')
django.setup()

from scripts.models import Script

def fix_categories():
    """Corriger les catégories pour suivre le format TRMM"""
    print("🔧 Correction des catégories...")
    
    # Dictionnaire de correspondance
    category_mapping = {
        "System": "TRMM (Linux):System Monitoring",
        "Docker": "TRMM (Linux):Docker", 
        "Database": "TRMM (Linux):Database",
        "Plesk": "TRMM (Linux):Plesk",
        "Synology": "TRMM (Linux):Synology"
    }
    
    fixed_count = 0
    
    for old_category, new_category in category_mapping.items():
        scripts = Script.objects.filter(category=old_category)
        count = scripts.count()
        if count > 0:
            print(f"  {old_category} → {new_category} ({count} scripts)")
            scripts.update(category=new_category)
            fixed_count += count
    
    print(f"\n✅ {fixed_count} scripts mis à jour avec les bonnes catégories!")

if __name__ == "__main__":
    fix_categories()