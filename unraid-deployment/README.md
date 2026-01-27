# Unraid Smart Server Deployment

Complete, modular deployment files for a fully-featured Unraid smart home server with Media Services, AI Tools, Infrastructure, and Home Automation.

## 🚀 Quick Start (Unraid + Portainer First)

### 1. Prerequisites (Fresh Docker)
- **Unraid 6.12+** with Docker enabled.
- **Portainer CE** installed from Apps (this is your primary deployment control plane).
- **User Scripts plugin** installed from Apps (used for post-deploy automation).
- NVIDIA drivers installed for the RTX 4070 if you plan to run AI locally.
- Accounts: Plex Pass, Real-Debrid, Tailscale, Cloudflare (for tunnels).

### 2. Generate `.env` Files (Interactive Wizard)
Use the wizard to prompt through every required variable:
```bash
cd unraid-deployment
./scripts/env-wizard.sh
```

If you prefer manual setup, copy from templates:
```bash
cp env-templates/.env.infrastructure .env.infrastructure
cp env-templates/.env.media .env.media
cp env-templates/.env.ai-core .env.ai-core
cp env-templates/.env.home-automation .env.home-automation
cp env-templates/.env.agentic .env.agentic
```

### 3. Preflight (Ports + Docker Socket + DNS)
```bash
./scripts/preflight.sh --profile nvidia
```

### 4. Deploy with Portainer (Priority Path)
1. Open **Portainer** → Stacks → **Add stack**
2. Create stacks from the files in `stacks/` with the matching `.env.*` file:
   - `infrastructure.yml` → `.env.infrastructure`
   - `media.yml` → `.env.media`
   - `ai-core.yml` → `.env.ai-core` (use profile selection in Portainer)
   - `home-automation.yml` → `.env.home-automation`
   - `agentic.yml` → `.env.agentic`
3. Deploy in order: **infrastructure → media → ai-core → home-automation → agentic**.

### 5. Post-Deploy (User Scripts)
Use the User Scripts plugin to run the Chimera media configurator:
```bash
mkdir -p /boot/config/plugins/user.scripts/scripts/chimera-configurator
mkdir -p /boot/config/plugins/chimera
cp user-scripts/chimera-configurator/* /boot/config/plugins/user.scripts/scripts/chimera-configurator/
cp user-scripts/chimera-configurator/media_configurator.py /boot/config/plugins/chimera/
chmod +x /boot/config/plugins/user.scripts/scripts/chimera-configurator/script
chmod +x /boot/config/plugins/chimera/media_configurator.py
```
Then go to **Settings → User Scripts** and run **Chimera Media Stack Configurator**.

### 6. Optional: CLI Automation (If You Want It)
The scripted path is available, but Portainer remains the primary control plane:
```bash
./scripts/chimera-install.sh --all
```

### 7. Auto-Configure Media Stack (Recommended)
After deploying the media stack, run the Chimera configurator to automatically wire everything together.

**Three deployment options:**

#### Option A: User Scripts Plugin (Easiest)
```bash
# Copy to User Scripts
mkdir -p /boot/config/plugins/user.scripts/scripts/chimera-configurator
mkdir -p /boot/config/plugins/chimera
cp user-scripts/chimera-configurator/* /boot/config/plugins/user.scripts/scripts/chimera-configurator/
cp user-scripts/chimera-configurator/media_configurator.py /boot/config/plugins/chimera/
```
Then go to **Settings → User Scripts** and run "Chimera Media Stack Configurator"

#### Option B: Portainer Stack
Deploy `portainer/chimera-configurator/docker-compose-simple.yml` as a stack in Portainer.

#### Option C: Command Line
```bash
# Fully automatic mode
./scripts/chimera-setup.sh --auto

# Preview changes first
./scripts/chimera-setup.sh --auto --dry-run

# Interactive mode
./scripts/chimera-setup.sh --interactive
```

This automatically configures:
- Rdt-Client → Sonarr/Radarr (download client)
- Prowlarr → Sonarr/Radarr (indexer sync)
- Bazarr → Sonarr/Radarr (subtitles)
- Overseerr → Sonarr/Radarr (requests)
- Root folders and paths

See **[CHIMERA-SETUP.md](./CHIMERA-SETUP.md)** for full deployment guide.

### 8. Configure Homepage Dashboard
Copy the dashboard configuration to your Homepage appdata folder:
```bash
cp configs/homepage-dashboard.yaml /mnt/user/appdata/homepage/config.yml
```

### 9. Verify GPU Support (for AI stack)
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
- **Rdt-Client** - Real-Debrid download client
- **Zurg** - Real-Debrid integration

### AI Core Stack
- **Ollama** - Local LLM inference engine
- **Open WebUI** - ChatGPT-like interface
- **Qdrant** - Vector database for RAG

**NVIDIA RTX 4070:** Use the `nvidia` profile in Portainer or set `AI_CORE_PROFILE=nvidia` in `.env.ai-core`.

### Home Automation Stack
- **Home Assistant** - Home automation hub
- **Mosquitto** - MQTT broker
- **Node-RED** - Visual automation workflows
- **Zigbee2MQTT** - Zigbee device integration
- **ESPHome** - ESP device management

### Agentic Stack
- **n8n** - Orchestration for agentic workflows
- **Browserless** - Headless Chrome for web automation
- **Cloudflared** - Cloudflare Tunnel ingress

## 📚 Documentation

For complete setup instructions, configuration details, and troubleshooting:
- **[UNRAID-DEPLOYMENT.md](./UNRAID-DEPLOYMENT.md)** - Comprehensive deployment guide
- **[CHIMERA-SETUP.md](./CHIMERA-SETUP.md)** - Media stack auto-configuration (User Scripts, Portainer, CLI)
- **[AGENTIC-BIDDING.md](./AGENTIC-BIDDING.md)** - Agentic bidding workflow + Zero Trust ingress
- **[CHIMERA-OPS.md](./CHIMERA-OPS.md)** - Ops runbook, prompts, and service cheat sheets

## 🛠 Utility Scripts

| Script | Purpose |
|--------|---------|
| `chimera-setup.sh` | Auto-configure media stack integrations (Sonarr↔Radarr↔Prowlarr↔Rdt-Client) |
| `media_configurator.py` | Python tool for media stack configuration (used by chimera-setup.sh) |
| `auto-deploy.sh` | Automated deployment of all stacks (supports profiles and single-stack mode) |
| `preflight.sh` | Validates docker socket access, env files, ports, DNS, and GPU profile |
| `wipe-and-prep.sh` | Clean slate: removes all containers and prepares directories (requires --force) |
| `gpu-check.sh` | Verify NVIDIA GPU support for AI services |
| `agentic-bootstrap.sh` | Creates ai_grid network, checks ports, and primes appdata |
| `chimera-install.sh` | End-to-end installer (prepare → validate → deploy → configure) |

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
