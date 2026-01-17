# 🏠 Home Assistant Voice Assistant Integration

## Overview

This guide connects your local vLLM AI to Home Assistant's Voice Preview Edition for fully private, local voice control.

**Architecture:**
```
┌─────────────────────┐     ┌──────────────────────┐
│  Voice Preview      │────▶│  Home Assistant      │
│  Edition Device     │     │  (Wyoming Protocol)  │
└─────────────────────┘     └──────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│  Whisper        │        │  vLLM           │        │  Piper          │
│  (Speech→Text)  │        │  (AI Brain)     │        │  (Text→Speech)  │
│  Port 10300     │        │  Port 8000      │        │  Port 10200     │
└─────────────────┘        └─────────────────┘        └─────────────────┘
```

## Prerequisites

- ✅ Brain AI stack running (vLLM + Docker services)
- ✅ Home Assistant installed (any method)
- ✅ Voice Preview Edition device (optional, can use phone/browser)
- ✅ Both systems on same network

---

## Step 1: Verify Services are Running

On your Brain AI machine, check all services:

```bash
# Check vLLM
~/brain-ai/vllm-server.sh status

# Check Wyoming services
docker ps | grep -E "whisper|piper"

# Should show:
# brain_whisper ... Up
# brain_piper   ... Up
```

Get your Brain AI machine's IP:
```bash
ip addr | grep "inet 192"
# Example output: inet 192.168.1.9/24
```

**Your IP:** `192.168.1.9` (use your actual IP)

---

## Step 2: Configure Firewall (if enabled)

```bash
# Allow Wyoming and vLLM ports
sudo ufw allow 8000/tcp   # vLLM API
sudo ufw allow 10200/tcp  # Piper TTS
sudo ufw allow 10300/tcp  # Whisper STT
sudo ufw allow 11434/tcp  # Ollama (backup)
```

---

## Step 3: Add Wyoming Integrations to Home Assistant

### 3.1 Open Home Assistant

Go to your Home Assistant URL (e.g., http://homeassistant.local:8123)

### 3.2 Add Whisper (Speech-to-Text)

1. Go to **Settings → Devices & Services**
2. Click **"+ Add Integration"**
3. Search for **"Wyoming Protocol"**
4. Enter:
   - **Host:** `192.168.1.9` (your Brain AI IP)
   - **Port:** `10300`
5. Click **Submit**
6. Name it: `Brain Whisper`

### 3.3 Add Piper (Text-to-Speech)

1. Click **"+ Add Integration"** again
2. Search for **"Wyoming Protocol"**
3. Enter:
   - **Host:** `192.168.1.9`
   - **Port:** `10200`
4. Click **Submit**
5. Name it: `Brain Piper`

---

## Step 4: Add LLM Integration

### Option A: Using Home-LLM (Recommended)

Home-LLM is a custom integration that works great with vLLM.

1. **Install HACS** if not already installed:
   - https://hacs.xyz/docs/setup/download

2. **Install Home-LLM:**
   - Go to **HACS → Integrations**
   - Click **"+ Explore & Download Repositories"**
   - Search for **"Home LLM"**
   - Install and restart Home Assistant

3. **Configure Home-LLM:**
   - Go to **Settings → Devices & Services**
   - Click **"+ Add Integration"**
   - Search for **"Local LLM Conversation"**
   - Select **"Generic OpenAI API Compatible"**
   - Enter:
     - **Host:** `http://192.168.1.9:8000`
     - **API Key:** `sk-no-key-needed`
     - **Model:** (leave blank or enter your model name)
   - Enable **"Assist"** checkbox

### Option B: Using Built-in OpenAI Integration

1. Go to **Settings → Devices & Services**
2. Click **"+ Add Integration"**
3. Search for **"OpenAI Conversation"**
4. Click **"Configure"**
5. Enter:
   - **API Key:** `sk-no-key-needed`
6. After adding, click **"Configure"** on the integration
7. Set **"API Base URL"** to: `http://192.168.1.9:8000/v1`

---

## Step 5: Create Voice Assistant

1. Go to **Settings → Voice Assistants**
2. Click **"+ Add Assistant"**
3. Configure:

| Setting | Value |
|---------|-------|
| Name | Brain AI |
| Language | English |
| Conversation Agent | Local LLM (or OpenAI) |
| Speech-to-Text | Brain Whisper |
| Text-to-Speech | Brain Piper |
| Wake Word | (optional) |

4. Click **"Create"**

---

## Step 6: Configure Voice Preview Edition

### Via ESPHome (if self-built):

Add to your ESPHome YAML:

```yaml
voice_assistant:
  microphone: ...
  speaker: ...
  
  on_wake_word_detected:
    - light.turn_on: status_led
    
  pipeline: "Brain AI"  # Your assistant name
```

### Via Home Assistant Device Page:

1. Go to **Settings → Devices & Services**
2. Find your Voice Preview Edition
3. Click **"Configure"**
4. Set **"Voice Assistant"** to **"Brain AI"**

---

## Step 7: Test the Voice Assistant

### Browser Test:
1. Go to any Home Assistant dashboard
2. Click the **microphone icon** in the top right
3. Say: "What time is it?"
4. You should hear Piper respond

### Voice Preview Edition Test:
1. Say the wake word (e.g., "Okay Nabu")
2. Wait for the activation sound
3. Say: "Turn on the living room lights"

### Debug Test:
1. Go to **Developer Tools → Services**
2. Call service: `conversation.process`
3. Data:
   ```yaml
   text: "What is the weather like?"
   agent_id: conversation.brain_ai
   ```

---

## Recommended AI Models for Home Assistant

| Model | Size | Best For |
|-------|------|----------|
| `NousResearch/Hermes-3-Llama-3.1-8B` | 8B | Tool calling, device control |
| `Qwen/Qwen2.5-7B-Instruct` | 7B | General queries, fast response |
| `meta-llama/Llama-3.2-3B-Instruct` | 3B | Ultra-fast, basic commands |

**For Home Assistant, Hermes-3 is ideal** because it supports tool/function calling which allows the AI to properly interact with your devices.

To switch models:
```bash
nano ~/brain-ai/.env
# Set: VLLM_MODEL=NousResearch/Hermes-3-Llama-3.1-8B
~/brain-ai/vllm-server.sh restart
```

---

## Customize the AI Personality

In Home Assistant, edit your conversation agent's prompt:

1. Go to **Settings → Devices & Services**
2. Find your LLM integration
3. Click **"Configure"**
4. Edit the **System Prompt**:

```
You are a helpful home assistant named Brain. You control a smart home.
Keep responses brief and conversational - under 2 sentences when possible.
When asked to control devices, do so immediately without asking for confirmation.
Be friendly but efficient.
```

---

## Troubleshooting

### "Wyoming not discovered"

1. Check the service is running:
   ```bash
   docker logs brain_whisper
   docker logs brain_piper
   ```

2. Test connectivity from Home Assistant machine:
   ```bash
   nc -zv 192.168.1.9 10300
   nc -zv 192.168.1.9 10200
   ```

### "LLM responses are slow"

1. Use a smaller/faster model (Qwen 7B or Llama 3B)
2. Reduce `max_tokens` in the conversation agent settings
3. Check GPU memory isn't full: `rocm-smi`

### "Voice commands don't control devices"

1. **Enable "Assist"** in your LLM integration
2. **Expose entities** to Assist:
   - Go to **Settings → Voice Assistants → Expose**
   - Select which devices the AI can control
3. Use a model with **tool calling** support (Hermes-3)

### "Transcription errors"

1. Try a larger Whisper model:
   ```bash
   # Edit docker-compose.yml, change whisper command to:
   command: ["--model", "medium-int8", "--language", "en"]
   # Then: docker compose up -d whisper
   ```

2. Reduce background noise
3. Speak clearly and pause after wake word

### "TTS sounds robotic"

Try a different Piper voice:
```bash
# Edit docker-compose.yml, change piper command to:
command: ["--voice", "en_US-amy-medium"]
# Then: docker compose up -d piper
```

Available voices: https://rhasspy.github.io/piper-samples/

---

## Advanced: Multiple Assistants

You can create different assistants for different rooms:

1. **Living Room AI** - Uses faster model, casual personality
2. **Kitchen AI** - Specialized for timers and recipes
3. **Bedroom AI** - Quieter voice, nighttime-aware

Each can have different:
- Conversation agents (different LLM prompts)
- TTS voices
- Exposed entities

---

## Performance Optimization

### For Fastest Response:

```bash
# Use smallest model
VLLM_MODEL=meta-llama/Llama-3.2-3B-Instruct
VLLM_MAX_MODEL_LEN=2048
VLLM_MAX_SEQS=8
```

### For Best Quality:

```bash
# Use Hermes with tool calling
VLLM_MODEL=NousResearch/Hermes-3-Llama-3.1-8B
VLLM_MAX_MODEL_LEN=8192
VLLM_MAX_SEQS=4
```

### Streaming Responses:

Enable in Home Assistant conversation agent settings to get faster perceived responses (words appear as they're generated).

---

## Security Considerations

1. **Local only**: All processing stays on your network
2. **No cloud**: Voice data never leaves your home
3. **Firewall**: Only open ports on your local network
4. **VPN**: Use Tailscale if you need remote access

---

## Related Links

- [Home Assistant Voice](https://www.home-assistant.io/voice_control/)
- [Wyoming Protocol](https://www.home-assistant.io/integrations/wyoming/)
- [Home-LLM](https://github.com/acon96/home-llm)
- [Piper TTS Samples](https://rhasspy.github.io/piper-samples/)
- [Whisper Models](https://github.com/openai/whisper)
