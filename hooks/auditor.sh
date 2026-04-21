#!/usr/bin/env bash
# AI Dev Kit — Auditor (PreToolUse hook)
# Intercepts Write/Edit/MultiEdit tool calls from Claude Code.
# Claude Code passes tool data as JSON on stdin.
# exit 0 = allow write  |  exit 1 = block write

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="$PROJECT_ROOT/.claude/hooks/logs/audit.log"

source "$SCRIPT_DIR/lib/python_cmd.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/universal_rules.sh"
source "$SCRIPT_DIR/lib/java_rules.sh"
source "$SCRIPT_DIR/lib/frontend_rules.sh"
source "$SCRIPT_DIR/lib/custom_rules.sh"
source "$SCRIPT_DIR/lib/reporter.sh"

FINDINGS=()

# ── Parse stdin JSON from Claude Code ────────────────────────────────────────

STDIN_DATA=$(cat)

# Normalize Windows backslashes to forward slashes
STDIN_DATA=$(echo "$STDIN_DATA" | sed 's|\\\\|/|g; s|\\"|"|g')

extract_json_field() {
  local json="$1"
  local field="$2"
  # Try jq first, fall back to grep/sed
  if command -v jq &>/dev/null; then
    echo "$json" | jq -r ".$field // empty" 2>/dev/null
  else
    echo "$json" | grep -oP "\"$field\":\s*\"\K[^\"]*" | head -1
  fi
}

TOOL_NAME=$(extract_json_field "$STDIN_DATA" "tool_name")
FILE_PATH=$(extract_json_field "$(echo "$STDIN_DATA" | grep -oP '"tool_input"\s*:\s*\{[^}]+')" "file_path")
CONTENT=$(echo "$STDIN_DATA" | ${PYTHON_CMD:-python3} -c "
import sys, json
data = json.load(sys.stdin)
inp = data.get('tool_input', {})
print(inp.get('content', inp.get('new_string', '')))
" 2>/dev/null || echo "")

# Only audit write/edit operations
case "$TOOL_NAME" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

[[ -z "$FILE_PATH" ]] && exit 0

# ── Suppression check ─────────────────────────────────────────────────────────
# If content contains // ai-kit:ignore ALL, skip all rules
if echo "$CONTENT" | grep -qP 'ai-kit:ignore\s+ALL'; then
  exit 0
fi

# Load global suppressions from .aikit-ignore (one rule ID per line, # for comments)
GLOBAL_SUPPRESSED=()
AIKIT_IGNORE_FILE="$PROJECT_ROOT/.aikit-ignore"
if [[ -f "$AIKIT_IGNORE_FILE" ]]; then
  while IFS= read -r line; do
    line=$(echo "$line" | sed 's/#.*//' | xargs)
    [[ -n "$line" ]] && GLOBAL_SUPPRESSED+=("$line")
  done < "$AIKIT_IGNORE_FILE"
fi

_is_globally_suppressed() {
  local rule_id="$1"
  for suppressed in "${GLOBAL_SUPPRESSED[@]+"${GLOBAL_SUPPRESSED[@]}"}"; do
    [[ "$suppressed" == "$rule_id" ]] && return 0
  done
  return 1
}

# ── Write content to temp file for analysis ──────────────────────────────────
TEMP_FILE=$(mktemp /tmp/aikit-audit-XXXXXX)
trap 'rm -f "$TEMP_FILE"' EXIT
echo "$CONTENT" > "$TEMP_FILE"

# Add line numbers for reporting
nl -ba "$TEMP_FILE" > "${TEMP_FILE}.nl"
mv "${TEMP_FILE}.nl" "$TEMP_FILE"

# ── Invalidate stack cache if key files changed ───────────────────────────────
case "$(basename "$FILE_PATH")" in
  pom.xml|package.json|angular.json)
    invalidate_stack_cache "$PROJECT_ROOT"
    ;;
esac

# ── Detect stack ──────────────────────────────────────────────────────────────
if [[ "${AIKIT_AUDIT_TEST:-false}" == true ]]; then
  # In test mode, infer stack from file extension so all applicable rules run
  STACK_JAVA=false; STACK_ANGULAR=false; STACK_REACT=false; STACK_TYPESCRIPT=false
  echo "$FILE_PATH" | grep -qiE '\.java$'          && STACK_JAVA=true       || true
  echo "$FILE_PATH" | grep -qiE '\.(ts|tsx|js|jsx)$' && { STACK_ANGULAR=true; STACK_REACT=true; STACK_TYPESCRIPT=true; } || true
else
  detect_stack "$PROJECT_ROOT"
fi

# ── Run applicable rule sets ──────────────────────────────────────────────────

# Filter per-rule suppressions from content
_is_suppressed() {
  local rule_id="$1"
  echo "$CONTENT" | grep -qP "ai-kit:ignore\s+$rule_id"
}

run_universal_rules "$FILE_PATH" "$TEMP_FILE"

# Java rules: .java files
if [[ "$STACK_JAVA" == true ]] && echo "$FILE_PATH" | grep -qiE '\.java$'; then
  run_java_rules "$FILE_PATH" "$TEMP_FILE"
fi

# Frontend rules: .ts, .tsx, .js, .jsx files
if [[ "$STACK_ANGULAR" == true || "$STACK_REACT" == true ]]; then
  if echo "$FILE_PATH" | grep -qiE '\.(ts|tsx|js|jsx)$'; then
    run_frontend_rules "$FILE_PATH" "$TEMP_FILE"
  fi
fi

# Custom rules from .aikit-rules.yml
run_custom_rules "$FILE_PATH" "$TEMP_FILE" "$PROJECT_ROOT/.aikit-rules.yml"

# Filter suppressed rules out of FINDINGS (inline + global .aikit-ignore)
FILTERED_FINDINGS=()
for finding in "${FINDINGS[@]}"; do
  rule=$(echo "$finding" | cut -d'|' -f2)
  if ! _is_suppressed "$rule" && ! _is_globally_suppressed "$rule"; then
    FILTERED_FINDINGS+=("$finding")
  fi
done
FINDINGS=("${FILTERED_FINDINGS[@]+"${FILTERED_FINDINGS[@]}"}")

# ── Report and decide ─────────────────────────────────────────────────────────
report_findings "$LOG_FILE"

if has_blocking_findings; then
  exit 1
fi

exit 0
