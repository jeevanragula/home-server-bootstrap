#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"
echo "Home Server Bootstrap"
if [[ "${EUID}" -ne 0 ]]; then echo "Run: sudo bash setup.sh"; exit 1; fi
ADMIN_USER="${SUDO_USER:-}"
if [[ -z "$ADMIN_USER" || "$ADMIN_USER" == "root" ]]; then ADMIN_USER="$(logname 2>/dev/null || true)"; fi
if [[ -z "$ADMIN_USER" || "$ADMIN_USER" == "root" ]]; then echo "ERROR: Run with sudo from your normal Ubuntu login user."; exit 1; fi
if [[ ! -f "$ROOT_DIR/.env" ]]; then cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"; fi
if [[ ! -f "$ROOT_DIR/compose/secrets.env" ]]; then
  DB_PASSWORD="$(openssl rand -hex 32)"
  cat > "$ROOT_DIR/compose/secrets.env" <<EOF
# Generated locally by setup.sh. Never commit this file.
IMMICH_DB_USERNAME=immich
IMMICH_DB_PASSWORD=$DB_PASSWORD
IMMICH_DB_NAME=immich
EOF
  chmod 600 "$ROOT_DIR/compose/secrets.env"
fi
bash "$ROOT_DIR/install.sh"
if ! tailscale ip -4 >/dev/null 2>&1; then
  echo "Authenticate Tailscale using the URL shown below:"
  tailscale up
fi
docker compose --env-file "$ROOT_DIR/.env" --env-file "$ROOT_DIR/compose/secrets.env" -f "$ROOT_DIR/compose/docker-compose.yml" up -d
chmod +x "$ROOT_DIR"/scripts/*.sh "$ROOT_DIR"/install.sh
echo
echo "Setup complete."
echo "Immich: http://<server-ip>:2283"
echo "Home Assistant: http://<server-ip>:8123"
echo "If needed, authenticate Tailscale with: sudo tailscale up"
echo "For SSD backup: ./scripts/backup-to-ssd.sh"
