#!/bin/bash
# =============================================================================
# Fedora User Scripts — Uninstaller
# =============================================================================
set -euo pipefail

APP_NAME="fedora-user-scripts"
INSTALL_DIR="$HOME/.local/share/$APP_NAME"

echo "Fedora User Scripts — Uninstaller"
echo ""

# Stop and disable service
echo "Stopping service..."
systemctl --user stop "$APP_NAME.service" 2>/dev/null || true
systemctl --user disable "$APP_NAME.service" 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/$APP_NAME.service"
systemctl --user daemon-reload

# Remove cron jobs created by the app
echo "Cleaning up cron jobs..."
crontab -l 2>/dev/null | grep -v "^#.*fus:" | grep -v "fus:" > /tmp/crontab_clean 2>/dev/null || true
crontab /tmp/crontab_clean 2>/dev/null || true
rm -f /tmp/crontab_clean

read -rp "Remove all scripts and data in $INSTALL_DIR? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    rm -rf "$INSTALL_DIR"
    echo "Data removed."
else
    echo "Data preserved at $INSTALL_DIR"
    # Still remove app files but keep scripts
    rm -f "$INSTALL_DIR/app.py" "$INSTALL_DIR/cron_manager.py" "$INSTALL_DIR/requirements.txt"
    rm -rf "$INSTALL_DIR/venv" "$INSTALL_DIR/templates" "$INSTALL_DIR/static"
    echo "App files removed, scripts preserved."
fi

echo ""
echo "Uninstallation complete."
