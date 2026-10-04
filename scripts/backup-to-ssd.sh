#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/.env"
MOUNT_POINT="/mnt/home-server-backup"
BACKUP_ROOT="$MOUNT_POINT/home-server-backup"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE not found."
  exit 1
fi

DATA_ROOT="$(awk -F= '$1=="DATA_ROOT" {print substr($0, index($0,$2))}' "$CONFIG_FILE")"
DATA_ROOT="${DATA_ROOT:-/srv/docker}"

if [[ ! -d "$DATA_ROOT/immich/library" ]]; then
  echo "ERROR: Immich library not found at $DATA_ROOT/immich/library"
  exit 1
fi

sudo mkdir -p "$MOUNT_POINT"

if ! mountpoint -q "$MOUNT_POINT"; then
  echo "Backup SSD is not mounted."
  echo "Connect the exFAT SSD and identify it with: lsblk -f"
  echo "Then mount the correct partition with:"
  echo "  sudo mount /dev/sdX1 $MOUNT_POINT"
  echo "DO NOT guess the device name."
  exit 1
fi

FSTYPE="$(findmnt -n -o FSTYPE "$MOUNT_POINT")"
if [[ "$FSTYPE" != "exfat" ]]; then
  echo "ERROR: $MOUNT_POINT is mounted as '$FSTYPE', expected exfat."
  exit 1
fi

mkdir -p "$BACKUP_ROOT/photos" "$BACKUP_ROOT/homeassistant" "$BACKUP_ROOT/database"

echo "==> Backing up Immich photos..."
sudo rsync -a --human-readable --info=progress2   "$DATA_ROOT/immich/library/"   "$BACKUP_ROOT/photos/"

echo "==> Creating consistent Immich database dump..."
DB_USER="$(grep '^IMMICH_DB_USERNAME=' "$ROOT_DIR/compose/secrets.env" | cut -d= -f2-)"
DB_NAME="$(grep '^IMMICH_DB_NAME=' "$ROOT_DIR/compose/secrets.env" | cut -d= -f2-)"
sudo docker exec immich_postgres pg_dump   -U "$DB_USER"   -d "$DB_NAME"   | gzip > "$BACKUP_ROOT/database/immich.sql.gz"

echo "==> Backing up Home Assistant configuration..."
sudo tar -C "$DATA_ROOT" -czf   "$BACKUP_ROOT/homeassistant/homeassistant-$(date +%Y%m%d-%H%M%S).tar.gz"   homeassistant

sync
echo "Backup completed successfully."
