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

def verify_scripts():
    """Vérifier que tous les scripts sont correctement configurés"""
    print("🔍 Vérification des scripts...")
    
    # Scripts Plesk
    plesk_scripts = Script.objects.filter(name__icontains='plesk')
    print(f"Scripts Plesk: {plesk_scripts.count()}")
    
    for script in plesk_scripts:
        issues = []
        
        if not script.guid:
            issues.append("pas de GUID")
        if not script.filename:
            issues.append("pas de filename")
        if not script.script_hash:
            issues.append("pas de hash")
        if script.hidden:
            issues.append("masqué")
        if script.script_type != 'builtin':
            issues.append(f"mauvais type: {script.script_type}")
        if script.shell != 'shell':
            issues.append(f"mauvais shell: {script.shell}")
        if 'linux' not in (script.supported_platforms or []):
            issues.append(f"mauvaises plateformes: {script.supported_platforms}")
            
        if issues:
            print(f"  ❌ {script.name}: {', '.join(issues)}")
        else:
            print(f"  ✅ {script.name}")
    
    # Vérifier un script spécifique
    if plesk_scripts.exists():
        test_script = plesk_scripts.first()
        print(f"\nDétails du script de test:")
        print(f"  name: {test_script.name}")
        print(f"  guid: {test_script.guid}")
        print(f"  filename: {test_script.filename}")
        print(f"  script_type: {test_script.script_type}")
        print(f"  shell: {test_script.shell}")
        print(f"  category: {test_script.category}")
        print(f"  supported_platforms: {test_script.supported_platforms}")
        print(f"  hidden: {test_script.hidden}")
        print(f"  script_hash: {'oui' if test_script.script_hash else 'non'}")
    
    print(f"\n✅ Vérification terminée!")

if __name__ == "__main__":
    verify_scripts()