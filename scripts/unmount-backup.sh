#!/usr/bin/env bash
set -euo pipefail

MOUNT_POINT="/mnt/home-server-backup"

if ! mountpoint -q "$MOUNT_POINT"; then
  echo "Backup SSD is not mounted."
  exit 0
fi

sync
sudo umount "$MOUNT_POINT"
echo "Backup SSD safely unmounted. You can unplug it."
