# Agentic Bidding Stack (Unraid + Cloudflare Zero Trust)

This guide wires a local, sovereign agentic workflow on Unraid using **n8n + Browserless + Cloudflare Tunnel** and ties it to your existing AI backends (Ollama/Open WebUI on either Unraid or the Pop!_OS “Brain”). The goal: an automated bidding configurator that scrapes auctions, reasons about prices, and executes bids with an approval gate.

## 1) Prerequisites

- **Docker** enabled on Unraid.
- **Cloudflare Zero Trust** account + domain (e.g., `happystrugglebus.us`).
- **AI backend** (either):
  - **Unraid**: use the existing `ai-core` stack (Ollama + Open WebUI). 
  - **Brain (Pop!_OS)**: keep Ollama/vLLM on the Brain and expose it over LAN.

> **Brain GPU note:** The Brain stack can run on its own GPU/host. This Unraid deployment assumes an RTX 4070 with NVIDIA runtime for containers.

## 2) Create the dedicated AI network

Run on the Unraid terminal:

```bash
cd /mnt/user

docker network create ai_grid
```

This network gives stable DNS names (e.g., `n8n`, `browserless`, `ollama`) across containers.

## 3) Configure environment variables

Copy the template and edit it:

```bash
cd /mnt/user/appdata
mkdir -p chimera-agentic

cd /workspace/hope/unraid-deployment
cp env-templates/.env.agentic .env.agentic
nano .env.agentic
```

Fill in:
- `CF_TUNNEL_TOKEN` (Cloudflare Tunnel token)
- `BROWSERLESS_TOKEN` (protects your headless browser)
- `N8N_HOST`, `N8N_EDITOR_BASE_URL`, `N8N_WEBHOOK_URL` (your domain)
- Optional `OLLAMA_BASE_URL` (if Ollama is on the Brain, set this to `http://<brain-ip>:11434`)

## 4) Bootstrap the stack directories

```bash
cd /workspace/hope/unraid-deployment
./scripts/agentic-bootstrap.sh
```

This script verifies Docker socket access, checks for port collisions, creates `ai_grid`, and ensures appdata directories exist.

## 5) Deploy the agentic stack

### Option A: Portainer
- Create a new stack named `agentic`.
- Upload `stacks/agentic.yml`.
- Load environment variables from `.env.agentic`.
- Deploy.

### Option B: Docker Compose

```bash
cd /workspace/hope/unraid-deployment/stacks

docker compose -f agentic.yml --env-file ../.env.agentic up -d
```

## 6) Cloudflare Tunnel routing

In Cloudflare Zero Trust, map routes:

| Subdomain | Service | Target |
| --- | --- | --- |
| `n8n.happystrugglebus.us` | n8n | `http://n8n:5678` |
| `ai.happystrugglebus.us` | Open WebUI | `http://openwebui:8080` |
| `browserless.happystrugglebus.us` | Browserless | `http://browserless:3000` |
| `api.happystrugglebus.us` (optional) | Ollama | `http://ollama:11434` |

Add Cloudflare Access policies to lock access to your identity.

## 7) n8n workflow: “Bidding Agent”

### Flow Summary
1. **Webhook** (`/start-bid`) receives payload `{ url, max_price, user }`.
2. **Browserless** scrapes price + time remaining.
3. **Ollama Chat** evaluates the action (wait/bid + amount).
4. **Approval Gate** (human-in-the-loop) for high-value bids.
5. **Browserless** executes the bid.
6. **Screenshot** stored to `/mnt/user/auctions/won`.

### Recommended System Prompt
```
You are a bidding strategist.
Inputs: current_price, max_price, time_remaining.
Rules:
- Never bid above max_price.
- Bid only when time_remaining < 10 minutes.
- Output strict JSON: {"action":"wait"|"bid","amount":number}
```

## 8) Open WebUI Function (Bridge)

Add a function in Open WebUI to trigger n8n:

```python
import requests


def start_bidding_agent(url: str, max_price: float, __user__):
    webhook_url = "http://n8n:5678/webhook/start-bid"
    payload = {
        "url": url,
        "max_price": max_price,
        "user": __user__["email"],
    }
    response = requests.post(webhook_url, json=payload, timeout=30)
    response.raise_for_status()
    return f"Agent initialized: {response.json().get('id')}"
```

## 9) Operational Safeguards

- **Approval gate** required for any bids above your configured threshold.
- **Budget caps** enforced in n8n via a hard limit node.
- **Cloudflare Access** protects the public endpoints.
- **Browserless token** prevents anonymous scraping.

## 10) Validation checklist

- `n8n` UI loads at `https://n8n.happystrugglebus.us`.
- Browserless returns a session at `https://browserless.happystrugglebus.us` (token required).
- n8n can reach Ollama (`OLLAMA_BASE_URL`).
- Webhook accepts requests and creates monitoring workflow runs.
