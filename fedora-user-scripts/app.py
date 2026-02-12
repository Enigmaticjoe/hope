#!/usr/bin/env python3
"""Fedora User Scripts — a web UI for managing and scheduling bash scripts."""

import json
import os
import queue
import re
import signal
import subprocess
import threading
import time
import uuid
from pathlib import Path

from flask import (
    Flask,
    Response,
    jsonify,
    render_template,
    request,
)

from cron_manager import CronManager

app = Flask(__name__)

# ---------------------------------------------------------------------------
# Detect deployment mode
# ---------------------------------------------------------------------------
IS_CONTAINER = os.path.exists("/.dockerenv") or os.environ.get("FUS_CONTAINER") == "1"
HOST_ROOT = os.environ.get("FUS_HOST_ROOT", "")  # e.g. "/host" in host-access mode

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPTS_DIR = Path(
    os.environ.get(
        "FUS_SCRIPTS_DIR",
        Path.home() / ".local" / "share" / "fedora-user-scripts" / "scripts",
    )
)
SCRIPTS_DIR.mkdir(parents=True, exist_ok=True)

# In-memory store of running processes: {run_id: {...}}
_running: dict[str, dict] = {}
_running_lock = threading.Lock()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _script_dir(script_id: str) -> Path:
    return SCRIPTS_DIR / script_id


def _read_meta(script_id: str) -> dict | None:
    meta_path = _script_dir(script_id) / "meta.json"
    if not meta_path.exists():
        return None
    return json.loads(meta_path.read_text())


def _write_meta(script_id: str, meta: dict) -> None:
    d = _script_dir(script_id)
    d.mkdir(parents=True, exist_ok=True)
    (d / "meta.json").write_text(json.dumps(meta, indent=2))


def _read_script(script_id: str) -> str:
    p = _script_dir(script_id) / "script"
    return p.read_text() if p.exists() else ""


def _write_script(script_id: str, content: str) -> None:
    d = _script_dir(script_id)
    d.mkdir(parents=True, exist_ok=True)
    p = d / "script"
    p.write_text(content)
    p.chmod(0o755)


def _list_scripts() -> list[dict]:
    scripts = []
    if not SCRIPTS_DIR.exists():
        return scripts
    for entry in sorted(SCRIPTS_DIR.iterdir()):
        if entry.is_dir():
            meta = _read_meta(entry.name)
            if meta:
                meta["id"] = entry.name
                scripts.append(meta)
    return scripts


def _get_cron_manager() -> CronManager | None:
    try:
        return CronManager()
    except Exception:
        return None



# ---------------------------------------------------------------------------
# Routes — Pages
# ---------------------------------------------------------------------------

@app.route("/")
def index():
    return render_template("index.html")


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


@app.route("/api/info")
def api_info():
    return jsonify({
        "version": "1.0.0",
        "container": IS_CONTAINER,
        "host_access": bool(HOST_ROOT),
        "scripts_dir": str(SCRIPTS_DIR),
    })


# ---------------------------------------------------------------------------
# Routes — API
# ---------------------------------------------------------------------------

@app.route("/api/scripts", methods=["GET"])
def api_list_scripts():
    cron = _get_cron_manager()
    scripts = _list_scripts()
    for s in scripts:
        s["schedule"] = cron.get_schedule(s["id"]) if cron else ""
    return jsonify(scripts)


@app.route("/api/scripts", methods=["POST"])
def api_create_script():
    data = request.get_json(force=True)
    name = data.get("name", "").strip()
    if not name:
        return jsonify({"error": "Name is required"}), 400

    script_id = str(uuid.uuid4())[:8]
    meta = {
        "name": name,
        "description": data.get("description", ""),
        "created": time.time(),
    }
    _write_meta(script_id, meta)
    _write_script(script_id, data.get("script", "#!/bin/bash\n\n"))
    meta["id"] = script_id
    return jsonify(meta), 201


@app.route("/api/scripts/<script_id>", methods=["GET"])
def api_get_script(script_id: str):
    meta = _read_meta(script_id)
    if not meta:
        return jsonify({"error": "Not found"}), 404
    meta["id"] = script_id
    meta["script"] = _read_script(script_id)
    cron = _get_cron_manager()
    meta["schedule"] = cron.get_schedule(script_id) if cron else ""
    return jsonify(meta)


@app.route("/api/scripts/<script_id>", methods=["PUT"])
def api_update_script(script_id: str):
    meta = _read_meta(script_id)
    if not meta:
        return jsonify({"error": "Not found"}), 404

    data = request.get_json(force=True)
    if "name" in data:
        meta["name"] = data["name"]
    if "description" in data:
        meta["description"] = data["description"]
    _write_meta(script_id, meta)

    if "script" in data:
        _write_script(script_id, data["script"])

    meta["id"] = script_id
    return jsonify(meta)


@app.route("/api/scripts/<script_id>", methods=["DELETE"])
def api_delete_script(script_id: str):
    d = _script_dir(script_id)
    if not d.exists():
        return jsonify({"error": "Not found"}), 404
    # Remove cron job if any
    cron = _get_cron_manager()
    if cron:
        cron.remove(script_id)
    # Remove files
    import shutil
    shutil.rmtree(d)
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# Routes — Scheduling
# ---------------------------------------------------------------------------

@app.route("/api/scripts/<script_id>/schedule", methods=["PUT"])
def api_set_schedule(script_id: str):
    meta = _read_meta(script_id)
    if not meta:
        return jsonify({"error": "Not found"}), 404

    data = request.get_json(force=True)
    schedule = data.get("schedule", "")  # cron expression or empty to disable
    schedule = schedule.strip()

    if schedule and not re.fullmatch(r"(@reboot|(@(yearly|annually|monthly|weekly|daily|hourly))|([^\s]+\s+){4}[^\s]+)", schedule):
        return jsonify({"error": "Invalid cron expression"}), 400

    cron = _get_cron_manager()
    if cron is None:
        return jsonify({"error": "Cron service unavailable on this host"}), 503

    if not schedule:
        cron.remove(script_id)
    else:
        script_path = str((_script_dir(script_id) / "script").resolve())
        try:
            cron.set_schedule(script_id, meta["name"], script_path, schedule)
        except ValueError:
            return jsonify({"error": "Invalid cron expression"}), 400

    return jsonify({"schedule": cron.get_schedule(script_id)})


# ---------------------------------------------------------------------------
# Routes — Execution (with SSE streaming)
# ---------------------------------------------------------------------------

@app.route("/api/scripts/<script_id>/run", methods=["POST"])
def api_run_script(script_id: str):
    meta = _read_meta(script_id)
    if not meta:
        return jsonify({"error": "Not found"}), 404

    script_path = str((_script_dir(script_id) / "script").resolve())
    run_id = str(uuid.uuid4())[:12]

    data = request.get_json(silent=True) or {}
    input_text = data.get("input", "")
    run_as_sudo = bool(data.get("run_as_sudo", False))

    if not isinstance(input_text, str):
        return jsonify({"error": "Input must be a string"}), 400

    q: queue.Queue[str | None] = queue.Queue()

    def _run():
        try:
            command = ["/bin/bash", script_path]
            if run_as_sudo:
                command = ["sudo", "-n", "/bin/bash", script_path]
                q.put("[sudo mode enabled: requires passwordless sudo for this command]\n")

            proc = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                stdin=subprocess.PIPE,
                text=True,
                bufsize=1,
                preexec_fn=os.setsid,
            )
            with _running_lock:
                _running[run_id]["pid"] = proc.pid

            if input_text and proc.stdin:
                proc.stdin.write(input_text)
                if not input_text.endswith("\n"):
                    proc.stdin.write("\n")
                proc.stdin.flush()
            if proc.stdin:
                proc.stdin.close()

            for line in proc.stdout:  # type: ignore[union-attr]
                q.put(line)
            proc.wait()
            q.put(f"\n[Process exited with code {proc.returncode}]\n")
        except Exception as exc:
            q.put(f"\n[Error: {exc}]\n")
        finally:
            q.put(None)  # sentinel
            with _running_lock:
                if run_id in _running:
                    _running[run_id]["done"] = True

    with _running_lock:
        _running[run_id] = {
            "script_id": script_id,
            "queue": q,
            "pid": None,
            "done": False,
        }

    t = threading.Thread(target=_run, daemon=True)
    t.start()

    return jsonify({"run_id": run_id})


@app.route("/api/runs/<run_id>/stream")
def api_stream(run_id: str):
    with _running_lock:
        entry = _running.get(run_id)
    if not entry:
        return jsonify({"error": "Run not found"}), 404

    q = entry["queue"]

    def generate():
        while True:
            try:
                line = q.get(timeout=30)
            except queue.Empty:
                yield "data: \n\n"  # keep-alive
                continue
            if line is None:
                yield "event: done\ndata: finished\n\n"
                break
            yield f"data: {json.dumps(line)}\n\n"

    return Response(generate(), mimetype="text/event-stream")


@app.route("/api/runs/<run_id>/stop", methods=["POST"])
def api_stop_run(run_id: str):
    with _running_lock:
        entry = _running.get(run_id)
    if not entry:
        return jsonify({"error": "Run not found"}), 404
    pid = entry.get("pid")
    if pid:
        try:
            os.killpg(os.getpgid(pid), signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            try:
                os.kill(pid, signal.SIGTERM)
            except (ProcessLookupError, PermissionError):
                pass
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    port = int(os.environ.get("FUS_PORT", 9855))
    app.run(host="0.0.0.0", port=port, debug=False)
