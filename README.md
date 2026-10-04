# Home Server Bootstrap

Simple, reproducible setup for an old laptop running **Ubuntu Server 24.04 LTS**.

The server runs:

- **Immich** — family photo backup and browsing
- **Home Assistant** — home automation
- **Docker Compose** — service management
- **Tailscale** — private remote access
- **AdGuard Home** — network-wide DNS ad/tracker blocking
- **Dozzle** — Docker log viewer
- **UFW** — basic firewall protection

The internal laptop storage is the live storage. A portable **1 TB exFAT SSD** is used only as an offline backup.

## 1. Fresh Ubuntu installation

Install Ubuntu Server 24.04 LTS and enable **OpenSSH Server** during installation.

After logging in:

```bash
git clone https://github.com/jeevanragula/home-server-bootstrap.git ~/home-server-bootstrap
cd ~/home-server-bootstrap
cp .env.example .env
nano .env
sudo bash setup.sh
```

After `.env` has been configured, `sudo bash setup.sh` is the only setup command required.

On the first run, Tailscale may open an authentication flow. Authenticate the server with your Tailscale account and then allow the setup to continue.

## 2. Configuration

All local configuration is kept in **one file**:

```text
.env
```

It contains:

- Server paths
- Time zone
- Immich PostgreSQL credentials
- Immich version
- Backup SSD paths

The file is ignored by Git and must never be committed.

Keep a secure copy of `.env` in your password manager. The backup script also copies it to the offline SSD for disaster recovery.

Example:

```env
DATA_ROOT=/srv/docker
TZ=Asia/Kolkata

IMMICH_DB_USERNAME=immich
IMMICH_DB_PASSWORD=your-long-password
IMMICH_DB_NAME=immich

IMMICH_VERSION=v3.2.2

BACKUP_MOUNT=/mnt/home-server-backup
BACKUP_ROOT=/mnt/home-server-backup/homeserver
```

## 3. Services

### Immich

Immich is exposed on:

```text
http://<server-ip>:2283
```

The deployment includes:

- Immich Server
- PostgreSQL with VectorChord/pgvector support
- Valkey

**Immich machine learning is intentionally disabled** to keep CPU and RAM usage low on the old laptop. Face recognition and other ML-dependent features are therefore unavailable.

### Home Assistant

Home Assistant is exposed on:

```text
http://<server-ip>:8123
```

### AdGuard Home

AdGuard Home provides network-wide DNS filtering for your home devices.

Initial setup:

```text
http://<server-ip>:3000
```

After the first-run wizard, configure your home router's DNS server to use the home server's LAN IP.

AdGuard's DNS service listens on port `53`. DHCP is intentionally **not** enabled; let your existing router continue providing DHCP.

AdGuard persistent data is stored under:

```text
/srv/docker/adguard/
├── work/
└── conf/
```

### Dozzle

Dozzle provides a lightweight browser UI for viewing Docker container logs:

```text
http://<server-ip>:8080
```

It has read-only access to the Docker socket. Container actions and shell access are intentionally disabled.

Dozzle persistent data is stored under:

```text
/srv/docker/dozzle/
```

### Tailscale

Tailscale runs directly on Ubuntu as a system service rather than inside Docker. This allows remote access without exposing the services directly to the public Internet.

Validate the server's Tailscale installation and connection at any time:

```bash
cd ~/home-server-bootstrap
sudo bash ./scripts/check-tailscale.sh
```

The check verifies that:

- Tailscale is installed.
- `tailscaled` is running.
- The server is authenticated and connected.
- A Tailscale IPv4 address is assigned.
- The `tailscale0` interface exists.
- Tailscale network diagnostics can run.

The validation script is **read-only** and does not change Tailscale configuration.

## 4. Live storage

All persistent application data is stored under:

```text
/srv/docker/
├── immich/
│   ├── library/
│   └── postgres/
└── homeassistant/
```

Do not manually move or rename files inside the Immich library while Immich is running. Use the Immich application for photo management.

## 5. Offline SSD backup

Keep the portable SSD disconnected during normal operation.

Connect it only when you want to perform a backup:

```bash
cd ~/home-server-bootstrap
./scripts/backup-to-ssd.sh
```

The script:

1. Finds exactly one existing exFAT filesystem.
2. Mounts the SSD.
3. Creates the `homeserver/` directory if required.
4. Copies `.env`.
5. Incrementally copies the Immich photo library.
6. Creates an Immich PostgreSQL dump.
7. Archives the Home Assistant configuration.
8. Syncs the filesystem.
9. Safely unmounts the SSD.

### SSD layout

```text
SSD/
└── homeserver/
    ├── .env
    ├── photos/
    ├── database/
    │   └── immich.sql.gz
    └── homeassistant/
        └── homeassistant.tar.gz
```

### Backup safety

The backup script is intentionally **non-destructive**.

It:

- does **not** use `rsync --delete`
- does **not** delete files from the SSD
- keeps photos that were later deleted from the server
- incrementally copies the photo library instead of creating duplicate snapshot directories
- does **not** format, partition, wipe, or initialize the SSD
- refuses to guess if multiple exFAT disks are connected
- fails safely if no suitable existing exFAT filesystem is found

**Important:** No script in this repository formats or initializes the portable SSD. The SSD must be prepared separately, outside this repository, before it is used for backups.

Database and Home Assistant backups are refreshed on each backup run.

## 6. Disaster recovery

If the laptop fails:

1. Install Ubuntu Server 24.04 LTS.
2. Clone this repository.
3. Restore the backed-up `.env`.
4. Run `setup.sh`.
5. Restore the Immich database and application data from the SSD.

The SSD contains both the application configuration and the data required for recovery.

## 7. Useful commands

Start or update services:

```bash
./scripts/up.sh
```

Stop services:

```bash
./scripts/down.sh
```

Validate Tailscale:

```bash
sudo bash ./scripts/check-tailscale.sh
```

Run an offline SSD backup:

```bash
./scripts/backup-to-ssd.sh
```

Unmount the backup SSD manually if necessary:

```bash
./scripts/unmount-backup.sh
```

## 8. Important notes

- The portable SSD is **never formatted, partitioned, wiped, or initialized** by this repository.
- Keep the SSD disconnected when it is not being used for backup.
- Keep a separate secure copy of `.env` in your password manager.
- Do not commit `.env` to Git.
- Do not manually modify the Immich library while Immich is running.
