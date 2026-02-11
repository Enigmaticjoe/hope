#!/bin/bash
# =============================================================================
# Fedora User Scripts — Installer for Fedora 43+
# =============================================================================
set -euo pipefail

APP_NAME="fedora-user-scripts"
INSTALL_DIR="$HOME/.local/share/$APP_NAME"
VENV_DIR="$INSTALL_DIR/venv"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "================================================"
echo "  Fedora User Scripts — Installer"
echo "================================================"
echo ""

# ---- 1. System dependencies ----
echo "[1/5] Checking system dependencies..."
if ! command -v python3 &>/dev/null; then
    echo "  Installing python3..."
    sudo dnf install -y python3 python3-pip
else
    echo "  python3 found: $(python3 --version)"
fi

# Ensure crond is available for cron scheduling
if ! command -v crond &>/dev/null && ! systemctl is-active --quiet crond 2>/dev/null; then
    echo "  Installing cronie for cron scheduling..."
    sudo dnf install -y cronie
    sudo systemctl enable --now crond
else
    echo "  crond available"
fi

# ---- 2. Create install directory & venv ----
echo "[2/5] Setting up virtual environment..."
mkdir -p "$INSTALL_DIR"
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# ---- 3. Install Python dependencies ----
echo "[3/5] Installing Python packages..."
pip install --upgrade pip -q
pip install -r "$SRC_DIR/requirements.txt" -q
echo "  Flask + python-crontab installed"

# ---- 4. Copy app files ----
echo "[4/5] Installing application files..."
cp "$SRC_DIR/app.py"          "$INSTALL_DIR/"
cp "$SRC_DIR/cron_manager.py" "$INSTALL_DIR/"
cp "$SRC_DIR/requirements.txt" "$INSTALL_DIR/"
cp -r "$SRC_DIR/templates"    "$INSTALL_DIR/"
cp -r "$SRC_DIR/static"       "$INSTALL_DIR/"

# ---- 5. Install systemd user service ----
echo "[5/5] Installing systemd user service..."
mkdir -p "$HOME/.config/systemd/user"

cat > "$HOME/.config/systemd/user/$APP_NAME.service" << EOF
[Unit]
Description=Fedora User Scripts
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$VENV_DIR/bin/python app.py
Restart=on-failure
RestartSec=5
Environment=FUS_SCRIPTS_DIR=$INSTALL_DIR/scripts
Environment=FUS_PORT=9855

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable "$APP_NAME.service"
systemctl --user start  "$APP_NAME.service"

echo ""
echo "================================================"
echo "  Installation complete!"
echo ""
echo "  Web UI:  http://localhost:9855"
echo "  Service: systemctl --user status $APP_NAME"
echo "  Logs:    journalctl --user -u $APP_NAME -f"
echo ""
echo "  Scripts stored in: $INSTALL_DIR/scripts/"
echo "================================================"
