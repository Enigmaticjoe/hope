#!/bin/bash
# auto-deploy.sh - Pull latest images and deploy all stack YMLs via Portainer/Compose.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
STACKS_DIR="${ROOT_DIR}/stacks"

# Load environment variables from .env files
set -a
[ -f "${ROOT_DIR}/.env.infrastructure" ] && source "${ROOT_DIR}/.env.infrastructure"
[ -f "${ROOT_DIR}/.env.media" ] && source "${ROOT_DIR}/.env.media"
[ -f "${ROOT_DIR}/.env.ai-core" ] && source "${ROOT_DIR}/.env.ai-core"
[ -f "${ROOT_DIR}/.env.home-automation" ] && source "${ROOT_DIR}/.env.home-automation"
[ -f "${ROOT_DIR}/.env.agentic" ] && source "${ROOT_DIR}/.env.agentic"
set +a

# (Optional) If secrets are stored in a secure location, copy them into .env files
if [ -d "${ROOT_DIR}/secrets" ]; then
  for envfile in .env.infrastructure .env.media .env.ai-core .env.home-automation .env.agentic; do
    if [ -f "${ROOT_DIR}/secrets/${envfile}" ]; then
      echo "Copying secret file for $envfile"
      cp "${ROOT_DIR}/secrets/${envfile}" "${ROOT_DIR}/${envfile}"
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
docker compose -f "${STACKS_DIR}/infrastructure.yml" --env-file "${ROOT_DIR}/.env.infrastructure" pull
docker compose -f "${STACKS_DIR}/media.yml" --env-file "${ROOT_DIR}/.env.media" pull
docker compose -f "${STACKS_DIR}/ai-core.yml" --env-file "${ROOT_DIR}/.env.ai-core" pull
docker compose -f "${STACKS_DIR}/home-automation.yml" --env-file "${ROOT_DIR}/.env.home-automation" pull
docker compose -f "${STACKS_DIR}/agentic.yml" --env-file "${ROOT_DIR}/.env.agentic" pull

echo "Deploying infrastructure stack..."
docker compose -f "${STACKS_DIR}/infrastructure.yml" --env-file "${ROOT_DIR}/.env.infrastructure" up -d

echo "Deploying media stack..."
docker compose -f "${STACKS_DIR}/media.yml" --env-file "${ROOT_DIR}/.env.media" up -d

echo "Deploying AI core stack..."
docker compose -f "${STACKS_DIR}/ai-core.yml" --env-file "${ROOT_DIR}/.env.ai-core" up -d

echo "Deploying home automation stack..."
docker compose -f "${STACKS_DIR}/home-automation.yml" --env-file "${ROOT_DIR}/.env.home-automation" up -d

echo "Deploying agentic stack..."
docker compose -f "${STACKS_DIR}/agentic.yml" --env-file "${ROOT_DIR}/.env.agentic" up -d

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
