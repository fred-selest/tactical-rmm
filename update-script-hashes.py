#!/usr/bin/env python3

import os
import sys
import django
import hashlib
import hmac

# Ajouter le chemin de Tactical RMM
sys.path.append('/rmm/api/tacticalrmm')

# Configurer les paramètres Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tacticalrmm.settings')
django.setup()

from scripts.models import Script
from django.conf import settings

def update_script_hashes():
    """Mettre à jour les hashes des scripts"""
    print("🔧 Mise à jour des hashes des scripts...")
    
    # Trouver tous les scripts builtin avec guid
    scripts_to_update = Script.objects.filter(
        script_type='builtin',
        guid__isnull=False
    )
    
    print(f"Scripts à mettre à jour: {scripts_to_update.count()}")
    
    updated_count = 0
    
    for script in scripts_to_update:
        if script.script_body:
            # Calculer le hash
            msg = script.code.encode(errors="ignore")
            script_hash = hmac.new(settings.SECRET_KEY.encode(), msg, hashlib.sha256).hexdigest()
            
            # Mettre à jour le hash
            script.script_hash = script_hash
            script.save()
            updated_count += 1
    
    print(f"\n✅ {updated_count} scripts mis à jour avec succès!")

if __name__ == "__main__":
    update_script_hashes()