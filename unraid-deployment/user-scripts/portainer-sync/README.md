# Chimera Portainer Sync (User Script)

This User Script copies stack files and env templates into **/boot/config/plugins/chimera/portainer** so Portainer can deploy stacks locally without pulling from Git.

## Install

```bash
mkdir -p /boot/config/plugins/user.scripts/scripts/portainer-sync
cp /path/to/unraid-deployment/user-scripts/portainer-sync/* \
  /boot/config/plugins/user.scripts/scripts/portainer-sync/
chmod +x /boot/config/plugins/user.scripts/scripts/portainer-sync/script
```

## Run

From **Settings → User Scripts**, run **Chimera Portainer Sync**.

### Optional: override repo location
If your repo isn’t in the default path, set `SOURCE_DIR` inside the script.
