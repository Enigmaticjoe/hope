#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_TEMPLATES_DIR="${ROOT_DIR}/env-templates"
STACKS_DIR="${ROOT_DIR}/stacks"

STACKS_DEFAULT=(infrastructure media ai-core home-automation agentic)

DRY_RUN=false
TARGET_STACK="all"
MODE_PREPARE=false
MODE_VALIDATE=false
MODE_DEPLOY=false
MODE_CONFIGURE=false
MODE_BOOTSTRAP=false

usage() {
  cat <<'USAGE'
Chimera Install Orchestrator

Usage: chimera-install.sh [OPTIONS]

Options:
  --all                 Run prepare + validate + deploy + configure (default).
  --prepare             Copy env templates if missing and create appdata dirs.
  --validate            Validate prerequisites, env files, and port conflicts.
  --deploy              Deploy docker compose stacks.
  --configure           Run media auto-configurator after deploy.
  --bootstrap           Run agentic bootstrap (ai_grid network + port checks).
  --stack <name>        Deploy only one stack (infrastructure|media|ai-core|ai-core-amd|home-automation|agentic).
  --dry-run             Show commands without executing them.
  -h, --help            Show this help.

Examples:
  ./chimera-install.sh --all
  ./chimera-install.sh --prepare --validate --deploy --stack media
  ./chimera-install.sh --bootstrap --stack agentic
  ./chimera-install.sh --configure
USAGE
}

log() {
  printf "\n[%s] %s\n" "${1}" "${2}"
}

run_cmd() {
  if ${DRY_RUN}; then
    echo "DRY-RUN: $*"
  else
    "$@"
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

load_envs() {
  set -a
  for env_file in "${ROOT_DIR}"/.env.*; do
    if [[ -f "${env_file}" ]]; then
      # shellcheck disable=SC1090
      source "${env_file}"
    fi
  done
  set +a
}

prepare_envs() {
  log "PREPARE" "Checking env files..."
  for stack in "${STACKS_DEFAULT[@]}"; do
    local env_file="${ROOT_DIR}/.env.${stack}"
    local template_file="${ENV_TEMPLATES_DIR}/.env.${stack}"
    if [[ ! -f "${env_file}" ]]; then
      if [[ -f "${template_file}" ]]; then
        log "PREPARE" "Copying ${template_file} -> ${env_file}"
        run_cmd cp "${template_file}" "${env_file}"
      else
        echo "Missing env template: ${template_file}" >&2
        exit 1
      fi
    fi
  done
}

ensure_appdata_dirs() {
  local appdata_path=${APPDATA_PATH:-/mnt/user/appdata}
  log "PREPARE" "Ensuring appdata directories exist under ${appdata_path}"
  local dirs=(
    tailscale homepage uptime-kuma dozzle
    plex sonarr radarr prowlarr bazarr overseerr tautulli
    zurg rdt-client
    ollama openwebui qdrant
    homeassistant mosquitto nodered zigbee2mqtt esphome
    n8n
  )
  for dir in "${dirs[@]}"; do
    run_cmd mkdir -p "${appdata_path}/${dir}"
  done
}

check_docker() {
  require_command docker
  if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running or not accessible." >&2
    exit 1
  fi
  if [[ ! -S /var/run/docker.sock ]]; then
    echo "Docker socket not found at /var/run/docker.sock" >&2
    exit 1
  fi
}

check_compose() {
  require_command docker
  if ! docker compose version >/dev/null 2>&1; then
    echo "docker compose plugin is required." >&2
    exit 1
  fi
}

check_ports() {
  require_command ss
  require_command rg
  local ports=(
    8008 9000 3010 9999
    32400 8989 7878 9696 5055 6767 8181 9090
    11434 3000 6333
    8123 1880 8080 6052
    5678
  )
  for port in "${ports[@]}"; do
    if ss -tulpn | rg -q ":${port}\\b"; then
      echo "Port ${port} is already in use. Resolve conflicts before deployment." >&2
      exit 1
    fi
  done
}

validate_env_files() {
  log "VALIDATE" "Checking env files exist"
  for stack in "${STACKS_DEFAULT[@]}"; do
    if [[ ! -f "${ROOT_DIR}/.env.${stack}" ]]; then
      echo "Missing .env.${stack}. Run --prepare or copy from env-templates." >&2
      exit 1
    fi
  done
}

ensure_ai_grid_network() {
  local network_name=${AI_GRID_NETWORK:-ai_grid}
  if ! docker network ls --format '{{.Name}}' | rg -q "^${network_name}$"; then
    log "BOOTSTRAP" "Creating docker network ${network_name}"
    run_cmd docker network create "${network_name}"
  fi
}

deploy_stack() {
  local stack=$1
  local stack_file="${STACKS_DIR}/${stack}.yml"
  local env_file="${ROOT_DIR}/.env.${stack}"
  if [[ "${stack}" == "ai-core-amd" ]]; then
    env_file="${ROOT_DIR}/.env.ai-core"
  fi
  if [[ ! -f "${stack_file}" ]]; then
    echo "Missing stack file: ${stack_file}" >&2
    exit 1
  fi
  if [[ ! -f "${env_file}" ]]; then
    echo "Missing env file: ${env_file}" >&2
    exit 1
  fi
  log "DEPLOY" "Deploying ${stack}"
  run_cmd docker compose -f "${stack_file}" --env-file "${env_file}" pull
  run_cmd docker compose -f "${stack_file}" --env-file "${env_file}" up -d
}

run_configurator() {
  local configurator="${SCRIPT_DIR}/chimera-setup.sh"
  if [[ -x "${configurator}" ]]; then
    log "CONFIGURE" "Running media stack configurator"
    run_cmd "${configurator}" --auto
  else
    echo "Configurator not found or not executable: ${configurator}" >&2
    exit 1
  fi
}

run_agentic_bootstrap() {
  local bootstrap="${SCRIPT_DIR}/agentic-bootstrap.sh"
  if [[ -x "${bootstrap}" ]]; then
    log "BOOTSTRAP" "Running agentic bootstrap"
    run_cmd "${bootstrap}"
  else
    echo "Agentic bootstrap not found: ${bootstrap}" >&2
    exit 1
  fi
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    MODE_PREPARE=true
    MODE_VALIDATE=true
    MODE_DEPLOY=true
    MODE_CONFIGURE=true
    MODE_BOOTSTRAP=true
    return
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        MODE_PREPARE=true
        MODE_VALIDATE=true
        MODE_DEPLOY=true
        MODE_CONFIGURE=true
        MODE_BOOTSTRAP=true
        shift
        ;;
      --prepare)
        MODE_PREPARE=true
        shift
        ;;
      --validate)
        MODE_VALIDATE=true
        shift
        ;;
      --deploy)
        MODE_DEPLOY=true
        shift
        ;;
      --configure)
        MODE_CONFIGURE=true
        shift
        ;;
      --bootstrap)
        MODE_BOOTSTRAP=true
        shift
        ;;
      --stack)
        TARGET_STACK=$2
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  load_envs

  if ${MODE_PREPARE}; then
    prepare_envs
    ensure_appdata_dirs
  fi

  if ${MODE_VALIDATE}; then
    check_docker
    check_compose
    validate_env_files
    check_ports
  fi

  if ${MODE_BOOTSTRAP}; then
    check_docker
    ensure_ai_grid_network
    run_agentic_bootstrap
  fi

  if ${MODE_DEPLOY}; then
    check_docker
    check_compose
    if [[ "${TARGET_STACK}" == "all" ]]; then
      for stack in "${STACKS_DEFAULT[@]}"; do
        deploy_stack "${stack}"
      done
    else
      deploy_stack "${TARGET_STACK}"
    fi
  fi

  if ${MODE_CONFIGURE}; then
    run_configurator
  fi
}

main "$@"
