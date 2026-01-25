#!/bin/bash
set -e

cd "$(dirname "$0")/../compose"
docker compose --env-file ../.env up -d
