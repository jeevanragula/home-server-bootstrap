#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_DIR="$ROOT_DIR/compose"

cd "$COMPOSE_DIR"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: $ROOT_DIR/.env not found."
  echo "Create it from .env.example."
  exit 1
fi

if [[ ! -f "$COMPOSE_DIR/secrets.env" ]]; then
  echo "ERROR: $COMPOSE_DIR/secrets.env not found."
  echo "Create it from compose/secrets.example."
  exit 1
fi

docker compose   --env-file "$ROOT_DIR/.env"   --env-file "$COMPOSE_DIR/secrets.env"   up -d
