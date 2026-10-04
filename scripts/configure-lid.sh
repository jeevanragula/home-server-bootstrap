#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo " Configuring laptop lid behavior"
echo "========================================"

if [[ "\${EUID}" -ne 0 ]]; then
  echo "[ERROR] Run this script with sudo."
  exit 1
fi

CONFIG_DIR="/etc/systemd/logind.conf.d"
CONFIG_FILE="$CONFIG_DIR/home-server.conf"

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

echo "[OK] Lid-close configuration written: $CONFIG_FILE"
cat "$CONFIG_FILE"

echo "[INFO] Applying systemd-logind configuration..."
systemctl restart systemd-logind
echo "[OK] systemd-logind restarted."

echo "[SUCCESS] Laptop lid is configured to be ignored."
echo "[SUCCESS] Closing the lid will NOT trigger suspend, hibernate, or shutdown."
echo "========================================"
