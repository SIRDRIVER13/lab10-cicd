#!/bin/bash
# Instalacja self-hosted runnera GitHub Actions na Macu (wdraża do lokalnego klastra kind).
#   bash deploy/setup-runner.sh      a potem:  cd ~/actions-runner-lab10 && ./run.sh
set -euo pipefail
REPO=lab10-cicd
OWNER=$(gh api user -q .login)
VER=$(gh api repos/actions/runner/releases/latest -q .tag_name | sed 's/^v//')
ARCH=$([ "$(uname -m)" = arm64 ] && echo arm64 || echo x64)
DIR="$HOME/actions-runner-lab10"

mkdir -p "$DIR" && cd "$DIR"
echo "== Pobieranie runnera $VER ($ARCH)"
curl -fsSL -o runner.tar.gz "https://github.com/actions/runner/releases/download/v$VER/actions-runner-osx-$ARCH-$VER.tar.gz"
tar xzf runner.tar.gz && rm runner.tar.gz

TOKEN=$(gh api -X POST "repos/$OWNER/$REPO/actions/runners/registration-token" -q .token)
./config.sh --url "https://github.com/$OWNER/$REPO" --token "$TOKEN" \
  --name mac-lab10 --labels lab10 --work _work --unattended --replace
echo "Gotowe. Uruchom runner w osobnej karcie terminala:  cd $DIR && ./run.sh"
