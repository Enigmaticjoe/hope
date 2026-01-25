# Project Chimera - Homelab Infrastructure

## System Overview

A **federated, privacy-first homelab** running local AI, media automation, and home automation across multiple nodes. All processing happens locally - no cloud dependencies.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PROJECT CHIMERA TOPOLOGY                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│   │   THE BRAIN     │    │   THE BRAWN     │    │  UNRAID SERVER  │        │
│   │  192.168.1.223  │◄──►│  192.168.1.224  │◄──►│  192.168.1.222  │        │
│   │                 │    │                 │    │                 │        │
│   │  i5-13600K      │    │  Ultra 7 265F   │    │  Xeon           │        │
│   │  RTX 4070 12GB  │    │  RX 7900 XT     │    │  Arc A770 16GB  │        │
│   │  96GB RAM       │    │  128GB RAM      │    │  64GB RAM       │        │
│   │                 │    │                 │    │                 │        │
│   │  Role:          │    │  Role:          │    │  Role:          │        │
│   │  Inference      │    │  Training/Batch │    │  Media/IoT      │        │
│   └─────────────────┘    └─────────────────┘    └─────────────────┘        │
│                                                                             │
│                         ┌─────────────────┐                                 │
│                         │  HOME ASSISTANT │                                 │
│                         │  192.168.1.xxx  │                                 │
│                         │  Voice Control  │                                 │
│                         └─────────────────┘                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Node Details

### Node 1: The Brain (Pop!_OS AI Workstation)

**Primary Role**: Low-latency AI inference, real-time chat, tool orchestration

| Component | Specification |
|-----------|---------------|
| **IP Address** | 192.168.1.223 |
| **OS** | Pop!_OS 24.04 |
| **CPU** | Intel Core i5-13600K (14 cores) |
| **GPU** | NVIDIA RTX 4070 (12GB VRAM) |
| **RAM** | 96GB DDR5 |
| **Storage** | NVMe SSD |

**Services Running:**
| Service | Port | Type | Purpose |
|---------|------|------|---------|
| vLLM | 8000 | Bare Metal | AI inference engine |
| Ollama | 11434 | Bare Metal | Backup LLM runtime |
| Open WebUI | 3000 | Bare Metal | Chat interface |
| Qdrant | 6333 | Docker | Vector database |
| Portainer | 9443 | Docker | Container management |

**AI Models Loaded:**
- Dolphin 12B (primary - uncensored, tool-capable)
- Phi-4-abliterated (fast, uncensored)
- nomic-embed-text (embeddings)

---

### Node 2: The Brawn (Pop!_OS Workstation)

**Primary Role**: Storage, batch processing, long-context workloads

| Component | Specification |
|-----------|---------------|
| **IP Address** | 192.168.1.224 |
| **OS** | Pop!_OS 24.04 |
| **CPU** | Intel Core Ultra 7 265F (20 cores) |
| **GPU** | AMD RX 7900 XT (20GB VRAM) |
| **RAM** | 128GB DDR5 |
| **Storage** | NVMe SSD + HDD array |

**Services Running:**
| Service | Port | Type | Purpose |
|---------|------|------|---------|
| vLLM | 8000 | Bare Metal | Large model inference |
| Ollama | 11434 | Bare Metal | Model serving |
| Open WebUI | 3000 | Bare Metal | Chat interface |
| AnythingLLM | 3001 | Docker | Document RAG |
| Qdrant | 6333 | Docker | Vector database |
| SearXNG | 8888 | Docker | Private search |
| Whisper | 10300 | Docker | Speech-to-text (Wyoming) |
| Piper | 10200 | Docker | Text-to-speech (Wyoming) |

**AI Models Available:**
- Gemma-3-27B-Abliterated (AWQ quantized)
- WizardLM-13B-Uncensored
- Qwen2.5-7B-Instruct

---

### Node 3: Unraid Server (Media & Automation Hub)

**Primary Role**: Media serving, home automation, IoT hub, NVR

| Component | Specification |
|-----------|---------------|
| **IP Address** | 192.168.1.222 |
| **OS** | Unraid 7.2.2 |
| **CPU** | Intel Xeon |
| **GPU** | Intel Arc A770 (16GB VRAM) |
| **RAM** | 64GB ECC |
| **Storage** | Array (multiple TB) |

**Docker Stacks:**

#### Infrastructure Stack
| Service | Port | Purpose |
|---------|------|---------|
| Tailscale | - | VPN access |
| Homepage | 8008 | Dashboard |
| Uptime Kuma | 3010 | Monitoring |
| Dozzle | 9999 | Log viewer |
| Watchtower | - | Auto-updates |
| Portainer | 9443 | Container management |

#### Media Stack
| Service | Port | Purpose |
|---------|------|---------|
| Plex | 32400 | Media server |
| Sonarr | 8989 | TV management |
| Radarr | 7878 | Movie management |
| Prowlarr | 9696 | Indexer management |
| Bazarr | 6767 | Subtitles |
| Overseerr | 5055 | Media requests |
| Tautulli | 8181 | Plex analytics |
| Rdt-Client | 6500 | Real-Debrid client |
| Zurg | 9090 | Real-Debrid mount |

#### AI Stack
| Service | Port | Purpose |
|---------|------|---------|
| Ollama | 11434 | LLM inference |
| Open WebUI | 3000 | Chat interface |
| Qdrant | 6333 | Vector database |

#### Home Automation Stack
| Service | Port | Purpose |
|---------|------|---------|
| Home Assistant | 8123 | Automation hub |
| Mosquitto | 1883 | MQTT broker |
| Node-RED | 1880 | Visual automation |
| Zigbee2MQTT | 8080 | Zigbee bridge |
| ESPHome | 6052 | ESP device management |

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
│  (all nodes)│                                    │  (mobile)   │
└─────────────┘                                    └─────────────┘
    │
    ├─── 192.168.1.222 ── Unraid Server
    ├─── 192.168.1.223 ── The Brain
    ├─── 192.168.1.224 ── The Brawn
    └─── 192.168.1.xxx ── Home Assistant (dedicated)
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

### Pop!_OS Workstations
```
~/brain-ai/            # AI deployment files
├── install-vllm.sh
├── download-models.sh
├── vllm-server.sh
├── .env
└── models/            # Downloaded models

~/.cache/huggingface/  # HuggingFace cache
~/.ollama/             # Ollama models
```

---

## GPU Allocation

| Node | GPU | VRAM | Primary Use |
|------|-----|------|-------------|
| Brain | RTX 4070 | 12GB | Fast inference (7B-13B models) |
| Brawn | RX 7900 XT | 20GB | Large models (up to 27B quantized) |
| Unraid | Arc A770 | 16GB | Plex transcoding, backup inference |

**Model VRAM Requirements:**
- 7B models: ~14GB FP16, ~4GB Q4
- 13B models: ~26GB FP16, ~8GB Q4
- 27B models: ~54GB FP16, ~14GB Q4 (AWQ/GPTQ)
- 70B models: Not feasible on current hardware

---

## Service URLs (Quick Reference)

### Brain Node (192.168.1.223)
| Service | URL |
|---------|-----|
| Open WebUI | http://192.168.1.223:3000 |
| vLLM API | http://192.168.1.223:8000/v1 |
| Ollama API | http://192.168.1.223:11434 |
| Portainer | https://192.168.1.223:9443 |

### Brawn Node (192.168.1.224)
| Service | URL |
|---------|-----|
| Open WebUI | http://192.168.1.224:3000 |
| vLLM API | http://192.168.1.224:8000/v1 |
| AnythingLLM | http://192.168.1.224:3001 |
| SearXNG | http://192.168.1.224:8888 |
| Whisper (Wyoming) | tcp://192.168.1.224:10300 |
| Piper (Wyoming) | tcp://192.168.1.224:10200 |

### Unraid Server (192.168.1.222)
| Service | URL |
|---------|-----|
| Unraid Web UI | http://192.168.1.222 |
| Portainer | https://192.168.1.222:9443 |
| Homepage | http://192.168.1.222:8008 |
| Plex | http://192.168.1.222:32400/web |
| Home Assistant | http://192.168.1.222:8123 |
| Sonarr | http://192.168.1.222:8989 |
| Radarr | http://192.168.1.222:7878 |
| Overseerr | http://192.168.1.222:5055 |
| Uptime Kuma | http://192.168.1.222:3010 |
| Dozzle | http://192.168.1.222:9999 |

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

### vLLM Server Control
```bash
# On Pop!_OS nodes
~/brain-ai/vllm-server.sh start
~/brain-ai/vllm-server.sh stop
~/brain-ai/vllm-server.sh status
~/brain-ai/vllm-server.sh logs
```

### Model Download
```bash
~/brain-ai/download-models.sh
```

---

## Home Assistant Integration

### Voice Pipeline
```
User speaks
    │
    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Whisper   │────►│    vLLM     │────►│    Piper    │
│   (STT)     │     │   (Brain)   │     │   (TTS)     │
│ Port 10300  │     │  Port 8000  │     │ Port 10200  │
└─────────────┘     └─────────────┘     └─────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │    Home     │
                    │  Assistant  │
                    │ (Actions)   │
                    └─────────────┘
```

### Wyoming Protocol Endpoints
- Whisper STT: `tcp://192.168.1.224:10300`
- Piper TTS: `tcp://192.168.1.224:10200`
- LLM API: `http://192.168.1.223:8000/v1`

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
- Update Pop!_OS packages
- Review and prune old media
- Backup configurations

### Backup Strategy
- Unraid: Array parity protection
- Appdata: Daily backup to secondary drive
- Pop!_OS: Timeshift snapshots
- Critical configs: Git repository (this repo)

---

## Credentials & Secrets

**Location**: `/boot/config/plugins/chimera/` (Unraid) or `~/.config/chimera/` (Pop!_OS)

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
├── docker-compose.yml          # Pop!_OS AI stack
├── stack.env                   # Environment variables
├── install-vllm.sh            # vLLM installer
├── download-models.sh         # Model downloader
├── SETUP-GUIDE.md             # Pop!_OS setup guide
├── HOME-ASSISTANT-VOICE.md    # Voice integration guide
├── HOMELAB.md                 # This file
│
└── unraid-deployment/
    ├── README.md              # Quick start
    ├── UNRAID-DEPLOYMENT.md   # Full guide
    ├── CHIMERA-SETUP.md       # Auto-configurator guide
    ├── stacks/                # Docker compose files
    ├── env-templates/         # Environment templates
    ├── scripts/               # Automation scripts
    ├── user-scripts/          # Unraid User Scripts
    └── portainer/             # Portainer stacks
```

---

## Version History

| Date | Change |
|------|--------|
| 2025-01-25 | Added Chimera media stack auto-configurator |
| 2025-01-24 | Initial Unraid deployment files |
| 2025-01-17 | vLLM bare metal installation |
| 2025-01-16 | Project inception |

---

*Last updated: 2026-01-25*
