#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_DIR="${ROOT_DIR}/env-templates"

STACKS=(infrastructure media ai-core home-automation agentic moltbot)

log() {
  printf "\n[%s] %s\n" "${1}" "${2}"
}

prompt_yes_no() {
  local prompt="$1"
  local response=""
  while true; do
    read -r -p "${prompt} [y/n]: " response
    case "${response,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

render_env_file() {
  local template_file="$1"
  local target_file="$2"
  local tmp_file
  tmp_file="$(mktemp)"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ -z "${line}" || "${line}" =~ ^# ]]; then
      echo "${line}" >> "${tmp_file}"
      continue
    fi

    local key="${line%%=*}"
    local default="${line#*=}"
    local value=""
    read -r -p "Set ${key} [${default}]: " value
    if [[ -z "${value}" ]]; then
      value="${default}"
    fi
    echo "${key}=\"${value}\"" >> "${tmp_file}"
  done < "${template_file}"

  mv "${tmp_file}" "${target_file}"
}

main() {
  log "ENV" "Chimera .env wizard (Unraid + Portainer)."
  log "ENV" "Templates: ${TEMPLATE_DIR}"

  for stack in "${STACKS[@]}"; do
    local template_file="${TEMPLATE_DIR}/.env.${stack}"
    local target_file="${ROOT_DIR}/.env.${stack}"

    if [[ ! -f "${template_file}" ]]; then
      echo "Missing template: ${template_file}" >&2
      exit 1
    fi

    if [[ -f "${target_file}" ]]; then
      if ! prompt_yes_no "Found ${target_file}. Overwrite?"; then
        continue
      fi
    fi

    log "ENV" "Configuring ${target_file}"
    render_env_file "${template_file}" "${target_file}"
  done

  log "ENV" "Done. Review the .env files and adjust if needed."
}

main
