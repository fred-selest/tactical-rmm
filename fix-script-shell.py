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

def fix_script_shell():
    """Corriger le champ shell pour les scripts de surveillance"""
    print("🔧 Correction du champ shell pour les scripts de surveillance...")
    
    # Scripts à corriger
    surveillance_scripts = [
        "Surveillance CPU",
        "Surveillance Mémoire", 
        "Surveillance Disque",
        "Surveillance Réseau",
        "Surveillance Système Complète",
        "Surveillance Docker",
        "Surveillance MySQL/MariaDB",
        "Surveillance PostgreSQL",
        "Surveillance Bases de Données Complète"
    ]
    
    corrected_count = 0
    
    for script_name in surveillance_scripts:
        try:
            script = Script.objects.get(name=script_name)
            if script.shell != 'shell':
                print(f"🔄 Correction de {script_name}: {script.shell} → shell")
                script.shell = 'shell'
                script.save()
                corrected_count += 1
            else:
                print(f"✅ {script_name} déjà correct")
        except Script.DoesNotExist:
            print(f"⚠️  {script_name} non trouvé")
    
    print(f"\n✅ {corrected_count} scripts corrigés avec succès!")

if __name__ == "__main__":
    fix_script_shell()