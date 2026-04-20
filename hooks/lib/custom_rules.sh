#!/usr/bin/env bash
# Custom rules loader — reads .aikit-rules.yml from project root
# Functions: run_custom_rules <file_path> <content_file> [rules_file]
# Appends findings to FINDINGS array (defined in auditor.sh)

run_custom_rules() {
  local file_path="$1"
  local content_file="$2"
  local rules_file="${3:-.aikit-rules.yml}"

  [[ -f "$rules_file" ]] || return 0

  if ! command -v python3 &>/dev/null; then
    return 0
  fi

  local rules_json
  rules_json=$(python3 - "$rules_file" <<'PYEOF'
import sys, json

rules_file = sys.argv[1]
rules = []

try:
    with open(rules_file) as f:
        content = f.read()

    current = {}
    in_rules = False

    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith('#') or not stripped:
            continue
        if stripped == 'rules:':
            in_rules = True
            continue
        if not in_rules:
            continue
        if stripped.startswith('- id:'):
            if current:
                rules.append(current)
            current = {'id': stripped.split(':', 1)[1].strip()}
        elif stripped.startswith('id:') and current:
            current['id'] = stripped.split(':', 1)[1].strip()
        elif stripped.startswith('severity:'):
            current['severity'] = stripped.split(':', 1)[1].strip()
        elif stripped.startswith('files:'):
            current['files'] = stripped.split(':', 1)[1].strip().strip('"\'')
        elif stripped.startswith('pattern:'):
            current['pattern'] = stripped.split(':', 1)[1].strip().strip('"\'')
        elif stripped.startswith('message:'):
            current['message'] = stripped.split(':', 1)[1].strip().strip('"\'')

    if current:
        rules.append(current)

    print(json.dumps(rules))
except Exception:
    print('[]')
PYEOF
)

  [[ -z "$rules_json" || "$rules_json" == "[]" ]] && return 0

  local file_basename
  file_basename=$(basename "$file_path")

  local rule_count
  rule_count=$(echo "$rules_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

  for i in $(seq 0 $((rule_count - 1))); do
    local rule
    rule=$(echo "$rules_json" | python3 -c "import sys,json; r=json.load(sys.stdin)[$i]; print(r.get('id','?')+'|'+r.get('severity','MEDIUM')+'|'+r.get('files','*')+'|'+r.get('pattern','')+'|'+r.get('message','Custom rule violation'))")

    local rule_id severity files_glob pattern message
    rule_id=$(echo "$rule"   | cut -d'|' -f1)
    severity=$(echo "$rule"  | cut -d'|' -f2)
    files_glob=$(echo "$rule" | cut -d'|' -f3)
    pattern=$(echo "$rule"   | cut -d'|' -f4)
    message=$(echo "$rule"   | cut -d'|' -f5)

    [[ -z "$pattern" ]] && continue

    local applies=false
    IFS=',' read -ra globs <<< "$files_glob"
    for glob in "${globs[@]}"; do
      glob=$(echo "$glob" | tr -d ' ')
      local regex
      regex=$(echo "$glob" | sed 's/\./\\./g; s/\*/.*/g')
      if echo "$file_basename" | grep -qP "$regex"; then
        applies=true
        break
      fi
    done

    [[ "$applies" == false ]] && continue

    local match
    match=$(grep -inP "$pattern" "$content_file" 2>/dev/null | head -1)
    if [[ -n "$match" ]]; then
      local line_num
      line_num=$(echo "$match" | grep -oP '^\d+')
      FINDINGS+=("$severity|$rule_id|$file_path|${line_num:-1}|[Custom rule] $message|")
    fi
  done
}
