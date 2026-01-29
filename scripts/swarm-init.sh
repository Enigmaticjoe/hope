#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

STACK_FILE="${STACK_FILE:-${ROOT_DIR}/swarm/chimera-brain-stack.yml}"
STACK_NAME="${STACK_NAME:-chimera-brain}"
NODE_LABEL_KEY="${NODE_LABEL_KEY:-chimera.role}"
NODE_LABEL_VALUE="${NODE_LABEL_VALUE:-brain}"
ADVERTISE_ADDR="${ADVERTISE_ADDR:-}"
BRAIN_PREFLIGHT="${BRAIN_PREFLIGHT:-true}"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed or not in PATH." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not reachable. Verify docker socket permissions." >&2
  echo "Hint: ensure your user is in the docker group or run with sudo." >&2
  exit 1
fi

if ! id -nG "${USER}" | tr ' ' '\n' | grep -q '^docker$'; then
  echo "WARNING: user ${USER} is not in the docker group. Socket access may fail." >&2
fi

swarm_state=$(docker info --format '{{.Swarm.LocalNodeState}}' || echo "unknown")

if [[ "${swarm_state}" != "active" ]]; then
  if [[ -n "${ADVERTISE_ADDR}" ]]; then
    docker swarm init --advertise-addr "${ADVERTISE_ADDR}"
  else
    docker swarm init
  fi
fi

if [[ "${BRAIN_PREFLIGHT}" == "true" && -x "${ROOT_DIR}/scripts/brain-preflight.sh" ]]; then
  "${ROOT_DIR}/scripts/brain-preflight.sh"
fi

node_id=$(docker info --format '{{.Swarm.NodeID}}')
node_name=$(docker node inspect --format '{{.Description.Hostname}}' "${node_id}")

existing_label=$(docker node inspect --format "{{ index .Spec.Labels \"${NODE_LABEL_KEY}\" }}" "${node_id}" || true)
if [[ "${existing_label}" != "${NODE_LABEL_VALUE}" ]]; then
  docker node update --label-add "${NODE_LABEL_KEY}=${NODE_LABEL_VALUE}" "${node_name}"
fi

if [[ ! -f "${STACK_FILE}" ]]; then
  echo "Missing stack file: ${STACK_FILE}" >&2
  exit 1
fi

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

if [[ ! -e /dev/kfd || ! -e /dev/dri ]]; then
  echo "WARNING: ROCm devices not found at /dev/kfd or /dev/dri. Ollama may fail." >&2
fi

docker stack deploy -c "${STACK_FILE}" "${STACK_NAME}"

echo "Swarm stack '${STACK_NAME}' deployed using ${STACK_FILE}."
