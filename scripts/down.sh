#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_DIR="$ROOT_DIR/compose"

cd "$COMPOSE_DIR"

docker compose   --env-file "$ROOT_DIR/.env"   --env-file "$COMPOSE_DIR/secrets.env"   down
