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

def examine_scripts():
    print(f"Total de scripts dans la base: {Script.objects.count()}")
    
    # Afficher les scripts Linux
    linux_scripts = Script.objects.filter(supported_platforms__contains=['linux'])
    print(f"\nScripts Linux: {linux_scripts.count()}")
    for script in linux_scripts:
        print(f"- {script.name} (Catégorie: {script.category})")

if __name__ == "__main__":
    examine_scripts()