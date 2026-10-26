#!/bin/bash
# Utworzenie repozytorium GitHub i środowisk wdrożeniowych (test, production z zatwierdzeniem).
#   bash deploy/setup-github.sh
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=lab10-cicd
OWNER=$(gh api user -q .login)
USER_ID=$(gh api user -q .id)

git init -q -b main
git add .
git commit -q -m "Lab 10: monolit, mikroserwisy, pipeline CI/CD"
gh repo create "$REPO" --public --source . --remote origin --description "Lab 10 DevOps - CI/CD dla monolitu i mikroserwisów"

echo "== Środowisko test (bez ograniczeń)"
gh api -X PUT "repos/$OWNER/$REPO/environments/test" >/dev/null

echo "== Środowisko production: wymagane zatwierdzenie przez $OWNER, tylko gałąź main"
gh api -X PUT "repos/$OWNER/$REPO/environments/production" --input - >/dev/null <<JSON
{"reviewers":[{"type":"User","id":$USER_ID}],
 "deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}
JSON
gh api -X POST "repos/$OWNER/$REPO/environments/production/deployment-branch-policies" -f name=main >/dev/null

gh api "repos/$OWNER/$REPO/environments" -q '.environments[] | "\(.name): \(.protection_rules | map(.type) | join(", "))"'
echo "Repozytorium: https://github.com/$OWNER/$REPO"
