#!/usr/bin/env bash
# PostToolUse hook — compile check after .java file writes
# Claude Code passes tool result JSON on stdin.

set -euo pipefail

STDIN_DATA=$(cat)
SESSION_FILE=".claude/hooks/.session-state"

# Extract file path
if command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$STDIN_DATA" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
  FILE_PATH=$(echo "$STDIN_DATA" | grep -oP '(?<="file_path":\s*")[^"]+' | head -1)
fi

FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')

# Only act on production Java files
echo "$FILE_PATH" | grep -qiE '\.java$' || exit 0
echo "$FILE_PATH" | grep -qiE '/test/' && exit 0

# Track modified Java files for the Stop hook
mkdir -p "$(dirname "$SESSION_FILE")"
echo "$FILE_PATH" >> "$SESSION_FILE"

# Only compile if Maven wrapper exists
[[ -f "./mvnw" ]] || exit 0

echo ""
echo "[post-write] Compiling after edit: $(basename "$FILE_PATH")..."

# Run compile — suppress info output, show only errors
OUTPUT=$(./mvnw compile -q 2>&1) && STATUS=0 || STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  echo "[post-write] ✔ Compilation OK"
else
  echo "[post-write] ✘ Compilation errors:"
  echo "$OUTPUT" | grep -A2 '\[ERROR\]' | grep -v '^\-\-$' | head -30
  echo ""
  echo "[post-write] Fix the errors above before continuing."

  # Desktop notification (best-effort, non-blocking)
  FILE_NAME=$(basename "$FILE_PATH")
  if command -v notify-send &>/dev/null; then
    notify-send "AI Dev Kit — Build Failed" "$FILE_NAME caused a compile error" --icon=error 2>/dev/null || true
  elif command -v osascript &>/dev/null; then
    osascript -e "display notification \"$FILE_NAME caused a compile error\" with title \"AI Dev Kit — Build Failed\"" 2>/dev/null || true
  elif command -v powershell.exe &>/dev/null; then
    powershell.exe -NoProfile -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; \$n = New-Object System.Windows.Forms.NotifyIcon; \$n.Icon = [System.Drawing.SystemIcons]::Error; \$n.Visible = \$true; \$n.ShowBalloonTip(4000, 'AI Dev Kit — Build Failed', '$FILE_NAME caused a compile error', [System.Windows.Forms.ToolTipIcon]::Error); Start-Sleep -Seconds 5; \$n.Dispose()" 2>/dev/null || true
  fi
fi
