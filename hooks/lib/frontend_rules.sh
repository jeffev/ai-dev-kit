#!/usr/bin/env bash
# Angular / React / TypeScript analysis rules
# Functions: run_frontend_rules <file_path> <content_file>
# Appends findings to FINDINGS array (defined in auditor.sh)

run_frontend_rules() {
  local file_path="$1"
  local content_file="$2"

  local is_test=false
  echo "$file_path" | grep -qiE '(\.spec\.|\.test\.|__tests__)' && is_test=true

  _frontend_console_log "$file_path" "$content_file"

  if [[ "$is_test" == false ]]; then
    _frontend_typescript_any "$file_path" "$content_file"
    _frontend_subscribe_leak "$file_path" "$content_file"
    _frontend_env_secrets "$file_path" "$content_file"
    _frontend_useeffect_missing_deps "$file_path" "$content_file"
    _frontend_direct_dom "$file_path" "$content_file"
    _frontend_hardcoded_route "$file_path" "$content_file"
  fi
}

_frontend_console_log() {
  local file_path="$1"
  local content_file="$2"

  local match
  match=$(grep -inP 'console\.(log|warn|error|debug)\s*\(' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("LOW|F-001|$file_path|$line_num|console.log found in production code. Remove before merging.|")
  fi
}

_frontend_typescript_any() {
  local file_path="$1"
  local content_file="$2"

  local match
  match=$(grep -inP '(?<!\/\/.*):\s*any\b|as\s+any\b' "$content_file" 2>/dev/null | grep -v '^\s*//' | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("MEDIUM|F-002|$file_path|$line_num|TypeScript \`any\` type detected. Define a proper interface or use \`unknown\` with type narrowing.|")
  fi
}

_frontend_subscribe_leak() {
  local file_path="$1"
  local content_file="$2"

  # Only applies to Angular .ts files
  echo "$file_path" | grep -qiE '\.ts$' || return
  grep -qiP '@Component|@Injectable|@Directive|@Pipe' "$content_file" 2>/dev/null || return

  local has_subscribe
  has_subscribe=$(grep -cP '\.subscribe\s*\(' "$content_file" 2>/dev/null || echo 0)
  [[ "$has_subscribe" -eq 0 ]] && return

  if ! grep -qP 'takeUntil|takeUntilDestroyed|unsubscribe\(\)|async\s+pipe|Subscription' "$content_file" 2>/dev/null; then
    local line_num
    line_num=$(grep -nP '\.subscribe\s*\(' "$content_file" 2>/dev/null | head -1 | grep -oP '^\d+')
    FINDINGS+=("HIGH|F-003|$file_path|${line_num:-1}|RxJS .subscribe() without unsubscribe strategy — potential memory leak. Use takeUntilDestroyed() from @angular/core/rxjs-interop or the async pipe.|")
  fi
}

_frontend_env_secrets() {
  local file_path="$1"
  local content_file="$2"

  echo "$file_path" | grep -qiE '(environment\.(ts|js|prod|staging)|\.env(\.|$)|config\.(ts|js))' || return

  local match
  match=$(grep -inP '(apiKey|api_key|secret|password|token|privateKey)\s*[=:]\s*["'"'"'][^"'"'"'$\{]{4,}["'"'"']' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("CRITICAL|F-004|$file_path|$line_num|Secret in frontend environment file. Frontend bundles are public — use server-side proxying or runtime config injection.|")
  fi
}

_frontend_useeffect_missing_deps() {
  local file_path="$1"
  local content_file="$2"

  # Only React files
  echo "$file_path" | grep -qiE '\.(tsx|jsx)$' || return

  local match
  match=$(grep -inP 'useEffect\s*\(\s*\(' "$content_file" 2>/dev/null | while IFS= read -r line; do
    local ln
    ln=$(echo "$line" | grep -oP '^\d+')
    # Look ahead a few lines for missing dependency array (closing with just })
    local window
    window=$(sed -n "${ln},$((ln+6))p" "$content_file" 2>/dev/null)
    # Flag if no dependency array bracket found near the useEffect call
    if ! echo "$window" | grep -qP '\]\s*\)'; then
      echo "$line"
      break
    fi
  done | head -1)

  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("MEDIUM|F-005|$file_path|$line_num|useEffect without a dependency array runs on every render. Add [] for mount-only or list the actual dependencies.|")
  fi
}

_frontend_hardcoded_route() {
  local file_path="$1"
  local content_file="$2"

  # Only Angular .ts files
  echo "$file_path" | grep -qiE '\.ts$' || return
  grep -qiP '@Component|@Injectable' "$content_file" 2>/dev/null || return

  local match
  match=$(grep -inP 'this\.router\.navigate\s*\(\s*\[[\s'"'"'"]\/' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("LOW|F-007|$file_path|$line_num|router.navigate with hardcoded string literal. Extract route paths into a typed Routes constant to prevent silent breakage on refactoring.|")
  fi
}

_frontend_direct_dom() {
  local file_path="$1"
  local content_file="$2"

  # Only Angular .ts component files
  echo "$file_path" | grep -qiE '\.ts$' || return
  grep -qiP '@Component|@Directive' "$content_file" 2>/dev/null || return

  local match
  match=$(grep -inP 'document\.(getElementById|querySelector|querySelectorAll|getElementsBy)\s*\(' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("HIGH|F-006|$file_path|$line_num|Direct DOM manipulation in Angular component. Use @ViewChild with ElementRef or the Renderer2 service instead.|")
  fi
}
