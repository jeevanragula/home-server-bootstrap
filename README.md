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

The script automatically finds exactly one exFAT filesystem, mounts it, incrementally backs up the Immich library, creates an Immich PostgreSQL dump and timestamped Home Assistant archive, syncs everything, and safely unmounts the SSD. If multiple exFAT disks are connected, it refuses to guess.

The backup does not use `--delete`, so deleted live photos remain on the offline backup.

## Live storage

```text
/srv/docker/immich/library
/srv/docker/immich/postgres
/srv/docker/homeassistant
```

The portable SSD is never formatted by this repository.
