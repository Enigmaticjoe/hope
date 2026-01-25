# Unraid Smart Server Deployment Guide

Welcome to your smart Unraid deployment! This guide covers the setup of Media Services, AI Tools, Infrastructure, Agentic Workflows, and Home Automation on your Unraid server (**192.168.1.9**).
Welcome to your smart Unraid deployment! This guide covers the setup of Media Services, AI Tools, Infrastructure, Agentic Workflows, and Home Automation on your Unraid server.

## 1. Prerequisites

### Unraid & Hardware
Match these details to your system. The stacks are GPU-aware and support both NVIDIA and AMD workflows (ROCm for AI, NVENC/AMF for media).
* **CPU:** Verify if you have iGPU QuickSync (Intel non-F SKU) or must use a discrete GPU.
* **GPU:** NVIDIA or AMD supported.
* **RAM:** 64 GB+ recommended for AI workloads.
* **Storage:**
    * Cache: `/mnt/cache`
    * Vector DB: `/mnt/qdrant` (or an NVMe mount)

**Critical Step:** If your CPU lacks QuickSync, you must use a discrete GPU for Plex transcoding and AI acceleration. Ensure the matching driver plugin is installed and GPU is visible in `nvidia-smi` (NVIDIA) or `rocm-smi` (AMD).

### Accounts/Subscriptions
- **Plex Pass** (Required for hardware transcoding on NVIDIA).
- **Real-Debrid** (Premium account for Zurg/Riven).
- **Tailscale** (For secure remote access).
- **Cloudflare** (For the Agentic stack tunnels + Zero Trust policies).

### Networking
* **Server IP:** `UNRAID_IP` (example: `192.168.1.222`)
* **Gateway:** `192.168.1.1` (example)
* **Subnet:** `192.168.1.0/24`

### Portainer or Docker Compose
The provided installer supports a fully automated path. Ensure you have filled out the `.env` files in `env-templates/` and renamed them to `.env.infrastructure`, `.env.media`, etc.

**Recommended (Automated)**
```bash
cd unraid-deployment
./scripts/chimera-install.sh --all
```

**Targeted stacks**
```bash
./scripts/chimera-install.sh --prepare --validate --deploy --stack media
```

**Recommended preflight:**
```
./scripts/preflight.sh --profile rocm
```

---

## 2. Deployment Order

### a. Infrastructure Stack (Core services + Tailscale)
**File:** `stacks/infrastructure.yml`

Deploy this first to establish the backbone and remote access.
1.  **Tailscale:** Connects your server to your private VPN mesh.
2.  **Homepage:** Your central dashboard.

**Post-Deploy:**
* Log into Tailscale Admin and approve the `unraid` node.
* Enable "Subnet Routes" for `192.168.1.0/24` to access other LAN devices remotely.
* **Verify:** Access Homepage at `http://UNRAID_IP:8008`.

### b. Media Stack (Plex + Arr Suite + Real-Debrid)
**File:** `stacks/media.yml`

This sets up your "Netflix-like" streaming experience.

**Configuration Notes:**
* **Plex Transcoding:** Since your CPU has no iGPU, enable **hardware transcoding** for the RX 7900 XT (AMD). Ensure `/dev/dri` is passed through (set `PLEX_DRI_DEVICE=/dev/dri` in `.env.media`). In Plex Settings > Transcoder, enable hardware acceleration.
* **Real-Debrid (Zurg):** This service mounts your Real-Debrid torrents to `/mnt/user/realdebrid`. Ensure your `RD_API_KEY` is correct in `.env.media`.
* **Arr Suite:** Sonarr (`:8989`) and Radarr (`:7878`) should be configured to send downloads to the Zurg mount or your local `downloads` share on the cache.

**Verify:**
* **Plex:** `http://UNRAID_IP:32400`
* **Overseerr:** `http://UNRAID_IP:5055` (Request hub)

### c. AI Core Stack (Ollama + Open WebUI + Qdrant)
**File:** `stacks/ai-core.yml` (NVIDIA) or `stacks/ai-core-amd.yml` (AMD ROCm)

This enables your local "Sovereign AI" using the RX 7900 XT (ROCm) or CPU fallback.

**Deploy with profile:**
```
./scripts/auto-deploy.sh --stack ai-core --profile rocm
```

**Storage Optimization:**
If you want a dedicated NVMe path for Qdrant, update the volume mapping in the stack YAML to point to it:
    ```yaml
    volumes:
      - /mnt/qdrant/storage:/qdrant/storage
    ```

**Services:**
* **Ollama (Brain):** Running on port `11434`. On AMD, use the ROCm image and set `HSA_OVERRIDE_GFX_VERSION=11.0.0` in `.env.ai-core`.
* **Open WebUI (Chat):** `http://UNRAID_IP:3000`. Connects to Ollama and Qdrant for RAG (chatting with your docs).

### d. Agentic Stack (n8n + Browserless + Cloudflare)
**File:** `stacks/agentic.yml`

This stack powers your automated bidding and web scraping workflows.

1.  **Prerequisite:** Create the shared network: `docker network create ai_grid` (or run `./scripts/agentic-bootstrap.sh`)
2.  **Cloudflare:** Ensure `CF_TUNNEL_TOKEN` is set in `.env.agentic`. This exposes `n8n` and `browserless` securely to the web without opening router ports.
3.  **n8n:** The workflow automation tool (`:5678`). It can control your browserless instance to scrape sites and use Ollama to analyze the data (e.g., pricing analysis).

**Verify:**
* **n8n:** `https://n8n.example.com` (or your configured domain)
* **Browserless:** `http://UNRAID_IP:3000` (internal debug view)

### e. Home Automation Stack
**File:** `stacks/home-automation.yml`

* **Home Assistant:** `http://UNRAID_IP:8123`.
* **Zigbee:** Your diagnostics did not explicitly show a plugged-in Zigbee USB stick (only a UPS and peripherals). If you are using a network-based coordinator (like a SLZB-06), configure Zigbee2MQTT to point to its IP. If using a USB stick, ensure it is passed through in the YAML (`/dev/ttyUSB0`).

---

## 3. Post-Deployment Checklist

1.  **Check GPU Usage:**
    Run `watch nvidia-smi` (NVIDIA) or `watch rocm-smi` (AMD) in the Unraid terminal while generating text in Open WebUI or transcoding in Plex. You should see processes for `ollama` or `Plex Media Server`.
2.  **Backups:**
    Your AppData is on `/mnt/cache` (Samsung 990 EVO). Ensure the **Appdata Backup** plugin is installed and scheduled to back up to the Array (HDD) weekly.
3.  **Security:**
    Since `n8n` is exposed via Cloudflare, ensure you have enabled **Cloudflare Access** (Zero Trust) policies so only your email can access the endpoint, or set up strong authentication within n8n.

## 4. Cloudflare Tunnel Ingress (Optional)

For full ecosystem access via Cloudflare Zero Trust:
1. Add your routes in the Zero Trust dashboard.
2. Optional local ingress template: `configs/cloudflared-ingress.yml`.
3. Set `CF_TUNNEL_TOKEN` in `.env.agentic`.

## 5. Operator Cheat Sheets

See **[CHEATSHEETS.md](./CHEATSHEETS.md)** for:
- Prompts and workflows for automation
- Service configuration checklists
- Voice/assistant integration notes

Enjoy your new high-performance homelab!
