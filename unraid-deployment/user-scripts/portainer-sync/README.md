# Chimera Portainer Sync (User Script)

This User Script copies stack files and env templates into **/boot/config/plugins/chimera/portainer** so Portainer can deploy stacks locally without pulling from Git.

## Prerequisites

Clone the repo to the Unraid flash drive first:
```bash
mkdir -p /boot/config/plugins/chimera
git clone https://github.com/Enigmaticjoe/hope.git /boot/config/plugins/chimera/deployment
```

This puts your stacks at `/boot/config/plugins/chimera/deployment/unraid-deployment/stacks/`, which the sync script auto-detects.

**Alternative locations** (also auto-detected):
- `/mnt/user/appdata/chimera/unraid-deployment/stacks/`
- `/tmp/chimera/unraid-deployment/stacks/`

## Install

```bash
mkdir -p /boot/config/plugins/user.scripts/scripts/portainer-sync
cp /boot/config/plugins/chimera/deployment/unraid-deployment/user-scripts/portainer-sync/* \
  /boot/config/plugins/user.scripts/scripts/portainer-sync/
chmod +x /boot/config/plugins/user.scripts/scripts/portainer-sync/script
```

## Run

From **Settings -> User Scripts**, run **Chimera Portainer Sync**.

### Override repo location

If your repo is somewhere else, set `SOURCE_DIR` as a User Script variable:
```
SOURCE_DIR=/mnt/user/appdata/chimera/unraid-deployment
```

The script will search common locations automatically, but `SOURCE_DIR` takes priority if set.
