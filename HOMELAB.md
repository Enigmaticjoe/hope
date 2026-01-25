# Project Chimera - Homelab Infrastructure

## System Overview

A **federated, privacy-first homelab** running local AI, media automation, and home automation across multiple nodes. All processing happens locally - no cloud dependencies.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PROJECT CHIMERA TOPOLOGY                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│   │  UNRAID SERVER  │    │  PROXMOX NODE   │    │  PROXMOX NODE   │        │
│   │  192.168.1.222  │◄──►│  192.168.1.114  │◄──►│  192.168.1.124  │        │
│   │                 │    │                 │    │                 │        │
│   │  Unraid 7.2.2   │    │  Proxmox VE     │    │  Proxmox VE     │        │
│   │  Media + AI     │    │  (VMs/LXC)      │    │  (VMs/LXC)      │        │
│   │                 │    │                 │    │                 │        │
│   │  22 Containers  │    │                 │    │                 │        │
│   └─────────────────┘    └─────────────────┘    └─────────────────┘        │
│           │                                                                 │
│           │                                                                 │
│           ▼                                                                 │
│   ┌─────────────────┐                                                       │
│   │  HOME ASSISTANT │                                                       │
│   │  192.168.1.149  │                                                       │
│   │   (Bare Metal)  │                                                       │
│   │  Voice Control  │                                                       │
│   └─────────────────┘                                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Node Details

### Node 1: Unraid Server (Primary Hub)

**Primary Role**: Media serving, AI inference, storage, container hosting

| Component | Specification |
|-----------|---------------|
| **IP Address** | 192.168.1.222 |
| **OS** | Unraid 7.2.2 |
| **Containers** | 22 running |
| **Uptime** | 7 days |

**Docker Stacks (Currently Running):**

#### Infrastructure Stack
| Service | Port | Status | Purpose |
|---------|------|--------|---------|
| Tailscale | host | Running | VPN access |
| Homepage | 8010 | Healthy | Dashboard |
| Uptime Kuma | 3010 | Healthy | Monitoring |
| Dozzle | 9999 | Running | Log viewer |
| Watchtower | - | Healthy | Auto-updates |
| Portainer-BE | 9000 | Running | Container management |
| Traefik | 8001/44301 | Running | Reverse proxy |

#### Media Stack
| Service | Port | Status | Purpose |
|---------|------|--------|---------|
| Plex | 32400 | Running | Media server |
| Sonarr | 8989 | Running | TV management |
| Radarr | 7878 | Running | Movie management |
| Prowlarr | 9696 | Running | Indexer management |
| Bazarr | 6767 | Running | Subtitles |
| Overseerr | 5055 | Running | Media requests |
| Tautulli | 8181 | Running | Plex analytics |
| Stremio | 8089 | Running | Streaming |

#### AI Stack
| Service | Port | Status | Purpose |
|---------|------|--------|---------|
| Ollama | 11434 | Running | LLM inference |
| Open WebUI | 3000 | Healthy | Chat interface |
| Qdrant | 6333 | Running | Vector database |
| Faster-Whisper | 10300 | Running | Speech-to-text (Wyoming) |
| Piper | 10200 | Running | Text-to-speech (Wyoming) |
| WhisperLive-GPU | 9091 | Running | Real-time transcription |

---

### Node 2: Home Assistant (Bare Metal)

**Primary Role**: Home automation hub, voice assistant, IoT coordinator

| Component | Specification |
|-----------|---------------|
| **IP Address** | 192.168.1.149 |
| **OS** | Home Assistant OS (bare metal) |
| **Hardware** | Dedicated appliance |

**Services Running:**
| Service | Port | Purpose |
|---------|------|---------|
| Home Assistant | 8123 | Automation hub |
| Voice Assistant | - | Wyoming integration |

**Integrations:**
- Wyoming Protocol (connects to Whisper/Piper on Unraid)
- OpenAI-compatible API (connects to Ollama on Unraid)
- Zigbee/Z-Wave devices
- ESPHome devices

---

### Node 3: Proxmox Virtualization Cluster

**Primary Role**: Virtual machines, LXC containers, additional compute

| Node | IP Address | Status |
|------|------------|--------|
| Proxmox Node 1 | 192.168.1.114 | Online |
| Proxmox Node 2 | 192.168.1.124 | Online |
| Tailscale Node | 192.168.1.11 | Online |

**Capabilities:**
- VM hosting for isolated workloads
- LXC containers for lightweight services
- Cluster high-availability
- Backup and snapshot management

---

## Network Architecture

```
Internet
    │
    ▼
┌─────────────┐
│   Router    │  192.168.1.1
└─────────────┘
    │
    ├──────────────────────────────────────────────────────┐
    │                                                      │
    ▼                                                      ▼
┌─────────────┐                                    ┌─────────────┐
│  Tailscale  │◄──────── Mesh VPN ────────────────►│  Tailscale  │
│  (Unraid)   │                                    │  (mobile)   │
└─────────────┘                                    └─────────────┘
    │
    ├─── 192.168.1.222 ── Unraid Server (Primary - 22 containers)
    ├─── 192.168.1.149 ── Home Assistant (Bare Metal)
    ├─── 192.168.1.114 ── Proxmox Node 1
    ├─── 192.168.1.124 ── Proxmox Node 2
    └─── 192.168.1.11  ── Tailscale Node
```

**Key Network Features:**
- All services accessible via Tailscale from anywhere
- No ports exposed to internet (Tailscale only)
- Local subnet: 192.168.1.0/24
- Docker networks: br0 (bridge), custom per-stack

---

## Storage Layout

### Unraid Array
```
/mnt/user/
├── appdata/           # Container configs
│   ├── sonarr/
│   ├── radarr/
│   ├── plex/
│   ├── home-assistant/
│   └── ...
├── media/             # Media library
│   ├── movies/
│   ├── tv/
│   └── music/
├── downloads/         # Download staging
├── realdebrid/        # Zurg mount point
└── backups/           # System backups
```

---

## GPU Allocation

| Node | GPU | VRAM | Primary Use |
|------|-----|------|-------------|
| Unraid | Intel Arc A770 | 16GB | Plex transcoding, AI inference |

**Model VRAM Requirements (Ollama on Unraid):**
- 7B models: ~4GB Q4, ~8GB Q8
- 13B models: ~8GB Q4, ~14GB Q8
- Larger models may require offloading to CPU RAM

---

## Service URLs (Quick Reference)

### Unraid Server (192.168.1.222) - Primary Hub

**Infrastructure:**
| Service | URL |
|---------|-----|
| Unraid Web UI | http://192.168.1.222 |
| Portainer | http://192.168.1.222:9000 |
| Homepage | http://192.168.1.222:8010 |
| Uptime Kuma | http://192.168.1.222:3010 |
| Dozzle | http://192.168.1.222:9999 |
| Traefik Dashboard | http://192.168.1.222:8183 |

**Media:**
| Service | URL |
|---------|-----|
| Plex | http://192.168.1.222:32400/web |
| Sonarr | http://192.168.1.222:8989 |
| Radarr | http://192.168.1.222:7878 |
| Prowlarr | http://192.168.1.222:9696 |
| Bazarr | http://192.168.1.222:6767 |
| Overseerr | http://192.168.1.222:5055 |
| Tautulli | http://192.168.1.222:8181 |
| Stremio | http://192.168.1.222:8089 |

**AI:**
| Service | URL |
|---------|-----|
| Open WebUI | http://192.168.1.222:3000 |
| Ollama API | http://192.168.1.222:11434 |
| Qdrant | http://192.168.1.222:6333 |
| Whisper (Wyoming) | tcp://192.168.1.222:10300 |
| Piper (Wyoming) | tcp://192.168.1.222:10200 |
| WhisperLive | http://192.168.1.222:9091 |

### Home Assistant (192.168.1.149)
| Service | URL |
|---------|-----|
| Home Assistant | http://192.168.1.149:8123 |

---

## Automation Tools

### Chimera Media Stack Configurator
Auto-configures all media service integrations:
```bash
# On Unraid via User Scripts or CLI
./chimera-setup.sh --auto
```

**What it configures:**
- Rdt-Client → Sonarr/Radarr (download client)
- Prowlarr → Sonarr/Radarr (indexer sync)
- Bazarr → Sonarr/Radarr (subtitles)
- Overseerr → Sonarr/Radarr (requests)

### Ollama Model Management
```bash
# Pull new models
docker exec ollama ollama pull llama3.2:latest
docker exec ollama ollama pull nomic-embed-text:latest

# List installed models
docker exec ollama ollama list

# Remove a model
docker exec ollama ollama rm <model-name>
```

---

## Home Assistant Integration

**Home Assistant Location**: Bare metal at `192.168.1.149`

### Voice Pipeline
```
User speaks
    │
    ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Faster-Whisper │────►│     Ollama      │────►│      Piper      │
│     (STT)       │     │     (LLM)       │     │     (TTS)       │
│ 192.168.1.222   │     │ 192.168.1.222   │     │ 192.168.1.222   │
│   Port 10300    │     │   Port 11434    │     │   Port 10200    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Home Assistant │
                    │  192.168.1.149  │
                    │   (Actions)     │
                    └─────────────────┘
```

### Wyoming Protocol Configuration

In Home Assistant, add these Wyoming integrations:

**Whisper (Speech-to-Text):**
- Host: `192.168.1.222`
- Port: `10300`

**Piper (Text-to-Speech):**
- Host: `192.168.1.222`
- Port: `10200`

**LLM (via OpenAI-compatible API - Ollama):**
- API Base URL: `http://192.168.1.222:11434/v1`
- API Key: `ollama` (or any string)

**Alternative: WhisperLive (Real-time):**
- Host: `192.168.1.222`
- Port: `9091`

---

## Core Doctrine

1. **Digital Sovereignty** - All data stays local
2. **Transparency** - All AI decisions logged
3. **Self-Correction** - Systems adapt and improve
4. **Replaceability** - No vendor lock-in
5. **Operator Trust** - Human makes final decisions

---

## Maintenance

### Daily (Automated)
- Watchtower container updates
- Log rotation
- Health checks via Uptime Kuma

### Weekly
- Review Uptime Kuma alerts
- Check disk space on all nodes
- Review AI model performance

### Monthly
- Update Unraid OS
- Review and prune old media
- Backup configurations
- Update Proxmox nodes

### Backup Strategy
- Unraid: Array parity protection
- Appdata: Daily backup to secondary drive
- Proxmox: VM/LXC snapshots
- Critical configs: Git repository (this repo)

---

## Credentials & Secrets

**Location**: `/boot/config/plugins/chimera/` (Unraid)

**Required secrets:**
- Plex claim token
- Real-Debrid API key
- Tailscale auth key
- MQTT credentials (if using)

**Never commit secrets to git!**

---

## Project Files

```
hope/
├── HOMELAB.md                 # This file (infrastructure overview)
├── HOME-ASSISTANT-VOICE.md    # Voice integration guide
├── SETUP-GUIDE.md             # AI stack setup guide
│
└── unraid-deployment/
    ├── README.md              # Quick start
    ├── UNRAID-DEPLOYMENT.md   # Full guide
    ├── CHIMERA-SETUP.md       # Auto-configurator guide
    ├── stacks/                # Docker compose files
    ├── env-templates/         # Environment templates
    ├── scripts/               # Automation scripts
    │   ├── chimera-setup.sh   # Media stack configurator
    │   └── media_configurator.py
    ├── user-scripts/          # Unraid User Scripts
    └── portainer/             # Portainer stacks
```

---

## Version History

| Date | Change |
|------|--------|
| 2026-01-25 | Updated topology with correct IPs, removed outdated Pop!_OS references |
| 2025-01-25 | Added Chimera media stack auto-configurator |
| 2025-01-24 | Initial Unraid deployment files |
| 2025-01-17 | vLLM bare metal installation |
| 2025-01-16 | Project inception |

---

*Last updated: 2026-01-25*
