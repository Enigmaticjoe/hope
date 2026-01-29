#!/bin/bash
# gpu-check.sh - Validate GPU visibility on host and within Ollama container.

set -euo pipefail

check_nvidia() {
  if command -v nvidia-smi &> /dev/null; then
    echo "Host NVIDIA GPU status:"
    nvidia-smi

    if docker ps --format '{{.Names}}' | grep -q "^ollama-nvidia$"; then
      runtime=$(docker inspect -f '{{.HostConfig.Runtime}}' ollama-nvidia)
      if [ "$runtime" = "nvidia" ]; then
        echo "Ollama (NVIDIA) container is running with NVIDIA runtime. GPU should be accessible."
      else
        echo "WARNING: Ollama (NVIDIA) container is not using NVIDIA runtime. Check the compose config."
      fi
    elif docker ps --format '{{.Names}}' | grep -q "^ollama$"; then
      echo "NOTE: ollama container is running without NVIDIA runtime."
    else
      echo "NOTE: Ollama container is not running. Deploy the AI stack first."
    fi
    return 0
  fi
  return 1
}

if check_nvidia; then
  exit 0
fi
echo "ERROR: No NVIDIA GPU support detected (nvidia-smi missing)." >&2
echo "Install the NVIDIA drivers for the RTX 4070 and reboot before deploying AI services." >&2
exit 1
