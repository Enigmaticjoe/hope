# Chimera Operator Cheat Sheets

This file provides fast, actionable checklists and prompt templates for every service in the ecosystem. Keep it open while you deploy.

## 1. Core Paths & Ports (Baseline)
- Appdata root: `/mnt/user/appdata`
- Media:
  - TV: `/mnt/user/media/tv`
  - Movies: `/mnt/user/media/movies`
  - Downloads: `/mnt/user/downloads`
- Key ports:
  - Homepage `8008`, Plex `32400`, Sonarr `8989`, Radarr `7878`, Prowlarr `9696`, Overseerr `5055`, Bazarr `6767`
  - Ollama `11434`, Open WebUI `3000`, Qdrant `6333`
  - Home Assistant `8123`, Node-RED `1880`
  - n8n `5678`, Browserless `${BROWSERLESS_PORT:-3005}`

## 2. Service Quick-Start Checklists

### Infrastructure
- **Homepage**: Copy `configs/homepage-dashboard.yaml` to `/mnt/user/appdata/homepage/config.yml`.
- **Uptime Kuma**: Add monitors for every service URL; enable Telegram/Discord alerts.
- **Tailscale**: Approve node in admin console and enable subnet routes.

### Media
- **Plex**:
  - Claim server, enable hardware transcoding.
  - Add libraries for TV/Movies.
- **Sonarr/Radarr**:
  - Add root folders (TV/Movies).
  - Configure download client (Rdt-Client or qBittorrent).
- **Prowlarr**:
  - Add indexers, sync to Sonarr/Radarr.
- **Bazarr**:
  - Add subtitle languages; connect to Sonarr/Radarr.
- **Overseerr**:
  - Connect Plex for auth, link Sonarr/Radarr.

### AI Core
- **Ollama**: Pull models: `docker exec ollama ollama pull nomic-embed-text`.
- **Open WebUI**: Connect to Ollama + Qdrant for RAG.
- **Qdrant**: Keep storage on NVMe for speed.

### Home Automation
- **Home Assistant**: Complete onboarding; set trusted proxies for Cloudflare if using.
- **Node-RED**: Install `node-red-contrib-home-assistant-websocket`.
- **MQTT**: Set credentials in `.env.home-automation` and mirror in HA integration.

### Agentic
- **n8n**: Configure webhook URL and environment variables; add credentials.
- **Browserless**: Set token and concurrency.
- **Cloudflare Tunnel**: Use Zero Trust to publish only what you need.

## 3. Operator Prompts (Copy/Paste)

### Infrastructure Audit (n8n / Open WebUI)
```
You are my homelab auditor. Review the current stack, identify port conflicts,
validate DNS and resolve failures, and output a remediation checklist.
```

### Media Pipeline Debug
```
Analyze Sonarr/Radarr/Prowlarr status. Identify missing indexers, download
client issues, and path mapping errors. Provide precise fixes.
```

### Home Assistant Voice Bridge
```
Design a workflow that converts Home Assistant intents into calls to Open WebUI
or Ollama. Return the YAML or Node-RED steps required.
```

### Cloudflare Zero Trust Hardening
```
Audit my public endpoints. Propose Access policies, service tokens, and
least-privilege routing for each service.
```

## 4. Knowledge Expansion (AI)

### Open WebUI Knowledge Packs
- Upload PDFs, docs, or markdowns to Open WebUI “Knowledge” collections.
- Use a naming convention: `Stack/Service/Topic`.

### Qdrant Doc Ingestion (Manual)
- Drop docs into a shared folder, use a local ingestion script or Open WebUI UI.
- Keep datasets under 2-5GB per collection for fast retrieval.

## 5. High-Signal Troubleshooting

- **Container won’t start**: check ports, GPU visibility, and permissions.
- **Download failures**: verify DNS overrides; set `/etc/resolv.conf` with `1.1.1.1` and `8.8.8.8`.
- **OOM**: reduce context length or quantize models.
- **Missing mounts**: validate `/mnt/user` paths and appdata permissions.
