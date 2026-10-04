#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
COMPOSE_FILE="$ROOT_DIR/compose/docker-compose.yml"

echo "Home Server preflight"
echo "====================="

fail=0

check_url() {
  local name="$1"
  local url="$2"
  local http_code

  # Registry /v2/ commonly returns 401/403 when reachable and authentication is required.
  # Use IPv4 GET so broken IPv6 or HEAD handling does not cause false failures.
  http_code="$(curl -4 -sS -o /dev/null --connect-timeout 10 --max-time 15 -w '%{http_code}' "$url" 2>/dev/null || true)"

  if [[ "$http_code" =~ ^(2[0-9][0-9]|3[0-9][0-9]|401|403)$ ]]; then
    echo "[OK] $name reachable (HTTP $http_code)"
  else
    echo "[FAIL] $name is not reachable: $url (HTTP ${http_code:-connection failed})"
    fail=1
  fi
}

echo
echo "1. Internet connectivity"
if curl -fsS --connect-timeout 5 --max-time 10 -o /dev/null https://www.cloudflare.com/cdn-cgi/trace; then
  echo "[OK] HTTPS internet connectivity"
else
  echo "[FAIL] HTTPS internet connectivity"
  fail=1
fi

echo
echo "2. DNS resolution"
for host in registry-1.docker.io ghcr.io; do
  if getent hosts "$host" >/dev/null 2>&1; then
    echo "[OK] DNS resolves $host"
  else
    echo "[FAIL] DNS cannot resolve $host"
    fail=1
  fi
done

echo
echo "3. Container registries"
check_url "Docker Hub registry" "https://registry-1.docker.io/v2/"
check_url "GitHub Container Registry" "https://ghcr.io/v2/"

echo
echo "4. Docker"
if ! command -v docker >/dev/null 2>&1; then
  echo "[FAIL] Docker is not installed."
  fail=1
elif ! systemctl is-active --quiet docker; then
  echo "[FAIL] Docker service is not running."
  fail=1
else
  echo "[OK] Docker service is running."
fi

echo
echo "5. Docker storage"
DOCKER_ROOT="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)"
if [[ -n "$DOCKER_ROOT" ]]; then
  echo "[OK] Docker root: $DOCKER_ROOT"
  df -h "$DOCKER_ROOT" | tail -n 1
else
  echo "[FAIL] Could not determine Docker storage path."
  fail=1
fi

echo
echo "6. Compose and actual image pull"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[FAIL] .env not found: $ENV_FILE"
  fail=1
elif [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "[FAIL] Compose file not found: $COMPOSE_FILE"
  fail=1
elif ! docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config --quiet; then
  echo "[FAIL] Docker Compose configuration is invalid."
  fail=1
else
  echo "[OK] Docker Compose configuration is valid."
  echo "[INFO] Pulling all required images now."
  echo "[INFO] This is the real image-transfer test; successful pulls are cached for setup."
  if docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull; then
    echo "[OK] All required container images pulled successfully."
  else
    echo "[FAIL] One or more container image pulls failed."
    fail=1
  fi
fi

echo
echo "7. Disk space"
if df -P /srv/docker >/dev/null 2>&1; then
  AVAILABLE_KB="$(df -Pk /srv/docker | awk 'NR==2 {print $4}')"
  if [[ "$AVAILABLE_KB" =~ ^[0-9]+$ ]]; then
    AVAILABLE_GB="$(awk "BEGIN { printf \"%.1f\", $AVAILABLE_KB / 1024 / 1024 }")"
    echo "[OK] /srv/docker available space: ${AVAILABLE_GB} GB"
    if (( AVAILABLE_KB < 10485760 )); then
      echo "[WARN] Less than 10 GB is available on the Docker filesystem."
    fi
  fi
else
  echo "[WARN] /srv/docker does not exist yet; Docker will create it during setup."
fi

if (( fail != 0 )); then
  echo
  echo "[FAIL] Preflight checks failed. Fix the reported issues before starting services."
  exit 1
fi

echo
echo "[PASS] All required preflight checks passed."
