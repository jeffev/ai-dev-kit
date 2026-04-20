#!/usr/bin/env bash
# SessionStart hook — show project status when Claude Code session begins

set -euo pipefail

SESSION_FILE=".claude/hooks/.session-state"

# Clear session state from previous session
rm -f "$SESSION_FILE"
mkdir -p "$(dirname "$SESSION_FILE")"

echo ""
echo "╔══════════════════════════════════╗"
echo "║       AI Dev Kit — Session       ║"
echo "╚══════════════════════════════════╝"

# ── Git status ────────────────────────────────────────────────────────────────
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")

  echo ""
  echo "  Git"
  echo "  ├─ Branch:    $BRANCH"
  echo "  ├─ Modified:  $DIRTY file(s)"
  [[ "$AHEAD" -gt 0 ]] && echo "  └─ Unpushed:  $AHEAD commit(s)" || echo "  └─ In sync with remote"
fi

# ── Docker Compose status ─────────────────────────────────────────────────────
if command -v docker &>/dev/null && [[ -f "docker-compose.yml" || -f "docker-compose.yaml" ]]; then
  echo ""
  echo "  Docker Compose"

  STATUS=$(docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null | tail -n +2 || echo "")

  if [[ -z "$STATUS" ]]; then
    echo "  └─ No services running"
  else
    while IFS= read -r line; do
      NAME=$(echo "$line" | awk '{print $1}')
      STATE=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
      if echo "$STATE" | grep -qi "running\|up"; then
        echo "  ├─ [UP] $NAME ($STATE)"
      else
        echo "  ├─ [DOWN] $NAME ($STATE)"
      fi
    done <<< "$STATUS"
  fi
fi

# ── Maven / Node check ────────────────────────────────────────────────────────
echo ""
echo "  Environment"

if [[ -f "pom.xml" ]]; then
  JAVA_VER=$(java -version 2>&1 | grep -oP '(?<=version ")[^"]+' | head -1 || echo "?")
  echo "  ├─ Java $JAVA_VER"
fi

if [[ -f "package.json" ]]; then
  NODE_VER=$(node --version 2>/dev/null || echo "not found")
  echo "  ├─ Node $NODE_VER"
fi

# ── Test coverage ─────────────────────────────────────────────────────────────
# JaCoCo (Java)
JACOCO_CSV="target/site/jacoco/jacoco.csv"
if [[ -f "$JACOCO_CSV" ]]; then
  COVERED=$(awk -F',' 'NR>1 {c+=$8; m+=$9} END {print c+0, m+0}' "$JACOCO_CSV" 2>/dev/null | awk '{if ($1+$2>0) printf "%.0f", ($1/($1+$2))*100; else print "?"}')
  echo ""
  echo "  Last Test Run"
  echo "  └─ JaCoCo line coverage: ${COVERED}%"
fi

# Istanbul / NYC (JavaScript/TypeScript)
ISTANBUL_JSON="coverage/coverage-summary.json"
if [[ -f "$ISTANBUL_JSON" ]]; then
  LINES_PCT=$(python3 -c "import json,sys; d=json.load(open('$ISTANBUL_JSON')); t=d.get('total',{}); l=t.get('lines',{}); print(l.get('pct','?'))" 2>/dev/null || echo "?")
  echo ""
  echo "  Last Test Run"
  echo "  └─ Istanbul line coverage: ${LINES_PCT}%"
fi

# ── Audit log summary ─────────────────────────────────────────────────────────
LOG=".claude/hooks/logs/audit.log"
if [[ -f "$LOG" ]]; then
  TODAY=$(date '+%Y-%m-%d')
  TODAY_COUNT=$(grep -c "$TODAY" "$LOG" 2>/dev/null || echo 0)
  [[ "$TODAY_COUNT" -gt 0 ]] && echo "  └─ [!] $TODAY_COUNT LOW finding(s) today in audit.log"
fi

echo ""
