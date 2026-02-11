#!/bin/bash
# =============================================================================
# Fedora User Scripts — Container Entrypoint
# =============================================================================
set -e

SCRIPTS_DIR="${FUS_SCRIPTS_DIR:-/data/scripts}"
SEED_DIR="/seed-scripts"

# Ensure scripts directory exists
mkdir -p "$SCRIPTS_DIR"

# Seed default scripts on first run (only if the target dir doesn't exist yet)
if [ -d "$SEED_DIR" ]; then
    for script_dir in "$SEED_DIR"/*/; do
        script_id=$(basename "$script_dir")
        if [ ! -d "$SCRIPTS_DIR/$script_id" ]; then
            echo "[entrypoint] Seeding script: $script_id"
            cp -r "$script_dir" "$SCRIPTS_DIR/$script_id"
            chmod +x "$SCRIPTS_DIR/$script_id/script" 2>/dev/null || true
        fi
    done
fi

# Start crond for scheduled scripts
echo "[entrypoint] Starting crond..."
crond

# Launch the Flask app
echo "[entrypoint] Starting Fedora User Scripts on port ${FUS_PORT:-9855}..."
exec python3 /app/app.py
