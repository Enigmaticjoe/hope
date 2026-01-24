#!/bin/bash
# =============================================================================
# Chimera Setup - Media Stack Auto-Configuration
# =============================================================================
# One-command setup for your entire media stack on Unraid.
#
# This script wraps the Python media_configurator.py tool with common
# use cases and sensible defaults for Unraid environments.
#
# Usage:
#   ./chimera-setup.sh              # Interactive setup
#   ./chimera-setup.sh --auto       # Fully automatic mode
#   ./chimera-setup.sh --status     # Check current status
#   ./chimera-setup.sh --dry-run    # Preview changes without applying
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGURATOR="$SCRIPT_DIR/media_configurator.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     ██████╗██╗  ██╗██╗███╗   ███╗███████╗██████╗  █████╗    ║"
    echo "║    ██╔════╝██║  ██║██║████╗ ████║██╔════╝██╔══██╗██╔══██╗   ║"
    echo "║    ██║     ███████║██║██╔████╔██║█████╗  ██████╔╝███████║   ║"
    echo "║    ██║     ██╔══██║██║██║╚██╔╝██║██╔══╝  ██╔══██╗██╔══██║   ║"
    echo "║    ╚██████╗██║  ██║██║██║ ╚═╝ ██║███████╗██║  ██║██║  ██║   ║"
    echo "║     ╚═════╝╚═╝  ╚═╝╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ║"
    echo "║                                                              ║"
    echo "║              Media Stack Auto-Configuration                  ║"
    echo "║                      Unraid Edition                          ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_requirements() {
    # Check for Python 3
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: Python 3 is required but not installed.${NC}"
        echo "Install with: apt install python3 (or your package manager)"
        exit 1
    fi

    # Check for Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Warning: Docker not found. Container discovery will be limited.${NC}"
    fi

    # Check if configurator exists
    if [[ ! -f "$CONFIGURATOR" ]]; then
        echo -e "${RED}Error: media_configurator.py not found at $CONFIGURATOR${NC}"
        exit 1
    fi
}

show_help() {
    echo "Chimera Setup - Media Stack Auto-Configuration"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --auto, -a        Fully automatic mode - discover and configure everything"
    echo "  --interactive, -i Interactive setup wizard"
    echo "  --status, -s      Show current configuration status"
    echo "  --discover, -d    Discover available services"
    echo "  --dry-run         Preview changes without applying"
    echo "  --extract-keys    Extract API keys from config files"
    echo "  --reset           Clear saved configuration"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --auto                    # Fully automatic setup"
    echo "  $0 --auto --dry-run          # Preview automatic setup"
    echo "  $0 --interactive             # Step-by-step guided setup"
    echo "  $0 --status                  # Check what's configured"
    echo ""
    echo "For more options, run: python3 $CONFIGURATOR --help"
}

main() {
    print_banner
    check_requirements

    case "${1:-}" in
        --auto|-a)
            shift
            echo -e "${GREEN}Running automatic configuration...${NC}"
            python3 "$CONFIGURATOR" configure --auto "$@"
            ;;
        --interactive|-i)
            shift
            echo -e "${GREEN}Starting interactive setup wizard...${NC}"
            python3 "$CONFIGURATOR" configure --interactive "$@"
            ;;
        --status|-s)
            python3 "$CONFIGURATOR" status
            ;;
        --discover|-d)
            python3 "$CONFIGURATOR" discover
            ;;
        --dry-run)
            shift
            echo -e "${YELLOW}DRY-RUN MODE - No changes will be made${NC}"
            python3 "$CONFIGURATOR" configure --auto --dry-run "$@"
            ;;
        --extract-keys)
            shift
            python3 "$CONFIGURATOR" extract-keys "$@"
            ;;
        --reset)
            python3 "$CONFIGURATOR" reset
            ;;
        --help|-h)
            show_help
            ;;
        "")
            # Default: interactive mode
            echo -e "${GREEN}Starting interactive setup wizard...${NC}"
            echo -e "${YELLOW}Tip: Use --auto for fully automatic setup${NC}"
            echo ""
            python3 "$CONFIGURATOR" configure --interactive
            ;;
        *)
            # Pass through to Python script
            python3 "$CONFIGURATOR" "$@"
            ;;
    esac
}

main "$@"
