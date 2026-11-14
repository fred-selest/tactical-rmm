#!/bin/bash
# Compile l'agent Tactical RMM modifie pour Synology (DSM) a partir d'un tag
# officiel amidaware/rmmagent + synology.patch.
#
# A lancer sur une machine Linux avec Go >= 1.20 et `patch`, PAS sur le NAS
# (partition systeme de 2,3 Go, pas de Go).
#
# Usage : ./build.sh [vX.Y.Z]
#   Defaut : tag epingle dans ../rmmagent-linux.sh (AGENT_REF), c'est-a-dire
#   LATEST_AGENT_VER du serveur RMM.
#   GOARCH=amd64 par defaut (DS218+, DS920+...). GOARCH=arm64 pour les modeles ARM.
#
# Sortie : ./dist/rmmagent-synology-vX.Y.Z-linux-<arch> + .sha256
#
# Le patch a ete ecrit pour v2.9.1 puis rebase sur v2.12.0. S'il ne
# s'applique plus sur un nouveau tag, le build s'arrete : ne jamais livrer
# un agent standard sur le NAS, il perdrait la detection DSM/disques.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF="${1:-$(sed -n 's/^AGENT_REF="${TACTICAL_AGENT_REF:-\(v[0-9.]*\)}"$/\1/p' "$HERE/../rmmagent-linux.sh")}"
ARCH="${GOARCH:-amd64}"
PATCH_FILE="${SYNO_PATCH:-$HERE/synology.patch}"
DIST="$HERE/dist"

case "$REF" in
    v[0-9]*) ;;
    *) echo "ERREUR: tag attendu (vX.Y.Z), recu '$REF'" >&2; exit 1 ;;
esac
for cmd in go patch curl tar sha256sum; do
    command -v "$cmd" >/dev/null || { echo "ERREUR: $cmd absent" >&2; exit 1; }
done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "==> Source amidaware/rmmagent $REF"
curl -fsSL -o "$WORK/src.tar.gz" "https://github.com/amidaware/rmmagent/archive/refs/tags/$REF.tar.gz"
tar -xzf "$WORK/src.tar.gz" -C "$WORK"
SRC="$WORK/rmmagent-${REF#v}"
[ -d "$SRC" ] || { echo "ERREUR: $SRC absent apres extraction" >&2; exit 1; }

echo "==> Application de synology.patch"
# --fuzz=0 : contexte exact exige. Par defaut `patch` tolere un contexte
# approximatif et peut inserer le code au mauvais endroit sur un autre tag.
if ! patch -d "$SRC" -p1 --dry-run --forward --fuzz=0 --silent < "$PATCH_FILE"; then
    echo "ERREUR: synology.patch ne s'applique pas exactement sur $REF. Rebaser le patch." >&2
    exit 1
fi
patch -d "$SRC" -p1 --forward --fuzz=0 --silent < "$PATCH_FILE"

OUT="$DIST/rmmagent-synology-$REF-linux-$ARCH"
mkdir -p "$DIST"
echo "==> Compilation linux/$ARCH ($(go version | awk '{print $3}'))"
(cd "$SRC" && CGO_ENABLED=0 GOOS=linux GOARCH="$ARCH" go build -trimpath -ldflags "-s -w" -o "$OUT" .)

# Le binaire doit annoncer la version du tag (lisible seulement si l'arch
# de la machine de build correspond).
if [ "$(go env GOHOSTARCH)" = "$ARCH" ]; then
    v=$("$OUT" -version | sed -n 's/^Tactical RMM Agent: //p')
    [ "$v" = "${REF#v}" ] || { echo "ERREUR: binaire en '$v', attendu ${REF#v}" >&2; exit 1; }
fi
# Le correctif doit etre present dans le binaire.
grep -aq 'syno_serial' "$OUT" || { echo "ERREUR: correctif Synology absent du binaire" >&2; exit 1; }

(cd "$DIST" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256")
echo "==> OK : $OUT"
cat "$OUT.sha256"
