#!/usr/bin/env bash
# Output formatting and severity decision logic
# Functions: report_findings, has_blocking_findings
# Reads FINDINGS array (defined in auditor.sh)
# Format: "SEVERITY|RULE|FILE|LINE|MESSAGE|"

# ANSI colors (safe — Claude Code renders stderr in a terminal)
_R='\033[0;31m'   # red
_Y='\033[0;33m'   # yellow
_C='\033[0;36m'   # cyan
_G='\033[0;32m'   # green
_B='\033[1;34m'   # bold blue
_W='\033[1;37m'   # bold white
_D='\033[2;37m'   # dim white
_N='\033[0m'      # reset

_divider() { printf '%b' "${_D}────────────────────────────────────────────────${_N}\n" >&2; }

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

  # MEDIUM warnings
  for finding in "${warnings[@]}"; do
    local rule file line msg
    rule=$(echo "$finding" | cut -d'|' -f2)
    file=$(echo "$finding" | cut -d'|' -f3)
    line=$(echo "$finding" | cut -d'|' -f4)
    msg=$(echo "$finding" | cut -d'|' -f5)
    printf '\n' >&2
    _divider
    printf '%b\n' "  ${_Y}⚠  MEDIUM${_N}  ${_W}${rule}${_N}" >&2
    _divider
    printf '%b\n' "  ${_D}file ${_N}${_C}${file}:${line}${_N}" >&2
    printf '%b\n' "  ${_D}fix  ${_N}${msg}" >&2
    printf '%b\n' "  ${_D}─── file written — address before merging${_N}" >&2
  done

  # CRITICAL / HIGH blocking findings
  for finding in "${blocking[@]}"; do
    local severity rule file line msg
    severity=$(echo "$finding" | cut -d'|' -f1)
    rule=$(echo "$finding" | cut -d'|' -f2)
    file=$(echo "$finding" | cut -d'|' -f3)
    line=$(echo "$finding" | cut -d'|' -f4)
    msg=$(echo "$finding" | cut -d'|' -f5)
    local color="$_R"
    local icon="✖"
    [[ "$severity" == "CRITICAL" ]] && icon="✖✖"
    printf '\n' >&2
    _divider
    printf '%b\n' "  ${color}${icon} ${severity}${_N}  ${_W}${rule}${_N}  ${_D}(write blocked)${_N}" >&2
    _divider
    printf '%b\n' "  ${_D}file ${_N}${_C}${file}:${line}${_N}" >&2
    printf '%b\n' "  ${_D}fix  ${_N}${msg}" >&2
    printf '%b\n' "  ${_D}suppress  ${_N}// ai-kit:ignore ${rule}" >&2
  done

  if has_blocking_findings; then
    printf '\n' >&2
    printf '%b\n' "  ${_R}Write blocked.${_N} Fix the issue(s) above and try again." >&2
    printf '\n' >&2
  fi
}
