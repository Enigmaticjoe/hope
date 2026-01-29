# Portainer Local Stack Files (Unraid-Native)

These files are meant to **live on the Unraid host** so Portainer can deploy stacks without relying on external Git repos.

## Target Layout on Unraid

```
/boot/config/plugins/chimera/portainer/
├─ stacks/
│  ├─ infrastructure.yml
│  ├─ media.yml
│  ├─ ai-core.yml
│  ├─ home-automation.yml
│  └─ agentic.yml
└─ env/
   ├─ .env.infrastructure
   ├─ .env.media
   ├─ .env.ai-core
   ├─ .env.home-automation
   └─ .env.agentic
```

## Deploy Flow (Portainer)

1. Use the User Script **Chimera Portainer Sync** to copy files into `/boot/config/plugins/chimera/portainer/`.
2. In Portainer, go to **Stacks → Add stack**.
3. Paste the stack content from the local file or open the file in a separate tab and copy/paste.
4. Load the matching `.env.*` file content into the **Environment variables** section.

> These files are intentionally stored on the Unraid flash (`/boot`) so they persist across reboots and stay inside the Unraid environment.
