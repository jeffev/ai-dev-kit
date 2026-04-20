#!/usr/bin/env bash
# PostToolUse hook — TypeScript type check after .ts/.tsx writes
# Claude Code passes tool result JSON on stdin.

set -euo pipefail

STDIN_DATA=$(cat)

# Extract file path
if command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$STDIN_DATA" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
  FILE_PATH=$(echo "$STDIN_DATA" | grep -oP '(?<="file_path":\s*")[^"]+' | head -1)
fi

FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')

# Only act on TypeScript files outside test files
echo "$FILE_PATH" | grep -qiE '\.(ts|tsx)$' || exit 0
echo "$FILE_PATH" | grep -qiE '(\.spec\.|\.test\.)' && exit 0

# Find the tsconfig.json closest to the written file
find_tsconfig() {
  local dir
  dir=$(dirname "$FILE_PATH")
  while [[ "$dir" != "." && "$dir" != "/" ]]; do
    [[ -f "$dir/tsconfig.json" ]] && echo "$dir/tsconfig.json" && return
    dir=$(dirname "$dir")
  done
  [[ -f "tsconfig.json" ]] && echo "tsconfig.json"
}

TSCONFIG=$(find_tsconfig)
[[ -z "$TSCONFIG" ]] && exit 0

# npx must be available
if ! command -v npx &>/dev/null; then
  exit 0
fi

echo ""
echo "[post-write] Type checking after edit: $(basename "$FILE_PATH")..."

OUTPUT=$(npx tsc --noEmit -p "$TSCONFIG" 2>&1) && STATUS=0 || STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  echo "[post-write] ✔ Types OK"
else
  echo "[post-write] ✘ Type errors:"
  BASENAME=$(basename "$FILE_PATH")
  RELEVANT=$(echo "$OUTPUT" | grep "$BASENAME" | head -15)
  if [[ -n "$RELEVANT" ]]; then
    echo "$RELEVANT"
  else
    echo "$OUTPUT" | head -20
  fi
  echo ""
  echo "[post-write] Fix the type errors above before continuing."
fi
