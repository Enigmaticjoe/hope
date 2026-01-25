# Unraid Smart Server Deployment Guide

Welcome to your smart Unraid deployment! This guide covers the setup of Media Services, AI Tools, Infrastructure, Agentic Workflows, and Home Automation on your Unraid server (**192.168.1.9**).

## 1. Prerequisites

### Unraid & Hardware
Your system is a powerhouse with two-tier architecture:
* **CPU:** Intel Core Ultra 7 265F (no iGPU).
* **GPU:** AMD Radeon RX 7900 XT (20GB VRAM).
* **RAM:** 128 GB (enough for heavy cache + large RAG stores).
* **Storage:**
    * Cache: Samsung 990 EVO Plus (`/mnt/cache`)
    * Array: Unraid array for bulk media

**Critical Step:** For AMD ROCm, ensure `/dev/kfd` and `/dev/dri` are present and set `HSA_OVERRIDE_GFX_VERSION=11.0.0` (RDNA3/gfx1100). Use the **ROCm profile** for Ollama.

### Accounts/Subscriptions
- **Plex Pass** (Required for hardware transcoding on NVIDIA).
- **Real-Debrid** (Premium account for Zurg/Riven).
- **Tailscale** (For secure remote access).
- **Cloudflare** (For the Agentic stack tunnels + Zero Trust policies).

### Networking
* **Server IP:** `192.168.1.9`
* **Gateway:** `192.168.1.1` (Assumed)
* **Subnet:** `192.168.1.0/24`

### Portainer or Docker Compose
The provided `auto-deploy.sh` script handles deployment. Ensure you have filled out the `.env` files in `env-templates/` and renamed them to `.env.infrastructure`, `.env.media`, etc.

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
* **Verify:** Access Homepage at `http://192.168.1.9:8008`.

### b. Media Stack (Plex + Arr Suite + Real-Debrid)
**File:** `stacks/media.yml`

This sets up your "Netflix-like" streaming experience.

**Configuration Notes:**
* **Plex Transcoding:** Since your CPU has no iGPU, enable **hardware transcoding** for the RX 7900 XT (AMD). Ensure `/dev/dri` is passed through (set `PLEX_DRI_DEVICE=/dev/dri` in `.env.media`). In Plex Settings > Transcoder, enable hardware acceleration.
* **Real-Debrid (Zurg):** This service mounts your Real-Debrid torrents to `/mnt/user/realdebrid`. Ensure your `RD_API_KEY` is correct in `.env.media`.
* **Arr Suite:** Sonarr (`:8989`) and Radarr (`:7878`) should be configured to send downloads to the Zurg mount or your local `downloads` share on the cache.

**Verify:**
* **Plex:** `http://192.168.1.9:32400`
* **Overseerr:** `http://192.168.1.9:5055` (Request hub)

### c. AI Core Stack (Ollama + Open WebUI + Qdrant)
**File:** `stacks/ai-core.yml`

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
* **Ollama (Brain):** Running on port `11434`. Use `--profile rocm` for the RX 7900 XT or `--profile cpu` for CPU-only fallback.
* **Open WebUI (Chat):** `http://192.168.1.9:3000`. Connects to Ollama and Qdrant for RAG (chatting with your docs).

### d. Agentic Stack (n8n + Browserless + Cloudflare)
**File:** `stacks/agentic.yml`

This stack powers your automated bidding and web scraping workflows.

1.  **Prerequisite:** Create the shared network: `docker network create ai_grid`
2.  **Cloudflare:** Ensure `CF_TUNNEL_TOKEN` is set in `.env.agentic`. This exposes `n8n` and `browserless` securely to the web without opening router ports.
3.  **n8n:** The workflow automation tool (`:5678`). It can control your browserless instance to scrape sites and use Ollama to analyze the data (e.g., pricing analysis).

**Verify:**
* **n8n:** `https://n8n.your-domain.tld` (or your configured domain)
* **Browserless:** `http://192.168.1.9:3000` (internal debug view)

### e. Home Automation Stack
**File:** `stacks/home-automation.yml`

* **Home Assistant:** `http://192.168.1.9:8123`.
* **Zigbee:** Your diagnostics did not explicitly show a plugged-in Zigbee USB stick (only a UPS and peripherals). If you are using a network-based coordinator (like a SLZB-06), configure Zigbee2MQTT to point to its IP. If using a USB stick, ensure it is passed through in the YAML (`/dev/ttyUSB0`).

---

## 3. Post-Deployment Checklist

1.  **Check GPU Usage:**
    * NVIDIA: `watch nvidia-smi`
    * AMD ROCm: `watch rocm-smi` (or validate `/dev/kfd` usage)
2.  **Backups:**
    Your AppData is on `/mnt/cache` (Samsung 990 EVO). Ensure the **Appdata Backup** plugin is installed and scheduled to back up to the Array (HDD) weekly.
3.  **Security:**
    Since `n8n` is exposed via Cloudflare, ensure you have enabled **Cloudflare Access** (Zero Trust) policies so only your email can access the endpoint, or set up strong authentication within n8n.

Enjoy your new high-performance homelab! 🚀
