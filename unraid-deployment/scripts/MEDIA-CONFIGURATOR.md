# Chimera Media Stack Configurator

Automated cross-configuration tool for your media stack on Unraid. This tool eliminates the tedious manual setup of connecting Sonarr, Radarr, Prowlarr, Bazarr, Overseerr, Rdt-Client, and Plex together.

## Features

- **Auto-Discovery**: Finds running Docker containers and their IPs automatically
- **API Key Extraction**: Reads API keys directly from service config files
- **Cross-Configuration**: Wires all services together in one command
- **Idempotent**: Safe to run multiple times - won't duplicate settings
- **Dry-Run Mode**: Preview changes before applying
- **Unraid-Optimized**: Uses Unraid paths and conventions

## What Gets Configured

| Integration | Description |
|-------------|-------------|
| Rdt-Client → Sonarr | Adds Real-Debrid as download client |
| Rdt-Client → Radarr | Adds Real-Debrid as download client |
| Prowlarr → Sonarr | Syncs indexers automatically |
| Prowlarr → Radarr | Syncs indexers automatically |
| Bazarr → Sonarr | Connects for subtitle management |
| Bazarr → Radarr | Connects for subtitle management |
| Overseerr → Sonarr | Enables TV show requests |
| Overseerr → Radarr | Enables movie requests |
| Root Folders | Sets up media library paths |

## Quick Start

### Option 1: Fully Automatic (Recommended)

```bash
cd /mnt/user/appdata/chimera  # or wherever you placed the files
./chimera-setup.sh --auto
```

This will:
1. Scan for running Docker containers
2. Extract API keys from config files
3. Verify all service connections
4. Configure all integrations automatically

### Option 2: Interactive Setup

```bash
./chimera-setup.sh --interactive
```

Guides you through each service, letting you confirm or modify settings.

### Option 3: Preview First

```bash
./chimera-setup.sh --auto --dry-run
```

See exactly what would be configured without making changes.

## Commands

| Command | Description |
|---------|-------------|
| `./chimera-setup.sh --auto` | Fully automatic configuration |
| `./chimera-setup.sh --interactive` | Step-by-step guided setup |
| `./chimera-setup.sh --status` | Check current integration status |
| `./chimera-setup.sh --discover` | Scan for available services |
| `./chimera-setup.sh --extract-keys` | Extract API keys from configs |
| `./chimera-setup.sh --dry-run` | Preview changes (combine with --auto) |
| `./chimera-setup.sh --reset` | Clear saved configuration |

## Advanced Usage

The underlying Python script offers more options:

```bash
# Configure with custom appdata path
python3 media_configurator.py configure --auto --appdata /mnt/user/my-appdata

# Just discover services without configuring
python3 media_configurator.py discover

# Check detailed status
python3 media_configurator.py status
```

## Requirements

- **Python 3.6+** (included in most Unraid setups)
- **Docker** (for container discovery)
- **Running media stack containers**

## How It Works

1. **Discovery Phase**
   - Queries Docker for running containers
   - Matches container names to known services
   - Gets container IPs and mapped ports
   - Scans for services on expected ports

2. **Key Extraction Phase**
   - Reads Sonarr/Radarr/Prowlarr config.xml files
   - Parses Bazarr config.yaml
   - Extracts API keys automatically

3. **Verification Phase**
   - Tests each service API endpoint
   - Validates API keys work
   - Reports service versions

4. **Configuration Phase**
   - Adds download clients (Rdt-Client)
   - Configures root folders
   - Sets up Prowlarr ↔ Arr sync
   - Configures Bazarr connections
   - Sets up Overseerr integrations

## Troubleshooting

### Services Not Found

```bash
# Check if containers are running
docker ps

# Try manual port scan
./chimera-setup.sh --discover
```

### API Keys Not Extracted

API keys are read from these locations:
- Sonarr: `{appdata}/sonarr/config.xml`
- Radarr: `{appdata}/radarr/config.xml`
- Prowlarr: `{appdata}/prowlarr/config.xml`
- Bazarr: `{appdata}/bazarr/config/config.yaml`

If your paths differ, use interactive mode or provide keys manually.

### Connection Failures

1. Check container networking (`docker network ls`)
2. Verify services are on the same Docker network
3. Try using container names instead of IPs

### Configuration Not Persisting

On Unraid, config is saved to `/boot/config/plugins/chimera/` for persistence across reboots. If this path isn't writable, it falls back to the script directory.

## Files

| File | Purpose |
|------|---------|
| `chimera-setup.sh` | User-friendly wrapper script |
| `media_configurator.py` | Main Python configurator |
| `config.json` | Saved configuration (auto-generated) |

## Comparison to Manual Setup

| Manual Setup | Chimera |
|--------------|---------|
| ~20 minutes clicking through UIs | ~30 seconds |
| Easy to miss settings | Comprehensive |
| Error-prone | Validated |
| Hard to replicate | Repeatable |
| No verification | Automatic checks |

## Integration with Unraid Deployment

This tool is part of the Project Chimera Unraid deployment. Run it after deploying the media stack:

```bash
# 1. Deploy media stack
docker compose -f stacks/media.yml up -d

# 2. Wait for services to start (~30 seconds)
sleep 30

# 3. Auto-configure everything
./scripts/chimera-setup.sh --auto
```

---

**Note**: This tool configures API connections between services. You still need to:
- Set up your Real-Debrid credentials in Rdt-Client
- Add indexers to Prowlarr
- Configure quality profiles as desired
- Claim your Plex server
