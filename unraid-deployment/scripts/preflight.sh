#!/usr/bin/env bash
set -euo pipefail

PROFILE=""

set -a
[ -f .env.infrastructure ] && source .env.infrastructure
[ -f .env.media ] && source .env.media
[ -f .env.ai-core ] && source .env.ai-core
[ -f .env.home-automation ] && source .env.home-automation
[ -f .env.agentic ] && source .env.agentic
set +a

usage() {
  cat <<'EOF'
Usage: preflight.sh [--profile cpu|nvidia|rocm]

Validates docker socket access, env files, appdata paths, port conflicts, and DNS.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
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

STACK_ENV_FILES=(.env.infrastructure .env.media .env.ai-core .env.home-automation .env.agentic)

ensure_docker_socket() {
  if [[ ! -S /var/run/docker.sock ]]; then
    echo "Docker socket not found at /var/run/docker.sock" >&2
    exit 1
  fi

  if [[ ! -r /var/run/docker.sock ]]; then
    echo "Docker socket is not readable. Verify permissions before continuing." >&2
    exit 1
  fi
}

ensure_env_files() {
  local missing=0
  for env_file in "${STACK_ENV_FILES[@]}"; do
    if [[ ! -f "$env_file" ]]; then
      echo "Missing env file: $env_file" >&2
      missing=1
    fi
  done
  if [[ "$missing" -eq 1 ]]; then
    echo "Copy env-templates/*.env into place before deploying." >&2
    exit 1
  fi
}

ensure_appdata_paths() {
  local appdata_path="${APPDATA_PATH:-/mnt/user/appdata}"
  if [[ ! -d "$appdata_path" ]]; then
    echo "Appdata path does not exist: $appdata_path" >&2
    exit 1
  fi
}

check_ports() {
  local homepage_port="${HOMEPAGE_PORT:-8008}"
  local browserless_port="${BROWSERLESS_PORT:-3005}"
  local ports=(
    "${homepage_port}" 3010 9999
    11434 3000 6333
    32400 32469 1900 32410 32412 32413 32414
    8989 7878 9696 6767 5055 8181 9090 6500
    8123 1880 1883 8080 6052
    5678 "${browserless_port}"
  )
  declare -A seen=()
  local in_use=0
  for port in "${ports[@]}"; do
    if [[ -z "${port}" ]]; then
      continue
    fi
    if [[ -n "${seen[${port}]:-}" ]]; then
      continue
    fi
    seen["${port}"]=1
    if command -v ss >/dev/null 2>&1; then
      if ss -tulpn | rg -q ":${port}\\b"; then
        echo "Port ${port} is already in use." >&2
        in_use=1
      fi
    elif command -v lsof >/dev/null 2>&1; then
      if lsof -i ":${port}" >/dev/null 2>&1; then
        echo "Port ${port} is already in use." >&2
        in_use=1
      fi
    else
      echo "WARN: Neither ss nor lsof is available for port checks." >&2
      break
    fi
  done

  if [[ "$in_use" -eq 1 ]]; then
    echo "Resolve port conflicts before deploying." >&2
    exit 1
  fi
}

check_dns() {
  if [[ -f /etc/resolv.conf ]]; then
    if rg -q "nameserver 127.0.0.53" /etc/resolv.conf; then
      echo "WARN: systemd-resolved stub detected in /etc/resolv.conf" >&2
      echo "      Consider setting direct DNS (e.g., 1.1.1.1 or 8.8.8.8)." >&2
    fi
  fi
}

check_gpu() {
  if [[ "$PROFILE" == "nvidia" ]]; then
    if ! command -v nvidia-smi >/dev/null 2>&1; then
      echo "WARN: nvidia-smi not found. NVIDIA profile may fail." >&2
    fi
  fi
  if [[ "$PROFILE" == "rocm" ]]; then
    if [[ ! -e /dev/kfd ]]; then
      echo "WARN: /dev/kfd not found. ROCm profile may fail." >&2
    fi
    if [[ ! -e /dev/dri ]]; then
      echo "WARN: /dev/dri not found. ROCm profile may fail." >&2
    fi
  fi
}

main() {
  ensure_docker_socket
  ensure_env_files
  ensure_appdata_paths
  check_ports
  check_dns
  check_gpu
  echo "Preflight checks complete."
}

main
