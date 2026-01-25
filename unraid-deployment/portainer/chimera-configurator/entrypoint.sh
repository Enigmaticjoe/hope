#!/bin/bash
# Chimera Configurator Container Entrypoint

set -e

echo "============================================"
echo "  Chimera Media Stack Configurator"
echo "============================================"
echo ""

# Set up config path
export CONFIG_FILE="${CONFIG_PATH}/media_stack_config.json"

# Run the configurator
exec python3 /app/media_configurator.py "$@"
