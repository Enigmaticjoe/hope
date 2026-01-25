#!/bin/bash
# gpu-check.sh - Validate AMD ROCm GPU visibility on host and within Ollama container.

if [[ ! -e /dev/kfd ]]; then
  echo "ERROR: /dev/kfd not found. Install the AMD GPU driver plugin and reboot."
  exit 1
fi

echo "Host AMD ROCm status:"
if command -v rocm-smi &> /dev/null; then
  rocm-smi
elif command -v rocminfo &> /dev/null; then
  rocminfo | head -n 40
else
  echo "WARNING: rocm-smi or rocminfo not found. Install ROCm tools to inspect GPU."
fi

if docker ps --format '{{.Names}}' | grep -q "^ollama$"; then
  if docker inspect -f '{{json .HostConfig.Devices}}' ollama | rg -q '/dev/kfd'; then
    echo "Ollama container is mapped to /dev/kfd. ROCm GPU should be accessible."
  else
    echo "WARNING: Ollama container is missing /dev/kfd. Check the compose config."
  fi
else
  echo "NOTE: Ollama container is not running. Deploy the AI stack first."
fi

# Optionally test an Ollama command (ensure a model is installed first):
# docker exec ollama ollama list
