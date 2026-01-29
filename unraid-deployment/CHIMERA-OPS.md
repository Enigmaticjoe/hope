# CHIMERA Operations, Prompts & Cheat Sheets

Purpose: one-stop runbook for install, validation, and daily ops across the Unraid ecosystem.

## 1) Fast Install (Automated)
```bash
cd unraid-deployment

# 1) Copy templates
cp env-templates/.env.infrastructure .env.infrastructure
cp env-templates/.env.media .env.media
cp env-templates/.env.ai-core .env.ai-core
cp env-templates/.env.home-automation .env.home-automation
cp env-templates/.env.agentic .env.agentic

# 2) Preflight checks
./scripts/preflight.sh --profile nvidia

# 3) Deploy everything
./scripts/auto-deploy.sh --profile nvidia

# 4) Auto-configure media stack
./scripts/chimera-setup.sh --auto
```

## 2) Release/Validation Checklist
**Run these every time you change compose files or env settings.**

1. **Preflight validation**
   ```bash
   ./scripts/preflight.sh --profile nvidia
   ```
2. **Docker config sanity**
   ```bash
   docker compose -f stacks/ai-core.yml --env-file .env.ai-core config >/dev/null
   ```
3. **Port collision audit**
   ```bash
   ss -tulpn | rg "(8008|9000|11434|3000|6333|8123|32400)"
   ```
4. **Container health**
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
   ```
5. **AI stack smoke test**
   ```bash
   curl -s http://192.168.1.9:11434/api/tags | jq .
   ```
6. **Cloudflare tunnel status**
   ```bash
   docker logs --tail=50 cloudflared
   ```

## 3) Home Assistant ↔ AI Bridge (Local Voice/Logic)
Use Home Assistant to call your AI endpoint (vLLM on The Brain, or Ollama on Unraid).

### Example: REST Command in Home Assistant
Add to `configuration.yaml`:
```yaml
rest_command:
  chimera_ai_prompt:
    url: "http://192.168.1.2:8000/v1/chat/completions"
    method: POST
    headers:
      Content-Type: application/json
    payload: >-
      {
        "model": "dolphin-mistral",
        "messages": [
          {"role": "system", "content": "You are the home automation co-pilot."},
          {"role": "user", "content": "{{ prompt }}"}
        ],
        "temperature": 0.2
      }
```
Trigger via an automation or a script:
```yaml
service: rest_command.chimera_ai_prompt
data:
  prompt: "Check if any doors are open and tell me what's on."
```

### Optional: Node-RED HTTP Call
Use `http request` node to hit `http://ollama:11434/api/generate` for local LLM responses.

## 4) Cloudflare Everywhere (Ingress + Zero Trust)
**Goal:** expose services safely via Cloudflare Tunnel + Zero Trust policies.

**Checklist:**
- Create one tunnel per environment (`unraid-prod`, `brain-prod`).
- Map DNS records to internal services (e.g., `ha.your-domain.tld → http://homeassistant:8123`).
- Use **Zero Trust Access** to protect admin UIs (Portainer, n8n, Open WebUI).
- Disable public access for anything not explicitly routed via Cloudflare.

**Recommended mappings:**
| Service | Internal URL | Cloudflare Public Host |
| --- | --- | --- |
| Home Assistant | http://192.168.1.9:8123 | ha.your-domain.tld |
| Open WebUI | http://192.168.1.9:3000 | ai.your-domain.tld |
| n8n | http://192.168.1.9:5678 | n8n.your-domain.tld |
| Plex | http://192.168.1.9:32400 | plex.your-domain.tld |

## 5) Service Cheat Sheets (Ports + Appdata)
### Infrastructure
- Homepage → `http://192.168.1.9:8008` → `/mnt/user/appdata/homepage`
- Portainer → `http://192.168.1.9:9000` → `/mnt/user/appdata/portainer`
- Uptime Kuma → `http://192.168.1.9:3010` → `/mnt/user/appdata/uptime-kuma`
- Dozzle → `http://192.168.1.9:9999`
- Tailscale → `/mnt/user/appdata/tailscale`

### Media
- Plex → `http://192.168.1.9:32400/web` → `/mnt/user/appdata/plex`
- Sonarr → `http://192.168.1.9:8989` → `/mnt/user/appdata/sonarr`
- Radarr → `http://192.168.1.9:7878` → `/mnt/user/appdata/radarr`
- Prowlarr → `http://192.168.1.9:9696` → `/mnt/user/appdata/prowlarr`
- Overseerr → `http://192.168.1.9:5055` → `/mnt/user/appdata/overseerr`
- Bazarr → `http://192.168.1.9:6767` → `/mnt/user/appdata/bazarr`
- Tautulli → `http://192.168.1.9:8181` → `/mnt/user/appdata/tautulli`
- Zurg → `/mnt/user/appdata/zurg`

### AI Core
- Ollama API → `http://192.168.1.9:11434` → `/mnt/user/appdata/ollama`
- Open WebUI → `http://192.168.1.9:3000` → `/mnt/user/appdata/openwebui`
- Qdrant → `http://192.168.1.9:6333` → `/mnt/user/appdata/qdrant`

### Home Automation
- Home Assistant → `http://192.168.1.9:8123` → `/mnt/user/appdata/homeassistant`
- Mosquitto → `mqtt://192.168.1.9:1883` → `/mnt/user/appdata/mosquitto`
- Node-RED → `http://192.168.1.9:1880` → `/mnt/user/appdata/nodered`
- Zigbee2MQTT → `http://192.168.1.9:8080` → `/mnt/user/appdata/zigbee2mqtt`
- ESPHome → `http://192.168.1.9:6052` → `/mnt/user/appdata/esphome`

### Agentic
- n8n → `http://192.168.1.9:5678` → `/mnt/user/appdata/n8n`
- Browserless → `http://192.168.1.9:${BROWSERLESS_PORT:-3005}`
- Cloudflared → `https://dash.cloudflare.com`

### MoltBot
- MoltBot Gateway → `ws://192.168.1.9:18789` → `/mnt/user/appdata/moltbot`
- MoltBot Canvas → `http://192.168.1.9:18793`

## 6) AI Prompt Templates (Ops + Media + Home)
**Stack Health Prompt**
> You are Jules, the homelab ops controller. Produce a JSON report of failed containers, port conflicts, and DNS issues from the latest logs. Provide fix steps.

**Home Assistant Automation Prompt**
> Create a Home Assistant automation YAML that announces when the front door opens, then calls the local AI endpoint to summarize the last 5 events.

**Media Intake Prompt**
> Given a list of requested titles, generate Sonarr/Radarr root folder mappings and quality profiles. Output in YAML.

## 7) Knowledge Ingestion (Get Smarter)
Use Open WebUI Knowledge + Qdrant to ingest docs, PDFs, or logs.

**Recommended flow:**
1. Upload docs in Open WebUI → **Knowledge**.
2. Tag collections by domain (e.g., `unraid`, `homeassistant`, `plex`).
3. Use n8n to schedule weekly knowledge refreshes from your docs folder.

**Example n8n idea:**
- Trigger: cron weekly
- Fetch: files from `/mnt/user/docs/chimera`
- Chunk & embed: via Open WebUI or Ollama embeddings
- Store: Qdrant collection

## 8) Troubleshooting Fast Hits
- **Container won't start:** check docker socket permissions and port collisions, then confirm appdata paths exist.
- **DNS lookup fails:** update `/etc/resolv.conf` to `1.1.1.1`/`8.8.8.8` (systemd-resolved stub is hostile).
- **NVIDIA errors:** confirm the driver plugin is installed and `nvidia-smi` reports the RTX 4070.
