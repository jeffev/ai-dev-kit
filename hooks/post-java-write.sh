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
echo "[post-write] Compilando após edição em $(basename "$FILE_PATH")..."

# Run compile — suppress info output, show only errors
OUTPUT=$(./mvnw compile -q 2>&1) && STATUS=0 || STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  echo "[post-write] ✔ Compilação OK"
else
  echo "[post-write] ✘ Erros de compilação:"
  # Filter noise — show only ERROR lines and the lines around them
  echo "$OUTPUT" | grep -A2 '\[ERROR\]' | grep -v '^\-\-$' | head -30
  echo ""
  echo "[post-write] Corrija os erros antes de continuar."
fi
