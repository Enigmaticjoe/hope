#!/bin/bash
# auto-deploy.sh - Pull latest images and deploy all stack YMLs via Portainer/Compose.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_DIR="$BASE_DIR/stacks"

# Load environment variables from .env files
set -a
[ -f "$BASE_DIR/.env.infrastructure" ] && source "$BASE_DIR/.env.infrastructure"
[ -f "$BASE_DIR/.env.media" ] && source "$BASE_DIR/.env.media"
[ -f "$BASE_DIR/.env.ai-core" ] && source "$BASE_DIR/.env.ai-core"
[ -f "$BASE_DIR/.env.home-automation" ] && source "$BASE_DIR/.env.home-automation"
[ -f "$BASE_DIR/.env.agentic" ] && source "$BASE_DIR/.env.agentic"
set +a

# (Optional) If secrets are stored in a secure location, copy them into .env files
if [ -d "$BASE_DIR/secrets" ]; then
  for envfile in .env.infrastructure .env.media .env.ai-core .env.home-automation .env.agentic; do
    if [ -f "$BASE_DIR/secrets/$envfile" ]; then
      echo "Copying secret file for $envfile"
      cp "$BASE_DIR/secrets/$envfile" "$BASE_DIR/$envfile"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/create-ai-network.sh" ]; then
  "$SCRIPT_DIR/create-ai-network.sh"
fi

echo "Pulling latest Docker images for all stacks..."
docker compose -f "$STACK_DIR/infrastructure.yml" --env-file "$BASE_DIR/.env.infrastructure" pull
docker compose -f "$STACK_DIR/media.yml" --env-file "$BASE_DIR/.env.media" pull
docker compose -f "$STACK_DIR/ai-core.yml" --env-file "$BASE_DIR/.env.ai-core" pull
docker compose -f "$STACK_DIR/home-automation.yml" --env-file "$BASE_DIR/.env.home-automation" pull
if [ -f "$BASE_DIR/.env.agentic" ]; then
  docker compose -f "$STACK_DIR/agentic.yml" --env-file "$BASE_DIR/.env.agentic" pull
fi

echo "Deploying infrastructure stack..."
docker compose -f "$STACK_DIR/infrastructure.yml" --env-file "$BASE_DIR/.env.infrastructure" up -d

echo "Deploying media stack..."
docker compose -f "$STACK_DIR/media.yml" --env-file "$BASE_DIR/.env.media" up -d

echo "Deploying AI core stack..."
docker compose -f "$STACK_DIR/ai-core.yml" --env-file "$BASE_DIR/.env.ai-core" up -d

echo "Deploying home automation stack..."
docker compose -f "$STACK_DIR/home-automation.yml" --env-file "$BASE_DIR/.env.home-automation" up -d

if [ -f "$BASE_DIR/.env.agentic" ]; then
  echo "Deploying agentic stack..."
  docker compose -f "$STACK_DIR/agentic.yml" --env-file "$BASE_DIR/.env.agentic" up -d
fi

echo "All stacks deployed. Verify via Portainer UI or 'docker ps' that containers are running."

# Optional: Run Chimera media stack auto-configuration
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
