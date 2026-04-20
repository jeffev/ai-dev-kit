#!/usr/bin/env bash
# Universal rules — apply to every file regardless of stack
# Functions: run_universal_rules <file_path> <content_file>
# Appends findings to FINDINGS array (defined in auditor.sh)

run_universal_rules() {
  local file_path="$1"
  local content_file="$2"

  # Skip test files for secret detection
  local is_test=false
  if echo "$file_path" | grep -qiE '(/test/|\.spec\.|\.test\.|Test\.java$|Spec\.ts$)'; then
    is_test=true
  fi

  if [[ "$is_test" == false ]]; then
    _check_hardcoded_secrets "$file_path" "$content_file"
  fi

  _check_todo_fixme "$file_path" "$content_file"
}

_check_hardcoded_secrets() {
  local file_path="$1"
  local content_file="$2"

  local patterns=(
    'password\s*[=:]\s*["'"'"'][^"'"'"'$\{]{4,}["'"'"']'
    'secret\s*[=:]\s*["'"'"'][^"'"'"'$\{]{4,}["'"'"']'
    'api[_-]?key\s*[=:]\s*["'"'"'][^"'"'"'$\{]{8,}["'"'"']'
    'token\s*[=:]\s*["'"'"'][^"'"'"'$\{]{8,}["'"'"']'
    'AWS_SECRET_ACCESS_KEY\s*='
    'AWS_ACCESS_KEY_ID\s*=\s*[A-Z0-9]{16,}'
    'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
    'jwt[_-]?secret\s*[=:]\s*["'"'"'][^"'"'"'$\{]{8,}["'"'"']'
  )

  for pattern in "${patterns[@]}"; do
    local match
    match=$(grep -inP "$pattern" "$content_file" 2>/dev/null | head -1)
    if [[ -n "$match" ]]; then
      local line_num
      line_num=$(echo "$match" | grep -oP '^\d+')
      FINDINGS+=("CRITICAL|U-001|$file_path|$line_num|Possible hardcoded secret detected. Move to environment variables or a secrets manager.|")
      return
    fi
  done
}

_check_todo_fixme() {
  local file_path="$1"
  local content_file="$2"

  local match
  match=$(grep -inP '\b(TODO|FIXME)\b' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("LOW|U-002|$file_path|$line_num|TODO/FIXME found in new code. Resolve before merging.|")
  fi
}
