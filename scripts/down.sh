#!/bin/bash
cd "$(dirname "$0")/../compose"
docker compose --env-file secrets.env down
