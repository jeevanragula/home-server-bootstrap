# Home Server Bootstrap

Simple Ubuntu Server home server for an old Dell laptop.

## Purpose

- Immich for phone photo backup
- Home Assistant for home automation
- Docker Compose for service management
- Tailscale for remote/private access
- Internal HDD for live application data
- Portable exFAT SSD for offline backups

The SSD is **backup-only**. The bootstrap script never formats, mounts, or writes to it.

## Repository layout

```
.
├── compose/
│   ├── docker-compose.yml
│   └── secrets.example
├── scripts/
│   ├── up.sh
│   ├── down.sh
│   ├── backup-to-ssd.sh
│   └── unmount-backup.sh
├── .env.example
├── .gitignore
└── install.sh
```

## First-time setup

```bash
git clone https://github.com/jeevanragula/home-server-bootstrap.git ~/home-server-bootstrap
cd ~/home-server-bootstrap

cp .env.example .env
cp compose/secrets.example compose/secrets.env
nano compose/secrets.env

sudo ./install.sh
```

Log out and SSH back in so the Docker group membership is refreshed.

Start the services:

```bash
./scripts/up.sh
```

Then create the first administrator account through the Immich and Home Assistant web UIs. Application users/passwords are **not** managed by Compose.

## Normal operation

```bash
./scripts/up.sh
./scripts/down.sh
```

Pulling the repository does not overwrite `.env` or `compose/secrets.env`; both are ignored by Git.

## SSD backup workflow

The SSD should remain disconnected except during backup.

1. Connect the exFAT SSD.
2. Identify it carefully:

```bash
lsblk -f
```

3. Mount the correct SSD partition:

```bash
sudo mkdir -p /mnt/home-server-backup
sudo mount /dev/sdX1 /mnt/home-server-backup
```

**Never guess /dev/sdX1. Verify it with `lsblk -f`.**

4. Run:

```bash
./scripts/backup-to-ssd.sh
```

The backup contains:

- Immich photos/library files
- A consistent PostgreSQL dump of the Immich database
- A timestamped Home Assistant configuration archive

The backup script deliberately does **not** copy the live PostgreSQL data directory to exFAT. PostgreSQL data should be backed up with `pg_dump`.

5. Safely unmount:

```bash
./scripts/unmount-backup.sh
```

Then unplug the SSD.

## What is backed up

Live data:

```
/srv/docker/immich/library
/srv/docker/immich/postgres
/srv/docker/homeassistant
```

Backup:

```
SSD:/home-server-backup/photos/
/home-server-backup/database/immich.sql.gz
/home-server-backup/homeassistant/
```

Docker images and containers are not backed up because they can be recreated from the Compose file.

## Security model

- No application passwords are committed to Git.
- Tailscale provides remote private access.
- Docker services use an internal bridge network.
- The SSD is normally offline, reducing exposure to accidental deletion/ransomware.
- SSH should be hardened to Tailscale-only only after Tailscale access has been tested.

## Important

Do not manually rename, move, or delete files inside the live Immich library. Use Immich for photo management and this backup workflow for copies.
