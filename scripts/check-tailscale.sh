#!/usr/bin/env bash
set -euo pipefail

echo "Tailscale validation"
echo "===================="

if ! command -v tailscale >/dev/null 2>&1; then
  echo "[FAIL] Tailscale is not installed."
  exit 1
fi
echo "[OK] Tailscale command is installed."

if ! systemctl is-active --quiet tailscaled; then
  echo "[FAIL] tailscaled is not running."
  echo "       Run: sudo systemctl enable --now tailscaled"
  exit 1
fi
echo "[OK] tailscaled is running."

STATUS_JSON="$(sudo tailscale status --json)"

BACKEND_STATE="$(jq -r '.BackendState // empty' <<<"$STATUS_JSON")"
if [[ "$BACKEND_STATE" != "Running" ]]; then
  echo "[FAIL] Tailscale is not connected. BackendState=$BACKEND_STATE"
  echo "       Run: sudo tailscale up"
  exit 1
fi
echo "[OK] Tailscale backend is Running."

TAILSCALE_IP="$(sudo tailscale ip -4 2>/dev/null || true)"
if [[ -z "$TAILSCALE_IP" ]]; then
  echo "[FAIL] No Tailscale IPv4 address assigned."
  exit 1
fi
echo "[OK] Tailscale IPv4: $TAILSCALE_IP"

if ! ip link show tailscale0 >/dev/null 2>&1; then
  echo "[FAIL] tailscale0 network interface is missing."
  exit 1
fi
echo "[OK] tailscale0 interface exists."

echo
echo "Tailscale status:"
sudo tailscale status

echo
echo "Tailscale network check:"
sudo tailscale netcheck

echo
echo "[PASS] Tailscale is installed, running, authenticated, and has an active VPN interface."
