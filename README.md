# Lab 10 – budowanie, dostarczanie i wdrażanie różnych typów aplikacji

| Katalog | Zawartość |
| --- | --- |
| `monolith/` | Task API – monolit (Python/Flask + SQLite), paczka `.whl` + obraz Docker |
| `microservices/catalog` | mikroserwis katalogu produktów (Python/Flask) |
| `microservices/gateway` | mikroserwis gateway (Node.js/Express, npm) – woła catalog |
| `k8s/` | klaster kind, przestrzenie nazw `test` i `prod`, manifesty aplikacji |
| `deploy/` | `deploy.sh` (wdrożenie + rollback + monitoring), parametry środowisk, konfiguracja GitHub i runnera |
| `scripts/build.sh` | lokalny build wszystkich artefaktów |
| `.github/workflows/` | pipeline monolitu, mikroserwisów i ręczny rollback |

## Gałęzie
- `feature/**` – CI: build, testy jednostkowe i integracyjne, SAST, DAST, skan obrazów
- `develop` – CI + publikacja w GHCR (`X.Y.Z-dev.N`) + wdrożenie na **test**
- `main` – CI + publikacja (`X.Y.Z`, `X.Y.Z-sha`) + GitHub Release z `.whl` + **test** + zatwierdzenie + **prod**

## Adresy
| Środowisko | Monolit | Mikroserwisy (gateway) |
| --- | --- | --- |
| test | http://localhost:30110 | http://localhost:30120 |
| prod | http://localhost:30210 | http://localhost:30220 |
