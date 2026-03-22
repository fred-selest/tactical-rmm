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

def fix_script_types():
    """Corriger le script_type pour tous les scripts de surveillance"""
    print("🔧 Correction du script_type pour les scripts de surveillance...")
    
    # Trouver tous les scripts qui doivent être builtin
    monitoring_scripts = Script.objects.filter(
        name__icontains='surveillance'
    ) | Script.objects.filter(
        name__icontains='plesk'
    )
    
    corrected_count = 0
    
    for script in monitoring_scripts:
        if script.script_type != 'builtin':
            print(f"🔄 Correction de {script.name}: {script.script_type} → builtin")
            script.script_type = 'builtin'
            script.save()
            corrected_count += 1
        else:
            print(f"✅ {script.name} déjà correct")
    
    print(f"\n✅ {corrected_count} scripts corrigés avec succès!")

if __name__ == "__main__":
    fix_script_types()