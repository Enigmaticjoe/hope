#!/bin/bash
# Traefik Setup Script for Unraid
# Run this on your Unraid server

set -e

APPDATA="/mnt/user/appdata/traefik"
JAI_DIR="/mnt/user/appdata/jai"

echo "=== Traefik Setup for Unraid ==="

# Create directories
echo "Creating directories..."
mkdir -p "$APPDATA"/{config,certs}
mkdir -p "$JAI_DIR"

# Copy configuration files
echo "Copying configuration..."
cp traefik.yml "$APPDATA/"
cp config/dynamic.yml "$APPDATA/config/"
cp docker-compose.yml "$APPDATA/"

# Create acme.json with correct permissions
touch "$APPDATA/acme.json"
chmod 600 "$APPDATA/acme.json"

# Generate self-signed certificate for local domains
echo "Generating self-signed certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$APPDATA/certs/local.key" \
  -out "$APPDATA/certs/local.crt" \
  -subj "/CN=*.local" \
  -addext "subjectAltName=DNS:*.local,DNS:localhost,IP:192.168.1.222,IP:192.168.1.9,IP:100.108.197.12"

# Create Docker network if it doesn't exist
echo "Creating Docker network..."
docker network create traefik-net 2>/dev/null || echo "Network already exists"

# Copy jAI files
echo "Copy your jAI homepage files to: $JAI_DIR"
echo "  - index.html"
echo "  - manifest.json"
echo "  - sw.js"
echo "  - icons/"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Copy your jAI files to $JAI_DIR"
echo "2. cd $APPDATA && docker-compose up -d"
echo "3. Add to your hosts file or local DNS:"
echo "   192.168.1.222  jai.local chat.local vllm.local ollama.local search.local rag.local traefik.local"
echo ""
echo "Access your services:"
echo "  - jAI Homepage:  https://jai.local"
echo "  - Open WebUI:    https://chat.local"
echo "  - vLLM API:      https://vllm.local"
echo "  - Traefik:       https://traefik.local"
