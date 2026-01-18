# Integration Guide for Existing Unraid Setup

## Your Current Setup Analysis

**Server IP:** 192.168.1.222
**Existing Containers:** 13 total (11 running, 2 stopped)

### Services You Already Have:
- ✅ ollama (but needs GPU support)
- ✅ open-webui (working)
- ✅ Qdrant (but needs GPU support)
- ✅ ESPHome (working)
- ✅ Portainer-BE (Business Edition)
- ✅ zurg (stopped)

### What This Deployment Adds:
- 🆕 Complete Media Stack (Plex, *arr suite)
- 🆕 Infrastructure tools (Tailscale, Homepage, monitoring)
- 🆕 Home Automation (Home Assistant, MQTT, Node-RED, Zigbee2MQTT)
- 🔧 GPU-accelerated AI (upgrade your existing ollama/Qdrant)

## Integration Strategy

### Option 1: Selective Deployment (Recommended)

Deploy only what you're missing, keep your working containers.

#### Step 1: Deploy Infrastructure Stack (NEW)
```bash
docker compose -f infrastructure.yml --env-file .env.infrastructure up -d
```

**New Services:**
- Tailscale (VPN access)
- Homepage (dashboard at :8008)
- Uptime Kuma (:3010)
- Dozzle (:9999)
- Watchtower (auto-updates)

**No conflicts** - all use different ports

#### Step 2: Deploy Media Stack (NEW)
```bash
docker compose -f media.yml --env-file .env.media up -d
```

**New Services:**
- Plex (:32400)
- Sonarr (:8989)
- Radarr (:7878)
- Prowlarr (:9696)
- Bazarr (:6767)
- Overseerr (:5055)
- Tautulli (:8181)

**⚠️ Note:** Your zurg container is stopped. The media stack includes zurg configured properly. You should:
1. Remove your old zurg: `docker rm zurg`
2. Let the media stack deploy the new one

#### Step 3: Upgrade AI Stack (REPLACE)

Your current AI containers work but **aren't using your GPU**. Here's how to upgrade:

**Stop existing containers:**
```bash
docker stop ollama qdrant
docker rm ollama qdrant
```

**Deploy GPU-accelerated versions:**
```bash
docker compose -f ai-core.yml --env-file .env.ai-core up -d
```

**What changes:**
- ollama: Now uses `runtime: nvidia` for GPU acceleration
- Qdrant: Upgrades to `qdrant:gpu-nvidia-latest` image
- open-webui: Re-created to link properly to new containers

**⚠️ Important:**
- Your open-webui data will be preserved (in `/mnt/user/appdata/open-webui`)
- Your ollama models will be preserved (in `/mnt/user/appdata/ollama`)
- You may need to stop your current open-webui first: `docker stop open-webui && docker rm open-webui`

#### Step 4: Deploy Home Automation (OPTIONAL)

If you want Home Assistant integration:
```bash
docker compose -f home-automation.yml --env-file .env.home-automation up -d
```

**⚠️ Port Conflict:** Your KitchenOwl uses port 8123, which Home Assistant also needs.

**Solutions:**
- A) Don't deploy homeassistant service (edit the YAML to remove it)
- B) Change KitchenOwl to a different port
- C) Use the Home Assistant you already have on another machine

The other services (Mosquitto MQTT, Node-RED, Zigbee2MQTT) use different ports and won't conflict.

### Option 2: Clean Slate Deployment

If you want to start fresh with the organized stack structure:

1. **Backup your data:**
   ```bash
   # Your important appdata folders:
   cd /mnt/user/appdata
   tar -czf ~/backup-$(date +%Y%m%d).tar.gz \
     ollama open-webui qdrant ESPHome portainer-be \
     kitchenowl n8n nextcloud searxng stremio
   ```

2. **Run wipe script:**
   ```bash
   ./scripts/wipe-and-prep.sh
   ```

3. **Deploy all stacks:**
   ```bash
   ./scripts/auto-deploy.sh
   ```

4. **Restore specific data:**
   ```bash
   # Restore any apps you want to keep
   tar -xzf ~/backup-*.tar.gz -C /mnt/user/appdata
   ```

## Port Conflict Resolution

### Current Port Usage:
| Port | Your Container | Deployment Files | Resolution |
|------|---------------|------------------|------------|
| 5000 | 13Feet-Ladder | - | No conflict |
| 5678 | n8n | - | No conflict |
| 6333 | Qdrant | Qdrant (upgrade) | Replace with GPU version |
| 7814/7914 | Firefox | - | No conflict |
| 8080 | open-webui | Zigbee2MQTT | **CONFLICT** |
| 8081 | SearXNG | - | No conflict |
| 8082 | stremio | - | No conflict |
| 8123 | KitchenOwl | Home Assistant | **CONFLICT** |
| 9000/9001 | Portainer | - | No conflict |
| 11434 | ollama | ollama (upgrade) | Replace with GPU version |

### Fixing Port Conflicts:

**Conflict 1: Port 8080**
- Your open-webui uses 8080
- Deployment's Zigbee2MQTT also needs 8080

**Solution:** Edit `home-automation.yml` to change Zigbee2MQTT port:
```yaml
zigbee2mqtt:
  ports:
    - "8083:8080"  # Changed from 8080:8080
```

**Conflict 2: Port 8123**
- Your KitchenOwl uses 8123
- Home Assistant needs 8123

**Solution:** Either skip Home Assistant (you have it elsewhere) or change KitchenOwl's port.

## Updating IP Addresses

All example files use `192.168.1.9`. Since your server is `192.168.1.222`, update:

### In .env files:
```bash
# If using Tailscale, update LOCAL_SUBNET if needed
LOCAL_SUBNET=192.168.1.0/24  # This is fine if your network is 192.168.1.x
```

### In homepage-dashboard.yaml:
```bash
# Find and replace all instances
sed -i 's/192.168.1.9/192.168.1.222/g' configs/homepage-dashboard.yaml
```

## Recommended Integration Steps

### Phase 1: Add Infrastructure (Week 1)
1. Update `.env.infrastructure` with your values
2. Deploy infrastructure stack
3. Configure Tailscale
4. Access Homepage dashboard at http://192.168.1.222:8008

### Phase 2: Add Media Services (Week 2)
1. Get Real-Debrid API key
2. Get Plex claim token
3. Update `.env.media`
4. Remove old zurg: `docker rm zurg`
5. Deploy media stack
6. Configure Plex libraries

### Phase 3: Upgrade AI Stack (Week 3)
1. Verify GPU drivers: `nvidia-smi`
2. Backup current Ollama models
3. Stop and remove old AI containers
4. Deploy GPU-accelerated AI stack
5. Test with `./scripts/gpu-check.sh`
6. Pull models: `docker exec ollama ollama pull llama2`

### Phase 4: Fix Problem Containers
1. **n8n** - Debug why it's restarting:
   ```bash
   docker logs n8n
   ```

2. **Nextcloud** - Fix exit error:
   ```bash
   docker logs nextcloud
   ```

### Phase 5: Optional Home Automation
1. Decide if you need Home Assistant (you may already have it)
2. Fix port 8080 conflict (Zigbee2MQTT)
3. Deploy home automation stack

## GPU Acceleration Setup

Before upgrading AI stack, ensure GPU support:

```bash
# Check if Unraid has NVIDIA plugin
nvidia-smi

# If not installed:
# 1. Go to Unraid Apps
# 2. Search "Nvidia-Driver"
# 3. Install plugin
# 4. Reboot
```

Then verify Docker can use GPU:
```bash
# Check docker runtime
docker info | grep -i runtime

# Should show:
# Runtimes: nvidia runc
```

## Summary

**Quickest Win:** Deploy Infrastructure + Media stacks (no conflicts)
```bash
cd unraid-deployment
# Edit .env files first
docker compose -f stacks/infrastructure.yml --env-file .env.infrastructure up -d
docker compose -f stacks/media.yml --env-file .env.media up -d
```

**Most Impactful:** Upgrade AI stack to use GPU
```bash
# Stop old containers
docker stop ollama qdrant open-webui
docker rm ollama qdrant open-webui

# Deploy GPU versions
docker compose -f stacks/ai-core.yml --env-file .env.ai-core up -d

# Verify GPU usage
./scripts/gpu-check.sh
```

## Questions to Answer Before Proceeding

1. **Do you have NVIDIA GPU drivers installed on Unraid?**
   - Check: `nvidia-smi`
   - If no, install Nvidia-Driver plugin first

2. **Do you want to keep your existing open-webui setup?**
   - If yes: Just upgrade ollama/Qdrant, keep open-webui
   - If no: Let stack recreate all three

3. **What happened to your n8n and Nextcloud containers?**
   - Check logs to debug before adding more services

4. **Do you have a Real-Debrid account?**
   - Required for media stack's zurg integration
   - Get API key from: https://real-debrid.com/apitoken

5. **Do you want Tailscale VPN access?**
   - Allows secure remote access without port forwarding
   - Get auth key from: https://login.tailscale.com/admin/settings/keys

Let me know your preferences and I'll create a specific deployment plan!
