#!/bin/bash
# ==============================================================================
# PORTAINER CE INSTALLER FOR FEDORA 43
# ==============================================================================
# PURPOSE:   Install Docker Engine + Portainer CE on Fedora 43
# PORTAINER: Community Edition (latest stable)
# PORT:      9000 (web UI), 8000 (tunnel, optional)
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PORTAINER_VERSION="latest"
PORTAINER_DATA="/var/lib/portainer"
PORTAINER_PORT=9000
PORTAINER_TUNNEL_PORT=8000

# Root Check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root: sudo ./install-portainer-fedora.sh${NC}"
   exit 1
fi

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║        PORTAINER CE INSTALLER FOR FEDORA 43                   ║
║        Docker Engine + Portainer Community Edition            ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ==============================================================================
# PHASE 1: INSTALL DOCKER ENGINE
# ==============================================================================
echo -e "${BLUE}[PHASE 1]${NC} Installing Docker Engine for Fedora 43..."

# Remove old Docker versions if they exist
echo -e "${YELLOW}[1/6]${NC} Removing old Docker versions (if any)..."
dnf remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-selinux \
    docker-engine-selinux \
    docker-engine 2>/dev/null || true

# Install required dependencies
echo -e "${YELLOW}[2/6]${NC} Installing dependencies..."
dnf install -y dnf-plugins-core

# Add Docker repository
echo -e "${YELLOW}[3/6]${NC} Adding Docker repository..."
dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

# Install Docker Engine
echo -e "${YELLOW}[4/6]${NC} Installing Docker Engine..."
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
echo -e "${YELLOW}[5/6]${NC} Starting Docker service..."
systemctl start docker
systemctl enable docker

# Verify Docker installation
echo -e "${YELLOW}[6/6]${NC} Verifying Docker installation..."
if docker --version > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker installed successfully: $(docker --version)${NC}"
else
    echo -e "${RED}✗ Docker installation failed${NC}"
    exit 1
fi

# ==============================================================================
# PHASE 2: INSTALL PORTAINER CE
# ==============================================================================
echo -e "\n${BLUE}[PHASE 2]${NC} Installing Portainer CE..."

# Create Portainer data directory
echo -e "${YELLOW}[1/4]${NC} Creating Portainer data directory..."
mkdir -p "$PORTAINER_DATA"

# Pull Portainer image
echo -e "${YELLOW}[2/4]${NC} Pulling Portainer CE image..."
docker pull portainer/portainer-ce:${PORTAINER_VERSION}

# Stop and remove existing Portainer container if it exists
echo -e "${YELLOW}[3/4]${NC} Checking for existing Portainer container..."
if docker ps -a | grep -q portainer; then
    echo -e "   ${YELLOW}→${NC} Stopping and removing existing Portainer container..."
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
fi

# Run Portainer container
echo -e "${YELLOW}[4/4]${NC} Starting Portainer CE container..."
docker run -d \
    -p ${PORTAINER_TUNNEL_PORT}:8000 \
    -p ${PORTAINER_PORT}:9000 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${PORTAINER_DATA}:/data \
    portainer/portainer-ce:${PORTAINER_VERSION}

# Verify Portainer is running
sleep 3
if docker ps | grep -q portainer; then
    echo -e "${GREEN}✓ Portainer CE is running${NC}"
else
    echo -e "${RED}✗ Portainer failed to start${NC}"
    exit 1
fi

# ==============================================================================
# PHASE 3: FIREWALL CONFIGURATION
# ==============================================================================
echo -e "\n${BLUE}[PHASE 3]${NC} Configuring firewall..."

if systemctl is-active --quiet firewalld; then
    echo -e "${YELLOW}[1/2]${NC} Opening Portainer ports in firewalld..."
    firewall-cmd --permanent --add-port=${PORTAINER_PORT}/tcp
    firewall-cmd --permanent --add-port=${PORTAINER_TUNNEL_PORT}/tcp
    firewall-cmd --reload
    echo -e "${GREEN}✓ Firewall rules added${NC}"
else
    echo -e "${YELLOW}[!] firewalld is not running - skipping firewall configuration${NC}"
fi

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  INSTALLATION COMPLETE                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Portainer Web UI:${NC}      http://$(hostname -I | awk '{print $1}'):${PORTAINER_PORT}"
echo -e "${BLUE}Portainer Tunnel:${NC}      Port ${PORTAINER_TUNNEL_PORT}"
echo -e "${BLUE}Data Directory:${NC}        ${PORTAINER_DATA}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Open your browser and navigate to: http://localhost:${PORTAINER_PORT}"
echo -e "  2. Create your admin account (first login)"
echo -e "  3. Connect to the local Docker environment"
echo ""
echo -e "${GREEN}Portainer will automatically start on system reboot.${NC}"
echo ""
