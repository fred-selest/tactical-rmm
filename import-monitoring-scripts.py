#!/usr/bin/env python3
"""Importeur canonique des scripts de surveillance dans Tactical RMM.

Utilisé par update-tactical-rmm.sh (import_updated_scripts) et par
install-automated.sh (import_monitoring_scripts). C'est volontairement le SEUL
endroit où la liste des scripts est décrite : une seconde copie embarquée dans
un heredoc avait divergé (scripts Synology absents) et les deux chemins
n'importaient pas le même jeu de scripts.

Usage:
    import-monitoring-scripts.py [REPO_DIR] [RMM_DIR]

REPO_DIR  repertoire du depot contenant scripts/  (defaut: repertoire courant)
RMM_DIR   chemin de l'application Django       (defaut: /rmm/api/tacticalrmm)

Sortie:
    RESULTAT_IMPORT <importes> <manquants>  sur stdout, consomme par le shell.
"""

import os
import sys
import traceback
from pathlib import Path

REPO_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    os.environ.get("TACTICAL_RMM_REPO_DIR") or os.getcwd()
)
RMM_DIR = sys.argv[2] if len(sys.argv) > 2 else os.environ.get(
    "RMM_PATH", "/rmm/api/tacticalrmm"
)

sys.path.insert(0, RMM_DIR)
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tacticalrmm.settings')

import django
django.setup()

from scripts.models import Script


def read_script_file(filepath):
    """Lire le contenu d'un fichier de script. Retourne None si illisible."""
    try:
        with open(filepath, 'r') as f:
            return f.read()
    except (FileNotFoundError, IsADirectoryError, PermissionError, UnicodeDecodeError) as e:
        print(f"AVERTISSEMENT fichier illisible {filepath}: {e}")
        return None


def import_script(name, filepath, category, supported_platforms=None):
    """Importer un script dans la base. Retourne True/False, ne lève pas."""
    supported_platforms = supported_platforms or ['linux']
    content = read_script_file(filepath)
    if content is None:
        return False

    try:
        existing = Script.objects.filter(name=name).first()
        if existing:
            existing.script_body = content
            existing.category = category
            existing.supported_platforms = supported_platforms
            existing.shell = 'shell'
            existing.save()
        else:
            Script.objects.create(
                name=name,
                script_type='shell',
                shell='shell',
                category=category,
                script_body=content,
                supported_platforms=supported_platforms
            )
    except Exception:
        # Un script en erreur ne doit pas interrompre tout le lot.
        print(f"ERREUR import {name}:")
        traceback.print_exc(file=sys.stdout)
        return False

    return True


def all_scripts():
    return (
        [
            ("Surveillance CPU", "scripts/system/check-cpu.sh", "System"),
            ("Surveillance Mémoire", "scripts/system/check-memory.sh", "System"),
            ("Surveillance Disque", "scripts/system/check-disk.sh", "System"),
            ("Surveillance Réseau", "scripts/system/check-network.sh", "System"),
            ("Surveillance Système Complète", "scripts/system/check-system.sh", "System"),
        ] + [
            ("Surveillance Docker", "scripts/docker/check-docker.sh", "Docker"),
        ] + [
            ("Surveillance MySQL/MariaDB", "scripts/database/check-mysql.sh", "Database"),
            ("Surveillance PostgreSQL", "scripts/database/check-postgresql.sh", "Database"),
            ("Surveillance Bases de Données Complète", "scripts/database/check-database.sh", "Database"),
        ] + [
            ("Plesk - Surveillance complète", "scripts/plesk/plesk_surveillance_complete.sh", "Plesk"),
            ("Plesk - Vérification services", "scripts/plesk/plesk_check_services.sh", "Plesk"),
            ("Plesk - Vérification disque", "scripts/plesk/plesk_check_disk.sh", "Plesk"),
            ("Plesk - Vérification SSL", "scripts/plesk/plesk_check_ssl.sh", "Plesk"),
            ("Plesk - Vérification mail", "scripts/plesk/plesk_check_mail.sh", "Plesk"),
            ("Plesk - Vérification sauvegarde", "scripts/plesk/plesk_check_backup.sh", "Plesk"),
            ("Plesk - Vérification sécurité", "scripts/plesk/plesk_check_security.sh", "Plesk"),
            ("Plesk - Vérification Docker", "scripts/plesk/plesk_check_docker.sh", "Plesk"),
            ("Plesk - Vérification Docker Compose", "scripts/plesk/plesk_check_docker_compose.sh", "Plesk"),
            ("Plesk - Vérification tout", "scripts/plesk/plesk_check_all.sh", "Plesk"),
        ] + [
            ("Synology - Surveillance complète", "scripts/synology/synology_surveillance_complete.sh", "Synology"),
            ("Synology - Vérification tout", "scripts/synology/synology_check_all.sh", "Synology"),
            ("Synology - Vérification système", "scripts/synology/synology_check_system.sh", "Synology"),
            ("Synology - Vérification disques", "scripts/synology/synology_check_disks.sh", "Synology"),
            ("Synology - Vérification RAID", "scripts/synology/synology_check_raid.sh", "Synology"),
            ("Synology - Vérification services", "scripts/synology/synology_check_services.sh", "Synology"),
            ("Synology - Vérification sauvegarde", "scripts/synology/synology_check_backup.sh", "Synology"),
            ("Synology - Vérification HyperBackup", "scripts/synology/synology_check_hyperbackup.sh", "Synology"),
            ("Synology - Vérification sécurité", "scripts/synology/synology_check_security.sh", "Synology"),
        ]
    )


def main():
    scripts = all_scripts()
    print(f"Importation de {len(scripts)} scripts depuis {REPO_DIR}")

    imported, missing = 0, []
    for name, relpath, category in scripts:
        if import_script(name, str(REPO_DIR / relpath), category):
            imported += 1
        else:
            missing.append(name)

    # Ligne machine-lisible, lue par update-tactical-rmm.sh et
    # install-automated.sh pour ne plus annoncer un succès au vide.
    print(f"RESULTAT_IMPORT {imported} {len(missing)}")
    for name in missing:
        print(f"MANQUANT {name}")

    return 0 if imported else 1


if __name__ == "__main__":
    sys.exit(main())
