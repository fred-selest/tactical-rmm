# 📁 Structure des Fichiers - Dashboard Linux Integration

> **Guide pour comprendre l'organisation des fichiers publics et privés**

## 🎯 Vue d'ensemble

Ce projet contient **deux ensembles de fichiers** :

1. **Fichiers PUBLICS** (committés dans Git) - avec domaines génériques
2. **Fichiers PRIVÉS** (ignorés par Git) - avec vos domaines réels

---

## 📂 Structure des Fichiers

### ✅ Fichiers Publics (dans Git)

Ces fichiers utilisent des **placeholders génériques** et peuvent être partagés publiquement :

```
tactical-rmm/
├── 📄 .gitignore                              ← Configuration Git
│
├── 🚀 SCRIPTS D'INSTALLATION (publics)
│   ├── install-interactive-public.sh         ← Script d'installation interactif
│   └── test-installation-public.sh           ← Script de tests automatiques
│
├── 📚 DOCUMENTATION (publique)
│   ├── START_HERE_PUBLIC.md                  ← Guide de démarrage
│   ├── INSTALLATION_GUIDE.md                 ← Guide d'installation complet
│   ├── GUIDE_UTILISATION_ADMIN_PUBLIC.md     ← Guide Admin Django
│   ├── QUICK_INSTALL.md                      ← Installation rapide
│   └── DASHBOARD_INTEGRATION_README.md       ← Architecture
│
└── 📁 integration/
    ├── backend/                              ← Code Django
    ├── frontend/                             ← (futur) Interface web
    └── docs/                                 ← Documentation technique
```

**Domaines utilisés dans les fichiers publics :**
- `rmm.votre-domaine.com`
- `api.votre-domaine.com`
- `mesh.votre-domaine.com`

### 🔒 Fichiers Privés (ignorés par Git)

Ces fichiers contiennent vos **domaines réels** et ne sont **PAS committés** :

```
tactical-rmm/
├── 🚀 SCRIPTS D'INSTALLATION (privés)
│   ├── install-interactive-private.sh        ← Pour votre serveur
│   └── test-installation-private.sh          ← Tests avec vos domaines
│
└── 📚 DOCUMENTATION (privée)
    ├── START_HERE_PRIVATE.md                 ← Guide personnalisé
    ├── INSTALLATION_PRIVATE.md               ← Guide avec vos domaines
    └── GUIDE_UTILISATION_ADMIN_PRIVATE.md    ← Guide personnalisé
```

**Vos domaines réels utilisés dans les fichiers privés :**
- `rmm.selest.info`
- `api.selest.info`
- `mesh.selest.info`

---

## 🔐 Protection des Informations Privées

### Le fichier `.gitignore` protège :

```gitignore
# Tous les fichiers privés
*-private.sh
*-private.md
*_PRIVATE.md
INSTALLATION_PRIVATE.md
START_HERE_PRIVATE.md
GUIDE_UTILISATION_ADMIN_PRIVATE.md

# Fichiers originaux avec domaines spécifiques
install-interactive.sh
test-installation.sh
INSTALLATION_RMM_SELEST_INFO.md
GUIDE_UTILISATION_ADMIN.md
START_HERE.md
```

---

## 🚀 Comment Utiliser

### Pour Vous (utilisation privée)

Utilisez les **fichiers PRIVÉS** qui contiennent vos domaines réels :

```bash
# Sur votre serveur rmm.selest.info
cd ~/tactical-rmm

# Lancer l'installation avec VOS domaines
sudo ./install-interactive-private.sh

# Tester avec VOS domaines
./test-installation-private.sh

# Lire la documentation personnalisée
cat START_HERE_PRIVATE.md
cat INSTALLATION_PRIVATE.md
```

### Pour Partager (version publique)

Les **fichiers PUBLICS** sont prêts à être partagés :

```bash
# Ces fichiers sont dans Git et peuvent être partagés
git add .gitignore
git add install-interactive-public.sh
git add test-installation-public.sh
git add INSTALLATION_GUIDE.md
git add GUIDE_UTILISATION_ADMIN_PUBLIC.md
git add START_HERE_PUBLIC.md

# Les fichiers privés ne seront PAS ajoutés (protégés par .gitignore)
git status  # Vérifier qu'aucun fichier privé n'apparaît
```

---

## 📋 Correspondance des Fichiers

| Usage | Fichier Public (Git) | Fichier Privé (Local) |
|-------|---------------------|----------------------|
| **Installation** | `install-interactive-public.sh` | `install-interactive-private.sh` |
| **Tests** | `test-installation-public.sh` | `test-installation-private.sh` |
| **Démarrage** | `START_HERE_PUBLIC.md` | `START_HERE_PRIVATE.md` |
| **Guide Installation** | `INSTALLATION_GUIDE.md` | `INSTALLATION_PRIVATE.md` |
| **Guide Admin** | `GUIDE_UTILISATION_ADMIN_PUBLIC.md` | `GUIDE_UTILISATION_ADMIN_PRIVATE.md` |

---

## 🔄 Workflow Git

### ✅ Ce qui sera committé

```bash
git status
# Fichiers à commiter :
#   .gitignore
#   install-interactive-public.sh
#   test-installation-public.sh
#   INSTALLATION_GUIDE.md
#   GUIDE_UTILISATION_ADMIN_PUBLIC.md
#   START_HERE_PUBLIC.md
```

### ❌ Ce qui sera ignoré (et c'est BIEN !)

```bash
# Ces fichiers restent sur VOTRE machine uniquement
#   install-interactive-private.sh       ← Avec api.selest.info
#   test-installation-private.sh         ← Avec mesh.selest.info
#   START_HERE_PRIVATE.md                ← Avec rmm.selest.info
#   INSTALLATION_PRIVATE.md
#   GUIDE_UTILISATION_ADMIN_PRIVATE.md
```

---

## 🛡️ Vérification de Sécurité

Avant de pousser sur GitHub, vérifiez toujours :

```bash
# 1. Vérifier qu'aucun fichier privé n'est tracké
git status

# 2. Vérifier le contenu des fichiers à commiter
git diff --cached

# 3. Chercher vos domaines dans les fichiers publics (ne devrait rien retourner)
grep -r "selest\.info" install-interactive-public.sh test-installation-public.sh *.md 2>/dev/null | grep -v "private\|PRIVATE"

# Si cette commande retourne des résultats, NE PAS COMMITER !
```

---

## 📝 Mettre à Jour les Fichiers

### Si vous modifiez un fichier public

```bash
# 1. Modifier le fichier public
nano install-interactive-public.sh

# 2. Copier les changements vers le fichier privé
cp install-interactive-public.sh install-interactive-private.sh

# 3. Remplacer les placeholders par vos domaines réels
sed -i 's/votre-domaine\.com/selest.info/g' install-interactive-private.sh
```

### Si vous modifiez un fichier privé

```bash
# 1. Modifier le fichier privé
nano install-interactive-private.sh

# 2. Copier vers le fichier public
cp install-interactive-private.sh install-interactive-public.sh

# 3. Remplacer vos domaines par des placeholders
sed -i 's/selest\.info/votre-domaine.com/g' install-interactive-public.sh
sed -i 's/api\.selest/api.votre-domaine/g' install-interactive-public.sh
sed -i 's/mesh\.selest/mesh.votre-domaine/g' install-interactive-public.sh
```

---

## 🔍 Exemple Concret

### Fichier Public (committé)

```bash
# install-interactive-public.sh (ligne 154)
echo "  • GET    https://api.votre-domaine.com/api/v3/linux-deployments/"
echo "  • POST   https://api.votre-domaine.com/api/v3/linux-deployments/create/"
```

### Fichier Privé (local uniquement)

```bash
# install-interactive-private.sh (ligne 154)
echo "  • GET    https://api.selest.info/api/v3/linux-deployments/"
echo "  • POST   https://api.selest.info/api/v3/linux-deployments/create/"
```

---

## 🎯 Commandes Rapides

### Utiliser les fichiers privés (usage quotidien)

```bash
# Installation sur votre serveur
sudo ./install-interactive-private.sh

# Tests
./test-installation-private.sh

# Documentation
less START_HERE_PRIVATE.md
```

### Préparer pour Git (partage public)

```bash
# Vérifier les fichiers à commiter
git status

# Vérifier qu'aucun domaine privé n'est présent
grep -r "selest\.info" $(git diff --cached --name-only) 2>/dev/null

# Commiter si tout est OK
git add .gitignore *-public.sh *_PUBLIC.md INSTALLATION_GUIDE.md
git commit -m "Add Linux Dashboard integration files (public version)"
git push
```

---

## ⚠️ Points d'Attention

### ✅ À FAIRE

- ✅ Toujours utiliser les fichiers **privés** sur votre serveur
- ✅ Vérifier `.gitignore` avant chaque commit
- ✅ Tester `git status` avant de pousser
- ✅ Garder les fichiers privés à jour avec les modifications

### ❌ À ÉVITER

- ❌ Ne **JAMAIS** commiter les fichiers `*-private.*`
- ❌ Ne **JAMAIS** commiter vos domaines réels
- ❌ Ne **JAMAIS** désactiver le `.gitignore`
- ❌ Ne **JAMAIS** faire `git add .` sans vérification

---

## 🆘 Aide Rapide

### "J'ai accidentellement committé un fichier privé"

```bash
# AVANT de pusher
git reset HEAD fichier-privé.sh
git checkout -- fichier-privé.sh

# APRÈS avoir pushé (DANGER!)
# Contactez immédiatement pour aide
# Nécessite de réécrire l'historique Git
```

### "Je ne suis pas sûr de ce qui sera committé"

```bash
# Voir tous les fichiers qui seront committés
git status

# Voir le contenu exact qui sera committé
git diff --cached

# Chercher vos domaines
git diff --cached | grep -i "selest"
# Ne devrait RIEN retourner !
```

### "Je veux réinitialiser mes fichiers privés"

```bash
# Regénérer les fichiers privés depuis les publics
cp install-interactive-public.sh install-interactive-private.sh
sed -i 's/votre-domaine\.com/selest.info/g' install-interactive-private.sh

# Pareil pour les autres fichiers
# ... répéter pour chaque fichier
```

---

## 📚 Documentation

Pour plus d'informations :

- **Installation :** Voir `START_HERE_PRIVATE.md` (votre version)
- **Guide complet :** Voir `INSTALLATION_PRIVATE.md` (votre version)
- **Admin Django :** Voir `GUIDE_UTILISATION_ADMIN_PRIVATE.md` (votre version)

---

## ✨ Résumé

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  📁 Fichiers PUBLICS (Git)                                  │
│     → Domaines génériques (votre-domaine.com)              │
│     → Peuvent être partagés publiquement                   │
│     → Committés dans Git                                    │
│                                                             │
│  🔒 Fichiers PRIVÉS (Local)                                 │
│     → Vos domaines réels (selest.info)                     │
│     → Restent sur votre machine                            │
│     → Protégés par .gitignore                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Vous êtes maintenant prêt à travailler en toute sécurité !** 🎉

---

**Auteur:** fred-selest
**Version:** 1.0.0
**Date:** Mars 2026
