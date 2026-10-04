# Home Server Bootstrap

## Fresh Ubuntu Server

After installing Ubuntu Server:

\`\`\`bash
git clone https://github.com/jeevanragula/home-server-bootstrap.git ~/home-server-bootstrap
cd ~/home-server-bootstrap
sudo bash setup.sh
\`\`\`

**That is the only setup command.**

It installs Docker, Tailscale, required packages, power settings and firewall rules, creates live storage under \`/srv/docker\`, generates the Immich DB secret, and starts Immich + Home Assistant.

If Tailscale needs authentication, run \`sudo tailscale up\` once.

Open Immich on port 2283 and Home Assistant on port 8123, then create their admin accounts in the web UIs.

## Photo backup

Keep the portable exFAT SSD disconnected normally.

When connected, run:

\`\`\`bash
./scripts/backup-to-ssd.sh
\`\`\`

The script automatically finds exactly one exFAT filesystem, mounts it, incrementally backs up the Immich library, creates an Immich PostgreSQL dump and timestamped Home Assistant archive, syncs everything, and safely unmounts the SSD.

If multiple exFAT disks are connected, it refuses to guess.

The backup does not use \`--delete\`, so deleted live photos remain on the offline backup.

## Live storage

\`\`\`
/srv/docker/immich/library
/srv/docker/immich/postgres
/srv/docker/homeassistant
\`\`\`

The portable SSD is never formatted by this repository.
