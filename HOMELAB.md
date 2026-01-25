# Project Chimera - Homelab Infrastructure

## "The Jules Protocol" - System v1.4.0

A **Sovereign Intelligence Ecosystem** designed to eliminate reliance on Big Tech. It operates as a localized "Digital Organism" where specialized nodes handle distinct cognitive and physical tasks.

**Architecture**: Distributed Hybrid Mesh (6-Node Topology)
**Persona**: Jules Winnfield (Sovereign Home Intelligence)

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                            PROJECT CHIMERA - 6 NODE TOPOLOGY                              │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│   ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                     │
│   │   THE BRAIN     │    │   THE BRAWN     │    │  THE SENTINEL   │                     │
│   │    (Node A)     │◄──►│    (Node B)     │◄──►│    (Node C)     │                     │
│   │                 │    │                 │    │                 │                     │
│   │  Pop!_OS 24.04  │    │  Unraid 7.x     │    │  Proxmox VE     │                     │
│   │  RX 7900 XT     │    │  RTX 4070       │    │  Dual Coral TPU │                     │
│   │  AI Inference   │    │  Media/Storage  │    │  NVR/Detection  │                     │
│   └────────┬────────┘    └────────┬────────┘    └─────────────────┘                     │
│            │                      │                                                      │
│            │    10GbE Fiber       │                                                      │
│            └──────────┬───────────┘                                                      │
│                       │                                                                  │
│                       ▼                                                                  │
│            ┌─────────────────┐         ┌─────────────────┐                              │
│            │ THE WORKSTATION │         │    THE EDGE     │                              │
│            │    (Node F)     │◄───────►│    (Node D)     │                              │
│            │                 │         │                 │                              │
│            │  Win11/Linux    │         │ Home Assistant  │                              │
│            │  Command Deck   │         │  (Bare Metal)   │                              │
│            └─────────────────┘         └────────┬────────┘                              │
│                                                 │                                        │
│                                                 ▼                                        │
│                                      ┌─────────────────┐                                │
│                                      │   THE SWARM     │                                │
│                                      │    (Node E)     │                                │
│                                      │                 │                                │
│                                      │  ESP32 + Pi     │                                │
│                                      │  Sensors/DNS    │                                │
│                                      └─────────────────┘                                │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## The Six Pillars (Hardware Infrastructure)

### Node A: "The Brain" (Cognition Core)

**Role**: Pure AI Inference & Logic

| Component | Specification |
|-----------|---------------|
| **OS** | Pop!_OS 24.04 (Linux) |
| **CPU** | Intel Core Ultra 7 265F (20 Cores) |
| **GPU** | AMD Radeon RX 7900 XT (20GB VRAM) |
| **RAM** | 128GB DDR5 |
| **Function** | Bare Metal vLLM inference |

**Services Running:**
| Service | Port | Type | Purpose |
|---------|------|------|---------|
| vLLM | 8000 | Bare Metal | Sovereign LLM inference (Dolphin-Mistral) |
| Whisper | 10300 | Docker | Speech-to-text (Wyoming) |
| Piper | 10200 | Docker | Text-to-speech (Wyoming) |
| AnythingLLM | 3001 | Docker | RAG - "Chat with Data" |
| Qdrant | 6333 | Docker | Vector database |
| Open WebUI | 3000 | Bare Metal | Chat interface |

**AI Models Loaded:**
- Dolphin-Mistral (primary - uncensored, tool-capable)
- Phi-4-abliterated (fast, uncensored)
- nomic-embed-text (embeddings)

---

### Node B: "The Brawn" (Infinite Vault)

**Role**: Storage, Media Transcoding, & Legacy Automation

| Component | Specification |
|-----------|---------------|
| **OS** | Unraid 7.x |
| **CPU** | Intel Core i5-13600K (14 Cores) |
| **GPU** | NVIDIA GeForce RTX 4070 (12GB VRAM) |
| **Storage** | 22TB+ Array + 3TB NVMe Cache |
| **Function** | NVENC Transcoding, Media serving |

**Docker Stacks:**

#### Infrastructure Stack
| Service | Port | Purpose |
|---------|------|---------|
| Tailscale | - | VPN access |
| Homepage | 8010 | Dashboard |
| Uptime Kuma | 3010 | Monitoring |
| Dozzle | 9999 | Log viewer |
| Watchtower | - | Auto-updates |
| Portainer | 9000 | Container management |

#### Media Stack
| Service | Port | Purpose |
|---------|------|---------|
| Plex | 32400 | Media server (NVENC) |
| Sonarr | 8989 | TV management |
| Radarr | 7878 | Movie management |
| Prowlarr | 9696 | Indexer management |
| Bazarr | 6767 | Subtitles |
| Overseerr | 5055 | Media requests |
| Tautulli | 8181 | Plex analytics |
| Rdt-Client | 6500 | Real-Debrid client |
| Zurg | 9090 | Real-Debrid mount |
| Tunarr | - | Linear TV channels |

#### AI Stack (Backup)
| Service | Port | Purpose |
|---------|------|---------|
| Ollama | 11434 | Backup LLM inference |
| Open WebUI | 3000 | Chat interface |

---

### Node C: "The Sentinel" (Visual Cortex)

**Role**: Dedicated NVR & Object Detection

| Component | Specification |
|-----------|---------------|
| **Hardware** | Shuttle DH670 |
| **Platform** | Proxmox VE (Windows 10 VM + Linux LXC) |
| **Accelerator** | Dual Google Coral Edge TPUs |
| **Function** | 24/7 surveillance & AI detection |

**Services Running:**
| Service | Platform | Purpose |
|---------|----------|---------|
| Blue Iris | Windows VM | Forensics: 24/7 continuous recording |
| Frigate | Linux LXC | AI Sentry: Person/Cat/Car detection (<100ms) |

---

### Node D: "The Edge" (Autonomic Nervous System)

**Role**: IoT State Machine & Physical Interface

| Component | Specification |
|-----------|---------------|
| **Hardware** | HP EliteDesk Mini |
| **Platform** | Home Assistant (Bare Metal) |
| **IP Address** | 192.168.1.149 |
| **Function** | Controls lights, locks, sensors |

**Services Running:**
| Service | Port | Purpose |
|---------|------|---------|
| Home Assistant | 8123 | Automation hub |
| Voice Assistant | - | Wyoming integration |

**Integrations:**
- Wyoming Protocol (connects to Whisper/Piper on Brain)
- OpenAI-compatible API (connects to vLLM on Brain)
- Zigbee/Z-Wave devices
- ESPHome devices
- MQTT (Mosquitto on Brawn)

---

### Node E: "The Swarm" (Sensory Mesh)

**Role**: Distributed Input/Output & Network Defense

| Component | Purpose |
|-----------|---------|
| **ESP32-S3 Nano Satellites (x3)** | Room-scale voice command injection |
| **Raspberry Pi Cluster (x2)** | Pi-hole DNS + Failover |

**Capabilities:**
- Telepathy: Room-scale voice commands ("Jules, secure the house")
- Digital Shield: Network-wide ad/telemetry blocking
- Distributed failover for critical DNS services

---

### Node F: "The Workstation" (Command Deck)

**Role**: Development, Administration, & Visualization

| Component | Specification |
|-----------|---------------|
| **Hardware** | High-Performance Desktop (Custom Build) |
| **OS** | Windows 11 / Linux Dual Boot |
| **Displays** | Multi-Monitor Array (Command Center) |

**Functions:**
| Role | Purpose |
|------|---------|
| **The IDE** | VS Code Remote connected to "The Brain" for coding agents |
| **The Bridge** | Runs the "Chimera Dashboard" (Homepage) to monitor all nodes |
| **The Terminal** | Primary SSH gateway to Brain, Brawn, and Sentinel |
| **Gaming/Rendering** | High-fidelity local processing |

---

## Network Architecture (VLAN Segmented)

```
Internet
    │
    ▼
┌─────────────┐
│   Router    │  192.168.1.1
└─────────────┘
    │
    ├────────────────────────────────────────────────────────────────┐
    │                                                                │
    ▼                                                                ▼
┌─────────────────────────────────────────┐              ┌─────────────────┐
│           VLAN 10 (TRUSTED)             │              │    Tailscale    │
│         10GbE Fiber Backbone            │              │   Mesh VPN      │
│                                         │              │   (Remote)      │
│  Brain ◄──► Brawn ◄──► Workstation     │              └─────────────────┘
│              │                          │
│              ▼                          │
│           Edge                          │
└─────────────────────────────────────────┘
    │
    ├─── VLAN 20 (IoT/RESTRICTED) ────────────────────────┐
    │    NO WAN ACCESS - Edge only                        │
    │    └── ESP32 Satellites, Smart Plugs, Lights        │
    │                                                      │
    └─── VLAN 30 (SECURITY/AIR-GAPPED) ───────────────────┤
         Completely isolated - No Internet                 │
         └── IP Cameras → Sentinel only                    │
```

**VLAN Configuration:**

| VLAN | Name | Members | Rules |
|------|------|---------|-------|
| 10 | Trusted Command | Brain, Brawn, Workstation, Edge | Unrestricted internal, 10GbE fiber |
| 20 | IoT Restricted | ESP32, Smart Plugs, Lights | NO WAN, Edge access only |
| 30 | Security | IP Cameras, Sentinel | Air-gapped, Sentinel + Admin tunnel only |

---

## GPU Allocation

| Node | GPU | VRAM | Primary Use |
|------|-----|------|-------------|
| Brain | AMD RX 7900 XT | 20GB | AI inference (vLLM) - uncensored models |
| Brawn | NVIDIA RTX 4070 | 12GB | Plex NVENC transcoding |
| Sentinel | Dual Coral TPU | - | Object detection (<100ms) |

**Model VRAM Requirements:**
- 7B models: ~14GB FP16, ~4GB Q4
- 13B models: ~26GB FP16, ~8GB Q4
- 27B models: ~54GB FP16, ~14GB Q4 (AWQ/GPTQ)

---

## Storage Layout

### Unraid Array (The Brawn)
```
/mnt/user/
├── appdata/           # Container configs
│   ├── sonarr/
│   ├── radarr/
│   ├── plex/
│   └── ...
├── media/             # Media library
│   ├── movies/
│   ├── tv/
│   └── music/
├── downloads/         # Download staging
├── realdebrid/        # Zurg mount (Infinite Library)
└── backups/           # System backups
```

### Pop!_OS (The Brain)
```
~/brain-ai/            # AI deployment files
├── install-vllm.sh
├── download-models.sh
├── vllm-server.sh
├── .env
└── models/            # Downloaded models

~/.cache/huggingface/  # HuggingFace cache
```

---

## Service URLs (Quick Reference)

### The Brain (Pop!_OS AI Node)
| Service | URL |
|---------|-----|
| Open WebUI | http://brain:3000 |
| vLLM API | http://brain:8000/v1 |
| AnythingLLM | http://brain:3001 |
| Whisper (Wyoming) | tcp://brain:10300 |
| Piper (Wyoming) | tcp://brain:10200 |

### The Brawn (Unraid Media/Storage)
| Service | URL |
|---------|-----|
| Unraid Web UI | http://brawn |
| Portainer | http://brawn:9000 |
| Homepage | http://brawn:8010 |
| Plex | http://brawn:32400/web |
| Sonarr | http://brawn:8989 |
| Radarr | http://brawn:7878 |
| Prowlarr | http://brawn:9696 |
| Overseerr | http://brawn:5055 |
| Uptime Kuma | http://brawn:3010 |

### The Edge (Home Assistant)
| Service | URL |
|---------|-----|
| Home Assistant | http://192.168.1.149:8123 |

### The Sentinel (NVR)
| Service | URL |
|---------|-----|
| Blue Iris | http://sentinel:81 (Admin tunnel only) |

---

## Functional Capabilities Matrix

| Domain | Node | Application | Capability |
|--------|------|-------------|------------|
| **Cognition** | Brain | vLLM | Sovereign Thought: Uncensored LLM inference |
| **Cognition** | Brain | AnythingLLM | RAG: "Chat with Data" - PDFs, code, notes |
| **Cognition** | Brain | Piper/Whisper | Conversation: Real-time STT/TTS |
| **Control** | Workstation | VS Code | Development: Remote coding on Brain |
| **Control** | Workstation | Portainer | Orchestration: Docker management |
| **Control** | Workstation | Grafana | Observability: GPU temps, network, events |
| **Media** | Brawn | Zurg/Rclone | Infinite Library: Cloud as local drive |
| **Media** | Brawn | Plex/NVENC | Elastic Streaming: 4K transcoding |
| **Media** | Brawn | Tunarr | Linear TV: Virtual channels |
| **Security** | Sentinel | Blue Iris | Forensics: 24/7 continuous recording |
| **Security** | Sentinel | Frigate | AI Sentry: Person/Cat/Car detection |
| **Security** | Edge | Automation | Active Defense: Lock doors, flash lights |
| **Sensory** | Swarm | Satellites | Telepathy: Room-scale voice commands |
| **Sensory** | Swarm | Pi-hole | Digital Shield: Ad/telemetry blocking |

---

## Advanced Workflow Scenarios

### A. The "Dev-Ops" Loop (Workstation + Brain)

**Intent**: Create a new AI agent that monitors 3D Printer status.

```
┌─────────────┐     SSH      ┌─────────────┐
│ Workstation │─────────────►│   Brain     │
│   VS Code   │              │   vLLM      │
└─────────────┘              └──────┬──────┘
                                    │
                                    ▼ Deploy
                             ┌─────────────┐
                             │    Edge     │
                             │ Home Assist │
                             └─────────────┘
```

1. VS Code connects remotely to Brain via SSH
2. Prompt local LLM: "Write a Python script to poll OctoPrint API"
3. Brain generates the code
4. Deploy script to Edge (Home Assistant)

### B. The "Security Overwatch" (Sentinel + Workstation)

**Intent**: Investigate a noise outside at 3 AM.

```
┌─────────────┐  Admin Tunnel  ┌─────────────┐
│ Workstation │───────────────►│  Sentinel   │
│ Matrix View │                │ Blue Iris   │
└─────────────┘                └──────┬──────┘
       │                              │
       │ Voice: "Jules, activate      │ Frigate
       │ Perimeter Protocol"          │ Detection
       ▼                              ▼
┌─────────────┐              ┌─────────────┐
│   Brain     │─────────────►│    Edge     │
│  Interpret  │   Signal     │ Floodlights │
└─────────────┘              └─────────────┘
```

1. Workstation pulls up Blue Iris "Matrix View" (VLAN 30 tunnel)
2. Sentinel highlights "Person Detected" via Frigate
3. Voice command: "Jules, activate Perimeter Protocol"
4. Brain interprets → signals Edge → Floodlights ON

### C. The "Immersive Media" Experience (Brawn + Workstation)

**Intent**: Watch 4K movie while compiling code.

```
┌─────────────┐   Direct Play   ┌─────────────┐
│ Workstation │◄────10GbE──────│   Brawn     │
│    Plex     │   80Mbps 4K    │   Plex      │
└─────────────┘                │   Zurg      │
                               └─────────────┘
```

1. Open Plex on Workstation
2. Brawn locates file (cached on Real-Debrid via Zurg)
3. Direct Play over 10GbE fiber - zero buffering, zero transcoding

---

## Home Assistant Voice Pipeline

```
User speaks (via Swarm satellite)
    │
    ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Whisper     │────►│      vLLM       │────►│      Piper      │
│     (STT)       │     │    (Jules)      │     │     (TTS)       │
│     Brain       │     │     Brain       │     │     Brain       │
│   Port 10300    │     │   Port 8000     │     │   Port 10200    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Home Assistant │
                    │     (Edge)      │
                    │   192.168.1.149 │
                    └─────────────────┘
```

### Wyoming Protocol Configuration

In Home Assistant, add these Wyoming integrations:

**Whisper (Speech-to-Text):**
- Host: `brain` (or IP of The Brain)
- Port: `10300`

**Piper (Text-to-Speech):**
- Host: `brain` (or IP of The Brain)
- Port: `10200`

**LLM (via OpenAI-compatible API - vLLM):**
- API Base URL: `http://brain:8000/v1`
- API Key: `sk-no-key-needed`

---

## Automation Tools

### Chimera Media Stack Configurator
Auto-configures all media service integrations on The Brawn:
```bash
# On Unraid via User Scripts or CLI
./chimera-setup.sh --auto
```

**What it configures:**
- Rdt-Client → Sonarr/Radarr (download client)
- Prowlarr → Sonarr/Radarr (indexer sync)
- Bazarr → Sonarr/Radarr (subtitles)
- Overseerr → Sonarr/Radarr (requests)

### vLLM Server Control (The Brain)
```bash
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

## Core Doctrine

1. **Digital Sovereignty** - All data stays local, no Big Tech dependencies
2. **Transparency** - All AI decisions logged
3. **Self-Correction** - Systems adapt and improve
4. **Replaceability** - No vendor lock-in
5. **Operator Trust** - Human makes final decisions

---

## Resource Summary

| Resource | Total |
|----------|-------|
| **Compute** | ~60+ Cores |
| **VRAM** | 32GB (20GB AI + 12GB Media) |
| **Storage** | Infinite Cloud + 25TB Local |
| **Vision** | 360-degree AI surveillance |
| **Voice** | Whole-home coverage |

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
- Update Unraid OS (Brawn)
- Update Pop!_OS (Brain)
- Update Proxmox (Sentinel)
- Review and prune old media
- Backup configurations

### Backup Strategy
- Brawn: Unraid array parity protection
- Brain: Critical configs to Git
- Sentinel: Proxmox VM/LXC snapshots
- Edge: Home Assistant snapshots

---

## Credentials & Secrets

**Locations:**
- Unraid (Brawn): `/boot/config/plugins/chimera/`
- Pop!_OS (Brain): `~/.config/chimera/`

**Required secrets:**
- Plex claim token
- Real-Debrid API key
- Tailscale auth key
- MQTT credentials

**Never commit secrets to git!**

---

## Project Files

```
hope/
├── HOMELAB.md                 # This file (Jules Protocol reference)
├── HOME-ASSISTANT-VOICE.md    # Voice integration guide
├── SETUP-GUIDE.md             # Brain AI setup guide
├── install-vllm.sh            # vLLM installer
├── download-models.sh         # Model downloader
│
└── unraid-deployment/         # Brawn deployment files
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
| 2026-01-25 | Major rewrite: Full Jules Protocol 6-node architecture |
| 2026-01-25 | Updated topology with correct IPs |
| 2025-01-25 | Added Chimera media stack auto-configurator |
| 2025-01-24 | Initial Unraid deployment files |
| 2025-01-17 | vLLM bare metal installation |
| 2025-01-16 | Project inception |

---

*Last updated: 2026-01-25*
*Document: The Jules Protocol v1.4.0*
