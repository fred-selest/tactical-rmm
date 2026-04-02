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

def fix_script_type():
    """Changer le script_type de builtin à userdefined pour éviter le filtre Community Scripts"""
    print("🔧 Changement du script_type pour éviter le filtre Community Scripts...")
    
    # Identifier nos scripts par leurs catégories
    our_categories = [
        "TRMM (Linux):System Monitoring",
        "TRMM (Linux):Docker", 
        "TRMM (Linux):Database",
        "TRMM (Linux):Plesk",
        "TRMM (Linux):Synology"
    ]
    
    scripts_to_update = Script.objects.filter(category__in=our_categories)
    count = scripts_to_update.count()
    
    if count > 0:
        print(f"  Mise à jour de {count} scripts...")
        # Changer le script_type
        scripts_to_update.update(script_type='userdefined')
        # Supprimer le guid et filename car ils ne sont pas nécessaires pour userdefined
        scripts_to_update.update(guid=None, filename=None)
        print(f"✅ {count} scripts mis à jour en userdefined!")
    else:
        print("⚠️  Aucun script trouvé à mettre à jour")
    
    # Vérifier un script Plesk
    plesk_script = Script.objects.filter(name__icontains='plesk').first()
    if plesk_script:
        print(f"\nVérification:")
        print(f"  name: {plesk_script.name}")
        print(f"  script_type: {plesk_script.script_type}")
        print(f"  guid: {plesk_script.guid}")
        print(f"  category: {plesk_script.category}")

if __name__ == "__main__":
    fix_script_type()