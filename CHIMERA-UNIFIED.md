# Project CHIMERA: Unified AI Ecosystem (Brain + Brawn)

Direct, zero-fluff deployment guide for your existing hardware. This is the foundation for a single unified AI system that stays local, stays fast, and stays under your control.

## 0) Scope (What This Delivers)

**The Brain (Pop!_OS 24.04):**
- Bare-metal vLLM on **port 8000** (primary model serving).
- ROCm-first Docker stack for **Ollama**, **Open WebUI**, **AnythingLLM**, **Qdrant**, **SearXNG**, **Whisper**, **Piper**.

**The Brawn (Unraid 6.12+):**
- Media + storage services (Plex + arrs) remain on Unraid.
- Home Assistant stays bare metal and connects to the Brain via local API for voice control.

**Key Constraints (Immutable):**
- **AMD 7900 XT** requires `HSA_OVERRIDE_GFX_VERSION=11.0.0` (RDNA3 / gfx1100).
- **vLLM on 8000**, **Portainer on 9000**.
- DNS fixes: **systemd-resolved stub resolver is hostile**; use hard resolvers.
- Preserve `/mnt/user/appdata` and avoid destructive Docker operations.

---

## 1) Network + Port Map (Known Context)

**The Brain (Pop!_OS):**
- vLLM: `http://<brain-ip>:8000`
- Open WebUI: `http://<brain-ip>:3000`
- Ollama: `http://<brain-ip>:11434`
- AnythingLLM: `http://<brain-ip>:3001`
- Qdrant: `http://<brain-ip>:6333`
- SearXNG: `http://<brain-ip>:8888`
- Whisper (Wyoming): `tcp://<brain-ip>:10300`
- Piper (Wyoming): `tcp://<brain-ip>:10200`
- Portainer: `http://<brain-ip>:9000`

**The Brawn (Unraid):**
- Plex (example): `http://<unraid-ip>:32400`
- Home Assistant: `http://<ha-ip>:8123`

---

## 2) IOMMU Groups (GPU & Audio Function)

You must confirm the **IOMMU group** for the 7900 XT and its HDMI audio function. This prevents pass-through collisions and confirms clean isolation for ROCm stability.

Run on Pop!_OS:
```bash
for g in /sys/kernel/iommu_groups/*; do
  echo "IOMMU Group ${g##*/}:"
  lspci -nns $(basename -a "$g/devices/"*) | sed 's/^/  /'
done
```

Record the group IDs for:
- **AMD 7900 XT GPU function**
- **AMD HDMI/Audio function**

Use those IDs anywhere you reference pass-through. Do **not** guess. This is mandatory for stability.

---

## 3) Brain Stack (Pop!_OS 24.04)

### 3.1 DNS Hard Override (Required)
`systemd-resolved` breaks container pulls and model downloads. Force resolvers:

```bash
sudo rm -f /etc/resolv.conf
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf
```

### 3.2 Preflight Port Check
```bash
./scripts/brain-preflight.sh
```

### 3.3 Bring Up the Brain Stack
```bash
cp .env.brain.example .env
docker compose up -d
```

### 3.4 Bare-Metal vLLM (Port 8000)
Use your existing vLLM install with ROCm. Keep model size ≤27B (AWQ/GPTQ). Do not attempt 70B on 20GB VRAM.

Example (adjust model path):
```bash
HSA_OVERRIDE_GFX_VERSION=11.0.0 \
python -m vllm.entrypoints.openai.api_server \
  --model /opt/models/Dolphin-Mistral-7B \
  --port 8000 \
  --host 0.0.0.0 \
  --max-model-len 8192
```

---

## 4) Brawn Stack (Unraid)

Use the **existing Unraid deployment repo** in `unraid-deployment/`:

```bash
cd unraid-deployment
./scripts/preflight.sh --profile rocm
```

Deploy stack order:
1) infrastructure
2) media
3) ai-core (only if you want Unraid GPU workloads)
4) home-automation
5) agentic

**Preserve** `/mnt/user/appdata` mappings. Never wipe those paths.

---

## 5) Integration: Home Assistant ↔ Brain Voice

Add Wyoming integrations in Home Assistant:
- Whisper: `host=<brain-ip>`, `port=10300`
- Piper: `host=<brain-ip>`, `port=10200`

Then route Home Assistant intents to the Brain API:
- Open WebUI for chat (`http://<brain-ip>:3000`)
- vLLM (OpenAI-compatible) on `http://<brain-ip>:8000/v1`

---

## 6) Moltbot (Clawdbot) Integration — Where It Lives

**Decision:** Run Moltbot Gateway on **The Brain (Pop!_OS)**.  
Rationale: it must stay loopback-first, talk to vLLM/Ollama locally, and stay close to the ROCm stack.  
Use **The Brawn (Unraid)** only for node workloads (storage, media actions) if you need an agent on that box.

**Ports (Gateway defaults):**
- Gateway WebSocket: `ws://127.0.0.1:18789`
- Canvas/host UI: `http://127.0.0.1:18793`

### 6.1 Install (Brain)
```bash
# Node.js 22+ required
node -v
npm install -g moltbot@latest

# Baseline health check
moltbot doctor
```

### 6.2 Minimal config (Brain)
Copy the example config:
```bash
mkdir -p ~/.moltbot
cp ./brain-config/moltbot/moltbot.json.example ~/.moltbot/moltbot.json
```

`~/.moltbot/moltbot.json`:
```json
{
  "gateway": {
    "bind": "127.0.0.1",
    "port": 18789
  },
  "canvas": {
    "enabled": true,
    "port": 18793
  },
  "llm": {
    "provider": "openai-compatible",
    "baseUrl": "http://127.0.0.1:8000/v1",
    "model": "dolphin-mistral"
  },
  "ollama": {
    "baseUrl": "http://127.0.0.1:11434"
  }
}
```

### 6.3 Run as a user service (Brain)
```bash
cat > ~/.config/systemd/user/moltbot.service <<'EOF'
[Unit]
Description=Moltbot Gateway
After=network-online.target

[Service]
Type=simple
Environment=NODE_OPTIONS=--max-old-space-size=4096
ExecStart=%h/.local/share/pnpm/moltbot gateway
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now moltbot.service
```

> If you installed via npm instead of pnpm, change the `ExecStart` path to your npm global bin location (`command -v moltbot`).

---

## 7) Operational Guardrails (Non-Negotiable)

- **Docker socket permissions:** verify `docker` group membership.
- **GPU availability:** check `rocm-smi` if containers can’t start.
- **Port collisions:** re-run `./scripts/brain-preflight.sh` after any changes.
- **Never run `docker system prune`** without a data-loss warning and backup.
- **Model size discipline:** 20GB VRAM = max ~27B quantized, keep `max_model_len <= 8192`.

---

## 8) What’s Next

Pick a direction:
1) **Validate the Brain stack** (best first move).
2) **Integrate Home Assistant voice pipeline**.
3) **Unraid media stack verification**.

State the directive. I’ll execute. 
