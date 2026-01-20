#!/bin/bash
# nip.io + Traefik Setup for Unraid
# No DNS configuration needed!

set -e

APPDATA="/mnt/user/appdata/traefik"
JAI_DIR="/mnt/user/appdata/jai"
UNRAID_IP="192.168.1.222"

echo "=========================================="
echo "  jAI + Traefik + nip.io Setup for Unraid"
echo "=========================================="
echo ""

# Create directories
echo "[1/6] Creating directories..."
mkdir -p "$APPDATA"/{config,certs}
mkdir -p "$JAI_DIR"/icons

# Create acme.json with correct permissions
touch "$APPDATA/acme.json"
chmod 600 "$APPDATA/acme.json"

# Generate self-signed certificate for nip.io domains
echo "[2/6] Generating SSL certificate for *.${UNRAID_IP}.nip.io..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$APPDATA/certs/nip.key" \
  -out "$APPDATA/certs/nip.crt" \
  -subj "/CN=*.${UNRAID_IP}.nip.io" \
  -addext "subjectAltName=DNS:*.${UNRAID_IP}.nip.io,DNS:${UNRAID_IP}.nip.io"

# Create Docker network if it doesn't exist
echo "[3/6] Creating Docker network..."
docker network create traefik-net 2>/dev/null || echo "  Network already exists"

# Check if config files exist
echo "[4/6] Checking configuration files..."
if [ ! -f "$APPDATA/traefik.yml" ]; then
    echo "  ERROR: traefik.yml not found in $APPDATA"
    echo "  Please copy the config files first"
    exit 1
fi

if [ ! -f "$APPDATA/config/dynamic.yml" ]; then
    echo "  ERROR: dynamic.yml not found in $APPDATA/config"
    exit 1
fi

# Check jAI files
echo "[5/6] Checking jAI files..."
if [ ! -f "$JAI_DIR/index.html" ]; then
    echo "  WARNING: index.html not found in $JAI_DIR"
    echo "  Please copy your jAI files"
fi

# Start containers
echo "[6/6] Starting Traefik..."
cd "$APPDATA"
docker-compose up -d

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Your services are now available at:"
echo ""
echo "  jAI Homepage:    https://jai.${UNRAID_IP}.nip.io"
echo "  Open WebUI:      https://chat.${UNRAID_IP}.nip.io"
echo "  vLLM API:        https://vllm.${UNRAID_IP}.nip.io"
echo "  Ollama:          https://ollama.${UNRAID_IP}.nip.io"
echo "  SearXNG:         https://search.${UNRAID_IP}.nip.io"
echo "  AnythingLLM:     https://rag.${UNRAID_IP}.nip.io"
echo "  Portainer:       https://portainer.${UNRAID_IP}.nip.io"
echo ""
echo "Note: Your browser will show a certificate warning."
echo "      Click 'Advanced' -> 'Proceed' to continue."
echo ""
echo "To check status:  docker logs traefik"
echo "To restart:       cd $APPDATA && docker-compose restart"
