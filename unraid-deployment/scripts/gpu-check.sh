#!/bin/bash
# gpu-check.sh - Validate NVIDIA GPU visibility on host and within Ollama container.

if ! command -v nvidia-smi &> /dev/null; then
  echo "ERROR: nvidia-smi not found. Install Unraid NVIDIA drivers plugin and reboot."
  exit 1
fi

echo "Host NVIDIA GPU status:"
nvidia-smi

if docker ps --format '{{.Names}}' | grep -q "^ollama$"; then
  runtime=$(docker inspect -f '{{.HostConfig.Runtime}}' ollama)
  if [ "$runtime" = "nvidia" ]; then
    echo "Ollama container is running with NVIDIA runtime. GPU should be accessible."
  else
    echo "WARNING: Ollama container is not using NVIDIA runtime. Check the compose config."
  fi
else
  echo "NOTE: Ollama container is not running. Deploy the AI stack first."
fi

# Optionally test an Ollama command (ensure a model is installed first):
# docker exec ollama ollama list
