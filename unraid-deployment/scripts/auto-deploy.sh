#!/bin/bash
# auto-deploy.sh - Pull latest images and deploy stack YMLs via Portainer/Compose.

set -euo pipefail

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
[ -f "${ROOT_DIR}/.env.moltbot" ] && source "${ROOT_DIR}/.env.moltbot"
set +a

STACKS=(infrastructure media ai-core home-automation agentic moltbot)
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
  --profile <name>     Compose profile for ai-core (cpu|nvidia)
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

if [[ -z "${PROFILE}" && -n "${AI_CORE_PROFILE:-}" ]]; then
  PROFILE="${AI_CORE_PROFILE}"
fi

if [[ -z "${PROFILE}" ]]; then
  PROFILE="nvidia"
fi

if [[ "$SKIP_PREFLIGHT" -eq 0 ]]; then
  if [[ -f "$SCRIPT_DIR/preflight.sh" ]]; then
    "$SCRIPT_DIR/preflight.sh" ${PROFILE:+--profile "$PROFILE"}
  else
    echo "WARNING: preflight.sh not found; skipping preflight checks."
  fi
fi

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

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: $*"
  else
    "$@"
  fi
}

for stack in "${STACKS[@]}"; do
  stack_file="${STACKS_DIR}/${stack}.yml"
  env_file="${ROOT_DIR}/.env.${stack}"

  if [[ ! -f "${stack_file}" ]]; then
    echo "WARNING: Stack file not found: ${stack_file}, skipping." >&2
    continue
  fi
  if [[ ! -f "${env_file}" ]]; then
    echo "WARNING: Env file not found: ${env_file}, skipping." >&2
    continue
  fi

  compose_args=(-f "${stack_file}" --env-file "${env_file}")
  profile_prefix=()
  if [[ "${stack}" == "ai-core" ]]; then
    profile_prefix=(env "COMPOSE_PROFILES=${PROFILE}")
  fi

  if [[ "$SKIP_PULL" -eq 0 ]]; then
    echo "Pulling images for ${stack}..."
    run_cmd "${profile_prefix[@]}" docker compose "${compose_args[@]}" pull
  fi

  echo "Deploying ${stack} stack..."
  run_cmd "${profile_prefix[@]}" docker compose "${compose_args[@]}" up -d
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
