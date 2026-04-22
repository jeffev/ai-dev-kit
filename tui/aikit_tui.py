#!/usr/bin/env python3
"""AI Dev Kit — TUI
Requires: pip install textual
Launch:   ai-kit tui  (from any project directory)
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from textual import on, work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, ScrollableContainer, Vertical
from textual.reactive import reactive
from textual.screen import ModalScreen
from textual.widgets import Button, Footer, Header, Input, Label, ListItem, ListView, Static


# ── Project helpers ───────────────────────────────────────────────────────────

def find_project_root() -> Path:
    p = Path.cwd()
    for parent in [p, *p.parents]:
        if (parent / ".aikit-specs").exists() or (parent / ".claude").exists():
            return parent
    return p


def list_specs(root: Path) -> list[dict]:
    active_id = ""
    pointer = root / ".aikit-specs" / ".active-spec"
    if pointer.exists():
        active_id = pointer.read_text().strip()

    specs: list[dict] = []
    for folder, status in [("active", "active"), ("draft", "draft"), ("done", "done")]:
        d = root / ".aikit-specs" / folder
        if not d.exists():
            continue
        for f in sorted(d.glob("*.md")):
            specs.append(_parse_spec(f, status, active_id))

    order = {"active": 0, "draft": 1, "done": 2}
    specs.sort(key=lambda s: (order.get(s["status"], 9), s["id"]))
    return specs


def _parse_spec(path: Path, status: str, active_id: str) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()

    m = re.match(r"(SPEC-\d+)", path.stem)
    spec_id = m.group(1) if m else path.stem

    what = ""
    in_what = False
    for line in lines:
        if re.match(r"^## What", line):
            in_what = True
            continue
        if in_what:
            if re.match(r"^## ", line):
                break
            if line.strip():
                what = line.strip()
                break

    checklist = []
    for i, line in enumerate(lines):
        m2 = re.match(r"^- \[([ x])\] (.+)", line)
        if m2:
            checklist.append({"done": m2.group(1) == "x", "text": m2.group(2), "line_index": i})

    # Parse expected files
    expected_files: list[str] = []
    in_files = False
    for line in lines:
        if re.match(r"^## Files expected to change", line):
            in_files = True
            continue
        if in_files:
            if re.match(r"^## ", line):
                break
            m3 = re.match(r"^- (.+)", line)
            if m3:
                f = re.sub(r"\s*\(.*\)$", "", m3.group(1)).strip()
                expected_files.append(f)

    return {
        "id": spec_id,
        "path": path,
        "status": status,
        "is_active": spec_id == active_id and status == "active",
        "what": what,
        "checklist": checklist,
        "expected_files": expected_files,
        "text": text,
        "total": len(checklist),
        "done": sum(1 for c in checklist if c["done"]),
    }


def get_git_status(root: Path) -> str:
    try:
        branch = subprocess.check_output(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=str(root), stderr=subprocess.DEVNULL, text=True
        ).strip()
        porcelain = subprocess.check_output(
            ["git", "status", "--porcelain"],
            cwd=str(root), stderr=subprocess.DEVNULL, text=True
        ).strip()
        modified = len(porcelain.splitlines()) if porcelain else 0
        try:
            ahead = subprocess.check_output(
                ["git", "rev-list", "--count", "@{u}..HEAD"],
                cwd=str(root), stderr=subprocess.DEVNULL, text=True
            ).strip()
        except Exception:
            ahead = "0"

        lines = [f"Branch:   {branch}", f"Modified: {modified} file(s)"]
        lines.append(f"Unpushed: {ahead} commit(s)" if int(ahead or 0) > 0 else "In sync with remote")
        if porcelain:
            for line in porcelain.splitlines()[:8]:
                lines.append(f"  {line}")
            if modified > 8:
                lines.append(f"  … +{modified - 8} more")
        return "\n".join(lines)
    except Exception as e:
        return f"git not available\n({e})"


def get_audit_summary(root: Path) -> str:
    log = root / ".claude" / "hooks" / "logs" / "audit.log"
    if not log.exists():
        return "No audit log found."
    lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
    today = datetime.now().strftime("%Y-%m-%d")
    today_lines = [l for l in lines if today in l]
    if not today_lines:
        return "No findings today."
    return "\n".join(today_lines[-15:])


def get_activity_data(root: Path, spec: dict) -> str:
    """Build the Activity tab content for a spec."""
    lines: list[str] = []

    # ── Start commit ──────────────────────────────────────────────────────────
    start_hash = ""
    start_commit_file = root / ".aikit-specs" / ".spec-start-commit"
    if start_commit_file.exists():
        start_hash = start_commit_file.read_text().strip()

    try:
        subprocess.check_output(
            ["git", "rev-parse", "--git-dir"],
            cwd=str(root), stderr=subprocess.DEVNULL
        )
        has_git = True
    except Exception:
        has_git = False

    # ── Commits since start ───────────────────────────────────────────────────
    lines.append("── Commits since spec start ──────────────────")
    if not has_git:
        lines.append("  (not a git repo)")
    elif not start_hash:
        lines.append("  (no start commit recorded — run 'spec start' first)")
    else:
        try:
            log_out = subprocess.check_output(
                ["git", "log", "--oneline", f"{start_hash}..HEAD"],
                cwd=str(root), stderr=subprocess.DEVNULL, text=True
            ).strip()
            if log_out:
                for entry in log_out.splitlines():
                    lines.append(f"  {entry}")
            else:
                lines.append("  (no commits yet since spec start)")
        except Exception:
            lines.append("  (could not read git log)")

    lines.append("")

    # ── Changed files vs scope ────────────────────────────────────────────────
    lines.append("── Files changed vs scope ────────────────────")
    if has_git and start_hash:
        try:
            diff_files = subprocess.check_output(
                ["git", "diff", "--name-only", f"{start_hash}..HEAD"],
                cwd=str(root), stderr=subprocess.DEVNULL, text=True
            ).strip()
            changed = diff_files.splitlines() if diff_files else []
        except Exception:
            changed = []

        expected = spec.get("expected_files", [])

        if not changed:
            lines.append("  (no file changes yet)")
        else:
            for f in changed:
                in_scope = any(
                    f == e or f.endswith(e) or e.endswith(f) or
                    Path(f).name == Path(e).name
                    for e in expected
                )
                icon = "✔" if in_scope else "✗"
                tag = "" if in_scope else "  ← out of scope"
                lines.append(f"  {icon}  {f}{tag}")

        # Expected files not yet touched
        untouched = [
            e for e in expected
            if not any(
                c == e or c.endswith(e) or e.endswith(c) or
                Path(c).name == Path(e).name
                for c in changed
            )
        ]
        if untouched:
            lines.append("")
            lines.append("  Not yet touched:")
            for f in untouched:
                lines.append(f"  ○  {f}")
    else:
        lines.append("  (no start commit — cannot compute diff)")

    lines.append("")

    # ── Audit log since start ─────────────────────────────────────────────────
    lines.append("── Audit findings (all time) ─────────────────")
    log_path = root / ".claude" / "hooks" / "logs" / "audit.log"
    if not log_path.exists():
        lines.append("  (no audit log found)")
    else:
        all_lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
        spec_id = spec["id"]
        # Show findings not just today but all time for this spec area
        relevant = [l for l in all_lines if "SPEC-SCOPE" in l or spec_id in l]
        if not relevant:
            # Fall back to last 10 entries
            relevant = all_lines[-10:]
        if relevant:
            for entry in relevant[-20:]:
                lines.append(f"  {entry}")
        else:
            lines.append("  (no findings)")

    return "\n".join(lines)


def _strip_ansi(text: str) -> str:
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def _find_bash() -> str:
    if sys.platform == "win32":
        for candidate in [
            r"C:\Program Files\Git\bin\bash.exe",
            r"C:\Program Files (x86)\Git\bin\bash.exe",
            r"C:\Program Files\Git\usr\bin\bash.exe",
        ]:
            if Path(candidate).exists():
                return candidate
    found = shutil.which("bash")
    return found if found else "bash"


def run_aikit(root: Path, *args: str) -> tuple[int, str, str]:
    bash = _find_bash()
    aikit_script = os.environ.get("AIKIT_SCRIPT", "")
    if aikit_script and Path(aikit_script).exists():
        cmd = [bash, aikit_script, *args]
    else:
        local = root / "ai-kit.sh"
        cmd = [bash, str(local), *args] if local.exists() else ["ai-kit", *args]
    try:
        r = subprocess.run(cmd, cwd=str(root), capture_output=True, text=True, encoding="utf-8", errors="replace")
        return r.returncode, r.stdout or "", r.stderr or ""
    except Exception as e:
        return 1, "", str(e)


# ── List items ────────────────────────────────────────────────────────────────

class SpecItem(ListItem):
    def __init__(self, spec: dict) -> None:
        super().__init__()
        self.spec = spec

    def compose(self) -> ComposeResult:
        s = self.spec
        if s["is_active"]:
            icon = "●"
        elif s["status"] == "active":
            icon = "○"
        elif s["status"] == "done":
            icon = "✓"
        else:
            icon = "·"
        badge = f" [{s['done']}/{s['total']}]" if s["total"] > 0 else ""
        yield Label(f" {icon} {s['id']}{badge}")


class ChecklistItem(ListItem):
    def __init__(self, item: dict, index: int) -> None:
        super().__init__()
        self.item_data = item
        self.task_index = index

    def compose(self) -> ComposeResult:
        box = "✔" if self.item_data["done"] else "○"
        cls = "done" if self.item_data["done"] else "todo"
        yield Label(f" {box}  {self.item_data['text']}", classes=cls)


# ── Modals ────────────────────────────────────────────────────────────────────

class InputModal(ModalScreen):
    BINDINGS = [("escape", "dismiss", "Cancel")]

    def __init__(self, title: str, placeholder: str = "") -> None:
        super().__init__()
        self._title = title
        self._placeholder = placeholder

    def compose(self) -> ComposeResult:
        with Vertical(id="modal-box"):
            yield Label(self._title, id="modal-title")
            yield Input(placeholder=self._placeholder, id="modal-input")
            with Horizontal(id="modal-btns"):
                yield Button("OK", variant="primary", id="ok")
                yield Button("Cancel", id="cancel-btn")

    @on(Button.Pressed, "#ok")
    def ok(self) -> None:
        v = self.query_one("#modal-input", Input).value.strip()
        self.dismiss(v or None)

    @on(Button.Pressed, "#cancel-btn")
    def cancel(self) -> None:
        self.dismiss(None)

    @on(Input.Submitted)
    def submitted(self) -> None:
        v = self.query_one("#modal-input", Input).value.strip()
        self.dismiss(v or None)


class ResultModal(ModalScreen):
    BINDINGS = [
        ("escape", "dismiss", "Close"),
        ("q", "dismiss", "Close"),
        ("enter", "dismiss", "Close"),
    ]

    def __init__(self, title: str, output: str) -> None:
        super().__init__()
        self._title = title
        self._output = output

    def compose(self) -> ComposeResult:
        with Vertical(id="result-box"):
            yield Label(self._title, id="result-title")
            with ScrollableContainer(id="result-scroll"):
                yield Static(self._output, id="result-content")
            yield Button("Close  [Enter]", variant="primary", id="close-btn")

    @on(Button.Pressed, "#close-btn")
    def close(self) -> None:
        self.dismiss()


# ── Main App ──────────────────────────────────────────────────────────────────

TABS = ["checklist", "activity", "spec"]
TAB_LABELS = {"checklist": "Checklist", "activity": "Activity", "spec": "Spec"}

class AikitTUI(App):
    TITLE = "AI Dev Kit"
    SUB_TITLE = "Spec-driven workflow"

    CSS = """
    Screen { background: $background; }

    /* ── Layout ── */
    #layout { layout: horizontal; height: 1fr; }

    #left-panel {
        width: 24;
        border-right: solid $primary-darken-3;
        background: $surface;
    }
    #left-header {
        background: $primary-darken-2;
        color: $text-muted;
        padding: 0 1;
        height: 1;
        text-style: bold;
    }
    #spec-list { height: 1fr; }
    #new-spec-btn { dock: bottom; width: 100%; height: 3; }

    #center-panel { width: 1fr; border-right: solid $primary-darken-3; }
    #spec-id-label {
        background: $primary-darken-2;
        padding: 0 1;
        height: 1;
        text-style: bold;
    }
    #spec-what {
        padding: 0 2;
        color: $text-muted;
        height: 1;
    }
    #spec-progress {
        padding: 0 2;
        color: $warning;
        height: 1;
    }

    /* ── Tab bar ── */
    #center-tabs {
        height: 3;
        layout: horizontal;
        border-bottom: solid $primary-darken-3;
        padding: 0 1;
        align: left middle;
        background: $surface;
    }
    .ctab {
        background: $surface;
        border: solid $primary-darken-3;
        color: $text-muted;
        padding: 0 2;
        height: 1;
        margin-right: 1;
        min-width: 14;
    }
    .ctab:hover { color: $text; }
    .ctab-active {
        background: $primary-darken-2;
        border: solid $accent;
        color: $accent;
        padding: 0 2;
        height: 1;
        margin-right: 1;
        min-width: 14;
    }

    /* ── Tab panels ── */
    #tab-checklist { height: 1fr; }
    #tab-activity  { height: 1fr; display: none; }
    #tab-spec      { height: 1fr; display: none; padding: 1; }

    #checklist { height: 1fr; margin: 0 1; }

    #activity-content { height: auto; padding: 1; }
    #spec-content     { height: auto; }

    /* ── Action bar ── */
    #action-bar {
        height: 3;
        layout: horizontal;
        border-top: solid $primary-darken-3;
        padding: 0 1;
        align: left middle;
    }
    #action-bar Button { margin-right: 1; min-width: 11; }
    #busy-label { color: $warning; margin-left: 1; }

    /* ── Right panel ── */
    #right-panel { width: 30; background: $surface; }
    #right-header {
        background: $primary-darken-2;
        color: $text-muted;
        padding: 0 1;
        height: 1;
        text-style: bold;
    }
    #git-container {
        height: 14;
        border-bottom: solid $primary-darken-3;
        padding: 1;
        overflow-y: auto;
    }
    #audit-container { height: 1fr; padding: 1; overflow-y: auto; }
    .section-label { color: $accent; text-style: bold; margin-bottom: 1; }

    /* ── Checklist item colors ── */
    .done { color: $success; }
    .todo { color: $accent; }

    /* ── Modals ── */
    InputModal { align: center middle; }
    #modal-box {
        background: $surface;
        border: thick $primary;
        padding: 1 2;
        width: 64;
        height: auto;
    }
    #modal-title { text-align: center; margin-bottom: 1; text-style: bold; }
    #modal-btns { height: auto; margin-top: 1; align: center middle; }
    #modal-btns Button { margin: 0 1; }

    ResultModal { align: center middle; }
    #result-box {
        background: $surface;
        border: thick $primary;
        padding: 1 2;
        width: 84;
        height: 28;
        layout: vertical;
    }
    #result-title { height: 1; text-align: center; text-style: bold; color: $accent; margin-bottom: 1; }
    #result-scroll { height: 1fr; border: solid $primary-darken-3; padding: 0 1; overflow-y: auto; }
    #result-content { height: auto; }
    #close-btn { height: 3; width: 100%; margin-top: 1; }
    """

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("n", "new_spec", "New"),
        Binding("r", "refresh_all", "Refresh"),
        Binding("a", "approve", "Approve"),
        Binding("s", "start", "Start"),
        Binding("1", "tab_checklist", "Checklist"),
        Binding("2", "tab_activity", "Activity"),
        Binding("3", "tab_spec", "Spec"),
    ]

    selected_spec: reactive[dict | None] = reactive(None)
    active_tab: reactive[str] = reactive("checklist")

    def __init__(self) -> None:
        super().__init__()
        self.root = find_project_root()
        self.specs: list[dict] = []

    # ── Compose ───────────────────────────────────────────────────────────────

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal(id="layout"):
            # Left — spec list
            with Vertical(id="left-panel"):
                yield Label(" SPECS", id="left-header")
                yield ListView(id="spec-list")
                yield Button("＋ New Spec", id="new-spec-btn", variant="primary")

            # Center — spec detail + tabs
            with Vertical(id="center-panel"):
                yield Label(" Select a spec", id="spec-id-label")
                yield Label("", id="spec-what")
                yield Label("", id="spec-progress")

                # Tab bar
                with Horizontal(id="center-tabs"):
                    yield Button("Checklist  [1]", id="ctab-checklist", classes="ctab-active")
                    yield Button("Activity   [2]", id="ctab-activity",  classes="ctab")
                    yield Button("Spec       [3]", id="ctab-spec",      classes="ctab")

                # Tab panels
                with Vertical(id="tab-checklist"):
                    yield ListView(id="checklist")

                with ScrollableContainer(id="tab-activity"):
                    yield Static("Select a spec to see activity.", id="activity-content")

                with ScrollableContainer(id="tab-spec"):
                    yield Static("Select a spec to read it.", id="spec-content")

                # Action bar
                with Horizontal(id="action-bar"):
                    yield Button("Approve", id="btn-approve")
                    yield Button("Start",   id="btn-start",  variant="success")
                    yield Button("Review",  id="btn-review", variant="warning")
                    yield Button("Close",   id="btn-close",  variant="error")
                    yield Label("", id="busy-label")

            # Right — git + audit
            with Vertical(id="right-panel"):
                yield Label(" STATUS", id="right-header")
                with ScrollableContainer(id="git-container"):
                    yield Label("Git", classes="section-label")
                    yield Static("…", id="git-content")
                with ScrollableContainer(id="audit-container"):
                    yield Label("Audit Log — today", classes="section-label")
                    yield Static("…", id="audit-content")

        yield Footer()

    def on_mount(self) -> None:
        self.load_specs()
        self.load_status()

    # ── Data loading ──────────────────────────────────────────────────────────

    def load_specs(self) -> None:
        self.specs = list_specs(self.root)
        lv = self.query_one("#spec-list", ListView)
        lv.clear()
        for spec in self.specs:
            lv.append(SpecItem(spec))

    def load_status(self) -> None:
        self.query_one("#git-content", Static).update(get_git_status(self.root))
        self.query_one("#audit-content", Static).update(get_audit_summary(self.root))

    # ── Tab switching ─────────────────────────────────────────────────────────

    def _switch_tab(self, tab: str) -> None:
        self.active_tab = tab
        for t in TABS:
            panel = self.query_one(f"#tab-{t}")
            panel.display = (t == tab)
            btn = self.query_one(f"#ctab-{t}", Button)
            btn.remove_class("ctab-active")
            btn.add_class("ctab-active" if t == tab else "ctab")
            if t != tab:
                btn.remove_class("ctab-active")
                btn.add_class("ctab")
            else:
                btn.remove_class("ctab")
                btn.add_class("ctab-active")

        # Populate on switch
        if self.selected_spec:
            if tab == "activity":
                self._load_activity(self.selected_spec)
            elif tab == "spec":
                self.query_one("#spec-content", Static).update(self.selected_spec["text"])

    @on(Button.Pressed, "#ctab-checklist")
    def tab_checklist(self) -> None: self._switch_tab("checklist")

    @on(Button.Pressed, "#ctab-activity")
    def tab_activity(self) -> None: self._switch_tab("activity")

    @on(Button.Pressed, "#ctab-spec")
    def tab_spec_btn(self) -> None: self._switch_tab("spec")

    def action_tab_checklist(self) -> None: self._switch_tab("checklist")
    def action_tab_activity(self)  -> None: self._switch_tab("activity")
    def action_tab_spec(self)      -> None: self._switch_tab("spec")

    def _load_activity(self, spec: dict) -> None:
        self.query_one("#activity-content", Static).update("⟳ Loading…")
        self._fetch_activity(spec)

    @work(thread=True)
    def _fetch_activity(self, spec: dict) -> None:
        data = get_activity_data(self.root, spec)
        self.call_from_thread(self.query_one("#activity-content", Static).update, data)

    # ── Spec selection ────────────────────────────────────────────────────────

    @on(ListView.Selected, "#spec-list")
    def spec_selected(self, event: ListView.Selected) -> None:
        if isinstance(event.item, SpecItem):
            self.selected_spec = event.item.spec
            self._render_detail(event.item.spec)
            # Reset to checklist tab on new selection
            self._switch_tab("checklist")

    def _render_detail(self, spec: dict) -> None:
        status_tag = "● ACTIVE" if spec["is_active"] else spec["status"].upper()
        self.query_one("#spec-id-label", Label).update(f" {spec['id']}  {status_tag}")
        self.query_one("#spec-what", Label).update(f"  {spec['what']}" if spec["what"] else "")

        done, total = spec["done"], spec["total"]
        if total > 0:
            pct = int((done / total) * 100)
            filled = pct // 10
            bar = "█" * filled + "░" * (10 - filled)
            self.query_one("#spec-progress", Label).update(
                f"  [{bar}] {done}/{total} tasks ({pct}%)"
            )
        else:
            self.query_one("#spec-progress", Label).update("")

        cl = self.query_one("#checklist", ListView)
        cl.clear()
        todo_rank = 0
        for item in spec["checklist"]:
            if not item["done"]:
                todo_rank += 1
            cl.append(ChecklistItem(item, todo_rank if not item["done"] else 0))

        # Pre-populate spec tab content
        self.query_one("#spec-content", Static).update(spec["text"])

    # ── Checklist click ───────────────────────────────────────────────────────

    @on(ListView.Selected, "#checklist")
    def checklist_clicked(self, event: ListView.Selected) -> None:
        if not isinstance(event.item, ChecklistItem):
            return
        item = event.item
        if item.item_data["done"]:
            return
        spec = self.selected_spec
        if spec is None or not spec["is_active"]:
            self.notify("Only active specs can be updated.", severity="warning")
            return
        self._set_busy(f"⟳ Ticking task {item.task_index}…")
        self._run_tick(item.task_index)

    @work(thread=True)
    def _run_tick(self, task_index: int) -> None:
        rc, out, err = run_aikit(self.root, "spec", "update", "tick", str(task_index))
        self.call_from_thread(self._set_idle)
        if rc == 0:
            self.call_from_thread(self.notify, f"Task {task_index} ticked ✔", severity="information")
            self.call_from_thread(self._reload_selected_spec)
        else:
            combined = _strip_ansi(out + err).strip()
            self.call_from_thread(self.push_screen, ResultModal("Tick error", combined))

    # ── Action buttons ────────────────────────────────────────────────────────

    @on(Button.Pressed, "#new-spec-btn")
    def action_new_spec(self) -> None:
        def handle(description: str | None) -> None:
            if not description:
                return
            self._set_busy("⟳ Creating spec (calling AI)…")
            self._run_new_spec(description)
        self.push_screen(InputModal("New Spec", "Describe the feature or task…"), handle)

    @work(thread=True)
    def _run_new_spec(self, description: str) -> None:
        rc, out, err = run_aikit(self.root, "spec", "new", description)
        self.call_from_thread(self._set_idle)
        self.call_from_thread(self.push_screen, ResultModal("New Spec", _strip_ansi(out + err).strip()))
        self.call_from_thread(self.load_specs)

    @on(Button.Pressed, "#btn-approve")
    def action_approve(self) -> None:
        spec = self._require_spec()
        if spec is None:
            return
        self._set_busy("⟳ Approving…")
        self._run_approve(spec["id"])

    @work(thread=True)
    def _run_approve(self, spec_id: str) -> None:
        rc, out, err = run_aikit(self.root, "spec", "approve", spec_id)
        self.call_from_thread(self._set_idle)
        self.call_from_thread(self.push_screen, ResultModal(f"Approve {spec_id}", _strip_ansi(out + err).strip()))
        self.call_from_thread(self._reload_selected_spec)

    @on(Button.Pressed, "#btn-start")
    def action_start(self) -> None:
        spec = self._require_spec()
        if spec is None:
            return
        self._set_busy("⟳ Starting spec (calling AI)…")
        self._run_start(spec["id"])

    @work(thread=True)
    def _run_start(self, spec_id: str) -> None:
        rc, out, err = run_aikit(self.root, "spec", "start", spec_id)
        self.call_from_thread(self._set_idle)
        self.call_from_thread(self.push_screen, ResultModal(f"Start {spec_id}", _strip_ansi(out + err).strip()))
        self.call_from_thread(self._reload_selected_spec)

    @on(Button.Pressed, "#btn-review")
    def btn_review_pressed(self) -> None:
        spec = self._require_spec()
        if spec is None:
            return
        self._set_busy("⟳ Running review (calling AI)…")
        self._run_review(spec["id"])

    @work(thread=True)
    def _run_review(self, spec_id: str) -> None:
        rc, out, err = run_aikit(self.root, "spec", "review", spec_id)
        self.call_from_thread(self._set_idle)
        self.call_from_thread(
            self.push_screen, ResultModal(f"Review {spec_id}", _strip_ansi(out + err).strip())
        )
        self.call_from_thread(self._reload_selected_spec)

    @on(Button.Pressed, "#btn-close")
    def btn_close_pressed(self) -> None:
        spec = self._require_spec()
        if spec is None:
            return
        self._set_busy("⟳ Closing (running review first)…")
        self._run_close(spec["id"])

    @work(thread=True)
    def _run_close(self, spec_id: str) -> None:
        rc, out, err = run_aikit(self.root, "spec", "close", spec_id, "--force")
        self.call_from_thread(self._set_idle)
        self.call_from_thread(
            self.push_screen, ResultModal(f"Close {spec_id}", _strip_ansi(out + err).strip())
        )
        self.call_from_thread(self.load_specs)

    # ── Key actions ───────────────────────────────────────────────────────────

    def action_refresh_all(self) -> None:
        self._reload_selected_spec() if self.selected_spec else self.load_specs()
        self.load_status()
        if self.active_tab == "activity" and self.selected_spec:
            self._load_activity(self.selected_spec)
        self.notify("Refreshed.", severity="information")

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _set_busy(self, message: str) -> None:
        self.query_one("#busy-label", Label).update(message)
        for btn_id in ["btn-approve", "btn-start", "btn-review", "btn-close"]:
            self.query_one(f"#{btn_id}", Button).disabled = True

    def _set_idle(self) -> None:
        self.query_one("#busy-label", Label).update("")
        for btn_id in ["btn-approve", "btn-start", "btn-review", "btn-close"]:
            self.query_one(f"#{btn_id}", Button).disabled = False

    def _require_spec(self) -> dict | None:
        if self.selected_spec is None:
            self.notify("Select a spec first.", severity="warning")
            return None
        return self.selected_spec

    def _reload_selected_spec(self) -> None:
        if self.selected_spec is None:
            return
        spec_id = self.selected_spec["id"]
        self.load_specs()
        for spec in self.specs:
            if spec["id"] == spec_id:
                self.selected_spec = spec
                self._render_detail(spec)
                if self.active_tab == "activity":
                    self._load_activity(spec)
                return


if __name__ == "__main__":
    AikitTUI().run()
