#!/bin/bash
# Lokalny build wszystkich typów aplikacji: paczka .whl monolitu + obrazy Docker.
#   bash scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
MONO_V=$(cat monolith/VERSION); MS_V=$(cat microservices/VERSION)

echo "== 1/4 Monolit: paczka Pythona (.whl, .tar.gz) w wersji $MONO_V"
python3 -m venv /tmp/lab10-build >/dev/null
/tmp/lab10-build/bin/pip install -q build
rm -rf monolith/dist && /tmp/lab10-build/bin/python -m build monolith >/dev/null
ls -l monolith/dist

echo "== 2/4 Monolit: obraz Docker zbudowany z paczki .whl"
docker build -q --build-arg APP_VERSION="$MONO_V" -t "lab10-monolith:$MONO_V" monolith

echo "== 3/4 Mikroserwis catalog (Python)"
docker build -q --build-arg APP_VERSION="$MS_V" -t "lab10-catalog:$MS_V" microservices/catalog

echo "== 4/4 Mikroserwis gateway (Node.js, npm ci)"
docker build -q --build-arg APP_VERSION="$MS_V" -t "lab10-gateway:$MS_V" microservices/gateway

echo "== Artefakty:"
docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep -E 'REPOSITORY|lab10-'
