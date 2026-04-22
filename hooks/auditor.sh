#!/usr/bin/env bash
# AI Dev Kit — Auditor (PreToolUse hook)
# Intercepts Write/Edit/MultiEdit tool calls from Claude Code.
# Claude Code passes tool data as JSON on stdin.
# exit 0 = allow write  |  exit 1 = block write

set -euo pipefail
export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8  # grep -P requires a UTF-8 locale on Windows/Git Bash

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

# Extract tool_name, file_path, and content via Python (handles JSON correctly,
# normalizes Windows backslash paths without corrupting the content field)
read -r TOOL_NAME FILE_PATH <<< "$(echo "$STDIN_DATA" | ${PYTHON_CMD:-python3} -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tool_name = data.get('tool_name', '')
    inp = data.get('tool_input', {})
    file_path = inp.get('file_path', '').replace('\\\\', '/')
    print(tool_name + '\t' + file_path)
except Exception:
    print('\t')
" 2>/dev/null || echo -e '\t')"

CONTENT=$(echo "$STDIN_DATA" | ${PYTHON_CMD:-python3} -c "
import sys, json
try:
    data = json.load(sys.stdin)
    inp = data.get('tool_input', {})
    print(inp.get('content', inp.get('new_string', '')))
except Exception:
    pass
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

# Spec scope guard — warn when writing a file outside the active spec's scope
_run_spec_scope_guard() {
  local active_spec_pointer="$PROJECT_ROOT/.aikit-specs/.active-spec"
  [[ -f "$active_spec_pointer" ]] || return 0

  local spec_id
  spec_id=$(cat "$active_spec_pointer")
  local spec_file
  spec_file=$(find "$PROJECT_ROOT/.aikit-specs/active" -name "${spec_id}-*.md" 2>/dev/null | head -1)
  [[ -f "$spec_file" ]] || return 0

  # Extract expected files from spec
  local expected_files
  expected_files=$(awk '/^## Files expected to change/{found=1;next} found && /^## /{exit} found && /^- /{print}' "$spec_file" \
    | sed 's/^- //' | sed 's/ *(new)$//' | sed 's/ *← NEW$//' | tr -d ' ')

  [[ -z "$expected_files" ]] && return 0

  # Normalize the file path being written for comparison
  local norm_path
  norm_path=$(echo "$FILE_PATH" | sed 's|\\|/|g')

  # Check if the written file matches any expected file (basename or path suffix)
  local file_basename
  file_basename=$(basename "$norm_path")

  while IFS= read -r expected; do
    [[ -z "$expected" ]] && continue
    local exp_base
    exp_base=$(basename "$expected")
    # Match on basename or if the written path ends with the expected path
    if [[ "$file_basename" == "$exp_base" ]] || echo "$norm_path" | grep -qF "$expected"; then
      return 0
    fi
  done <<< "$expected_files"

  # File is not in scope — log LOW finding
  FINDINGS+=("LOW|SPEC-SCOPE|$FILE_PATH|1|File not listed in $spec_id scope. Scope creep? Update the spec or add: // ai-kit:ignore SPEC-SCOPE|")
}

_run_spec_scope_guard

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
