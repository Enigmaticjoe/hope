#!/bin/bash
# gpu-check.sh - Validate AMD ROCm GPU visibility on host and within Ollama container.

if ! command -v rocm-smi &> /dev/null; then
  echo "ERROR: rocm-smi not found. Install the Unraid ROCm stack and reboot."
  exit 1
fi

echo "Host AMD GPU status:"
rocm-smi

if docker ps --format '{{.Names}}' | grep -q "^ollama$"; then
  kfd=$(docker inspect -f '{{json .HostConfig.Devices}}' ollama | grep -c "/dev/kfd" || true)
  dri=$(docker inspect -f '{{json .HostConfig.Devices}}' ollama | grep -c "/dev/dri" || true)
  if [ "$kfd" -gt 0 ] && [ "$dri" -gt 0 ]; then
    echo "Ollama container has /dev/kfd and /dev/dri mapped. ROCm should be accessible."
  else
    echo "WARNING: Ollama container is missing /dev/kfd or /dev/dri. Check the compose config."
  fi
else
  echo "NOTE: Ollama container is not running. Deploy the AI stack first."
fi

# Optionally test an Ollama command (ensure a model is installed first):
# docker exec ollama ollama list
