#!/usr/bin/env bash
# AI Dev Kit — Smart Commit
# Usage: bash smart-commit.sh [--push] [--dry-run]
# Reviews staged diff via claude -p, generates a Conventional Commit message, commits and optionally pushes.

set -euo pipefail

C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

ok()   { echo -e "  ${C_GREEN}[OK]${C_RESET}  $*"; }
warn() { echo -e "  ${C_YELLOW}[WARN]${C_RESET}  $*"; }
fail() { echo -e "  ${C_RED}[FAIL]${C_RESET}  $*"; }
info() { echo -e "  ${C_CYAN}…${C_RESET}  $*"; }

# ── Args ──────────────────────────────────────────────────────────────────────
DO_PUSH=false
DRY_RUN=false
NO_REVIEW=false
for arg in "$@"; do
  case "$arg" in
    --push)      DO_PUSH=true ;;
    --dry-run)   DRY_RUN=true ;;
    --no-review) NO_REVIEW=true ;;
  esac
done

echo ""
echo -e "${C_BOLD}Smart Commit${C_RESET}"
echo "─────────────────────────"

# ── Check staged changes ──────────────────────────────────────────────────────
if ! git diff --cached --quiet 2>/dev/null; then
  DIFF=$(git diff --cached)
else
  fail "Nothing staged. Run: git add <files>"
  exit 1
fi

STAGED_FILES=$(git diff --cached --name-only)
FILE_COUNT=$(echo "$STAGED_FILES" | wc -l | tr -d ' ')
info "$FILE_COUNT staged file(s):"
echo "$STAGED_FILES" | sed 's/^/       /'
echo ""

# ── Block on open CRITICAL/HIGH findings from today ──────────────────────────
AUDIT_LOG=".claude/hooks/logs/audit.log"
if [[ -f "$AUDIT_LOG" && "$NO_REVIEW" == false ]]; then
  TODAY=$(date '+%Y-%m-%d')
  BLOCKING=$(grep "$TODAY" "$AUDIT_LOG" 2>/dev/null | grep -E "\|(CRITICAL|HIGH)\|" | wc -l | tr -d ' ')
  if [[ "$BLOCKING" -gt 0 ]]; then
    echo ""
    warn "$BLOCKING CRITICAL/HIGH finding(s) in today's audit.log — resolve before committing."
    grep "$TODAY" "$AUDIT_LOG" | grep -E "\|(CRITICAL|HIGH)\|" | while IFS='|' read -r date sev rule file line msg _; do
      echo "    [$sev] $rule  $file:$line"
    done
    echo ""
    echo -n "  Commit anyway? [y/N] "
    read -r override
    if [[ "$override" != "y" && "$override" != "Y" ]]; then
      fail "Commit cancelled. Fix the findings above first."
      exit 1
    fi
  fi
fi

# ── Review via claude -p ──────────────────────────────────────────────────────
if [[ "$NO_REVIEW" == true ]]; then
  warn "Skipping AI review (--no-review)"
else
info "Reviewing changes..."

REVIEW=$(echo "$DIFF" | claude -p "$(cat <<'PROMPT'
You are an experienced code reviewer. Analyze this git diff and check ONLY for:

1. Hardcoded secrets or tokens (passwords, API keys, JWT secrets)
2. Forgotten console.log / System.out.println in production code
3. Spring Boot endpoints without @PreAuthorize
4. SQL with string concatenation (SQL Injection risk)
5. Large commented-out code blocks that should be deleted
6. Files that clearly should not be committed (.env, *.log, target/, node_modules/)

Reply with EXACTLY one of two formats:

If everything is OK:
APPROVED

If issues found:
REJECTED
- [CRITICAL/HIGH/MEDIUM] Description of the issue (file:line if possible)
- ...
PROMPT
)")

echo ""

if echo "$REVIEW" | grep -q "^APPROVED"; then
  ok "Review approved"
else
  echo -e "  ${C_RED}Review rejected:${C_RESET}"
  echo "$REVIEW" | grep -v "^REJECTED" | sed 's/^/  /'
  echo ""

  echo -n "  Commit anyway? [y/N] "
  read -r answer
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    fail "Commit cancelled."
    exit 1
  fi
  warn "Committing with warnings..."
fi
fi  # end NO_REVIEW block

# ── Generate commit message ───────────────────────────────────────────────────
info "Generating commit message..."

COMMIT_MSG=$(echo "$DIFF" | claude -p "$(cat <<'PROMPT'
Generate a commit message following the Conventional Commits specification.

Required format:
<type>(<scope>): <short description>

[optional body — only include if there are multiple relevant changes, max 3 lines]

Allowed types: feat, fix, refactor, test, chore, docs, style, perf, ci
- scope: name of the affected module/component (e.g. user, auth, payment)
- description: imperative mood, lowercase, no trailing period, max 72 chars

Reply with ONLY the commit message. No additional text.
PROMPT
)")

echo ""
echo -e "  ${C_BOLD}Generated message:${C_RESET}"
echo "  $COMMIT_MSG"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  warn "Dry-run mode — no commit was made."
  exit 0
fi

# ── Confirm and commit ────────────────────────────────────────────────────────
echo -n "  Confirm commit? [Y/n] "
read -r confirm
if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
  fail "Commit cancelled."
  exit 1
fi

git commit -m "$COMMIT_MSG"
ok "Commit created: $COMMIT_MSG"

# ── Optional push ─────────────────────────────────────────────────────────────
if [[ "$DO_PUSH" == true ]]; then
  info "Pushing..."
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push origin "$BRANCH"
  ok "Push complete → $BRANCH"
else
  echo ""
  echo "  To push: git push"
  echo "  Or use --push next time: bash smart-commit.sh --push"
fi

echo ""
