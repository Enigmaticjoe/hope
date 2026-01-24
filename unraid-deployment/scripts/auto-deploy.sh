#!/bin/bash
# auto-deploy.sh - Pull latest images and deploy all stack YMLs via Portainer/Compose.

# Load environment variables from .env files
set -a
[ -f .env.infrastructure ] && source .env.infrastructure
[ -f .env.media ] && source .env.media
[ -f .env.ai-core ] && source .env.ai-core
[ -f .env.home-automation ] && source .env.home-automation
set +a

# (Optional) If secrets are stored in a secure location, copy them into .env files
if [ -d ./secrets ]; then
  for envfile in .env.infrastructure .env.media .env.ai-core .env.home-automation; do
    if [ -f ./secrets/$envfile ]; then
      echo "Copying secret file for $envfile"
      cp ./secrets/$envfile $envfile
    fi
  done
fi

# Set up Mosquitto (MQTT) credentials if provided
if [[ -n "$MQTT_USER" && -n "$MQTT_PASSWORD" ]]; then
  echo "Creating Mosquitto configuration with credentials..."
  CONF_DIR="/mnt/user/appdata/mosquitto/config"
  mkdir -p "$CONF_DIR"
  # Create mosquitto.conf if it doesn't exist
  if [ ! -f "$CONF_DIR/mosquitto.conf" ]; then
    cat > "$CONF_DIR/mosquitto.conf" <<EOF
persistence true
persistence_location /mosquitto/data/
allow_anonymous false
password_file /mosquitto/config/passwordfile
EOF
  fi
  # Generate password file using mosquitto_passwd utility
  docker run --rm -v "$CONF_DIR":/mosquitto/config eclipse-mosquitto \
    mosquitto_passwd -c -b /mosquitto/config/passwordfile "$MQTT_USER" "$MQTT_PASSWORD"
fi

echo "Pulling latest Docker images for all stacks..."
docker compose -f infrastructure.yml --env-file .env.infrastructure pull
docker compose -f media.yml --env-file .env.media pull
docker compose -f ai-core.yml --env-file .env.ai-core pull
docker compose -f home-automation.yml --env-file .env.home-automation pull

echo "Deploying infrastructure stack..."
docker compose -f infrastructure.yml --env-file .env.infrastructure up -d

echo "Deploying media stack..."
docker compose -f media.yml --env-file .env.media up -d

echo "Deploying AI core stack..."
docker compose -f ai-core.yml --env-file .env.ai-core up -d

echo "Deploying home automation stack..."
docker compose -f home-automation.yml --env-file .env.home-automation up -d

echo "All stacks deployed. Verify via Portainer UI or 'docker ps' that containers are running."

# Optional: Run Chimera media stack auto-configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/chimera-setup.sh" ]; then
    echo ""
    echo "============================================"
    echo "Media Stack Auto-Configuration Available"
    echo "============================================"
    echo ""
    echo "Run the following to auto-configure your media stack:"
    echo "  $SCRIPT_DIR/chimera-setup.sh --auto"
    echo ""
    echo "Or with preview first:"
    echo "  $SCRIPT_DIR/chimera-setup.sh --auto --dry-run"
    echo ""

    # If --configure flag was passed, run auto-configuration
    if [[ "$*" == *"--configure"* ]]; then
        echo "Auto-configuring media stack (waiting 30s for services to start)..."
        sleep 30
        "$SCRIPT_DIR/chimera-setup.sh" --auto
    fi
fi
