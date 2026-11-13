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

def add_descriptions():
    """Ajouter des descriptions aux scripts"""
    print("📝 Ajout des descriptions...")
    
    # Dictionnaire des descriptions par nom de script
    descriptions = {
        # Scripts Plesk
        "Plesk - Surveillance complète": "Surveillance complète d'un serveur Plesk : services, disque, SSL, mail, sauvegarde, sécurité, Docker",
        "Plesk - Vérification services": "Vérification de l'état des services Plesk (nginx, apache, mysql, postfix, etc.)",
        "Plesk - Vérification disque": "Surveillance de l'utilisation disque par abonnement et espace système",
        "Plesk - Vérification SSL": "Vérification des certificats SSL et alerte si expiration imminente",
        "Plesk - Vérification mail": "Surveillance de la file d'attente mail et alerte si trop de messages en attente",
        "Plesk - Vérification sauvegarde": "Vérification de l'état des sauvegardes Plesk et alerte si trop anciennes",
        "Plesk - Vérification sécurité": "Vérification des mises à jour de sécurité Plesk et configuration de base",
        "Plesk - Vérification Docker": "Surveillance des conteneurs Docker sur le serveur Plesk",
        "Plesk - Vérification Docker Compose": "Vérification de l'état des stacks Docker Compose",
        "Plesk - Vérification tout": "Exécution de toutes les vérifications Plesk en une seule commande",
        
        # Scripts Synology
        "Synology - Surveillance complète": "Surveillance complète d'un NAS Synology : services, disques, sauvegarde, sécurité, RAID",
        "Synology - Vérification tout": "Exécution de toutes les vérifications Synology en une seule commande",
        "Synology - Vérification système": "Vérification de l'état du système Synology et des services",
        "Synology - Vérification disques": "Surveillance de l'état des disques durs Synology",
        "Synology - Vérification RAID": "Vérification de l'état du RAID/SHR Synology",
        "Synology - Vérification services": "Surveillance des services Synology (File Station, Download Station, etc.)",
        "Synology - Vérification sauvegarde": "Vérification de l'état des tâches de sauvegarde Synology",
        "Synology - Vérification HyperBackup": "Surveillance des tâches HyperBackup et alerte si échec",
        "Synology - Vérification sécurité": "Vérification des mises à jour de sécurité et configuration",
        
        # Scripts Système
        "Surveillance CPU": "Surveillance de l'utilisation CPU, charge système et température",
        "Surveillance Mémoire": "Surveillance de l'utilisation mémoire, swap et pression mémoire",
        "Surveillance Disque": "Surveillance de l'espace disque, inodes et E/S disque",
        "Surveillance Réseau": "Surveillance de la connectivité réseau, latence et statistiques",
        "Surveillance Système Complète": "Surveillance complète du système : CPU, mémoire, disque, réseau",
        
        # Scripts Docker
        "Surveillance Docker": "Surveillance complète de l'environnement Docker : conteneurs, images, volumes, espace disque",
        
        # Scripts Bases de données
        "Surveillance MySQL/MariaDB": "Surveillance complète de MySQL/MariaDB : connexions, performance, espace disque, réplication",
        "Surveillance PostgreSQL": "Surveillance complète de PostgreSQL : connexions, requêtes longues, verrous, autovacuum",
        "Surveillance Bases de Données Complète": "Surveillance des bases de données installées (MySQL, PostgreSQL)"
    }
    
    updated_count = 0
    
    for script_name, description in descriptions.items():
        try:
            script = Script.objects.get(name=script_name)
            if not script.description or script.description.strip() == "":
                script.description = description
                script.save()
                print(f"✅ {script_name}")
                updated_count += 1
        except Script.DoesNotExist:
            print(f"⚠️  {script_name} non trouvé")
    
    print(f"\n✅ {updated_count} descriptions ajoutées!")

if __name__ == "__main__":
    add_descriptions()