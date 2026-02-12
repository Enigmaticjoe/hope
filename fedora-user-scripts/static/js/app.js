/* ============================================================
   Fedora User Scripts — Frontend
   ============================================================ */

(() => {
  "use strict";

  // ---- State ----
  let scripts = [];
  let activeId = null;
  let editor = null;      // CodeMirror instance
  let currentRunId = null;
  let eventSource = null;

  // ---- DOM refs ----
  const $list          = document.getElementById("script-list");
  const $empty         = document.getElementById("empty-state");
  const $editorPanel   = document.getElementById("editor-panel");
  const $name          = document.getElementById("script-name");
  const $desc          = document.getElementById("script-desc");
  const $scheduleSelect  = document.getElementById("schedule-select");
  const $scheduleCustom  = document.getElementById("schedule-custom");
  const $scheduleStatus  = document.getElementById("schedule-status");
  const $outputSection = document.getElementById("output-section");
  const $outputConsole = document.getElementById("output-console");
  const $btnStop       = document.getElementById("btn-stop");
  const $runInput      = document.getElementById("run-input");
  const $runSudo       = document.getElementById("run-sudo");

  // ---- Init CodeMirror ----
  function initEditor() {
    editor = CodeMirror.fromTextArea(document.getElementById("code-editor"), {
      mode: "shell",
      theme: "dracula",
      lineNumbers: true,
      tabSize: 2,
      indentWithTabs: false,
      lineWrapping: true,
    });
  }

  // ---- API helpers ----
  async function api(url, opts = {}) {
    const res = await fetch(url, {
      headers: { "Content-Type": "application/json" },
      ...opts,
    });
    return res.json();
  }

  // ---- Render script list ----
  function renderList() {
    $list.innerHTML = "";
    if (scripts.length === 0) {
      $empty.classList.remove("hidden");
      return;
    }
    $empty.classList.add("hidden");

    for (const s of scripts) {
      const li = document.createElement("li");
      li.dataset.id = s.id;
      if (s.id === activeId) li.classList.add("active");

      let html = `<div class="script-item-name">${esc(s.name)}</div>`;
      if (s.description) {
        html += `<div class="script-item-desc">${esc(s.description)}</div>`;
      }
      if (s.schedule) {
        html += `<div class="script-item-schedule">⏱ ${esc(s.schedule)}</div>`;
      }
      li.innerHTML = html;
      li.addEventListener("click", () => loadScript(s.id));
      $list.appendChild(li);
    }
  }

  function esc(str) {
    const d = document.createElement("div");
    d.textContent = str;
    return d.innerHTML;
  }

  // ---- Load a script into the editor ----
  async function loadScript(id) {
    activeId = id;
    renderList();

    const data = await api(`/api/scripts/${id}`);
    $editorPanel.classList.remove("hidden");
    $name.value = data.name || "";
    $desc.value = data.description || "";
    editor.setValue(data.script || "#!/bin/bash\n\n");
    editor.refresh();

    // Schedule
    const sched = data.schedule || "";
    setScheduleUI(sched);
    $scheduleStatus.textContent = sched ? `Active: ${sched}` : "";

    // Reset output
    $outputSection.classList.add("hidden");
    $outputConsole.textContent = "";
    closeStream();
  }

  function setScheduleUI(cron) {
    // Check if it matches a preset
    const options = $scheduleSelect.querySelectorAll("option");
    let found = false;
    for (const opt of options) {
      if (opt.value === cron) { $scheduleSelect.value = cron; found = true; break; }
    }
    if (!found && cron) {
      $scheduleSelect.value = "custom";
      $scheduleCustom.classList.remove("hidden");
      $scheduleCustom.value = cron;
    } else {
      $scheduleCustom.classList.add("hidden");
    }
    if (!cron) $scheduleSelect.value = "";
  }

  // ---- Create new script ----
  async function createScript() {
    const data = await api("/api/scripts", {
      method: "POST",
      body: JSON.stringify({ name: "New Script", description: "", script: "#!/bin/bash\n\n" }),
    });
    await refreshList();
    loadScript(data.id);
  }

  // ---- Save script ----
  async function saveScript() {
    if (!activeId) return;
    await api(`/api/scripts/${activeId}`, {
      method: "PUT",
      body: JSON.stringify({
        name: $name.value,
        description: $desc.value,
        script: editor.getValue(),
      }),
    });
    await refreshList();
  }

  // ---- Delete script ----
  async function deleteScript() {
    if (!activeId) return;
    if (!confirm("Delete this script permanently?")) return;
    await api(`/api/scripts/${activeId}`, { method: "DELETE" });
    activeId = null;
    $editorPanel.classList.add("hidden");
    await refreshList();
  }

  // ---- Schedule ----
  async function applySchedule() {
    if (!activeId) return;
    let cron = $scheduleSelect.value;
    if (cron === "custom") cron = $scheduleCustom.value.trim();

    const res = await api(`/api/scripts/${activeId}/schedule`, {
      method: "PUT",
      body: JSON.stringify({ schedule: cron }),
    });
    $scheduleStatus.textContent = res.schedule ? `Active: ${res.schedule}` : "Schedule removed";
    await refreshList();
  }

  // ---- Run script ----
  async function runScript() {
    if (!activeId) return;
    // Auto-save before running
    await saveScript();

    $outputSection.classList.remove("hidden");
    $outputConsole.textContent = "";
    $btnStop.classList.remove("hidden");

    const res = await api(`/api/scripts/${activeId}/run`, {
      method: "POST",
      body: JSON.stringify({
        input: $runInput.value,
        run_as_sudo: $runSudo.checked,
      }),
    });
    currentRunId = res.run_id;
    openStream(res.run_id);
  }

  function openStream(runId) {
    closeStream();
    eventSource = new EventSource(`/api/runs/${runId}/stream`);
    eventSource.onmessage = (e) => {
      try {
        const line = JSON.parse(e.data);
        $outputConsole.textContent += line;
        $outputConsole.scrollTop = $outputConsole.scrollHeight;
      } catch {
        // keep-alive or non-JSON
      }
    };
    eventSource.addEventListener("done", () => {
      closeStream();
      $btnStop.classList.add("hidden");
    });
    eventSource.onerror = () => {
      closeStream();
      $btnStop.classList.add("hidden");
    };
  }

  function closeStream() {
    if (eventSource) { eventSource.close(); eventSource = null; }
  }

  async function stopRun() {
    if (!currentRunId) return;
    await api(`/api/runs/${currentRunId}/stop`, { method: "POST" });
  }

  // ---- Refresh ----
  async function refreshList() {
    scripts = await api("/api/scripts");
    renderList();
  }

  // ---- Schedule select toggle ----
  $scheduleSelect.addEventListener("change", () => {
    if ($scheduleSelect.value === "custom") {
      $scheduleCustom.classList.remove("hidden");
      $scheduleCustom.focus();
    } else {
      $scheduleCustom.classList.add("hidden");
    }
  });

  // ---- Wire up buttons ----
  document.getElementById("btn-new").addEventListener("click", createScript);
  document.getElementById("btn-save").addEventListener("click", saveScript);
  document.getElementById("btn-run").addEventListener("click", runScript);
  document.getElementById("btn-delete").addEventListener("click", deleteScript);
  document.getElementById("btn-schedule").addEventListener("click", applySchedule);
  document.getElementById("btn-stop").addEventListener("click", stopRun);
  document.getElementById("btn-clear-output").addEventListener("click", () => {
    $outputConsole.textContent = "";
  });

  // ---- Keyboard shortcut: Ctrl+S to save ----
  document.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === "s") {
      e.preventDefault();
      saveScript();
    }
  });

  // ---- Deployment info badge ----
  async function loadInfo() {
    try {
      const info = await api("/api/info");
      const $badge = document.getElementById("deploy-badge");
      if (info.container && info.host_access) {
        $badge.textContent = "Docker (Host Access)";
        $badge.className = "badge badge-host";
      } else if (info.container) {
        $badge.textContent = "Docker";
        $badge.className = "badge badge-container";
      } else {
        $badge.textContent = "Native";
        $badge.className = "badge badge-native";
      }
    } catch { /* ignore */ }
  }

  // ---- Boot ----
  initEditor();
  refreshList();
  loadInfo();
})();
