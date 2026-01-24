# Unraid Smart Server Deployment

Complete, modular deployment files for a fully-featured Unraid smart home server with Media Services, AI Tools, Infrastructure, and Home Automation.

## 🚀 Quick Start

### 1. Prerequisites
- Unraid server with Docker support
- NVIDIA GPU drivers installed (for AI features)
- Accounts: Plex Pass, Real-Debrid, Tailscale

### 2. Setup Environment Files
Copy and customize the environment templates:

```bash
cd unraid-deployment
cp env-templates/.env.infrastructure .env.infrastructure
cp env-templates/.env.media .env.media
cp env-templates/.env.ai-core .env.ai-core
cp env-templates/.env.home-automation .env.home-automation
```

Edit each `.env.*` file with your specific values (API keys, paths, etc.)

### 3. Deploy the Stacks

#### Option A: Using the Auto-Deploy Script
```bash
cd unraid-deployment
./scripts/auto-deploy.sh
```

#### Option B: Using Portainer
1. Open Portainer web UI (http://your-unraid-ip:9000)
2. Create a new stack for each YAML file in `stacks/`
3. Upload the corresponding `.env` file for each stack
4. Deploy in order: infrastructure → media → ai-core → home-automation

#### Option C: Using Docker Compose
```bash
cd unraid-deployment/stacks

# Deploy infrastructure stack
docker compose -f infrastructure.yml --env-file ../.env.infrastructure up -d

# Deploy media stack
docker compose -f media.yml --env-file ../.env.media up -d

# Deploy AI core stack
docker compose -f ai-core.yml --env-file ../.env.ai-core up -d

# Deploy home automation stack
docker compose -f home-automation.yml --env-file ../.env.home-automation up -d
```

### 4. Auto-Configure Media Stack (Recommended)
After deploying the media stack, run the Chimera configurator to automatically wire everything together:

```bash
# Fully automatic mode - discovers services, extracts API keys, configures integrations
./scripts/chimera-setup.sh --auto

# Or preview changes first
./scripts/chimera-setup.sh --auto --dry-run

# Or use interactive mode for step-by-step setup
./scripts/chimera-setup.sh --interactive
```

This automatically configures:
- Rdt-Client → Sonarr/Radarr (download client)
- Prowlarr → Sonarr/Radarr (indexer sync)
- Bazarr → Sonarr/Radarr (subtitles)
- Overseerr → Sonarr/Radarr (requests)
- Root folders and paths

See [scripts/MEDIA-CONFIGURATOR.md](./scripts/MEDIA-CONFIGURATOR.md) for full documentation.

### 5. Configure Homepage Dashboard
Copy the dashboard configuration to your Homepage appdata folder:
```bash
cp configs/homepage-dashboard.yaml /mnt/user/appdata/homepage/config.yml
```

### 6. Verify GPU Support (for AI stack)
```bash
./scripts/gpu-check.sh
```

## 📦 What's Included

### Infrastructure Stack
- **Tailscale** - Secure VPN access to your network
- **Homepage** - Unified dashboard for all services
- **Uptime Kuma** - Service monitoring
- **Dozzle** - Real-time log viewer
- **Watchtower** - Automatic container updates

### Media Stack
- **Plex** - Media server with hardware transcoding
- **Sonarr** - TV show management
- **Radarr** - Movie management
- **Prowlarr** - Indexer management
- **Bazarr** - Subtitle management
- **Overseerr** - Media requests
- **Tautulli** - Plex analytics
- **Zurg** - Real-Debrid integration

### AI Core Stack
- **Ollama** - Local LLM inference engine
- **Open WebUI** - ChatGPT-like interface
- **Qdrant** - Vector database for RAG

### Home Automation Stack
- **Home Assistant** - Home automation hub
- **Mosquitto** - MQTT broker
- **Node-RED** - Visual automation workflows
- **Zigbee2MQTT** - Zigbee device integration
- **ESPHome** - ESP device management

## 📚 Documentation

For complete setup instructions, configuration details, and troubleshooting:
- **[UNRAID-DEPLOYMENT.md](./UNRAID-DEPLOYMENT.md)** - Comprehensive deployment guide

## 🛠 Utility Scripts

| Script | Purpose |
|--------|---------|
| `chimera-setup.sh` | Auto-configure media stack integrations (Sonarr↔Radarr↔Prowlarr↔Rdt-Client) |
| `media_configurator.py` | Python tool for media stack configuration (used by chimera-setup.sh) |
| `auto-deploy.sh` | Automated deployment of all stacks |
| `wipe-and-prep.sh` | Clean slate: removes all containers and prepares directories |
| `gpu-check.sh` | Verify NVIDIA GPU support for AI services |

## 🔒 Security Notes

- **Never commit `.env` files to version control** - they contain sensitive API keys
- Store secrets securely (encrypted cloud storage or password manager)
- The `auto-deploy.sh` script supports loading secrets from a `./secrets/` directory
- Tailscale provides encrypted VPN access without opening ports on your router

## 🎯 Access Your Services

After deployment, access your services at:
- Homepage Dashboard: http://192.168.1.9:8008
- Plex: http://192.168.1.9:32400/web
- Open WebUI (AI): http://192.168.1.9:3000
- Home Assistant: http://192.168.1.9:8123
- And more! (See homepage dashboard for all links)

## 📝 Next Steps

1. **Run Chimera Setup**: `./scripts/chimera-setup.sh --auto` (connects all media services)
2. Configure Plex libraries and claim your server
3. Add indexers to Prowlarr (will auto-sync to Sonarr/Radarr)
4. Set up Real-Debrid credentials in Rdt-Client
5. Install Ollama models: `docker exec ollama ollama pull llama2`
6. Configure Home Assistant integrations
7. Set up Uptime Kuma monitors for your services

## 🤝 Support

For issues or questions:
1. Check the [comprehensive deployment guide](./UNRAID-DEPLOYMENT.md)
2. Review container logs via Dozzle (http://192.168.1.9:9999)
3. Verify all `.env` values are correct

## 📄 License

These deployment files are provided as-is for personal use. Individual services have their own licenses.
