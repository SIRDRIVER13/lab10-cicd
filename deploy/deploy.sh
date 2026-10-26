#!/bin/bash
# Wdrożenie aplikacji na środowisko test/prod w klastrze kind z automatycznym rollbackiem.
#   bash deploy/deploy.sh <test|prod> monolith      <obraz-monolitu>
#   bash deploy/deploy.sh <test|prod> microservices <obraz-catalog> <obraz-gateway>
# Zmienne opcjonalne: GHCR_TOKEN/GHCR_USER (dostęp do GHCR), SIMULATE_FAILURE=1 (wersja uszkodzona),
#                    SKIP_PULL=1 (obraz zbudowany lokalnie, ładowany przez kind load), COMMIT=<sha>
# Zgodny z bash 3.2 (macOS).
set -uo pipefail
cd "$(dirname "$0")/.."

ENV_NAME="${1:?Podaj środowisko: test lub prod}"
APP_TYPE="${2:?Podaj typ aplikacji: monolith lub microservices}"
shift 2
. "deploy/envs/${ENV_NAME}.env"

CLUSTER="${KIND_CLUSTER:-lab10}"
BROKEN=""; [ "${SIMULATE_FAILURE:-0}" = "1" ] && BROKEN="1"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
START=$(date +%s)

case "$APP_TYPE" in
  monolith)      IMAGES="$1"; DEPLOYMENTS="monolith"; PORT="$MONO_PORT"; MANIFEST=k8s/monolith.yaml ;;
  microservices) IMAGES="$1 $2"; DEPLOYMENTS="catalog gateway"; PORT="$GW_PORT"; MANIFEST=k8s/microservices.yaml ;;
  *) echo "Nieznany typ aplikacji: $APP_TYPE"; exit 2 ;;
esac

log() { echo "[$(date +%H:%M:%S)] $*"; }

# 1. Artefakty: obrazy pobiera klaster z GHCR (sekret imagePullSecret) albo ładujemy obraz lokalny
K="kubectl --context kind-$CLUSTER"
if [ "${SKIP_PULL:-0}" = "1" ]; then
  for IMG in $IMAGES; do
    log "Ładowanie lokalnego obrazu $IMG do klastra"
    kind load docker-image "$IMG" --name "$CLUSTER" >/dev/null || exit 1
  done
else
  if [ -n "${GHCR_TOKEN:-}" ]; then
    $K -n "$NS" create secret docker-registry ghcr --docker-server=ghcr.io \
      --docker-username="${GHCR_USER:-ci}" --docker-password="$GHCR_TOKEN" --dry-run=client -o yaml | $K apply -f - >/dev/null
    $K -n "$NS" patch serviceaccount default -p '{"imagePullSecrets":[{"name":"ghcr"}]}' >/dev/null
  fi
  log "Klaster pobierze artefakty z GHCR: $IMAGES"
fi

# 2. Zastosowanie manifestu z parametrami środowiska
IMG1=$(echo "$IMAGES" | cut -d' ' -f1); IMG2=$(echo "$IMAGES" | cut -d' ' -f2)
sed -e "s|__NS__|$NS|g" -e "s|__REPLICAS__|$REPLICAS|g" -e "s|__APP_ENV__|$APP_ENV|g" \
    -e "s|__MONO_PORT__|$MONO_PORT|g" -e "s|__GW_PORT__|$GW_PORT|g" -e "s|__BROKEN__|$BROKEN|g" \
    -e "s|__COMMIT__|${COMMIT:-manual}|g" -e "s|__IMAGE__|$IMG1|g" \
    -e "s|__CATALOG_IMAGE__|$IMG1|g" -e "s|__GATEWAY_IMAGE__|$IMG2|g" "$MANIFEST" | kubectl --context "kind-$CLUSTER" apply -f - || exit 1

# 3. Oczekiwanie na zakończenie rolloutu i test dymny
FAILED=0
for D in $DEPLOYMENTS; do
  log "Rollout $NS/$D"
  kubectl --context "kind-$CLUSTER" -n "$NS" rollout status "deployment/$D" --timeout=150s || FAILED=1
done
if [ "$FAILED" = "0" ]; then
  for i in 1 2 3 4 5 6 7 8 9 10; do
    curl -fsS -m 3 "http://localhost:$PORT/health" >/dev/null 2>&1 && break
    [ "$i" = "10" ] && FAILED=1
    sleep 2
  done
fi

# 4. Automatyczny rollback wszystkich Deploymentów tej aplikacji
if [ "$FAILED" = "1" ]; then
  log "BŁĄD WDROŻENIA na $NS - AUTOMATYCZNY ROLLBACK ($DEPLOYMENTS)"
  for D in $DEPLOYMENTS; do
    if [ "$(kubectl --context "kind-$CLUSTER" -n "$NS" rollout history "deployment/$D" | grep -c '^[0-9]')" -gt 1 ]; then
      kubectl --context "kind-$CLUSTER" -n "$NS" rollout undo "deployment/$D"
      kubectl --context "kind-$CLUSTER" -n "$NS" rollout status "deployment/$D" --timeout=120s
    else
      log "$D: brak poprzedniej wersji - pierwsze wdrożenie, usuwam"
      kubectl --context "kind-$CLUSTER" -n "$NS" delete "deployment/$D"
    fi
  done
  {
    echo "### ❌ Wdrożenie $APP_TYPE na $NS nieudane - wykonano rollback"
    echo '```'; kubectl --context "kind-$CLUSTER" -n "$NS" get deploy,pods -l "type=$( [ "$APP_TYPE" = monolith ] && echo monolith || echo microservice)" -o wide; echo '```'
  } >> "$SUMMARY"
  exit 1
fi

# 5. Monitoring wdrożenia: czas, dostępność i czas odpowiedzi po wdrożeniu
DURATION=$(( $(date +%s) - START ))
OK=0; TOTAL_MS=0
for i in $(seq 1 20); do
  T=$(curl -fsS -m 3 -o /dev/null -w '%{time_total}' "http://localhost:$PORT/health") && OK=$((OK+1)) && \
    TOTAL_MS=$(( TOTAL_MS + $(echo "$T" | awk '{printf "%d", $1*1000}') ))
done
AVG=$(( OK > 0 ? TOTAL_MS / OK : 0 ))
VERSION_JSON=$(curl -s "http://localhost:$PORT/")
log "WDROŻENIE OK: $APP_TYPE na $NS w ${DURATION}s, dostępność $OK/20, średni czas odpowiedzi ${AVG} ms"
echo "$VERSION_JSON"
{
  echo "### ✅ $APP_TYPE → $NS"
  echo "| Parametr | Wartość |"; echo "| --- | --- |"
  echo "| Obrazy | \`$IMAGES\` |"
  echo "| Czas wdrożenia | ${DURATION} s |"
  echo "| Dostępność po wdrożeniu | $OK/20 |"
  echo "| Średni czas odpowiedzi /health | ${AVG} ms |"
  echo "| Adres | http://localhost:$PORT |"
  echo '```json'; echo "$VERSION_JSON"; echo '```'
} >> "$SUMMARY"
