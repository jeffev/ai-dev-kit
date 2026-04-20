#!/usr/bin/env bash
# Stop hook — remind to run tests if Java or TS files were modified this session

set -euo pipefail

SESSION_FILE=".claude/hooks/.session-state"

[[ -f "$SESSION_FILE" ]] || exit 0

MODIFIED=$(cat "$SESSION_FILE" 2>/dev/null)
[[ -z "$MODIFIED" ]] && exit 0

JAVA_COUNT=$(echo "$MODIFIED" | grep -c '\.java$' || echo 0)
TS_COUNT=$(echo "$MODIFIED" | grep -cE '\.(ts|tsx)$' || echo 0)

[[ "$JAVA_COUNT" -eq 0 && "$TS_COUNT" -eq 0 ]] && exit 0

echo ""
echo "┌─────────────────────────────────────────┐"
echo "│              Test Reminder               │"
echo "└─────────────────────────────────────────┘"

if [[ "$JAVA_COUNT" -gt 0 ]]; then
  echo ""
  echo "  $JAVA_COUNT Java file(s) modified this session."
  echo ""
  echo "  Run tests:"

  if [[ -f "./mvnw" ]]; then
    SUGGESTIONS=$(echo "$MODIFIED" | grep '\.java$' | while read -r f; do
      BASE=$(basename "$f" .java)
      echo "    ./mvnw test -Dtest=${BASE}Test"
    done | head -3)

    echo "    ./mvnw test                     # all tests"
    [[ -n "$SUGGESTIONS" ]] && echo "$SUGGESTIONS"
  fi
fi

if [[ "$TS_COUNT" -gt 0 ]]; then
  echo ""
  echo "  $TS_COUNT TypeScript file(s) modified this session."
  echo ""
  echo "  Run tests:"

  if [[ -f "angular.json" ]]; then
    echo "    ng test --watch=false           # Angular"
  elif grep -q '"vitest"' package.json 2>/dev/null; then
    echo "    npx vitest run                  # Vitest"
  else
    echo "    npx jest --passWithNoTests      # Jest"
  fi
fi

echo ""

# Clear session state for next session
rm -f "$SESSION_FILE"
