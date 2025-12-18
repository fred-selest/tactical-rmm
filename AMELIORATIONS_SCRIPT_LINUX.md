# Améliorations du script LinuxRMM

## Analyse du script actuel

Le script `rmmagent-linux.sh` fonctionne bien pour une installation de base, mais présente plusieurs limitations découvertes lors de nos tests, notamment avec Synology.

## Problèmes identifiés

### 1. ⚠️ CRITIQUE : Partition système pleine

**Problème :** Le script installe Go dans `/usr/local/go/` (244 MB) et l'agent dans `/usr/local/bin/`, ce qui remplit les partitions système de petite taille (ex: Synology `/dev/md0` = 2.3 GB).

**Solution proposée :**
```bash
# Détection de Synology et installation dans /volume1
if [ -f /etc/synoinfo.conf ]; then
    INSTALL_PATH="/volume1/@appstore/tactical-rmm"
    GO_PATH="/volume1/@appstore/tactical-rmm/go"
else
    INSTALL_PATH="/opt/tacticalrmm"
    GO_PATH="/usr/local/go"
fi

mkdir -p "$INSTALL_PATH"
```

### 2. ❌ Go jamais désinstallé

**Problème :** Go est installé mais jamais nettoyé, même après compilation.

**Solution proposée :**
```bash
function go_cleanup() {
    echo "Nettoyage de Go..."
    rm -rf /usr/local/go/
    # Nettoyer aussi le cache Go
    rm -rf ~/go/
}

# Appeler après compilation :
agent_compile
go_cleanup  # ← Ajouter ceci
```

### 3. ⚠️ Aucune vérification des dépendances

**Problème :** Le script suppose que `wget`, `tar`, `systemd` sont disponibles.

**Solution proposée :**
```bash
function check_dependencies() {
    local missing=()

    for cmd in wget tar systemctl; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERREUR: Dépendances manquantes: ${missing[*]}"
        echo "Installation automatique..."

        # Détection du gestionnaire de paquets
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y wget tar systemd
        elif command -v yum &> /dev/null; then
            yum install -y wget tar systemd
        elif command -v opkg &> /dev/null; then
            # Synology
            opkg update && opkg install wget tar
        else
            echo "Gestionnaire de paquets non supporté"
            exit 1
        fi
    fi
}
```

### 4. 📝 Aucun logging

**Problème :** Pas de trace des installations/erreurs.

**Solution proposée :**
```bash
LOG_FILE="/var/log/tacticalrmm-install.log"

function log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Utilisation :
log "Début de l'installation"
log "Architecture détectée: $system"
```

### 5. ⚠️ Pas de sauvegarde avant mise à jour

**Problème :** Si la mise à jour échoue, l'agent est cassé.

**Solution proposée :**
```bash
function update_agent() {
    systemctl stop tacticalagent

    # Sauvegarde de l'ancien agent
    if [ -f /usr/local/bin/rmmagent ]; then
        cp /usr/local/bin/rmmagent /usr/local/bin/rmmagent.backup
        log "Agent sauvegardé"
    fi

    # Copie du nouvel agent
    if cp "$TMPDIR/temp_rmmagent" /usr/local/bin/rmmagent; then
        log "Agent mis à jour avec succès"
        rm "$TMPDIR/temp_rmmagent"
        rm -f /usr/local/bin/rmmagent.backup
    else
        log "ERREUR: Échec de la mise à jour, restauration..."
        cp /usr/local/bin/rmmagent.backup /usr/local/bin/rmmagent
        exit 1
    fi

    systemctl start tacticalagent
}
```

### 6. ❌ Pas de détection de distribution

**Problème :** Certaines distributions ont des particularités (Synology, Alpine, etc.).

**Solution proposée :**
```bash
function detect_system() {
    # Détection de Synology
    if [ -f /etc/synoinfo.conf ]; then
        OS_TYPE="synology"
        log "Système détecté: Synology DSM"
        return
    fi

    # Détection via /etc/os-release
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE="$ID"
        OS_VERSION="$VERSION_ID"
        log "Système détecté: $NAME $VERSION"
    else
        OS_TYPE="unknown"
        log "ATTENTION: Système non identifié"
    fi
}
```

### 7. 🔒 Aucune vérification des téléchargements

**Problème :** Pas de checksum ou vérification d'intégrité.

**Solution proposée :**
```bash
function download_with_verify() {
    local url=$1
    local output=$2

    log "Téléchargement: $url"

    if ! wget -q --show-progress -O "$output" "$url"; then
        log "ERREUR: Échec du téléchargement de $url"
        return 1
    fi

    # Vérifier que le fichier n'est pas vide
    if [ ! -s "$output" ]; then
        log "ERREUR: Fichier téléchargé vide"
        return 1
    fi

    log "Téléchargement réussi: $(du -h $output | cut -f1)"
    return 0
}
```

### 8. 🌍 Support multilingue

**Problème :** Tout est en anglais.

**Solution proposée :**
```bash
LANG="${LANG:-fr_FR}"

function msg() {
    case $1 in
        install_start)
            [ "$LANG" = "fr_FR" ] && echo "Début de l'installation..." || echo "Starting installation..."
            ;;
        install_complete)
            [ "$LANG" = "fr_FR" ] && echo "Installation terminée avec succès !" || echo "Installation completed successfully!"
            ;;
    esac
}
```

### 9. ⚠️ Gestion d'erreur de compilation

**Problème :** Si la compilation échoue, le script continue.

**Solution proposée :**
```bash
function agent_compile() {
    log "Compilation de l'agent..."

    download_with_verify "https://github.com/amidaware/rmmagent/archive/refs/heads/master.tar.gz" "$TMPDIR/rmmagent.tar.gz" || exit 1

    tar -xf "$TMPDIR/rmmagent.tar.gz" -C "$TMPDIR/" || {
        log "ERREUR: Échec de l'extraction"
        exit 1
    }

    cd "$TMPDIR/rmmagent-master"

    case $system in
        amd64) env CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags "-s -w" -o "$TMPDIR/temp_rmmagent" ;;
        x86) env CGO_ENABLED=0 GOOS=linux GOARCH=386 go build -ldflags "-s -w" -o "$TMPDIR/temp_rmmagent" ;;
        arm64) env CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags "-s -w" -o "$TMPDIR/temp_rmmagent" ;;
        armv6) env CGO_ENABLED=0 GOOS=linux GOARCH=arm go build -ldflags "-s -w" -o "$TMPDIR/temp_rmmagent" ;;
    esac

    # Vérifier que la compilation a réussi
    if [ ! -f "$TMPDIR/temp_rmmagent" ]; then
        log "ERREUR: Échec de la compilation"
        exit 1
    fi

    log "Compilation réussie ($(du -h $TMPDIR/temp_rmmagent | cut -f1))"

    cd "$TMPDIR"
    rm -R "$TMPDIR/rmmagent-master"
}
```

### 10. 📊 Status de l'agent

**Problème :** Pas de commande pour vérifier l'état de l'agent.

**Solution proposée :**
```bash
function status_agent() {
    echo "==================================="
    echo "STATUT DE L'AGENT TACTICAL RMM"
    echo "==================================="
    echo ""

    # Service systemd
    if systemctl is-active --quiet tacticalagent; then
        echo "✓ Service: ACTIF"
    else
        echo "✗ Service: INACTIF"
    fi

    # Binaire
    if [ -f /usr/local/bin/rmmagent ]; then
        echo "✓ Binaire: $(ls -lh /usr/local/bin/rmmagent | awk '{print $5}')"
    else
        echo "✗ Binaire: NON TROUVÉ"
    fi

    # Configuration
    if [ -d /etc/tacticalagent ]; then
        echo "✓ Configuration: OK"
    else
        echo "✗ Configuration: MANQUANTE"
    fi

    # Mesh
    if [ -d /opt/tacticalmesh ]; then
        echo "✓ Mesh: INSTALLÉ"
    else
        echo "✗ Mesh: NON INSTALLÉ"
    fi

    # Logs récents
    echo ""
    echo "Derniers logs:"
    journalctl -u tacticalagent -n 5 --no-pager
}

# Ajouter dans le case final :
case $1 in
    # ... install, update, uninstall ...
    status)
        status_agent
        exit 0;;
esac
```

### 11. 🔧 Support Synology amélioré

**Problème :** Synology a des spécificités (chemins, services).

**Solution proposée :**
```bash
function install_agent_synology() {
    local SYNO_INSTALL_PATH="/volume1/@appstore/tactical-rmm"
    mkdir -p "$SYNO_INSTALL_PATH"

    cp "$TMPDIR/temp_rmmagent" "$SYNO_INSTALL_PATH/rmmagent"
    chmod +x "$SYNO_INSTALL_PATH/rmmagent"

    "$SYNO_INSTALL_PATH/rmmagent" -m install -api $rmm_url -client-id $rmm_client_id -site-id $rmm_site_id -agent-type $rmm_agent_type -auth $rmm_auth

    rm "$TMPDIR/temp_rmmagent"

    # Service systemd adapté pour Synology
    cat << EOF > /etc/systemd/system/tacticalagent.service
[Unit]
Description=Tactical RMM Linux Agent
After=network.target syno-volume.target

[Service]
Type=simple
ExecStart=$SYNO_INSTALL_PATH/rmmagent -m svc
User=root
Group=root
Restart=always
RestartSec=5s
LimitNOFILE=1000000
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now tacticalagent
}
```

### 12. 🔄 Nettoyage automatique

**Problème :** Les fichiers temporaires s'accumulent.

**Solution proposée :**
```bash
function cleanup() {
    log "Nettoyage des fichiers temporaires..."

    # Nettoyer Go si installé temporairement
    if [ "$GO_INSTALLED_BY_SCRIPT" = "true" ]; then
        rm -rf /usr/local/go/
        log "Go désinstallé"
    fi

    # Nettoyer le répertoire temporaire
    rm -rf "$TMPDIR/rmmagent-master" 2>/dev/null
    rm -f "$TMPDIR/temp_rmmagent" 2>/dev/null
    rm -f "$TMPDIR/golang.tar.gz" 2>/dev/null
    rm -f "$TMPDIR/rmmagent.tar.gz" 2>/dev/null
    rm -f "$TMPDIR/meshagent" 2>/dev/null

    log "Nettoyage terminé"
}

# Appeler cleanup en fin de script
trap cleanup EXIT
```

## Script amélioré complet

Voici un exemple de structure améliorée :

```bash
#!/bin/bash

#############################################
# Tactical RMM - Script d'installation Linux
# Version améliorée avec support Synology
#############################################

set -e  # Arrêter en cas d'erreur

# Variables globales
VERSION="2.0"
LOG_FILE="/var/log/tacticalrmm-install.log"
GO_INSTALLED_BY_SCRIPT=false
LANG="${TACTICAL_LANG:-fr_FR}"

# Fonctions
function log() { ... }
function msg() { ... }
function check_dependencies() { ... }
function detect_system() { ... }
function go_install() { ... }
function go_cleanup() { ... }
function agent_compile() { ... }
function install_agent() { ... }
function install_agent_synology() { ... }
function update_agent() { ... }
function status_agent() { ... }
function cleanup() { ... }

# Début du script
log "=== Tactical RMM Installation Script v$VERSION ==="

# Vérifications préliminaires
check_dependencies
detect_system

# Exécution selon l'action
case $1 in
    install) ... ;;
    update) ... ;;
    uninstall) ... ;;
    status) ... ;;
    *) echo "Usage: $0 {install|update|uninstall|status}"; exit 1 ;;
esac
```

## Résumé des améliorations prioritaires

| Priorité | Amélioration | Impact |
|----------|--------------|--------|
| 🔴 CRITIQUE | Installation dans /opt ou /volume1 (pas /usr/local) | Évite partition pleine |
| 🔴 CRITIQUE | Nettoyage de Go après compilation | Économise 244 MB |
| 🟡 IMPORTANT | Sauvegarde avant mise à jour | Évite casse de l'agent |
| 🟡 IMPORTANT | Vérification des dépendances | Évite erreurs installation |
| 🟡 IMPORTANT | Logging complet | Facilite débogage |
| 🟢 UTILE | Support Synology optimisé | Meilleure compatibilité |
| 🟢 UTILE | Commande status | Facilite diagnostic |
| 🟢 UTILE | Support multilingue | Meilleure UX |

## Recommandations

1. **Pour Synology** : Toujours installer dans `/volume1/@appstore/`
2. **Pour tous** : Nettoyer Go après compilation (sauf si déjà installé)
3. **Sécurité** : Vérifier les checksums des téléchargements
4. **Maintenance** : Ajouter une commande `repair` pour réinstaller sans perdre la config

## Prochaines étapes

Souhaitez-vous que je crée une version améliorée complète du script avec toutes ces modifications ?
