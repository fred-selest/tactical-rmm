# Guide de Test - Intégration Dashboard Linux

Ce guide vous permet de vérifier que l'installation fonctionne correctement.

## ✅ Checklist de Vérification

### 1. Backend Django

```bash
# Vérifier qu'il n'y a pas d'erreurs
cd /rmm/api/tacticalrmm
sudo -u tactical /rmm/api/env/bin/python manage.py check
```

✅ **Résultat attendu** : `System check identified no issues (0 silenced).`

---

### 2. Service Actif

```bash
# Vérifier que le service est actif
systemctl status rmm.service
```

✅ **Résultat attendu** : `Active: active (running)`

---

### 3. API Accessible

```bash
# Remplacer par votre domaine
curl -I https://api.votre-domaine.com/api/v3/linux-deployments/
```

✅ **Résultat attendu** : `HTTP/1.1 401 Unauthorized`

❌ Si vous obtenez `404 Not Found`, l'API n'est pas configurée correctement.

---

### 4. Créer un Déploiement de Test

**Option A : Script interactif (Recommandé)**

```bash
cd ~/tactical-rmm
./create-deployment.sh
```

Suivez les instructions à l'écran.

**Option B : Via Django Shell**

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell
```

```python
from linux_deployments.models import LinuxDeployment
from datetime import timedelta
from django.utils import timezone

deployment = LinuxDeployment.objects.create(
    client_id=1,
    client_name="Test Client",
    site_id=1,
    site_name="Test Site",
    agent_type="server",
    arch="amd64",
    api_url="https://api.votre-domaine.com",
    mesh_url="https://mesh.votre-domaine.com/meshagents?id=test",
    auth_key="test-key",
    enable_ping=True,
    install_mesh=True,
    expires_at=timezone.now() + timedelta(days=30),
    created_by="test"
)

print(f"UUID: {deployment.uuid}")
print(f"URL: https://api.votre-domaine.com/clients/{deployment.uuid}/deploy/linux/")
```

✅ **Résultat attendu** : UUID et URL affichés

---

### 5. Tester l'URL Publique

```bash
# Remplacer {uuid} par l'UUID obtenu à l'étape 4
curl -I https://api.votre-domaine.com/clients/{uuid}/deploy/linux/
```

✅ **Résultat attendu** :
```
HTTP/1.1 200 OK
Content-Type: text/x-shellscript
Content-Disposition: attachment; filename="install-rmm-agent-{uuid}.sh"
```

---

### 6. Télécharger le Script

```bash
# Télécharger et afficher le script
curl https://api.votre-domaine.com/clients/{uuid}/deploy/linux/ | head -30
```

✅ **Résultat attendu** : Script bash avec vos informations (client, site, etc.)

---

### 7. Lister les Déploiements

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell << 'PYTHON'
from linux_deployments.models import LinuxDeployment

deployments = LinuxDeployment.objects.all()
print(f"\nTotal: {deployments.count()} déploiement(s)\n")

for d in deployments:
    status = "🔴 Expiré" if d.is_expired() else "🟢 Actif"
    print(f"{status} | {d.client_name}/{d.site_name}")
    print(f"   UUID: {d.uuid}")
    print(f"   Téléchargements: {d.download_count}")
    print()
PYTHON
```

✅ **Résultat attendu** : Liste de vos déploiements

---

### 8. Tester sur un Serveur Linux (Optionnel)

Si vous avez un serveur Linux de test :

```bash
# Sur le serveur Linux
wget https://api.votre-domaine.com/clients/{uuid}/deploy/linux/ -O install-test.sh
chmod +x install-test.sh

# Voir le contenu sans l'exécuter
cat install-test.sh
```

✅ **Résultat attendu** : Script avec tous les paramètres pré-configurés

---

### 9. Vérifier les Statistiques

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell << 'PYTHON'
from linux_deployments.models import LinuxDeployment

stats = {
    'total': LinuxDeployment.objects.count(),
    'actifs': LinuxDeployment.objects.filter(expires_at__gt=timezone.now()).count(),
    'downloads': sum(d.download_count for d in LinuxDeployment.objects.all()),
    'installations': sum(d.agents_installed for d in LinuxDeployment.objects.all()),
}

print("\n📊 Statistiques:")
print(f"  Total déploiements: {stats['total']}")
print(f"  Déploiements actifs: {stats['actifs']}")
print(f"  Téléchargements: {stats['downloads']}")
print(f"  Installations: {stats['installations']}")
PYTHON
```

---

### 10. Activer l'Admin Django (Optionnel)

```bash
# 1. Éditer local_settings.py
sudo nano /rmm/api/tacticalrmm/tacticalrmm/local_settings.py
```

Ajouter ou modifier :
```python
ADMIN_ENABLED = True
```

```bash
# 2. Créer un superuser
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py createsuperuser

# 3. Redémarrer
sudo systemctl restart rmm.service

# 4. Tester l'accès
curl -I https://api.votre-domaine.com/admin/
```

✅ **Résultat attendu** : `HTTP/1.1 302 Found` (redirection vers login)

Ouvrir dans un navigateur : `https://api.votre-domaine.com/admin/`

---

## 🐛 Problèmes Courants

### Problème : 404 Not Found sur l'API

**Solution** :
```bash
# Vérifier que les URLs sont bien configurées
grep -A 5 "linux_deployments" /rmm/api/tacticalrmm/tacticalrmm/urls.py

# Redémarrer le service
sudo systemctl restart rmm.service
```

---

### Problème : ModuleNotFoundError

**Solution** :
```bash
# Vérifier que l'app est dans INSTALLED_APPS
grep "linux_deployments" /rmm/api/tacticalrmm/tacticalrmm/settings.py

# Si absent, relancer l'installation
cd ~/tactical-rmm
sudo ./install-backend.sh
```

---

### Problème : Les migrations ne s'appliquent pas

**Solution** :
```bash
cd /rmm/api/tacticalrmm
sudo -u tactical /rmm/api/env/bin/python manage.py makemigrations linux_deployments
sudo -u tactical /rmm/api/env/bin/python manage.py migrate linux_deployments
sudo systemctl restart rmm.service
```

---

### Problème : Permission denied

**Solution** :
```bash
# Ajuster les permissions
sudo chown -R tactical:tactical /rmm/api/tacticalrmm/linux_deployments/
```

---

## 📊 Tests de Performance

### Test de charge (optionnel)

```bash
# Créer 10 déploiements de test
for i in {1..10}; do
    sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell << PYTHON
from linux_deployments.models import LinuxDeployment
from datetime import timedelta
from django.utils import timezone

LinuxDeployment.objects.create(
    client_id=$i,
    client_name="Test Client $i",
    site_id=$i,
    site_name="Test Site $i",
    agent_type="server",
    arch="amd64",
    api_url="https://api.votre-domaine.com",
    mesh_url="https://mesh.votre-domaine.com/meshagents?id=test$i",
    auth_key="test-key-$i",
    enable_ping=True,
    install_mesh=True,
    expires_at=timezone.now() + timedelta(days=30),
    created_by="test"
)
PYTHON
done

echo "✓ 10 déploiements créés"
```

### Nettoyer les déploiements de test

```bash
sudo -u tactical /rmm/api/env/bin/python /rmm/api/tacticalrmm/manage.py shell << 'PYTHON'
from linux_deployments.models import LinuxDeployment

# Supprimer tous les déploiements de test
deleted = LinuxDeployment.objects.filter(created_by="test").delete()
print(f"✓ {deleted[0]} déploiements de test supprimés")
PYTHON
```

---

## ✅ Checklist Finale

- [ ] Backend Django sans erreurs (`manage.py check`)
- [ ] Service rmm.service actif
- [ ] API retourne 401 (authentification requise)
- [ ] URL publique retourne 200 et un script
- [ ] Script contient les bonnes informations
- [ ] Déploiements créés et listables
- [ ] Statistiques accessibles
- [ ] (Optionnel) Admin Django accessible

---

## 🎉 Si tous les tests passent

**Félicitations ! L'intégration est fonctionnelle.**

Vous pouvez maintenant :
1. Créer des déploiements réels
2. Installer des agents Linux
3. Suivre les installations dans le dashboard
4. Utiliser l'admin Django pour gérer visuellement

---

## 📞 Support

Si un test échoue :
1. Vérifiez les logs : `journalctl -u rmm.service -n 50`
2. Relancez l'installation : `sudo ./install-backend.sh`
3. Consultez la documentation : `integration/docs/INTEGRATION_GUIDE.md`
4. Ouvrez une issue GitHub

---

**Bon déploiement ! 🚀**
