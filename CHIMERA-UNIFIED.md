# Project CHIMERA: Unified AI Ecosystem (Brain + Brawn)

Direct, zero-fluff deployment guide for your existing hardware. This is the foundation for a single unified AI system that stays local, stays fast, and stays under your control.

## 0) Scope (What This Delivers)

**The Brain (Pop!_OS 24.04):**
- Bare-metal vLLM on **port 8000** (primary model serving).
- ROCm-first Docker stack for **Ollama**, **Open WebUI**, **AnythingLLM**, **Qdrant**, **SearXNG**, **Whisper**, **Piper**.
- **MoltBot Gateway** (agent control plane on port 18789) + **Canvas UI** (port 18793).

**The Brawn (Unraid 6.12+):**
- Media + storage services (Plex + arrs) remain on Unraid.
- Home Assistant stays bare metal and connects to the Brain via local API for voice control.
- Optional MoltBot instance on Unraid for local-first agent orchestration.

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
- MoltBot Gateway: `ws://<brain-ip>:18789`
- MoltBot Canvas: `http://<brain-ip>:18793`

**The Brawn (Unraid):**
- Plex (example): `http://<unraid-ip>:32400`
- Home Assistant: `http://<ha-ip>:8123`
- MoltBot (optional): `ws://<unraid-ip>:18789`

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

This deploys: Ollama (ROCm), Open WebUI, Qdrant, AnythingLLM, SearXNG, Whisper, Piper, and **MoltBot**.

### 3.4 Brain Stack (Docker Swarm)
Swarm gives you restart policies, node labels, and stack deployment with a single command. This is **single-node** by default but ready for expansion.

**Initialize Swarm + deploy stack (recommended):**
```bash
./scripts/swarm-init.sh
```

**Manual Swarm deploy (explicit control):**
```bash
docker swarm init --advertise-addr <brain-ip>
docker node update --label-add chimera.role=brain $(docker info --format '{{.Swarm.NodeID}}')
set -a && source .env && set +a
docker stack deploy -c swarm/chimera-brain-stack.yml chimera-brain
```

**Notes:**
- Stack file: `swarm/chimera-brain-stack.yml`
- Uses `node.labels.chimera.role == brain` for placement.
- Keep `HSA_OVERRIDE_GFX_VERSION=11.0.0` for ROCm stability.
- Swarm bind mounts require absolute paths. Set `REPO_ROOT` in `.env` to the repo checkout path.

### 3.5 Bare-Metal vLLM (Port 8000)
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

### 3.6 MoltBot (Agent Control Plane)
MoltBot is included in both the Compose and Swarm stacks. It connects to vLLM (port 8000) and Ollama (port 11434) via `host.docker.internal`.

**Configuration:** `brain-config/moltbot/moltbot.json.example`
- Gateway binds to `0.0.0.0:18789` (reachable from outside the container).
- Canvas UI on port `18793`.
- LLM provider: OpenAI-compatible via vLLM, with Ollama fallback.

**First-run onboarding (one-time):**
```bash
docker exec -it chimera-moltbot moltbot onboard
```

**Verify:**
- Gateway: `ws://<brain-ip>:18789`
- Canvas: `http://<brain-ip>:18793`

---

## 4) Brawn Stack (Unraid)

Use the **existing Unraid deployment repo** in `unraid-deployment/`:

```bash
cd unraid-deployment
./scripts/preflight.sh --profile nvidia
```

Deploy stack order:
1) infrastructure
2) media
3) ai-core (only if you want Unraid GPU workloads)
4) home-automation
5) agentic
6) moltbot (optional - if you want a local agent on Unraid)

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

## 6) Operational Guardrails (Non-Negotiable)

- **Docker socket permissions:** verify `docker` group membership.
- **GPU availability:** check `rocm-smi` if containers can't start.
- **Port collisions:** re-run `./scripts/brain-preflight.sh` after any changes.
- **Never run `docker system prune`** without a data-loss warning and backup.
- **Model size discipline:** 20GB VRAM = max ~27B quantized, keep `max_model_len <= 8192`.

---

## 7) What's Next

Pick a direction:
1) **Validate the Brain stack** (best first move).
2) **Integrate Home Assistant voice pipeline**.
3) **Unraid media stack verification**.
4) **MoltBot agent onboarding + Canvas UI workflows**.
