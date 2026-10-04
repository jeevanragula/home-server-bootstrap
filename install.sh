#!/usr/bin/env bash
set -euo pipefail

echo "Home Server Bootstrap - Ubuntu Server"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo ./install.sh"
  exit 1
fi

ADMIN_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
if [[ -z "$ADMIN_USER" || "$ADMIN_USER" == "root" ]]; then
  echo "Could not determine the normal login user."
  echo "Run with sudo from your normal user account."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y
apt install -y ca-certificates curl gnupg lsb-release ufw jq unzip rsync exfatprogs util-linux upower openssl

# Docker
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

usermod -aG docker "$ADMIN_USER"
systemctl enable --now docker

# Keep Docker data on the internal HDD. The portable SSD is BACKUP ONLY.
mkdir -p /srv/docker
chown -R "$ADMIN_USER:$ADMIN_USER" /srv/docker

# Tailscale
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
systemctl enable --now tailscaled

echo
echo "Tailscale is installed. If this server is not already authenticated, run:"
echo "  sudo tailscale up"
echo

# Laptop server power behavior
mkdir -p /etc/systemd
cat >/etc/systemd/logind.conf.d/home-server.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

systemctl restart systemd-logind || true
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Low-battery shutdown
mkdir -p /etc/UPower
cat >/etc/UPower/UPower.conf <<'EOF'
[UPower]
PercentageLow=10
PercentageCritical=5
PercentageAction=PowerOff
CriticalPowerAction=PowerOff
EOF
systemctl restart upower || true

# Firewall: Tailscale access plus local-LAN fallback.
# Do NOT lock SSH to Tailscale until you have verified Tailscale SSH access.
ufw default deny incoming
ufw default allow outgoing
ufw allow in on tailscale0
ufw allow from 192.168.0.0/16 to any port 22
ufw allow from 192.168.0.0/16 to any port 2283
ufw allow from 192.168.0.0/16 to any port 8123
ufw --force enable

echo
echo "Bootstrap complete."
echo "IMPORTANT: log out and back in for Docker group membership."
echo "The portable exFAT SSD is not formatted or mounted by this script."
echo "It is intended to be connected only for backups."
