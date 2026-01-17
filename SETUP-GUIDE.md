# 🧠 Brain AI - Complete Setup Guide

## What You're Building

A **private, local AI system** that runs entirely on your computer. No data leaves your home. You'll have:

- **AI Chat** - Like ChatGPT, but private and uncensored
- **Voice Assistant** - Control your smart home with voice
- **Document Search** - Ask questions about your files
- **Multiple AI Models** - Switch between different personalities

**Your Hardware:**
- CPU: Intel Core Ultra 7 265F (20 cores)
- RAM: 128GB
- GPU: AMD RX 7900 XT (20GB VRAM)
- OS: Pop!_OS 24.04

---

## 📋 STEP 1: Prepare Your System (5 minutes)

Open a terminal (press `Ctrl + Alt + T`) and run these commands one at a time.

### 1.1 Stop Old Services

```bash
# Stop any existing Ollama
sudo systemctl stop ollama
sudo systemctl disable ollama

# Stop all Docker containers
docker stop $(docker ps -aq)
docker rm -f $(docker ps -aq)
```

### 1.2 Clean Up (Optional but Recommended)

```bash
# Remove old Docker data (WARNING: Deletes all container data!)
docker system prune -a --volumes -f
```

### 1.3 Reinstall Portainer

```bash
# Remove old Portainer
docker rm -f portainer 2>/dev/null
docker volume rm portainer_data 2>/dev/null

# Install fresh Portainer
docker run -d \
  --name portainer \
  --restart=always \
  -p 9000:9000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

**Wait 30 seconds**, then open: **https://localhost:9443**

Create your admin account when prompted.

---

## 📋 STEP 2: Install vLLM (15 minutes)

vLLM is the AI "brain" that runs your language models.

### 2.1 Download the Installation Files

```bash
# Create directory
mkdir -p ~/brain-ai
cd ~/brain-ai

# Download files (or copy from USB/download)
# Make sure install-vllm.sh is in this folder
```

### 2.2 Run the Installer

```bash
# Make it executable
chmod +x install-vllm.sh

# Run the installer
./install-vllm.sh
```

**What happens:**
1. Creates a Python environment
2. Installs PyTorch with AMD GPU support
3. Installs vLLM
4. Creates startup scripts

This takes 10-15 minutes. Go get coffee ☕

### 2.3 Configure vLLM

```bash
# Edit the configuration
nano ~/brain-ai/.env
```

**Important settings to check:**
```
VLLM_MODEL=cognitivecomputations/dolphin-2.9.3-mistral-nemo-12b
VLLM_PORT=8000
```

Press `Ctrl + X`, then `Y`, then `Enter` to save.

### 2.4 Download Your First Model

```bash
# Make download script executable
chmod +x download-models.sh

# Run the downloader
./download-models.sh
```

Select option `1` for Dolphin 12B (recommended first model).

**First download takes 10-20 minutes** depending on internet speed.

### 2.5 Start vLLM

```bash
# Start the server
./vllm-server.sh start

# Check if it's running
./vllm-server.sh status
```

**To make it start automatically on boot:**
```bash
sudo systemctl enable vllm
```

---

## 📋 STEP 3: Deploy Docker Stack (10 minutes)

### 3.1 Open Portainer

Go to: **https://localhost:9443**

### 3.2 Create the Stack

1. Click **"Stacks"** in the left menu
2. Click **"+ Add stack"**
3. Name it: `brain-ai`
4. Choose **"Upload"** and select `docker-compose.yml`
5. Scroll down to **"Environment variables"**
6. Click **"Load variables from .env file"**
7. Upload `stack.env`
8. Click **"Deploy the stack"**

**Wait 2-3 minutes** for all containers to start.

### 3.3 Verify Everything Started

In Portainer, click on your stack. You should see these containers running (green):
- ✅ brain_ollama
- ✅ brain_openwebui
- ✅ brain_anythingllm
- ✅ brain_qdrant
- ✅ brain_searxng
- ✅ brain_whisper
- ✅ brain_piper

---

## 📋 STEP 4: Download Ollama Models (5 minutes)

Open a terminal and run:

```bash
# Embedding model (required for document search)
docker exec brain_ollama ollama pull nomic-embed-text:latest

# Optional: backup chat model
docker exec brain_ollama ollama pull llama3.2:latest
```

---

## 📋 STEP 5: Test Your AI (2 minutes)

### 5.1 Open the Chat Interface

Go to: **http://localhost:3000**

This is Open WebUI - your main chat interface.

### 5.2 Select Your Model

1. In the top-left, click the model dropdown
2. You should see models from both vLLM and Ollama
3. Select the vLLM model (e.g., "dolphin-2.9.3-mistral-nemo-12b")

### 5.3 Test a Message

Type: `Hello! Tell me a joke.`

If you get a response, **congratulations!** Your AI is working! 🎉

---

## 📋 STEP 6: Connect Home Assistant Voice (Optional)

### 6.1 Find Your Computer's IP Address

```bash
ip addr | grep "192.168"
```

Note down the IP (e.g., `192.168.1.9`)

### 6.2 In Home Assistant

1. Go to **Settings → Devices & Services**
2. Click **"+ Add Integration"**
3. Search for **"Wyoming Protocol"**
4. Add **three** Wyoming integrations:

**Whisper (Speech-to-Text):**
- Host: `192.168.1.9` (your IP)
- Port: `10300`

**Piper (Text-to-Speech):**
- Host: `192.168.1.9` (your IP)
- Port: `10200`

### 6.3 Add the LLM Integration

1. Go to **Settings → Devices & Services**
2. Click **"+ Add Integration"**
3. Search for **"OpenAI Conversation"** or install **"Local OpenAI LLM"** from HACS
4. Configure:
   - API Base URL: `http://192.168.1.9:8000/v1`
   - API Key: `sk-no-key-needed`

### 6.4 Create a Voice Assistant

1. Go to **Settings → Voice Assistants**
2. Click **"+ Add Assistant"**
3. Configure:
   - Name: `Brain AI`
   - Language: English
   - Conversation Agent: Your LLM integration
   - Speech-to-Text: Whisper
   - Text-to-Speech: Piper

### 6.5 Test Voice

Click the microphone icon in Home Assistant and say:
"Turn on the living room lights"

---

## 🎯 Quick Reference

### Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Open WebUI | http://localhost:3000 | Main chat interface |
| AnythingLLM | http://localhost:3001 | Document RAG |
| SearXNG | http://localhost:8888 | Private search |
| Portainer | https://localhost:9443 | Docker management |
| vLLM API | http://localhost:8000/v1 | AI model API |
| Ollama API | http://localhost:11434 | Backup AI API |

### Terminal Commands

```bash
# vLLM Controls
~/brain-ai/vllm-server.sh start    # Start AI
~/brain-ai/vllm-server.sh stop     # Stop AI
~/brain-ai/vllm-server.sh status   # Check status
~/brain-ai/vllm-server.sh logs     # View logs

# Change AI Model
nano ~/brain-ai/.env               # Edit config
~/brain-ai/vllm-server.sh restart  # Apply changes

# Docker Controls
docker ps                          # List running containers
docker logs brain_ollama           # View Ollama logs
docker restart brain_openwebui     # Restart Open WebUI
```

### Switching AI Models

1. Edit the config:
   ```bash
   nano ~/brain-ai/.env
   ```

2. Change the model line:
   ```
   VLLM_MODEL=huihui-ai/Phi-4-abliterated
   ```

3. Restart vLLM:
   ```bash
   ~/brain-ai/vllm-server.sh restart
   ```

---

## ⚠️ Troubleshooting

### "vLLM won't start"

```bash
# Check logs
~/brain-ai/vllm-server.sh logs

# Common fix: restart with fresh state
pkill -f vllm
~/brain-ai/vllm-server.sh start
```

### "GPU not detected"

```bash
# Check GPU is visible
rocm-smi

# If no GPU shown, reboot
sudo reboot
```

### "Out of memory"

Your 20GB GPU can't run models larger than ~27B parameters.
Switch to a smaller model:

```bash
nano ~/brain-ai/.env
# Change to: VLLM_MODEL=Qwen/Qwen2.5-7B-Instruct
~/brain-ai/vllm-server.sh restart
```

### "Port already in use"

```bash
# Find what's using the port
sudo lsof -i :8000

# Kill it
sudo kill -9 <PID>
```

### "Home Assistant can't connect"

1. Check your firewall allows connections:
   ```bash
   sudo ufw allow 8000
   sudo ufw allow 10200
   sudo ufw allow 10300
   ```

2. Make sure services are bound to all interfaces (0.0.0.0), not just localhost.

---

## 🔒 Security Notes

1. **Keep your system updated**: `sudo apt update && sudo apt upgrade`
2. **Don't expose ports to the internet** unless you know what you're doing
3. **Your AI conversations stay local** - nothing is sent to the cloud
4. **Uncensored models** can generate any content - use responsibly

---

## 📞 Getting Help

- **vLLM Documentation**: https://docs.vllm.ai/
- **Open WebUI Discord**: https://discord.gg/open-webui
- **Home Assistant Forums**: https://community.home-assistant.io/
- **ROCm Documentation**: https://rocm.docs.amd.com/

---

## ✅ Checklist

Before you start chatting, verify:

- [ ] Portainer shows all containers running (green)
- [ ] `~/brain-ai/vllm-server.sh status` shows "RUNNING"
- [ ] http://localhost:3000 loads Open WebUI
- [ ] You can send a message and get a response
- [ ] (Optional) Home Assistant voice assistant responds

**You're done! Enjoy your private AI! 🚀**
