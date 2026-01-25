#!/bin/bash
set -e

cd "$(dirname "$0")/../compose"
docker compose --env-file secrets.env up -d
