# Unraid Smart Server Deployment Guide

Welcome to your smart Unraid deployment! This guide covers the setup of Media Services, AI Tools, Infrastructure, Agentic Workflows, and Home Automation on your Unraid server (**192.168.1.222**).

## 1. Prerequisites

### Unraid & Hardware
Your system is a powerhouse, but there is one critical configuration detail regarding your CPU:
* **CPU:** Intel Core i5-13600KF (Note: The "F" means **no integrated graphics**).
* **GPU:** NVIDIA GeForce RTX 4070.
* **RAM:** 96 GB (Excellent for loading large LLMs into memory).
* **Storage:**
    * Cache: Samsung 990 EVO Plus (`/mnt/cache`)
    * Vector DB: WD Black SN850X (`/mnt/qdrant`)

**Critical Step:** Since your CPU lacks QuickSync, you **must** use the RTX 4070 for Plex hardware transcoding and AI acceleration. Ensure the **NVIDIA Driver** plugin is installed from Community Apps and the GPU UUID is visible in `nvidia-smi`.

### Accounts/Subscriptions
- **Plex Pass** (Required for hardware transcoding on NVIDIA).
- **Real-Debrid** (Premium account for Zurg/Riven).
- **Tailscale** (For secure remote access).
- **Cloudflare** (For the Agentic stack tunnels).

### Networking
* **Server IP:** `192.168.1.222`
* **Gateway:** `192.168.1.1` (Assumed)
* **Subnet:** `192.168.1.0/24`

### Portainer or Docker Compose
The provided `auto-deploy.sh` script handles deployment. Ensure you have filled out the `.env` files in `env-templates/` and renamed them to `.env.infrastructure`, `.env.media`, etc.

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
* **Verify:** Access Homepage at `http://192.168.1.222:8008`.

### b. Media Stack (Plex + Arr Suite + Real-Debrid)
**File:** `stacks/media.yml`

This sets up your "Netflix-like" streaming experience.

**Configuration Notes:**
* **Plex Transcoding:** In your `.env.media` or Docker Compose, ensure `NVIDIA_VISIBLE_DEVICES=all` is set for Plex. Inside Plex Settings > Transcoder, set "Hardware transcoding device" to the **RTX 4070**.
* **Real-Debrid (Zurg):** This service mounts your Real-Debrid torrents to `/mnt/user/realdebrid`. Ensure your `RD_API_KEY` is correct in `.env.media`.
* **Arr Suite:** Sonarr (`:8989`) and Radarr (`:7878`) should be configured to send downloads to the Zurg mount or your local `downloads` share on the cache.

**Verify:**
* **Plex:** `http://192.168.1.222:32400`
* **Overseerr:** `http://192.168.1.222:5055` (Request hub)

### c. AI Core Stack (Ollama + Open WebUI + Qdrant)
**File:** `stacks/ai-core.yml`

This enables your local "Sovereign AI" using the RTX 4070.

**Storage Optimization:**
You have a dedicated NVMe partition mounted at `/mnt/qdrant` on your WD Black SN850X. This is perfect for high-speed vector retrieval.
* **Action:** In your `.env.ai-core` or the stack YAML, ensure the Qdrant volume points to this dedicated path:
    ```yaml
    volumes:
      - /mnt/qdrant/storage:/qdrant/storage
    ```

**Services:**
* **Ollama (Brain):** Running on port `11434`. It will offload layers to the RTX 4070 VRAM (12GB). With 96GB system RAM, you can also run massive models (70B parameters) using CPU offloading if needed.
* **Open WebUI (Chat):** `http://192.168.1.222:3000`. Connects to Ollama and Qdrant for RAG (chatting with your docs).

### d. Agentic Stack (n8n + Browserless + Cloudflare)
**File:** `stacks/agentic.yml`

This stack powers your automated bidding and web scraping workflows.

1.  **Prerequisite:** Create the shared network: `docker network create ai_grid`
2.  **Cloudflare:** Ensure `CF_TUNNEL_TOKEN` is set in `.env.agentic`. This exposes `n8n` and `browserless` securely to the web without opening router ports.
3.  **n8n:** The workflow automation tool (`:5678`). It can control your browserless instance to scrape sites and use Ollama to analyze the data (e.g., pricing analysis).

**Verify:**
* **n8n:** `https://n8n.happystrugglebus.us` (or your configured domain)
* **Browserless:** `http://192.168.1.222:3000` (internal debug view)

### e. Home Automation Stack
**File:** `stacks/home-automation.yml`

* **Home Assistant:** `http://192.168.1.222:8123`.
* **Zigbee:** Your diagnostics did not explicitly show a plugged-in Zigbee USB stick (only a UPS and peripherals). If you are using a network-based coordinator (like a SLZB-06), configure Zigbee2MQTT to point to its IP. If using a USB stick, ensure it is passed through in the YAML (`/dev/ttyUSB0`).

---

## 3. Post-Deployment Checklist

1.  **Check GPU Usage:**
    Run `watch nvidia-smi` in the Unraid terminal while generating text in Open WebUI or transcoding in Plex. You should see processes for `ollama` or `Plex Media Server`.
2.  **Backups:**
    Your AppData is on `/mnt/cache` (Samsung 990 EVO). Ensure the **Appdata Backup** plugin is installed and scheduled to back up to the Array (HDD) weekly.
3.  **Security:**
    Since `n8n` is exposed via Cloudflare, ensure you have enabled **Cloudflare Access** (Zero Trust) policies so only your email can access the endpoint, or set up strong authentication within n8n.

Enjoy your new high-performance homelab! 🚀
