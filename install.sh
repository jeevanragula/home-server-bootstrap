#!/usr/bin/env bash
set -e

echo "🚀 Home Server Bootstrap (Ubuntu Server + Tailscale + Docker)"

# =====================================================
# BASIC SYSTEM
# =====================================================
apt update && apt upgrade -y
apt install -y \
  ca-certificates curl gnupg lsb-release ufw jq unzip \
  util-linux mosquitto mosquitto-clients

# =====================================================
# DETECT DISKS
# =====================================================
echo "🔍 Detecting disks..."

ROOT_DISK=$(lsblk -no PKNAME "$(df / | tail -1 | awk '{print $1}')")
DATA_DISK=$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}' | grep -v "$ROOT_DISK" | head -n1)

if [ -z "$DATA_DISK" ]; then
  echo "❌ External SSD not found. Aborting."
  exit 1
fi

echo "➡️ External SSD detected: $DATA_DISK"

# =====================================================
# FORMAT + MOUNT SSD
# =====================================================
if ! mount | grep -q " /data "; then
  echo "⚠️ Formatting external SSD (ext4)"
  mkfs.ext4 -F "$DATA_DISK"
  mkdir -p /data
  UUID=$(blkid -s UUID -o value "$DATA_DISK")
  echo "UUID=$UUID /data ext4 defaults,noatime 0 2" >> /etc/fstab
  mount -a
fi

mkdir -p /data/{docker,photos,documents,backups,media}

# =====================================================
# DOCKER
# =====================================================
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi

usermod -aG docker "$SUDO_USER"
systemctl enable docker
systemctl start docker

systemctl stop docker
cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "/data/docker"
}
EOF
systemctl start docker

# =====================================================
# DOCKER COMPOSE (v2 plugin)
# =====================================================
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# =====================================================
# TAILSCALE
# =====================================================
curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable tailscaled
systemctl start tailscaled

echo "🔐 Login to Tailscale if prompted"
tailscale up || true

HOST=$(hostname)
tailscale cert "$HOST.ts" || true

# =====================================================
# FIREWALL (TAILSCALE-ONLY + LAN FALLBACK)
# =====================================================
LAN_SUBNET=$(ip route | awk '/src/ {print $1}' | head -n1)

ufw reset
ufw default deny incoming
ufw default allow outgoing

# Allow all traffic via Tailscale
ufw allow in on tailscale0

# Allow SSH ONLY via Tailscale
ufw allow in on tailscale0 to any port 22

# LAN fallback (web only)
ufw allow from "$LAN_SUBNET" to any port 80
ufw allow from "$LAN_SUBNET" to any port 443

ufw --force enable

# =====================================================
# SSH HARDENING (KEYS ONLY)
# =====================================================
echo "🔐 Hardening SSH"

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

systemctl restart ssh

# =====================================================
# LAPTOP SERVER HARDENING
# =====================================================
echo "🔒 Disabling sleep & lid actions"

sed -i 's/^#HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sed -i 's/^#HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sed -i 's/^#HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf

grep -q HandleLidSwitch= /etc/systemd/logind.conf || echo "HandleLidSwitch=ignore" >> /etc/systemd/logind.conf
grep -q HandleLidSwitchExternalPower= /etc/systemd/logind.conf || echo "HandleLidSwitchExternalPower=ignore" >> /etc/systemd/logind.conf
grep -q HandleLidSwitchDocked= /etc/systemd/logind.conf || echo "HandleLidSwitchDocked=ignore" >> /etc/systemd/logind.conf

systemctl restart systemd-logind
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# =====================================================
# AUTO SHUTDOWN ON LOW BATTERY (UPS MODE)
# =====================================================
mkdir -p /etc/UPower
cat > /etc/UPower/UPower.conf <<EOF
[UPower]
PercentageLow=10
PercentageCritical=5
PercentageAction=5
CriticalPowerAction=PowerOff
EOF

systemctl restart upower

# =====================================================
# DONE
# =====================================================
echo "✅ BOOTSTRAP COMPLETE"
echo "🔐 Access: Tailscale-only"
echo "➡️ Next steps:"
echo "   1) Add SSH key: ssh-copy-id user@$HOST"
echo "   2) Reboot recommended"
