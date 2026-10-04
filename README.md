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

The script automatically finds exactly one exFAT filesystem, mounts it, and backs up into the single configured `homeserver/` directory. Photo backup is incremental, so existing files are reused and only new/changed files are copied. It never uses `--delete`, so files removed from the live server remain on the SSD. If multiple exFAT disks are connected, it refuses to guess.

The SSD also receives a copy of `.env`, which is needed for disaster recovery. Keep the primary `.env` in your password manager as well. The database and Home Assistant backups are refreshed on each run; the script never deletes files from the SSD.

## Live storage

```text
/srv/docker/immich/library
/srv/docker/immich/postgres
/srv/docker/homeassistant
```

The portable SSD is never formatted by this repository.
