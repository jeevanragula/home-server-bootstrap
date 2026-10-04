#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
cd "\$ROOT_DIR"
echo "Home Server Bootstrap"

if [[ "\${EUID}" -ne 0 ]]; then echo "Run: sudo bash setup.sh"; exit 1; fi
ADMIN_USER="\${SUDO_USER:-}"
if [[ -z "\$ADMIN_USER" || "\$ADMIN_USER" == "root" ]]; then ADMIN_USER="\$(logname 2>/dev/null || true)"; fi
if [[ -z "\$ADMIN_USER" || "\$ADMIN_USER" == "root" ]]; then echo "ERROR: Run with sudo from your normal Ubuntu login user."; exit 1; fi

if [[ ! -f "\$ROOT_DIR/.env" ]]; then
  cp "\$ROOT_DIR/.env.example" "\$ROOT_DIR/.env"
  echo "Created .env from .env.example."
  echo "Edit .env and set your values, then run setup.sh again."
  chmod 600 "\$ROOT_DIR/.env"
  exit 1
fi

chmod 600 "\$ROOT_DIR/.env"

if grep -q "^IMMICH_DB_PASSWORD=CHANGE_ME_TO_YOUR_OWN_LONG_PASSWORD$" "\$ROOT_DIR/.env"; then
  echo "ERROR: Set your own IMMICH_DB_PASSWORD in .env before running setup."
  exit 1
fi

bash "\$ROOT_DIR/install.sh"
bash "\$ROOT_DIR/scripts/configure-lid.sh"

if ! tailscale ip -4 >/dev/null 2>&1; then
  echo "Authenticate Tailscale using the URL shown below:"
  tailscale up
fi

echo
echo "Running preflight checks before pulling Docker images..."
bash "\$ROOT_DIR/scripts/preflight.sh"

docker compose --env-file "\$ROOT_DIR/.env" -f "\$ROOT_DIR/compose/docker-compose.yml" up -d

chmod +x "\$ROOT_DIR"/scripts/*.sh "\$ROOT_DIR"/install.sh

echo
echo "Setup complete."
echo "Immich: http://<server-ip>:2283"
echo "Home Assistant: http://<server-ip>:8123"
echo "For SSD backup: ./scripts/backup-to-ssd.sh"
