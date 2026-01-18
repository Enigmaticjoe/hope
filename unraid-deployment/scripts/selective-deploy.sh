#!/bin/bash
# selective-deploy.sh - Deploy only new services, preserve existing containers
# Designed for 192.168.1.222 with existing containers

set -e

echo "================================================"
echo "Selective Deployment for Existing Unraid Setup"
echo "Server: 192.168.1.222"
echo "================================================"
echo ""

# Load environment variables
set -a
[ -f .env.infrastructure ] && source .env.infrastructure
[ -f .env.media ] && source .env.media
[ -f .env.ai-core ] && source .env.ai-core
[ -f .env.home-automation ] && source .env.home-automation
set +a

# Check if running in correct directory
if [ ! -f "stacks/infrastructure.yml" ]; then
    echo "ERROR: Please run this script from the unraid-deployment directory"
    echo "Usage: cd unraid-deployment && ./scripts/selective-deploy.sh"
    exit 1
fi

# Function to check if container exists
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^$1$"
}

# Function to check if container is running
container_running() {
    docker ps --format '{{.Names}}' | grep -q "^$1$"
}

echo "Current container status:"
echo "- ollama: $(container_running ollama && echo 'running' || echo 'not running')"
echo "- open-webui: $(container_running open-webui && echo 'running' || echo 'not running')"
echo "- qdrant: $(container_running qdrant && echo 'running' || echo 'not running')"
echo "- zurg: $(container_exists zurg && echo 'exists (stopped)' || echo 'not found')"
echo ""

# Prompt user for deployment choices
echo "What would you like to deploy?"
echo ""
echo "1) Infrastructure only (Tailscale, Homepage, Monitoring)"
echo "2) Media stack only (Plex, *arr suite)"
echo "3) Upgrade AI stack to GPU-accelerated"
echo "4) Home Automation (with port conflict fixes)"
echo "5) Infrastructure + Media (recommended first step)"
echo "6) Everything (Infrastructure + Media + AI upgrade + Home)"
echo "7) Custom selection"
echo ""
read -p "Enter choice (1-7): " choice

deploy_infrastructure() {
    echo ""
    echo "=== Deploying Infrastructure Stack ==="
    echo "Services: Tailscale, Homepage, Uptime Kuma, Dozzle, Watchtower"

    docker compose -f stacks/infrastructure.yml --env-file .env.infrastructure pull
    docker compose -f stacks/infrastructure.yml --env-file .env.infrastructure up -d

    echo "✅ Infrastructure deployed!"
    echo "Access Homepage at: http://192.168.1.222:8008"
    echo "Access Uptime Kuma at: http://192.168.1.222:3010"
    echo "Access Dozzle logs at: http://192.168.1.222:9999"
}

deploy_media() {
    echo ""
    echo "=== Deploying Media Stack ==="

    # Check and remove old zurg if exists
    if container_exists zurg; then
        echo "Found existing zurg container. Removing it..."
        docker stop zurg 2>/dev/null || true
        docker rm zurg
        echo "✅ Old zurg removed"
    fi

    echo "Services: Plex, Sonarr, Radarr, Prowlarr, Bazarr, Overseerr, Tautulli, Zurg"

    docker compose -f stacks/media.yml --env-file .env.media pull
    docker compose -f stacks/media.yml --env-file .env.media up -d

    echo "✅ Media stack deployed!"
    echo "Access Plex at: http://192.168.1.222:32400/web"
    echo "Access Overseerr at: http://192.168.1.222:5055"
}

upgrade_ai() {
    echo ""
    echo "=== Upgrading AI Stack to GPU-Accelerated ==="
    echo ""
    echo "⚠️  WARNING: This will stop and replace your existing AI containers"
    echo "Your data will be preserved (models, chats, etc.)"
    echo ""
    read -p "Continue? (y/n): " confirm

    if [ "$confirm" != "y" ]; then
        echo "Skipping AI upgrade"
        return
    fi

    # Check GPU availability
    if ! command -v nvidia-smi &> /dev/null; then
        echo "❌ ERROR: nvidia-smi not found!"
        echo "Install Unraid NVIDIA Drivers plugin first"
        return 1
    fi

    echo "GPU detected:"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader

    # Stop existing containers
    echo ""
    echo "Stopping existing containers..."
    for container in ollama open-webui qdrant; do
        if container_running $container; then
            echo "Stopping $container..."
            docker stop $container
        fi
    done

    # Remove containers (data is preserved in volumes)
    echo "Removing containers (data preserved)..."
    for container in ollama open-webui qdrant; do
        if container_exists $container; then
            docker rm $container
        fi
    done

    echo "Deploying GPU-accelerated AI stack..."
    docker compose -f stacks/ai-core.yml --env-file .env.ai-core pull
    docker compose -f stacks/ai-core.yml --env-file .env.ai-core up -d

    echo "✅ AI stack upgraded!"
    echo "Verifying GPU access..."
    sleep 5

    if [ -f scripts/gpu-check.sh ]; then
        ./scripts/gpu-check.sh
    fi

    echo ""
    echo "Access Open WebUI at: http://192.168.1.222:8080"
    echo "To pull a model: docker exec ollama ollama pull llama2"
}

deploy_home_automation() {
    echo ""
    echo "=== Deploying Home Automation Stack ==="
    echo "Using modified ports to avoid conflicts:"
    echo "  - Home Assistant: 8124 (instead of 8123 - KitchenOwl)"
    echo "  - Zigbee2MQTT: 8083 (instead of 8080 - open-webui)"

    # Set up Mosquitto credentials if provided
    if [[ -n "$MQTT_USER" && -n "$MQTT_PASSWORD" ]]; then
        echo "Setting up Mosquitto MQTT credentials..."
        CONF_DIR="/mnt/user/appdata/mosquitto/config"
        mkdir -p "$CONF_DIR"

        if [ ! -f "$CONF_DIR/mosquitto.conf" ]; then
            cat > "$CONF_DIR/mosquitto.conf" <<EOF
persistence true
persistence_location /mosquitto/data/
allow_anonymous false
password_file /mosquitto/config/passwordfile
EOF
        fi

        docker run --rm -v "$CONF_DIR":/mosquitto/config eclipse-mosquitto \
            mosquitto_passwd -c -b /mosquitto/config/passwordfile "$MQTT_USER" "$MQTT_PASSWORD"
    fi

    docker compose -f stacks/home-automation-no-conflicts.yml --env-file .env.home-automation pull
    docker compose -f stacks/home-automation-no-conflicts.yml --env-file .env.home-automation up -d

    echo "✅ Home Automation deployed!"
    echo "Access Home Assistant at: http://192.168.1.222:8124"
    echo "Access Node-RED at: http://192.168.1.222:1880"
    echo "Access Zigbee2MQTT at: http://192.168.1.222:8083"
}

# Execute based on choice
case $choice in
    1)
        deploy_infrastructure
        ;;
    2)
        deploy_media
        ;;
    3)
        upgrade_ai
        ;;
    4)
        deploy_home_automation
        ;;
    5)
        deploy_infrastructure
        deploy_media
        ;;
    6)
        deploy_infrastructure
        deploy_media
        upgrade_ai
        deploy_home_automation
        ;;
    7)
        echo ""
        read -p "Deploy Infrastructure? (y/n): " inf
        [ "$inf" = "y" ] && deploy_infrastructure

        read -p "Deploy Media? (y/n): " med
        [ "$med" = "y" ] && deploy_media

        read -p "Upgrade AI to GPU? (y/n): " ai
        [ "$ai" = "y" ] && upgrade_ai

        read -p "Deploy Home Automation? (y/n): " home
        [ "$home" = "y" ] && deploy_home_automation
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
echo "📊 View all containers: docker ps"
echo "📋 View logs: http://192.168.1.222:9999 (Dozzle)"
echo "🏠 View dashboard: http://192.168.1.222:8008 (Homepage)"
echo ""
echo "Next steps:"
echo "1. Configure Homepage dashboard: cp configs/homepage-dashboard-222.yaml /mnt/user/appdata/homepage/config.yml"
echo "2. Set up monitoring in Uptime Kuma: http://192.168.1.222:3010"
echo "3. Configure Plex libraries: http://192.168.1.222:32400/web"
echo "4. If AI upgraded, pull models: docker exec ollama ollama pull llama2"
echo ""
