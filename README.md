# Home Server Bootstrap

## Fresh Ubuntu Server

Clone the repository, create your one local configuration file, set your passwords, then run setup:

```bash
git clone https://github.com/jeevanragula/home-server-bootstrap.git ~/home-server-bootstrap
cd ~/home-server-bootstrap
cp .env.example .env
 nano .env
sudo bash setup.sh
```

The only persistent configuration file is `.env`. It contains server settings and service passwords and is ignored by Git. Keep a copy in your password manager or another secure location for disaster recovery.

`setup.sh` installs Docker, Tailscale, required packages, power settings and firewall rules, creates live storage under `/srv/docker`, configures the laptop lid, authenticates Tailscale if needed, and starts Immich + Home Assistant.

Immich uses port `2283` and Home Assistant uses port `8123`.

## Photo backup

Keep the portable exFAT SSD disconnected normally. When connected, run:

```bash
./scripts/backup-to-ssd.sh
```

The script automatically finds exactly one exFAT filesystem, mounts it, creates a completely new timestamped snapshot directory containing the Immich library, PostgreSQL dump and Home Assistant archive, then safely unmounts the SSD. Every run writes to a fresh directory; it never deletes, synchronizes with deletion, or overwrites an older backup. If multiple exFAT disks are connected, it refuses to guess.

Backups are append-only from this script's perspective. It never uses `--delete`, never removes old snapshots, and never writes into an existing snapshot. This means old backups remain available for recovery, at the cost of additional SSD space on each run.

## Live storage

```text
/srv/docker/immich/library
/srv/docker/immich/postgres
/srv/docker/homeassistant
```

The portable SSD is never formatted by this repository.
