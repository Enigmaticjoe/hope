# Chimera Media Stack Configurator - Unraid 7.x Deployment

Automated cross-configuration for your media stack on Unraid. This tool eliminates 20+ minutes of manual clicking through UIs by automatically wiring together Sonarr, Radarr, Prowlarr, Rdt-Client, Bazarr, and Overseerr.

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

## Deployment Options

Choose ONE of the following deployment methods:

---

## Option 1: User Scripts Plugin (Recommended)

The easiest method - adds a script to Unraid's User Scripts plugin.

### Installation

1. **Install User Scripts Plugin** (if not already installed)
   - Go to Apps → Search "User Scripts" → Install

2. **Copy the script files**
   ```bash
   # SSH into your Unraid server or use the terminal
   mkdir -p /boot/config/plugins/user.scripts/scripts/chimera-configurator
   mkdir -p /boot/config/plugins/chimera

   # Copy from the deployment files (adjust source path as needed)
   cp /path/to/unraid-deployment/user-scripts/chimera-configurator/* \
      /boot/config/plugins/user.scripts/scripts/chimera-configurator/

   # Copy the Python script to the persistent location
   cp /path/to/unraid-deployment/user-scripts/chimera-configurator/media_configurator.py \
      /boot/config/plugins/chimera/
   ```

3. **Make executable**
   ```bash
   chmod +x /boot/config/plugins/user.scripts/scripts/chimera-configurator/script
   chmod +x /boot/config/plugins/chimera/media_configurator.py
   ```

### Running

1. Go to **Settings → User Scripts**
2. Find "Chimera Media Stack Configurator"
3. Click **Run Script**
4. Use the interactive menu OR run with arguments:
   - **Run in Background** with `--auto` for fully automatic setup
   - **Run in Background** with `--dry-run` to preview changes first

### Arguments

| Argument | Description |
|----------|-------------|
| `--auto` | Fully automatic - discovers everything and configures |
| `--status` | Check current integration status |
| `--discover` | Just scan for services |
| `--dry-run` | Preview changes without applying |
| `--interactive` | Step-by-step guided setup |
| (no args) | Shows interactive menu |

---

## Option 2: Portainer Stack

Run the configurator as a Docker container via Portainer.

### Method A: Simple Stack (No Build)

1. **Copy the Python script**
   ```bash
   mkdir -p /boot/config/plugins/chimera
   cp /path/to/media_configurator.py /boot/config/plugins/chimera/
   ```

2. **Deploy in Portainer**
   - Go to Portainer → Stacks → Add Stack
   - Name: `chimera-configurator`
   - Paste the contents of `portainer/chimera-configurator/docker-compose-simple.yml`
   - Deploy

3. **Check Results**
   - Container runs, configures everything, then exits
   - Check container logs for results
   - To run again: Restart the container

### Method B: Full Container Build

1. **Copy all files to Unraid**
   ```bash
   mkdir -p /mnt/user/appdata/chimera-configurator
   cp -r /path/to/portainer/chimera-configurator/* /mnt/user/appdata/chimera-configurator/
   ```

2. **Deploy in Portainer**
   - Go to Portainer → Stacks → Add Stack
   - Name: `chimera-configurator`
   - Build method: Git repository or upload
   - Use the `docker-compose.yml` file
   - Deploy

---

## Option 3: Direct Command Line

Run directly from the Unraid terminal.

```bash
# Setup
mkdir -p /boot/config/plugins/chimera
cp media_configurator.py /boot/config/plugins/chimera/
chmod +x /boot/config/plugins/chimera/media_configurator.py

# Run
python3 /boot/config/plugins/chimera/media_configurator.py configure --auto

# Or with options
python3 /boot/config/plugins/chimera/media_configurator.py status
python3 /boot/config/plugins/chimera/media_configurator.py configure --dry-run
```

---

## Configuration Persistence

Configuration is stored in `/boot/config/plugins/chimera/` which persists across:
- Array restarts
- Unraid reboots
- Container recreations

## How It Works

1. **Discovery Phase**
   - Queries Docker for running containers
   - Matches container names to known services (sonarr, radarr, etc.)
   - Gets container IPs and mapped ports

2. **API Key Extraction**
   - Reads Sonarr/Radarr/Prowlarr `config.xml` files from appdata
   - Parses Bazarr `config.yaml`
   - No manual key entry needed!

3. **Verification**
   - Tests each service API endpoint
   - Validates API keys work
   - Reports service versions

4. **Configuration**
   - Adds download clients (Rdt-Client)
   - Configures root folders
   - Sets up Prowlarr sync
   - Connects Bazarr and Overseerr

## Troubleshooting

### Services Not Found

```bash
# Check running containers
docker ps | grep -E "sonarr|radarr|prowlarr"

# Run discovery only
python3 /boot/config/plugins/chimera/media_configurator.py discover
```

### API Keys Not Extracted

Check that appdata paths are correct:
```bash
ls /mnt/user/appdata/sonarr/config.xml
ls /mnt/user/appdata/radarr/config.xml
ls /mnt/user/appdata/prowlarr/config.xml
```

### Container Network Issues

If services can't connect to each other:
1. Ensure all media containers are on the same Docker network
2. Try using host network mode for the configurator container
3. Use container names instead of IPs

### Permission Errors

```bash
# Fix script permissions
chmod +x /boot/config/plugins/chimera/media_configurator.py
chmod +x /boot/config/plugins/user.scripts/scripts/chimera-configurator/script
```

## Requirements

- **Unraid 7.x** (Python 3 included)
- **Docker** (for container discovery)
- **Running media stack** (Sonarr, Radarr, etc.)
- **User Scripts plugin** (for Option 1)
- **Portainer** (for Option 2)

## Files Reference

```
/boot/config/plugins/
├── chimera/
│   ├── media_configurator.py      # Main Python script
│   └── media_stack_config.json    # Saved configuration
│
└── user.scripts/scripts/
    └── chimera-configurator/
        ├── script                  # User Scripts entry point
        ├── name                    # Display name
        ├── description             # Description
        └── media_configurator.py   # Copy of Python script
```

## After Configuration

The configurator handles API connections. You still need to:

1. **Rdt-Client**: Set up Real-Debrid credentials
2. **Prowlarr**: Add your indexers (will auto-sync to Sonarr/Radarr)
3. **Plex**: Claim your server and add libraries
4. **Quality Profiles**: Customize as desired

## Running Periodically

To re-run after adding new services:

**User Scripts**: Just click "Run Script" again

**Portainer**: Restart the container

**CLI**: Run the command again

The configurator is idempotent - safe to run multiple times. It won't duplicate settings.
