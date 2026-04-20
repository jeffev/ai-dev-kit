#!/usr/bin/env bash
# Output formatting and severity decision logic
# Functions: report_findings, has_blocking_findings
# Reads FINDINGS array (defined in auditor.sh)
# Format: "SEVERITY|RULE|FILE|LINE|MESSAGE|"

# Returns 0 if any CRITICAL or HIGH findings exist
has_blocking_findings() {
  for finding in "${FINDINGS[@]}"; do
    local severity
    severity=$(echo "$finding" | cut -d'|' -f1)
    if [[ "$severity" == "CRITICAL" || "$severity" == "HIGH" ]]; then
      return 0
    fi
  done
  return 1
}

report_findings() {
  local log_file="${1:-.claude/hooks/logs/audit.log}"

  local blocking=()
  local warnings=()
  local silent=()

  for finding in "${FINDINGS[@]}"; do
    local severity
    severity=$(echo "$finding" | cut -d'|' -f1)
    case "$severity" in
      CRITICAL|HIGH) blocking+=("$finding") ;;
      MEDIUM)        warnings+=("$finding") ;;
      LOW)           silent+=("$finding") ;;
    esac
  done

  # Silent log for LOW findings
  if [[ ${#silent[@]} -gt 0 ]]; then
    mkdir -p "$(dirname "$log_file")"
    for finding in "${silent[@]}"; do
      local rule file line msg
      rule=$(echo "$finding" | cut -d'|' -f2)
      file=$(echo "$finding" | cut -d'|' -f3)
      line=$(echo "$finding" | cut -d'|' -f4)
      msg=$(echo "$finding" | cut -d'|' -f5)
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] LOW $rule $file:$line — $msg" >> "$log_file"
    done
  fi

  # Print MEDIUM warnings to stderr (file still written)
  for finding in "${warnings[@]}"; do
    local rule file line msg
    rule=$(echo "$finding" | cut -d'|' -f2)
    file=$(echo "$finding" | cut -d'|' -f3)
    line=$(echo "$finding" | cut -d'|' -f4)
    msg=$(echo "$finding" | cut -d'|' -f5)
    echo "" >&2
    echo "[AUDITOR] MEDIUM — Rule $rule" >&2
    echo "File:    $file:$line" >&2
    echo "Fix:     $msg" >&2
    echo "File written. Address this before merging." >&2
  done

  # Print blocking findings to stderr (write will be blocked)
  for finding in "${blocking[@]}"; do
    local severity rule file line msg
    severity=$(echo "$finding" | cut -d'|' -f1)
    rule=$(echo "$finding" | cut -d'|' -f2)
    file=$(echo "$finding" | cut -d'|' -f3)
    line=$(echo "$finding" | cut -d'|' -f4)
    msg=$(echo "$finding" | cut -d'|' -f5)
    echo "" >&2
    echo "[AUDITOR] $severity — Rule $rule (Write blocked)" >&2
    echo "File:    $file:$line" >&2
    echo "Fix:     $msg" >&2
    echo "To allow intentionally: add comment  // ai-kit:ignore $rule" >&2
  done

  if has_blocking_findings; then
    echo "" >&2
    echo "Write blocked. Fix the issue(s) above and try again." >&2
  fi
}
