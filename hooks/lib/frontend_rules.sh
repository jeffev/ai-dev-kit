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

  # Match ": any" or "as any" but not in comments
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

  # Only applies to Angular .ts files (not React)
  echo "$file_path" | grep -qiE '\.ts$' || return
  grep -qiP '@Component|@Injectable|@Directive|@Pipe' "$content_file" 2>/dev/null || return

  local has_subscribe
  has_subscribe=$(grep -cP '\.subscribe\s*\(' "$content_file" 2>/dev/null || echo 0)
  [[ "$has_subscribe" -eq 0 ]] && return

  # Check for unsubscribe strategies
  if ! grep -qP 'takeUntil|takeUntilDestroyed|unsubscribe\(\)|async\s+pipe|Subscription' "$content_file" 2>/dev/null; then
    local line_num
    line_num=$(grep -nP '\.subscribe\s*\(' "$content_file" 2>/dev/null | head -1 | grep -oP '^\d+')
    FINDINGS+=("HIGH|F-003|$file_path|${line_num:-1}|RxJS .subscribe() without unsubscribe strategy — potential memory leak. Use takeUntilDestroyed() from @angular/core/rxjs-interop or the async pipe.|")
  fi
}

_frontend_env_secrets() {
  local file_path="$1"
  local content_file="$2"

  # Only applies to environment/config files
  echo "$file_path" | grep -qiE '(environment\.(ts|js|prod|staging)|\.env(\.|$)|config\.(ts|js))' || return

  local match
  match=$(grep -inP '(apiKey|api_key|secret|password|token|privateKey)\s*[=:]\s*["'"'"'][^"'"'"'$\{]{4,}["'"'"']' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("CRITICAL|F-004|$file_path|$line_num|Secret in frontend environment file. Frontend bundles are public — use server-side proxying or runtime config injection.|")
  fi
}
