# Fedora User Scripts

A web-based script manager for Fedora desktops — inspired by [Unraid's CA User Scripts](https://forums.unraid.net/topic/48286-plugin-ca-user-scripts/) plugin.

Create, edit, schedule, and run bash scripts from a clean web UI without touching the terminal.

## Features

- **Script Management** — Create, edit, rename, and delete bash scripts from the browser
- **Code Editor** — Syntax-highlighted bash editor (CodeMirror with Dracula theme)
- **One-Click Execution** — Run scripts and see real-time streaming output
- **Cron Scheduling** — Schedule scripts with preset intervals or custom cron expressions
- **Stop Running Scripts** — Kill long-running scripts from the UI
- **Keyboard Shortcuts** — Ctrl+S to save
- **Systemd Integration** — Runs as a user service, starts on login
- **Fedora Native** — Uses cronie + systemd user services, no Docker required

## Quick Start

```bash
git clone <repo> && cd fedora-user-scripts
./install.sh
```

Then open **http://localhost:9855** in your browser.

## Requirements

- Fedora 43+ (or any systemd-based Linux with Python 3.10+)
- Python 3.10+
- cronie (installed automatically by the installer)

## Schedule Options

| Preset               | Cron Expression   |
|----------------------|-------------------|
| Every 5 minutes      | `*/5 * * * *`     |
| Every 15 minutes     | `*/15 * * * *`    |
| Every 30 minutes     | `*/30 * * * *`    |
| Hourly               | `0 * * * *`       |
| Every 6 hours        | `0 */6 * * *`     |
| Every 12 hours       | `0 */12 * * *`    |
| Daily at midnight    | `0 0 * * *`       |
| Weekly (Sun midnight) | `0 0 * * 0`      |
| Monthly (1st)        | `0 0 1 * *`       |
| At startup / reboot  | `@reboot`         |
| Custom               | Any valid cron    |

## Service Management

```bash
# Check status
systemctl --user status fedora-user-scripts

# View logs
journalctl --user -u fedora-user-scripts -f

# Restart
systemctl --user restart fedora-user-scripts

# Stop
systemctl --user stop fedora-user-scripts
```

## Configuration

Environment variables (set in the systemd service file):

| Variable          | Default                                              | Description          |
|-------------------|------------------------------------------------------|----------------------|
| `FUS_PORT`        | `9855`                                               | Web UI port          |
| `FUS_SCRIPTS_DIR` | `~/.local/share/fedora-user-scripts/scripts`         | Script storage path  |

## File Structure

```
~/.local/share/fedora-user-scripts/
├── app.py              # Flask application
├── cron_manager.py     # Cron scheduling
├── venv/               # Python virtual environment
├── templates/          # HTML templates
├── static/             # CSS + JS
└── scripts/            # Your scripts (each in its own directory)
    ├── a1b2c3d4/
    │   ├── meta.json   # Name, description, timestamps
    │   └── script      # The bash script
    └── ...
```

## Uninstall

```bash
./uninstall.sh
```

## How It Compares to Unraid User Scripts

| Feature                  | Unraid CA User Scripts | Fedora User Scripts |
|--------------------------|------------------------|---------------------|
| Web UI                   | Yes                    | Yes                 |
| Create/Edit scripts      | Yes                    | Yes                 |
| Syntax highlighting      | No                     | Yes (CodeMirror)    |
| Run manually             | Yes                    | Yes                 |
| Real-time output         | Yes                    | Yes (SSE streaming) |
| Cron scheduling          | Yes                    | Yes                 |
| Custom cron expressions  | Yes                    | Yes                 |
| Stop running scripts     | No                     | Yes                 |
| Runs as service          | Plugin                 | systemd user service|
| Platform                 | Unraid only            | Any Linux (Fedora)  |
