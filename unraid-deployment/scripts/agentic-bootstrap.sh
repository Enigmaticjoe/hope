#!/usr/bin/env bash
set -euo pipefail

AI_GRID_NETWORK=${AI_GRID_NETWORK:-ai_grid}
APPDATA_PATH=${APPDATA_PATH:-/mnt/user/appdata}

port_in_use() {
  local port=$1
  if ss -tulpn | grep -qE ":${port}[[:space:]]|:${port}$"; then
    return 0
  fi
  return 1
}

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

ensure_network() {
  if ! docker network ls --format '{{.Name}}' | grep -q "^${AI_GRID_NETWORK}$"; then
    echo "Creating Docker network: ${AI_GRID_NETWORK}"
    docker network create "${AI_GRID_NETWORK}"
  else
    echo "Docker network already exists: ${AI_GRID_NETWORK}"
  fi
}

ensure_appdata_dirs() {
  mkdir -p "${APPDATA_PATH}/n8n"
}

check_ports() {
  local ports=(5678)
  for port in "${ports[@]}"; do
    if port_in_use "${port}"; then
      echo "Port ${port} is already in use. Update your stack env or stop the conflicting service." >&2
      exit 1
    fi
  done
}

main() {
  ensure_docker_socket
  check_ports
  ensure_network
  ensure_appdata_dirs
  echo "Agentic stack prerequisites complete."
}

main
