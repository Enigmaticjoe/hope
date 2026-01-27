# Unraid Smart Server Deployment Guide

Operator priority: **Unraid-native**, **Portainer-first**, **User Scripts for automation**. This guide assumes your Docker environment is fresh and nothing is installed yet.

## 1. Prerequisites

### Unraid & Hardware
Match these details to your system. This Unraid deployment is **NVIDIA-only** for GPU workloads (RTX 4070).
* **CPU:** Verify if you have iGPU QuickSync (Intel non-F SKU) or must use a discrete GPU.
* **GPU:** NVIDIA RTX 4070 (containerized workloads).
* **RAM:** 64 GB+ recommended for AI workloads.
* **Storage:**
    * Cache: `/mnt/cache`
    * Vector DB: `/mnt/qdrant` (or an NVMe mount)

**Critical Step:** If your CPU lacks QuickSync, you must use a discrete GPU for Plex transcoding and AI acceleration. Ensure the NVIDIA driver plugin is installed and the RTX 4070 is visible in `nvidia-smi`.

### Accounts/Subscriptions
- **Plex Pass** (Required for hardware transcoding on NVIDIA).
- **Real-Debrid** (Premium account for Zurg/Riven).
- **Tailscale** (For secure remote access).
- **Cloudflare** (For the Agentic stack tunnels + Zero Trust policies).

### Networking
* **Server IP:** `UNRAID_IP` (example: `192.168.1.222`)
* **Gateway:** `192.168.1.1` (example)
* **Subnet:** `192.168.1.0/24`

### Deployment Control Plane (Portainer First)
All stacks are designed for **Portainer** on Unraid. Portainer is the primary deployment method; CLI scripts are optional automation accelerators.

**Required:**
1. Install **Portainer CE** from Unraid Apps.
2. Install **User Scripts** plugin from Unraid Apps.
3. Enable Docker and confirm `/var/run/docker.sock` exists.

**Recommended preflight:**
```bash
cd unraid-deployment
./scripts/preflight.sh --profile nvidia
```

**Generate `.env` files (interactive):**
```bash
./scripts/env-wizard.sh
```

---

## 2. Deployment Order (Portainer)

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
* **Plex Transcoding:** Since your CPU has no iGPU, enable **hardware transcoding** for the RTX 4070. Ensure `/dev/dri` is passed through (set `PLEX_DRI_DEVICE=/dev/dri` in `.env.media`). In Plex Settings > Transcoder, enable hardware acceleration.
* **Real-Debrid (Zurg):** This service mounts your Real-Debrid torrents to `/mnt/user/realdebrid`. Ensure your `RD_API_KEY` is correct in `.env.media`.
* **Rdt-Client:** Runs on `:6500` and is used as the Real-Debrid download client for Sonarr/Radarr.
* **Arr Suite:** Sonarr (`:8989`) and Radarr (`:7878`) should be configured to send downloads to the Zurg mount or your local `downloads` share on the cache.

**Verify:**
* **Plex:** `http://UNRAID_IP:32400`
* **Overseerr:** `http://UNRAID_IP:5055` (Request hub)

### c. AI Core Stack (Ollama + Open WebUI + Qdrant)
**File:** `stacks/ai-core.yml` (NVIDIA)

This enables your local "Sovereign AI" using the RTX 4070 (NVIDIA) or CPU fallback.

**Deploy with profile:**
```
./scripts/auto-deploy.sh --stack ai-core --profile nvidia
```

**Storage Optimization:**
If you want a dedicated NVMe path for Qdrant, update the volume mapping in the stack YAML to point to it:
    ```yaml
    volumes:
      - /mnt/qdrant/storage:/qdrant/storage
    ```

**Services:**
* **Ollama (Brain):** Running on port `11434`. For Unraid, use the NVIDIA profile and confirm `nvidia-smi` works.
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
    Run `watch nvidia-smi` in the Unraid terminal while generating text in Open WebUI or transcoding in Plex. You should see processes for `ollama` or `Plex Media Server`.
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

---

## Port Reference (Conflict Check)
Use this list if you need to reassign ports before deployment:

**Infrastructure**
- Homepage: `${HOMEPAGE_PORT:-8008}`
- Portainer: `9000` / `9443` (Portainer default)
- Uptime Kuma: `3010`
- Dozzle: `9999`

**Media**
- Plex: `32400`, `32469`, `1900/udp`, `32410-32414/udp`
- Sonarr: `8989`
- Radarr: `7878`
- Prowlarr: `9696`
- Bazarr: `6767`
- Overseerr: `5055`
- Tautulli: `8181`
- Rdt-Client: `6500`
- Zurg: `9090`

**AI Core**
- Ollama: `11434`
- Open WebUI: `3000`
- Qdrant: `6333`

**Agentic**
- n8n: `5678`
- Browserless: `${BROWSERLESS_PORT:-3005}`

**Home Automation**
- Home Assistant: `8123`
- Mosquitto: `1883`
- Node-RED: `1880`
- Zigbee2MQTT: `8080`
- ESPHome: `6052`

Deploy clean or fix conflicts before you launch stacks.

Enjoy your new high-performance homelab.
