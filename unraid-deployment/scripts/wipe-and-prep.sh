#!/bin/bash
# wipe-and-prep.sh - Stop all containers, remove old data, and prepare directories for a fresh deployment.

echo "Stopping and removing all Docker containers..."
docker rm -f $(docker ps -aq) 2>/dev/null

echo "Removing unused Docker volumes and networks..."
docker volume prune -f
docker network prune -f

echo "Removing any old images..."
docker image prune -af

# Ensure no Real Debrid fuse mount is still active
if mountpoint -q /mnt/user/realdebrid; then
    echo "Unmounting Real Debrid fuse mount..."
    umount -l /mnt/user/realdebrid/pd_zurg 2>/dev/null || true
fi

echo "Cleaning application data directories..."
APPDATA_DIRS="plex sonarr radarr prowlarr bazarr overseerr tautulli zurg \
homepage uptime-kuma tailscale \
homeassistant mosquitto nodered zigbee2mqtt esphome \
ollama openwebui qdrant"
for d in $APPDATA_DIRS; do
    rm -rf /mnt/user/appdata/$d
done

echo "Recreating fresh directories..."
mkdir -p /mnt/user/appdata/{plex,sonarr,radarr,prowlarr,bazarr,overseerr,tautulli,zurg,homepage,uptime-kuma,tailscale}
mkdir -p /mnt/user/appdata/{homeassistant,mosquitto/config,mosquitto/data,mosquitto/log,nodered,zigbee2mqtt,esphome}
mkdir -p /mnt/user/appdata/{ollama,openwebui,qdrant/storage,qdrant/snapshots}
mkdir -p /mnt/user/media/{movies,tv,music,downloads}
mkdir -p /mnt/user/realdebrid

echo "System prep complete. All containers removed and directories are ready."
