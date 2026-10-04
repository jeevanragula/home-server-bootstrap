#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_DIR="$ROOT_DIR/compose"
cd "$COMPOSE_DIR"

[[ -f "$ROOT_DIR/.env" ]] || {
  echo "ERROR: $ROOT_DIR/.env not found."
  echo "Create it from .env.example."
  exit 1
}

docker compose --env-file "$ROOT_DIR/.env" up -d
