# Unraid Smart Server Deployment Guide

Welcome to your smart Unraid deployment! This guide covers the setup of Media Services, AI Tools, Infrastructure, and Home Automation on your Unraid server (assumed to be at 192.168.1.9). We will also discuss integration points (Alexa, Home Assistant) and best practices for managing secrets.

## 1. Prerequisites

### Unraid & Hardware
Ensure Unraid is up-to-date and your server (192.168.1.9) is running Docker. If you plan to use GPU-accelerated services (Plex transcoding, Ollama AI), install the NVIDIA Drivers plugin via Community Apps and reboot – verify with `nvidia-smi` on the Unraid console.

### Accounts/Subscriptions
- **Plex Pass** account (for hardware transcoding and Plex features).
- **Real-Debrid** premium account (for cached torrent integration).
- **Tailscale** account (for remote VPN access).
- (Optional) **Amazon Alexa** account and **Home Assistant Cloud** (for voice integration).

### Networking
The guide uses local IPs (e.g. 192.168.1.9). Update to match your network. We assume a LAN subnet of 192.168.1.0/24. Tailscale will handle secure remote access, so no ports need opening on your router.

### Portainer or Docker Compose
You can deploy the stacks using Portainer's Stacks UI (by uploading each YAML) or via command-line using Docker Compose. The provided `auto-deploy.sh` script assumes the Docker Compose plugin is available. If using Portainer, create four stacks (infrastructure, media, ai-core, home-automation) with the respective YAML content and .env files.

> **Important:** Review and fill in all .env files with your specific values (user IDs, API keys, passwords, etc.) before deploying. Keep these files secure and out of version control.

## 2. Deployment Order

It's recommended to deploy in the following order, as some services depend on others:

### a. Infrastructure Stack (Core services + Tailscale)
Deploy this first to set up Tailscale VPN, update watcher, and the Homepage dashboard. Once up, log into Tailscale's admin console and approve your Unraid node ("unraid") and enable Subnet Routes for 192.168.1.0/24 if prompted. This gives you remote access to LAN services via Tailscale.

**Verify:**
- Visit http://192.168.1.9:8008 – this is the Homepage dashboard (you should see a default page or the dashboard once configured).
- Visit http://192.168.1.9:3010 – Uptime Kuma status page.
- **Tailscale:** In Tailscale admin, note your server's tailnet IP or MagicDNS name (e.g. unraid.<your-tailnet>.ts.net). You can use this to reach services when off-network (e.g. http://unraid.<tailnet>.ts.net:8008 for Homepage). No need for Traefik/NGINX proxy or port forwarding!

### b. Media Stack (Plex + arr suite + Real-Debrid)
Deploy next. Before deployment:
- Log into Plex web UI (after container starts) to claim your server if not auto-claimed. Use `PLEX_CLAIM` from plex.tv/claim (it's in your .env and is used on first run only).
- In Plex, under Settings > Live TV & DVR, set up your HDHomeRun tuner if you have one (Plex should auto-detect it if Plex is on host network or same subnet – if not detected, you can manually specify the HDHomeRun's IP).

**Verify *arr services:**
- Sonarr (http://192.168.1.9:8989)
- Radarr (http://192.168.1.9:7878)
- etc., are accessible.

**Real-Debrid Integration:** The Zurg service is a custom Real-Debrid WebDAV and rclone setup that mounts your RD cloud torrents to /mnt/user/realdebrid on Unraid. Plex is pointed to this mount (/realdebrid in the container) so that content added to RD appears in Plex as if it were local.

- Make sure you added your RD API token in .env.media. Zurg will create the mount after deployment. Check its logs (http://192.168.1.9:9090 or Portainer) to see if it's mounting correctly.
- **Real-Debrid usage:** Use the provided Overseerr or *arr apps to request content. When a torrent is added via RD, Zurg+rclone will expose it under the realdebrid mount. Plex can then play it directly from RD without consuming local storage.
- **Tip:** The media share still has downloads folder configured for *arr – if you use a local downloader (qBittorrent, etc.), point it to that path so *arr can import. In this RD setup, *arr might not automatically mark items as done since files aren't actually moved into /media/movies or /media/tv. This is okay (Plex still sees them). For better automation, you can consider enabling Plex Debrid integration (set PD_ENABLED=true in Zurg and provide PLEX_TOKEN etc. in the .env) so that Sonarr/Radarr get notified of Plex's content. Initially, you might manage this manually (mark as acquired, etc.).

**Plex Access:** With Tailscale, you can stream remotely without Plex's relay (direct over VPN). Share your Plex server with friends by either: inviting them through Plex (for this they'll need Plex accounts and you'll need to enable remote access, which can work over Tailscale by advertising port 32400) or by having them install Tailscale and sharing your tailnet ("Device sharing" in Tailscale) – then they can access your Plex as if local. Plex Web can also be used via tailnet URL.

### c. AI Core Stack (Ollama + OpenWebUI + Qdrant)
This provides local AI capabilities:

- **Ollama** is the LLM backend. It's running on port 11434 with GPU support. Check `gpu-check.sh` output or run `nvidia-smi` to ensure it's utilizing your RTX 4070.
- **Open WebUI** (http://192.168.1.9:3000) is a user-friendly web chat interface. Open it in your browser – it's like your private ChatGPT. The first time, it may have no models installed. To install a model:
  - Either use the Open WebUI interface's model management to download a model from HuggingFace/Ollama, or open Unraid console and run: `docker exec ollama ollama pull llama2` (for example) to download a suitable LLM.
  - Once a model is available, you can chat with it in Open WebUI. The interface also supports **RAG (Retrieval Augmented Generation)**: It's connected to the Qdrant vector database.
- **Qdrant** is a vector DB for storing embeddings. Open WebUI will use Qdrant to store knowledge bases. You can test this: in Open WebUI, go to Documents/Knowledge section and upload a PDF or text file. The data will be indexed into Qdrant (collections prefixed with open-webui in Qdrant). You can then ask the AI about that document, and it will retrieve relevant info from Qdrant to augment the answer.
- Verify Qdrant is running (http://192.168.1.9:6333 – it may show a simple "Qdrant ok" message or JSON). The stack's .env has no secret for Qdrant since we run it open on LAN; if you secure Qdrant with an API key, add it to both Qdrant config and QDRANT_API_KEY in Open WebUI env.
- **GPU Use:** Ollama will automatically use the GPU for inference (we set it to use all GPUs). Qdrant is configured (QDRANT__GPU__INDEXING=1) to use the GPU for indexing vectors, speeding up large imports. You can monitor GPU usage with `watch nvidia-smi` during heavy AI tasks.

### d. Home Automation Stack (Home Assistant + MQTT + Node-RED + Zigbee2MQTT)
Deploy last:

- **Home Assistant:** Since you have an existing HA OS on a separate box, you might not need to run this container. (If you continue using your external HA, you can skip the homeassistant service in the YAML or ignore it.) However, the stack is provided in case you want to migrate to a supervised HA in Docker. It's configured in host networking mode so it can discover devices on your LAN. Access it at http://192.168.1.9:8123 (if running).
- **MQTT (Mosquitto):** The broker is on port 1883. We configured credentials in .env.home-automation – these were applied by the auto-deploy.sh which generated a passwordfile. In Home Assistant (either your external one or the included container), add the MQTT integration and point it to mqtt://192.168.1.9 with the same username/password (or if you left it open with allow_anonymous, just use the IP). You should see MQTT devices auto-discovered (e.g., Zigbee2MQTT devices).
- **Zigbee2MQTT:** If you have a USB Zigbee coordinator (e.g., a TI CC2652 stick) and plan to use Zigbee2MQTT instead of your Tuya Zigbee hub, plug it into Unraid and find its device path (e.g., /dev/ttyUSB0 or /dev/ttyACM0). Edit the zigbee2mqtt service in the YAML to uncomment the device mapping. Also edit Zigbee2MQTT's config file under /mnt/user/appdata/zigbee2mqtt/configuration.yaml to set your network key, etc., or use the Zigbee2MQTT UI (http://192.168.1.9:8080, default login: mqtt with no password) to configure. Zigbee2MQTT will connect to the Mosquitto broker (we passed it the mosquitto container's address and credentials). In Home Assistant, devices paired via Zigbee2MQTT will appear under MQTT integration.
- **Tuya Hub Users:** If you already have a Tuya Zigbee hub and prefer to use it, you can skip running Zigbee2MQTT altogether. Instead, use the Home Assistant Tuya integration or LocalTuya for your devices. The Zigbee2MQTT service can be stopped/removed if not needed.
- **Node-RED:** Accessible at http://192.168.1.9:1880. This is a powerful workflow automation tool. We haven't pre-configured flows, but you can install the Home Assistant websockets palette (node-red-contrib-home-assistant-websocket) to integrate with HA. For example, Node-RED can orchestrate complex automations reacting to HA events, or call the Open WebUI API for AI processing as part of an automation (imagine using AI to generate a message when an event happens, etc.).
- **ESPHome:** Accessible at http://192.168.1.9:6052. If you use ESPHome for IoT devices (ESP8266/ESP32), you can compile and flash firmware from this UI. Integrate it with Home Assistant by adding the ESPHome integration, and your ESP devices will appear.

After all stacks are up, open the **Homepage** (http://192.168.1.9:8008). Edit the dashboard using the `homepage-dashboard.yaml` provided (place its contents in config.yml in the Homepage appdata folder, then refresh). You should then see a dashboard with sections for Infrastructure, Media, AI, and Home Automation – providing quick links to all services' web UIs.

## 3. Post-Deployment Configuration

Now that the containers are running, you have some one-time setups and integrations to do:

### Plex
In Plex server settings, sign in with your Plex account and configure your Libraries. Add two libraries for Movies and TV pointing to /media/movies and /media/tv (the real local paths). Additionally, add a Library (or additional folders) for any content accessible via Real-Debrid: for example, you might mount your RD torrents under a separate folder in Plex. In our setup, we mounted RD under /realdebrid inside Plex. You can add that folder to your existing libraries or create a separate library ("Cloud Media"). Plex will then index content from RD (you must have at least one torrent in RD for the folder to not appear empty – add something via the RD website or *arr requests).

In Tautulli, set up monitoring for your Plex server (you'll need to enter your Plex token in Tautulli's settings). This will track usage stats.

**Overseerr:** Connect Overseerr to Plex (Settings > Services: add Plex, it should auto-detect your server on the same network). Also connect *arr: add Sonarr and Radarr instances (URLs http://sonarr:8989 etc. since Overseerr shares the compose network with them; use API keys from each app's settings). This allows Overseerr to send requests to *arr.

**Live TV:** If using Plex DVR with HDHomeRun: ensure the Plex container is on the same network as HDHomeRun. We used bridge networking with host ports – Plex might not auto-discover the tuner. If it doesn't, go to Live TV & DVR in Plex and manually add the HDHomeRun by its IP. Plex will guide you through channel setup and XMLTV guide (it can use Plex's guide data).

### Sonarr/Radarr
Add indexers via Prowlarr (which aggregates them) by pointing Sonarr/Radarr to Prowlarr's URL (http://prowlarr:9696) and API key. Also add a download client if needed (for Real-Debrid, you might not add a local client at all – see below). Ensure Sonarr and Radarr are set not to delete files after import (since in RD workflow, files stay in the cloud).

In Sonarr/Radarr, you can use the Real Debrid integration by treating Real-Debrid as a "torrent client" via an add-on script or the Plex Debrid integration. This is advanced – initially, consider manually adding magnets to RD or using the "Add to RD" function of the Debrid *arr fork.

Sonarr/Radarr will still be useful for organizing requests and monitoring what's available. When Plex library updates with new content (from RD), Sonarr/Radarr might not automatically know it's available. If you want full automation, consider running the Plex Debrid service included in the pd_zurg container (set PD_ENABLED=true and provide PLEX_TOKEN, PLEX_ADDRESS, etc. in the env file). This can sync Plex -> *arr status. Otherwise, you may occasionally mark items as acquired in *arr manually.

### Home Assistant & Alexa
Home Assistant (HA) can integrate with Alexa in two main ways:

1. **Home Assistant Cloud (Nabu Casa):** Easiest method – sign up for HA Cloud in HA settings. This lets you expose HA devices to Alexa and use Alexa voice commands without manual setup. You can then say, "Alexa, turn on the kitchen light" and HA will handle it. It also allows Alexa to trigger HA scenes, etc.
2. **Manual Alexa Skill:** More complex – you'd create a custom Alexa Smart Home skill and Lambda to relay to your HA's API. (If using this route, ensure WEBUI_URL in HA is set and reachable – e.g., via Tailscale or an HTTPS URL.)

**Exposing Entities:** Decide which HA entities to expose to Alexa (e.g., lights, thermostats). With Nabu Casa, you can toggle exposure in each entity's settings or in the cloud config panel. With a custom skill, you'd use the emulated_hue integration or the Alexa integration and define filters in configuration.yaml.

**Alexa -> Plex:** There is an official Plex Alexa Skill that allows "Alexa, ask Plex to play The Office in the Living Room." You can enable that in Alexa's skills store and link your Plex account. Since your Plex is remote (tailnet or behind VPN), it may not work out of the box via Alexa (which uses Plex's cloud servers to reach your Plex). If you have remote access enabled in Plex and Tailscale running, it might – test it. Alternatively, consider using Plex's built-in support for webhooks or notifications to HA for creative automations.

**Voice Assistant in HA:** You might also integrate a local voice assistant. For example, use Node-RED or HA Automations to route certain voice commands to the Open WebUI (LLM). This is advanced: you could capture an Alexa phrase, send it to your local AI, then speak back the answer via an Alexa Media Player integration (which allows sending TTS to Echo devices). This way, you essentially have Alexa asking your local GPT for answers. Keep in mind Alexa has tight response time limits, so this might only be practical for certain queries or via an HA intent.

### Node-RED Automation
With all systems connected, you can create powerful automations:

- **Example:** When Plex starts playing something, Node-RED can receive a webhook or Plex MQTT update and then trigger a Home Assistant scene to dim lights.
- **Example:** Use AI for notifications – if a security camera (Frigate, etc.) detects a person, have Node-RED call Open WebUI's API to describe the event in natural language and send it as a notification or speak it via Alexa ("Alert: A person was seen at the front door." generated by AI).

Ensure to install relevant nodes (Home Assistant, MQTT, etc.) in Node-RED's palette manager for easy integration.

## 4. Managing Secrets and Secure Access

Your deployment includes sensitive information (API keys, passwords) in environment files. Do not store these in public Git or backups. We structured the .env files so you can:

- **Store them securely** in an offline location (encrypted cloud storage or a private repository). For example, you might keep an encrypted ZIP of all .env files on Google Drive or a private GitHub Gist. The `auto-deploy.sh` looks for a `./secrets/` directory – you can mount your secure store (e.g., via rclone or Google Drive Fuse) to secrets before running the script to automatically populate secrets.
- **Use Docker/Portainer Secrets:** Portainer allows defining secrets which can be referenced in stacks. This avoids putting secrets directly in compose files. You could migrate things like RD_API_KEY to Portainer's secrets and update the YAML accordingly (see Portainer docs for syntax).
- **Use environment variables on the host:** If you run docker compose manually, you can export sensitive env vars in your shell so they aren't in files on disk. Our deployment uses .env files for convenience, but you can export e.g. RD_API_KEY at runtime instead.
- **Tailscale Keys:** The Tailscale auth key in .env.infrastructure is one-time use (if you generated a reusable key, treat it like a password). After your server connects the first time, you can remove the key from the .env for security (the container will remember its auth state in the volume). Revoke keys in Tailscale admin if leaked.
- **Plex Token:** Similarly, if you used PLEX_CLAIM, it's not needed after claiming. It's safe to leave blank post-deployment so it isn't accidentally reused.

Finally, note that with Tailscale providing secure access, you do not have traditional HTTPS certificates for your services (connections are encrypted at the VPN layer). When accessing via MagicDNS (e.g. https://unraid.tailnet.ts.net), you actually get a Tailscale-provided TLS cert. If you want to expose certain services to the internet without requiring VPN (not generally recommended for private services), you could integrate Cloudflare Tunnel or Caddy with Cloudflare DNS – but in this setup, it's unnecessary due to Tailscale's zero-config VPN.

## 5. Troubleshooting & Next Steps

### Stack Verification
Use `docker ps` to ensure all containers are "healthy" or "running". Check Portainer's UI for any container restarts or errors. Logs can be viewed with Dozzle (http://192.168.1.9:9999) or via `docker logs <container>`.

**Common issues:**
- **Missing or incorrect env values** (e.g., a typo in RD_API_KEY or expired PLEX_CLAIM token). Containers may exit if they can't validate keys.
- **Port conflicts:** If Unraid's GUI or another service was using a port we mapped, you'll need to adjust the port in the .env and redeploy. For example, if 8123 was in use, change HOMEASSISTANT_PORT and update the compose.
- **File permissions:** We set PUID/PGID to 1000 in most containers (you can change to Unraid's nobody user 99 if preferred). If you see permission issues writing to /mnt/user, ensure the UID matches or simply use 99/100 which has broad access on Unraid shares.
- **GPU not being used:** Run `gpu-check.sh`. If it warns that Ollama is not using the NVIDIA runtime, double-check that the Docker Engine has the NVIDIA runtime configured (/etc/docker/daemon.json on Unraid should contain the Nvidia runtime — the plugin usually does this). Also ensure your containers were created after the Nvidia plugin was installed (recreate if not).

### Stopping/Starting Stacks
You can manage each stack via Portainer (Stacks section) or via CLI (`docker compose -f <stack>.yml up -d` / `down`). The stacks are mostly independent, but do consider dependencies:

- If you reboot Unraid, all will come up automatically. The infrastructure stack's Tailscale will connect early – you might need to wait a minute for DNS to propagate if using MagicDNS.
- The media stack can function without the AI or home stack running, and vice versa. They are loosely coupled through network and API calls (e.g., HA might call AI API).

### Backups
Now that everything is configured, back up your appdata (the /mnt/user/appdata subfolders). Unraid's CA Backup plugin can do this on a schedule. This ensures if you need to rebuild, your Plex library, HA config, Node-RED flows, etc., are saved. Also back up your .env files (preferably encrypted).

### Updates
Watchtower is running (in the infrastructure stack) – it will pull updates for your containers automatically. It checks every 24h (as set by WATCHTOWER_POLL_INTERVAL). It will not update containers if it doesn't detect new images. When an update occurs, it will gracefully restart the container. You can inspect Watchtower's logs via Dozzle or `docker logs watchtower`. If you prefer manual updates, you can remove Watchtower.

### Monitoring
Uptime Kuma is prepped on port 3010. Consider configuring some monitors:
- e.g., Ping an external site to verify internet connectivity,
- HTTP monitor for Plex (http://plex:32400/web/index.html) to know if Plex is responding,
- TCP port monitor for HA (8123) etc.

You can also set up healthchecks for critical flows (like an API call to OpenWebUI's endpoint) – Kuma can hit internal addresses since it's on the same network.

### Next Steps and Ideas

- **Integrate Frigate NVR:** If you have IP cameras, you can deploy the Frigate container (with GPU decode support) and integrate it with Home Assistant. Use your AI stack's GPU for object detection (Frigate supports NVIDIA CUDA).
- **Wire up HA <> AI:** For example, use an automation or Node-RED flow to send your AI a daily summary of sensor data ("How was the house temperature today?") – the Open WebUI can ingest the data via its API and generate a summary, which HA can then send to you as a notification. This is cutting-edge smart home stuff!
- **Cloud Storage:** If you need a personal cloud (Nextcloud/Syncthing), you have a cloud-stack plan from the initial design (Nextcloud + MariaDB + Collabora). This was not deployed here, but you can easily add it as another stack later. Given you have Tailscale, you could also consider simpler solutions like Syncthing to sync files across your devices via the VPN.

Enjoy your all-in-one Unraid server:
- You can stream movies, download content seamlessly via Real-Debrid,
- Ask your private GPT-J or Llama 2 model questions (even when the internet is down!),
- Automate your home's lights and sensors,
- and access everything securely from anywhere using Tailscale.

Happy automating and please remember to keep your secrets safe and your system backed up. Now that the heavy lifting is done, you can focus on using and refining your smart home hub to your liking! 🚀
