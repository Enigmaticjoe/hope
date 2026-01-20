# Traefik Setup for Unraid

This configuration sets up Traefik as a reverse proxy on your Unraid server to host jAI and proxy to your services.

## Quick Start

### 1. Copy files to Unraid

```bash
# From your local machine
scp -r unraid-traefik/* root@192.168.1.222:/mnt/user/appdata/traefik/
scp index.html manifest.json sw.js root@192.168.1.222:/mnt/user/appdata/jai/
scp -r icons root@192.168.1.222:/mnt/user/appdata/jai/
```

### 2. Run setup on Unraid

```bash
ssh root@192.168.1.222
cd /mnt/user/appdata/traefik
chmod +x setup.sh
./setup.sh
```

### 3. Start Traefik

```bash
cd /mnt/user/appdata/traefik
docker-compose up -d
```

### 4. Configure DNS (choose one)

**Option A: Edit hosts file**
Add to `/etc/hosts` (Linux/Mac) or `C:\Windows\System32\drivers\etc\hosts` (Windows):
```
192.168.1.222  jai.local chat.local vllm.local ollama.local search.local rag.local traefik.local
```

**Option B: Use nip.io (no DNS needed)**
Access via: `https://jai.192.168.1.222.nip.io`

**Option C: Pi-hole/AdGuard Home**
Add local DNS records pointing to 192.168.1.222

## Services Mapped

| Service | Local URL | Proxied To |
|---------|-----------|------------|
| jAI Homepage | https://jai.local | nginx:80 |
| Open WebUI | https://chat.local | 192.168.1.9:3000 |
| vLLM API | https://vllm.local | 192.168.1.9:8000 |
| Ollama | https://ollama.local | 192.168.1.9:11434 |
| SearXNG | https://search.local | 192.168.1.9:8888 |
| AnythingLLM | https://rag.local | 192.168.1.9:3001 |
| Traefik Dashboard | https://traefik.local | internal |

## Tailscale Integration (Optional)

To use Tailscale's automatic HTTPS:

1. Enable MagicDNS and HTTPS in Tailscale admin
2. On Unraid: `tailscale cert unraid.your-tailnet.ts.net`
3. Update `dynamic.yml` to use Tailscale hostnames

## Troubleshooting

```bash
# Check Traefik logs
docker logs traefik

# Verify containers
docker ps

# Test connection
curl -k https://jai.local

# Restart Traefik
docker-compose restart
```

## Certificate Notes

- Self-signed certs are generated automatically
- Your browser will show a warning - click "Advanced" → "Proceed"
- For trusted certs, use Let's Encrypt (requires public domain) or Tailscale HTTPS
