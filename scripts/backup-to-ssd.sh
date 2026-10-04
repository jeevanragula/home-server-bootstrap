#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/.env"

[[ -f "$CONFIG_FILE" ]] || { echo "ERROR: Run setup.sh first."; exit 1; }

DATA_ROOT="$(awk -F= '$1=="DATA_ROOT" {print substr($0, index($0,$2))}' "$CONFIG_FILE")"
DATA_ROOT="${DATA_ROOT:-/srv/docker}"
MOUNT_POINT="$(grep "^BACKUP_MOUNT=" "$CONFIG_FILE" | cut -d= -f2-)"
MOUNT_POINT="${MOUNT_POINT:-/mnt/home-server-backup}"
BACKUP_ROOT="$(grep "^BACKUP_ROOT=" "$CONFIG_FILE" | cut -d= -f2-)"
BACKUP_ROOT="${BACKUP_ROOT:-$MOUNT_POINT/homeserver}"
DB_USER="$(grep "^IMMICH_DB_USERNAME=" "$CONFIG_FILE" | cut -d= -f2-)"
DB_NAME="$(grep "^IMMICH_DB_NAME=" "$CONFIG_FILE" | cut -d= -f2-)"

[[ -d "$DATA_ROOT/immich/library" ]] || { echo "ERROR: Immich library not found."; exit 1; }

sudo mkdir -p "$MOUNT_POINT"
AUTO_MOUNTED=0

if ! mountpoint -q "$MOUNT_POINT"; then
  mapfile -t EXFAT_DEVICES < <(lsblk -rpno NAME,FSTYPE | awk '$2=="exfat" {print $1}')
  if [[ "${#EXFAT_DEVICES[@]}" -eq 0 ]]; then
    echo "ERROR: No exFAT SSD found. Connect it and retry."
    exit 1
  fi
  if [[ "${#EXFAT_DEVICES[@]}" -gt 1 ]]; then
    echo "ERROR: More than one exFAT filesystem found; refusing to guess."
    printf "  %s\n" "${EXFAT_DEVICES[@]}"
    exit 1
  fi

  DEVICE="${EXFAT_DEVICES[0]}"
  echo "Mounting backup SSD: $DEVICE"
  sudo mount "$DEVICE" "$MOUNT_POINT"
  AUTO_MOUNTED=1
fi

cleanup() {
  if [[ "$AUTO_MOUNTED" -eq 1 ]]; then
    sync || true
    sudo umount "$MOUNT_POINT" || true
  fi
}
trap cleanup EXIT

FSTYPE="$(findmnt -n -o FSTYPE "$MOUNT_POINT")"
[[ "$FSTYPE" == "exfat" ]] || { echo "ERROR: Expected exfat, found $FSTYPE."; exit 1; }

sudo mkdir -p "$BACKUP_ROOT/photos" "$BACKUP_ROOT/database" "$BACKUP_ROOT/homeassistant"

echo "==> Backing up configuration..."
sudo cp "$CONFIG_FILE" "$BACKUP_ROOT/.env"
sudo chmod 600 "$BACKUP_ROOT/.env"

echo "==> Backing up Immich photos..."
# Incremental copy. No --delete: files removed from the live server remain on the SSD.
# --whole-file avoids delta-transfer overhead for a local SSD.
sudo rsync -a --whole-file --human-readable --info=progress2 \
  "$DATA_ROOT/immich/library/" "$BACKUP_ROOT/photos/"

if ! sudo docker inspect -f "{{.State.Running}}" immich_postgres 2>/dev/null | grep -q true; then
  echo "ERROR: immich_postgres is not running."
  exit 1
fi

echo "==> Creating Immich database backup..."
sudo sh -c "docker exec immich_postgres pg_dump -U \"$DB_USER\" -d \"$DB_NAME\" | gzip > \"$BACKUP_ROOT/database/immich.sql.gz\""

echo "==> Backing up Home Assistant..."
sudo tar -C "$DATA_ROOT" -czf "$BACKUP_ROOT/homeassistant/homeassistant.tar.gz" homeassistant

sync
echo "Backup complete."
echo "Backup location: $BACKUP_ROOT"
echo "No files were deleted from the SSD."
echo "SSD will be safely unmounted."
