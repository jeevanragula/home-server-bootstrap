#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/.env"
MOUNT_POINT="/mnt/home-server-backup"
BACKUP_ROOT="$MOUNT_POINT/home-server-backup"

[[ -f "$CONFIG_FILE" ]] || { echo "ERROR: Run setup.sh first."; exit 1; }
DATA_ROOT="$(awk -F= '$1=="DATA_ROOT" {print substr($0, index($0,$2))}' "$CONFIG_FILE")"
DATA_ROOT="${DATA_ROOT:-/srv/docker}"
DB_USER="$(grep "^IMMICH_DB_USERNAME=" "$CONFIG_FILE" | cut -d= -f2-)"
DB_NAME="$(grep "^IMMICH_DB_NAME=" "$CONFIG_FILE" | cut -d= -f2-)"

[[ -d "$DATA_ROOT/immich/library" ]] || { echo "ERROR: Immich library not found."; exit 1; }
sudo mkdir -p "$MOUNT_POINT"
AUTO_MOUNTED=0

if ! mountpoint -q "$MOUNT_POINT"; then
  mapfile -t EXFAT_DEVICES < <(lsblk -rpno NAME,FSTYPE | awk '$2=="exfat" {print $1}')
  if [[ "${#EXFAT_DEVICES[@]}" -eq 0 ]]; then echo "ERROR: No exFAT SSD found. Connect it and retry."; exit 1; fi
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

cleanup() { if [[ "$AUTO_MOUNTED" -eq 1 ]]; then sync || true; sudo umount "$MOUNT_POINT" || true; fi; }
trap cleanup EXIT
FSTYPE="$(findmnt -n -o FSTYPE "$MOUNT_POINT")"
[[ "$FSTYPE" == "exfat" ]] || { echo "ERROR: Expected exfat, found $FSTYPE."; exit 1; }
sudo mkdir -p "$BACKUP_ROOT"
SNAPSHOT_ROOT="$BACKUP_ROOT/snapshot-$(date +%Y%m%d-%H%M%S)-$"
sudo mkdir -p "$SNAPSHOT_ROOT/photos" "$SNAPSHOT_ROOT/homeassistant" "$SNAPSHOT_ROOT/database"
echo "==> Backing up Immich photos to a fresh snapshot..."
# The SSD is append-only from this script's perspective: no delete/overwrite flags are used.
# --whole-file is appropriate for a local SSD and avoids rsync's delta-transfer overhead.
sudo rsync -a --whole-file --human-readable --info=progress2 "$DATA_ROOT/immich/library/" "$SNAPSHOT_ROOT/photos/"
if ! sudo docker inspect -f "{{.State.Running}}" immich_postgres 2>/dev/null | grep -q true; then echo "ERROR: immich_postgres is not running."; exit 1; fi
echo "==> Creating Immich database dump..."
sudo sh -c "docker exec immich_postgres pg_dump -U \"$DB_USER\" -d \"$DB_NAME\" | gzip > \"$SNAPSHOT_ROOT/database/immich.sql.gz\""
echo "==> Backing up Home Assistant..."
sudo tar -C "$DATA_ROOT" -czf "$SNAPSHOT_ROOT/homeassistant/homeassistant.tar.gz" homeassistant
sync
echo "Backup complete. New snapshot: $SNAPSHOT_ROOT"
echo "Existing SSD backups were not modified or removed. SSD will be safely unmounted."
