# Port Mapping Reference for 192.168.1.222

## Current Port Usage (Your Existing Setup)

| Port(s) | Service | Status | Notes |
|---------|---------|--------|-------|
| 5000 | 13Feet-Ladder | ✅ Running | Paywall bypass |
| 5678 | n8n | ⚠️ Restarting | Has error - check logs |
| 6333 | Qdrant | ✅ Running | Not GPU-accelerated |
| 7814, 7914 | Firefox | ✅ Running | Web browser container |
| 8080 | open-webui | ✅ Running | AI chat interface |
| 8081 | SearXNG | ✅ Running | Meta search engine |
| 8082, 1141 | stremio | ✅ Running | Media streaming |
| 8123 | KitchenOwl | ✅ Running | Recipe/grocery manager |
| 8666 | Nextcloud | ❌ Stopped | Has error - check logs |
| 9000, 9001 | Portainer-BE | ✅ Running | Container management |
| 11434 | ollama | ✅ Running | Not GPU-accelerated |

## New Ports (Deployment Files)

### Infrastructure Stack - No Conflicts ✅
| Port | Service | Conflicts? |
|------|---------|-----------|
| 8008 | Homepage | ✅ Available |
| 3010 | Uptime Kuma | ✅ Available |
| 9999 | Dozzle | ✅ Available |
| N/A | Watchtower | ✅ No ports |
| Host | Tailscale | ✅ Host network |

### Media Stack - No Conflicts ✅
| Port | Service | Conflicts? |
|------|---------|-----------|
| 32400, 1900, 32410-32414 | Plex | ✅ Available |
| 8989 | Sonarr | ✅ Available |
| 7878 | Radarr | ✅ Available |
| 9696 | Prowlarr | ✅ Available |
| 6767 | Bazarr | ✅ Available |
| 5055 | Overseerr | ✅ Available |
| 8181 | Tautulli | ✅ Available |
| 9090 | Zurg | ✅ Available |

### AI Core Stack - Replaces Existing ⚠️
| Port | Service | Action Required |
|------|---------|----------------|
| 11434 | ollama | 🔄 Upgrade to GPU version |
| 8080 | open-webui | 🔄 Recreate linked to GPU ollama |
| 6333 | Qdrant | 🔄 Upgrade to GPU version |

### Home Automation Stack - Has Conflicts ❌
| Port | Service | Conflicts? | Solution |
|------|---------|-----------|----------|
| 8123 | Home Assistant | ❌ KitchenOwl | Use 8124 instead |
| 1883 | Mosquitto MQTT | ✅ Available | No conflict |
| 1880 | Node-RED | ✅ Available | No conflict |
| 8080 | Zigbee2MQTT | ❌ open-webui | Use 8083 instead |
| 6052 | ESPHome | ⚠️ You have ESPHome | Skip or migrate |

## Recommended Port Assignments

### Option 1: Modified Home Automation Ports
Use `home-automation-no-conflicts.yml` instead of `home-automation.yml`:
- Home Assistant: **8124** (instead of 8123)
- Zigbee2MQTT: **8083** (instead of 8080)

### Option 2: Skip Conflicting Services
Edit `home-automation.yml` and remove:
- `homeassistant` service (you have it elsewhere or use KitchenOwl's port)
- `esphome` service (you already have it running)

## Complete Service Map (After Full Deployment)

### Access URLs
```
# Infrastructure
http://192.168.1.222:8008  → Homepage Dashboard
http://192.168.1.222:9000  → Portainer (existing)
http://192.168.1.222:3010  → Uptime Kuma
http://192.168.1.222:9999  → Dozzle Logs

# Media
http://192.168.1.222:32400/web → Plex
http://192.168.1.222:8989  → Sonarr
http://192.168.1.222:7878  → Radarr
http://192.168.1.222:9696  → Prowlarr
http://192.168.1.222:6767  → Bazarr
http://192.168.1.222:5055  → Overseerr
http://192.168.1.222:8181  → Tautulli
http://192.168.1.222:9090  → Zurg

# AI & Tools (Existing + Upgraded)
http://192.168.1.222:8080  → Open WebUI
http://192.168.1.222:6333  → Qdrant
http://192.168.1.222:11434 → Ollama API
http://192.168.1.222:8081  → SearXNG
http://192.168.1.222:5678  → n8n
http://192.168.1.222:5000  → 13Feet-Ladder

# Home & Utilities (Existing)
http://192.168.1.222:8123  → KitchenOwl
http://192.168.1.222:7814  → Firefox
http://192.168.1.222:8082  → Stremio
http://192.168.1.222:8666  → Nextcloud (fix needed)

# Home Automation (New)
http://192.168.1.222:8124  → Home Assistant (modified port)
http://192.168.1.222:1880  → Node-RED
http://192.168.1.222:8083  → Zigbee2MQTT (modified port)
mqtt://192.168.1.222:1883  → Mosquitto MQTT
```

## Deployment Order (Avoiding Conflicts)

### Phase 1: Add Infrastructure ✅
```bash
# No conflicts - safe to deploy
docker compose -f stacks/infrastructure.yml --env-file .env.infrastructure up -d
```

### Phase 2: Add Media Stack ✅
```bash
# No conflicts - safe to deploy
# But first remove old zurg:
docker stop zurg && docker rm zurg

docker compose -f stacks/media.yml --env-file .env.media up -d
```

### Phase 3: Upgrade AI Stack (GPU) ⚠️
```bash
# Stop existing containers
docker stop ollama open-webui qdrant
docker rm ollama open-webui qdrant

# Deploy GPU-accelerated versions
docker compose -f stacks/ai-core.yml --env-file .env.ai-core up -d

# Verify GPU usage
./scripts/gpu-check.sh
```

### Phase 4: Add Home Automation (Modified Ports) ⚠️
```bash
# Use the no-conflicts version
docker compose -f stacks/home-automation-no-conflicts.yml \
  --env-file .env.home-automation up -d
```

## Port Conflict Resolution Commands

### If you want to change existing container ports:

**Change KitchenOwl to different port:**
```bash
docker stop KitchenOwl-All-in-one
# Edit the container in Portainer or recreate with new port
# Then Home Assistant can use 8123
```

**Change open-webui to different port (free up 8080 for Zigbee2MQTT):**
```bash
docker stop open-webui
# Edit port mapping: 8085:8080 instead of 8080:8080
# Then Zigbee2MQTT can use 8080
```

## Firewall/Router Notes

All services are on the local network (192.168.1.222). No ports need to be forwarded to the internet.

**For remote access:**
- Use Tailscale (deployed in infrastructure stack)
- No port forwarding needed
- Access services via Tailscale VPN as if you're on the local network

## Useful Commands

**Check what's listening on a port:**
```bash
netstat -tulpn | grep :8080
# or
lsof -i :8080
```

**View all Docker container ports:**
```bash
docker ps --format "table {{.Names}}\t{{.Ports}}" | sort
```

**Find available ports:**
```bash
# Check range 8000-9000
for port in {8000..9000}; do
  ! nc -z 192.168.1.222 $port && echo "Port $port is available"
done
```

## Quick Reference: Services by Category

### 🎬 Media & Entertainment
- Plex, Sonarr, Radarr, Prowlarr, Bazarr, Overseerr, Tautulli, Zurg, Stremio

### 🤖 AI & Search
- Ollama, Open WebUI, Qdrant, SearXNG, n8n

### 🏠 Home & Utilities
- KitchenOwl, Nextcloud, Firefox, 13Feet-Ladder

### 🛠 Infrastructure & Monitoring
- Portainer, Homepage, Uptime Kuma, Dozzle, Watchtower, Tailscale

### 🏡 Home Automation
- Home Assistant, Mosquitto, Node-RED, Zigbee2MQTT, ESPHome

---

**Total Services After Full Deployment:** ~30 containers
**Current Services:** 13 containers
**New Services Added:** ~17 containers
