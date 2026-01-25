#!/bin/bash
# auto-deploy.sh - Pull latest images and deploy stack YMLs via Portainer/Compose.

set -euo pipefail

# Load environment variables from .env files
set -a
[ -f .env.infrastructure ] && source .env.infrastructure
[ -f .env.media ] && source .env.media
[ -f .env.ai-core ] && source .env.ai-core
[ -f .env.home-automation ] && source .env.home-automation
[ -f .env.agentic ] && source .env.agentic
set +a

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKS=(infrastructure media ai-core home-automation agentic)
ONLY_STACK=""
SKIP_PULL=0
DRY_RUN=0
CONFIGURE=0
PROFILE=""
SKIP_PREFLIGHT=0

usage() {
  cat <<EOH
Usage: $0 [options]

Options:
  --stack <name>       Deploy a single stack (infrastructure|media|ai-core|home-automation|agentic)
  --profile <name>     Compose profile for ai-core (cpu|nvidia|rocm)
  --skip-pull          Skip docker image pulls
  --dry-run            Print the docker compose commands without running them
  --configure          Run chimera-setup.sh --auto after deployment
  --skip-preflight     Skip preflight checks
  --help               Show this help message
EOH
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      ONLY_STACK="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --skip-pull)
      SKIP_PULL=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --configure)
      CONFIGURE=1
      shift
      ;;
    --skip-preflight)
      SKIP_PREFLIGHT=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$ONLY_STACK" ]]; then
  if [[ ! " ${STACKS[*]} " =~ " ${ONLY_STACK} " ]]; then
    echo "Invalid stack name: ${ONLY_STACK}" >&2
    usage
    exit 1
  fi
  STACKS=("${ONLY_STACK}")
fi

if [[ "$SKIP_PREFLIGHT" -eq 0 ]]; then
  if [[ -f "$SCRIPT_DIR/preflight.sh" ]]; then
    "$SCRIPT_DIR/preflight.sh" ${PROFILE:+--profile "$PROFILE"}
  else
    echo "WARNING: preflight.sh not found; skipping preflight checks."
  fi
fi

# (Optional) If secrets are stored in a secure location, copy them into .env files
if [ -d ./secrets ]; then
  for envfile in .env.infrastructure .env.media .env.ai-core .env.home-automation .env.agentic; do
    if [ -f ./secrets/$envfile ]; then
      echo "Copying secret file for $envfile"
      cp ./secrets/$envfile $envfile
    fi
  done
fi

# Set up Mosquitto (MQTT) credentials if provided
if [[ -n "${MQTT_USER:-}" && -n "${MQTT_PASSWORD:-}" ]]; then
  echo "Creating Mosquitto configuration with credentials..."
  CONF_DIR="/mnt/user/appdata/mosquitto/config"
  mkdir -p "$CONF_DIR"
  # Create mosquitto.conf if it doesn't exist
  if [ ! -f "$CONF_DIR/mosquitto.conf" ]; then
    cat > "$CONF_DIR/mosquitto.conf" <<'MOSQ'
persistence true
persistence_location /mosquitto/data/
allow_anonymous false
password_file /mosquitto/config/passwordfile
MOSQ
  fi
  # Generate password file using mosquitto_passwd utility
  docker run --rm -v "$CONF_DIR":/mosquitto/config eclipse-mosquitto \
    mosquitto_passwd -c -b /mosquitto/config/passwordfile "$MQTT_USER" "$MQTT_PASSWORD"
fi

compose_run() {
  local stack_file=$1
  local env_file=$2
  local compose_profiles=$3
  shift 3
  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -n "$compose_profiles" ]]; then
      echo "COMPOSE_PROFILES=${compose_profiles} docker compose -f ${stack_file} --env-file ${env_file} $*"
    else
      echo "docker compose -f ${stack_file} --env-file ${env_file} $*"
    fi
  else
    if [[ -n "$compose_profiles" ]]; then
      COMPOSE_PROFILES="${compose_profiles}" docker compose -f "${stack_file}" --env-file "${env_file}" "$@"
    else
      docker compose -f "${stack_file}" --env-file "${env_file}" "$@"
    fi
  fi
}

for stack in "${STACKS[@]}"; do
  stack_file="${stack}.yml"
  env_file=".env.${stack}"
  if [[ ! -f "$stack_file" ]]; then
    echo "Missing stack file: ${stack_file}" >&2
    exit 1
  fi
  if [[ ! -f "$env_file" ]]; then
    echo "Missing env file: ${env_file}" >&2
    exit 1
  fi

  compose_profiles=""
  if [[ "$stack" == "ai-core" ]]; then
    compose_profiles="${PROFILE:-${COMPOSE_PROFILES:-cpu}}"
  fi

  if [[ "$SKIP_PULL" -eq 0 ]]; then
    echo "Pulling latest Docker images for ${stack}..."
    compose_run "$stack_file" "$env_file" "$compose_profiles" pull
  fi

  echo "Deploying ${stack} stack..."
  compose_run "$stack_file" "$env_file" "$compose_profiles" up -d

done

echo "All requested stacks deployed. Verify via Portainer UI or 'docker ps' that containers are running."

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

  if [[ "$CONFIGURE" -eq 1 ]]; then
    echo "Auto-configuring media stack (waiting 30s for services to start)..."
    sleep 30
    "$SCRIPT_DIR/chimera-setup.sh" --auto
  fi
fi
