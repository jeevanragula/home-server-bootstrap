#!/usr/bin/env bash
set -euo pipefail

echo "Tailscale and network validation"
echo "================================"

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
echo "Tailscale identity:"
sudo tailscale status --self=false 2>/dev/null | head -n 1 || true

echo
echo "DNS / MagicDNS:"
DNS_STATUS="$(sudo tailscale dns status 2>&1 || true)"
if grep -qiE "magicdns|nameserver|search domain|dns" <<<"$DNS_STATUS"; then
  echo "$DNS_STATUS"
else
  echo "[INFO] Could not determine MagicDNS status from this client."
  echo "       Check MagicDNS in the Tailscale admin console."
fi

echo
echo "Tailscale status:"
sudo tailscale status

echo
echo "Tailscale network check:"
sudo tailscale netcheck

echo
echo "Internet connectivity:"
if curl -fsS --connect-timeout 5 --max-time 10 -o /dev/null https://www.cloudflare.com/cdn-cgi/trace; then
  echo "[OK] HTTPS internet connectivity is working."
else
  echo "[FAIL] HTTPS internet connectivity check failed."
fi

echo
echo "Internet download speed (quick test):"
echo "Downloading 10 MB from Cloudflare; this consumes approximately 10 MB of data."
SPEED_RESULT="$(curl -L -sS -o /dev/null \
  --connect-timeout 10 --max-time 30 \
  -w '%{speed_download} %{time_total}' \
  'https://speed.cloudflare.com/__down?bytes=10000000' 2>/dev/null || true)"

if [[ -n "$SPEED_RESULT" ]]; then
  read -r BYTES_PER_SEC ELAPSED <<<"$SPEED_RESULT"
  if [[ "$BYTES_PER_SEC" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk "BEGIN { exit !($BYTES_PER_SEC > 0) }"; then
    SPEED_MBPS="$(awk "BEGIN { printf \"%.1f\", ($BYTES_PER_SEC * 8) / 1000000 }")"
    echo "[OK] Approximate download speed: ${SPEED_MBPS} Mbps (${ELAPSED}s)"
  else
    echo "[FAIL] Could not calculate download speed."
  fi
else
  echo "[FAIL] Internet speed test failed or timed out."
fi

echo
echo "[PASS] Tailscale and network validation completed."
echo
echo "SSH by machine name:"
echo "  ssh <ubuntu-user>@$(hostname)"
