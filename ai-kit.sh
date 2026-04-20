#!/usr/bin/env bash
# AI Dev Kit — Bootstrapper
# Usage: bash ai-kit.sh init
# Run from the root of your project.

set -euo pipefail

AIKIT_VERSION="1.0.0"
AIKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colours ───────────────────────────────────────────────────────────────────
C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

ok()   { echo -e "  ${C_GREEN}OK${C_RESET}  $*"; }
warn() { echo -e "  ${C_YELLOW}WARN${C_RESET} $*"; }
fail() { echo -e "  ${C_RED}FAIL${C_RESET} $*"; }
info() { echo -e "  ${C_CYAN}....${C_RESET} $*"; }
header() { echo -e "\n${C_BOLD}[$1]${C_RESET} $2"; }

# ── Phase 0: Pre-flight ───────────────────────────────────────────────────────
phase0_preflight() {
  header "Phase 0" "Pre-flight checks"

  local errors=0

  if command -v claude &>/dev/null; then
    ok "claude CLI found"
  else
    fail "claude CLI not found. Install Claude Code first: https://claude.ai/code"
    errors=$((errors+1))
  fi

  if command -v git &>/dev/null; then
    ok "git found"
  else
    fail "git not found"
    errors=$((errors+1))
  fi

  if command -v bash &>/dev/null; then
    ok "bash $(bash --version | head -1 | grep -oP '\d+\.\d+')"
  fi

  if command -v python3 &>/dev/null; then
    ok "python3 found (used for JSON parsing in auditor)"
  else
    warn "python3 not found — auditor will use grep fallback for JSON parsing"
  fi

  if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Pre-flight failed. Resolve the issues above and re-run."
    exit 1
  fi
}

# ── Phase 1: Stack Detection ──────────────────────────────────────────────────
phase1_detect() {
  header "Phase 1" "Stack detection"

  source "$AIKIT_DIR/hooks/lib/detect.sh"
  detect_stack "."

  [[ "$STACK_JAVA" == true ]]           && ok "Java${STACK_SPRING_BOOT_VERSION:+ + Spring Boot $STACK_SPRING_BOOT_VERSION}  (pom.xml)"
  [[ "$STACK_SPRING_SECURITY" == true ]] && ok "Spring Security"
  [[ "$STACK_LOMBOK" == true ]]          && ok "Lombok"
  [[ "$STACK_MAPSTRUCT" == true ]]       && ok "MapStruct"
  [[ "$STACK_JPA" == true ]]             && ok "JPA / Hibernate"
  [[ "$STACK_JUNIT5" == true ]]          && ok "JUnit 5 + Mockito"
  [[ "$STACK_FLYWAY" == true ]]          && ok "Flyway migrations"
  [[ "$STACK_ANGULAR" == true ]]         && ok "Angular"
  [[ "$STACK_REACT" == true ]]           && ok "React"
  [[ "$STACK_TYPESCRIPT" == true ]]      && ok "TypeScript"
  [[ "$STACK_VITE" == true ]]            && ok "Vite"
  [[ "$STACK_POSTGRESQL" == true ]]      && ok "PostgreSQL"
  [[ "$STACK_DOCKER_COMPOSE" == true ]]  && ok "Docker Compose"
  [[ "$STACK_MULTIMODULE" == true ]]     && ok "Multi-module Maven (${STACK_MODULE_LIST})"
}

# ── Phase 2: CLAUDE.md ────────────────────────────────────────────────────────
phase2_claude_md() {
  header "Phase 2" "Generating CLAUDE.md"

  if [[ -f "CLAUDE.md" ]]; then
    echo -n "  CLAUDE.md already exists. Regenerate? [y/N] "
    read -r answer
    [[ "$answer" != "y" && "$answer" != "Y" ]] && info "Skipped CLAUDE.md generation" && return
  fi

  local tree
  tree=$(find . -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/target/*' \
    -not -path '*/.claude/*' -maxdepth 4 | sort | head -80 | sed 's|^\./||')

  local pom_snippet=""
  [[ -f "pom.xml" ]] && pom_snippet=$(head -60 pom.xml)

  local pkg_snippet=""
  [[ -f "package.json" ]] && pkg_snippet=$(cat package.json)

  info "Calling claude -p to generate CLAUDE.md..."

  claude -p "$(cat <<PROMPT
You are a technical writer. Generate a CLAUDE.md file for a software project based on the detected stack and project structure below. This file will be loaded by Claude Code as context for every AI session in this project.

## Detected Stack
Java: $STACK_JAVA
Spring Boot: $STACK_SPRING_BOOT (version: $STACK_SPRING_BOOT_VERSION)
Spring Security: $STACK_SPRING_SECURITY
Lombok: $STACK_LOMBOK
MapStruct: $STACK_MAPSTRUCT
JPA: $STACK_JPA
JUnit5: $STACK_JUNIT5
Flyway: $STACK_FLYWAY
Angular: $STACK_ANGULAR
React: $STACK_REACT
TypeScript: $STACK_TYPESCRIPT
Vite: $STACK_VITE
PostgreSQL: $STACK_POSTGRESQL
Docker Compose: $STACK_DOCKER_COMPOSE
Multi-module: $STACK_MULTIMODULE
Modules: $STACK_MODULE_LIST

## Project Tree
$tree

## pom.xml (excerpt)
$pom_snippet

## package.json
$pkg_snippet

## Instructions
Generate a CLAUDE.md with these sections, in this order:
1. # Project Overview — 2-3 sentences: what this project does and its main tech stack
2. ## Stack — bulleted list of key technologies with versions where detected
3. ## Architecture — annotated folder tree showing each layer's purpose (controller, service, repository, dto, entity, mapper for Java; features/, core/, shared/ for Angular; components/ for React)
4. ## Running the Project — exact shell commands to start services, run tests, build
5. ## Non-Negotiable Rules — 6-10 short imperative rules derived from the detected stack. Examples: "Never write getters/setters manually — use Lombok @Data", "Never put business logic in controllers", "Always use constructor injection via @RequiredArgsConstructor"
6. ## Adding a New Feature — numbered checklist specific to the detected architecture (e.g., for Spring Boot: entity → repository → service → controller → tests)
7. ## Testing — how to run unit tests, integration tests, and e2e tests with exact commands

Rules for writing:
- Be terse and imperative. No marketing language.
- Every line must be useful to an AI reading it before writing code.
- Target 200-350 lines total.
- Do not add sections not listed above.
- Do not add comments explaining the CLAUDE.md format itself.
PROMPT
)" > CLAUDE.md

  local size
  size=$(wc -c < CLAUDE.md)
  ok "CLAUDE.md written (${size} bytes)"
}

# ── Phase 3: settings.json ────────────────────────────────────────────────────
phase3_settings() {
  header "Phase 3" "Writing .claude/settings.json"

  mkdir -p .claude

  local existing="{}"
  [[ -f ".claude/settings.json" ]] && existing=$(cat .claude/settings.json)

  # Build permissions allow list based on stack
  local allow_list='"Bash(git *)"'
  [[ "$STACK_JAVA" == true ]]          && allow_list="$allow_list, \"Bash(./mvnw *)\", \"Bash(mvn *)\""
  [[ "$STACK_ANGULAR" == true ]]       && allow_list="$allow_list, \"Bash(ng *)\", \"Bash(npm *)\""
  [[ "$STACK_REACT" == true ]]         && allow_list="$allow_list, \"Bash(npm *)\", \"Bash(npx *)\""
  [[ "$STACK_VITE" == true ]]          && allow_list="$allow_list, \"Bash(npx vite *)\""
  [[ "$STACK_DOCKER_COMPOSE" == true ]] && allow_list="$allow_list, \"Bash(docker compose *)\""

  python3 - "$existing" "$allow_list" <<'PYEOF'
import sys, json

existing = json.loads(sys.argv[1]) if sys.argv[1] != '{}' else {}
allow_raw = sys.argv[2]

hooks = existing.get("hooks", {})
hooks["PreToolUse"] = [
    {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/auditor.sh"}]
    }
]
hooks["PostToolUse"] = [
    {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
            {"type": "command", "command": "bash .claude/hooks/post-java-write.sh"},
            {"type": "command", "command": "bash .claude/hooks/post-ts-write.sh"}
        ]
    }
]
hooks["SessionStart"] = [
    {"hooks": [{"type": "command", "command": "bash .claude/hooks/session-start.sh"}]}
]
hooks["Stop"] = [
    {"hooks": [{"type": "command", "command": "bash .claude/hooks/stop-test-reminder.sh"}]}
]

perms = existing.get("permissions", {})
existing_allow = perms.get("allow", [])
new_allow = [s.strip().strip('"') for s in allow_raw.split(",")]
merged_allow = list(dict.fromkeys(existing_allow + new_allow))
perms["allow"] = merged_allow

existing["hooks"] = hooks
existing["permissions"] = perms

print(json.dumps(existing, indent=2))
PYEOF
) > .claude/settings.json

  ok ".claude/settings.json written (PreToolUse + PostToolUse + SessionStart + Stop)"
}

# ── Phase 4: Slash Commands ───────────────────────────────────────────────────
phase4_commands() {
  header "Phase 4" "Installing slash commands"

  mkdir -p .claude/commands

  _install_command "review"
  _install_command "test"
  _install_command "secure"

  [[ "$STACK_JAVA" == true ]] && {
    _install_command "endpoint"
    _install_command "dto"
    [[ "$STACK_FLYWAY" == true ]] && _install_command "migration"
  }

  [[ "$STACK_ANGULAR" == true ]] && _install_command "component-angular"
  [[ "$STACK_REACT" == true ]]   && _install_command "component-react"
}

_install_command() {
  local name="$1"
  local src="$AIKIT_DIR/commands/${name}.md"
  local dest=".claude/commands/${name}.md"

  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
    ok "/project:${name}  → .claude/commands/${name}.md"
  fi
}

# ── Phase 5: Auditor ──────────────────────────────────────────────────────────
phase5_auditor() {
  header "Phase 5" "Installing Auditor (Quality & Security Hook)"

  mkdir -p .claude/hooks/lib .claude/hooks/logs

  local hook_src="$AIKIT_DIR/hooks"

  # PreToolUse: auditor
  cp "$hook_src/auditor.sh"              .claude/hooks/auditor.sh
  # PostToolUse: compile + type checks
  cp "$hook_src/post-java-write.sh"      .claude/hooks/post-java-write.sh
  cp "$hook_src/post-ts-write.sh"        .claude/hooks/post-ts-write.sh
  # SessionStart + Stop
  cp "$hook_src/session-start.sh"        .claude/hooks/session-start.sh
  cp "$hook_src/stop-test-reminder.sh"   .claude/hooks/stop-test-reminder.sh
  # Rule libraries
  cp "$hook_src/lib/detect.sh"           .claude/hooks/lib/detect.sh
  cp "$hook_src/lib/java_rules.sh"       .claude/hooks/lib/java_rules.sh
  cp "$hook_src/lib/frontend_rules.sh"   .claude/hooks/lib/frontend_rules.sh
  cp "$hook_src/lib/universal_rules.sh"  .claude/hooks/lib/universal_rules.sh
  cp "$hook_src/lib/custom_rules.sh"     .claude/hooks/lib/custom_rules.sh
  cp "$hook_src/lib/reporter.sh"         .claude/hooks/lib/reporter.sh

  chmod +x .claude/hooks/*.sh
  chmod +x .claude/hooks/lib/*.sh

  touch .claude/hooks/logs/audit.log

  ok "auditor.sh, post-java-write.sh, post-ts-write.sh  instalados"
  ok "session-start.sh, stop-test-reminder.sh           instalados"
  ok "lib/*.sh                                          instalados"

  # Copy .aikit-rules.yml example if none exists
  if [[ ! -f ".aikit-rules.yml" ]]; then
    cp "$AIKIT_DIR/aikit-rules.example.yml" ".aikit-rules.yml"
    ok ".aikit-rules.yml criado (edite para adicionar regras do time)"
  fi

  # Install smart-commit as a standalone script at project root
  cp "$hook_src/smart-commit.sh" "./smart-commit.sh"
  chmod +x "./smart-commit.sh"
  ok "smart-commit.sh instalado na raiz do projeto"

  # Self-test: run auditor with a harmless synthetic input
  local test_input='{"tool_name":"Write","tool_input":{"file_path":"test.txt","content":"hello world"}}'
  if echo "$test_input" | bash .claude/hooks/auditor.sh &>/dev/null; then
    ok "Auditor self-test: PASSED"
  else
    warn "Auditor self-test returned non-zero (check .claude/hooks/logs/audit.log)"
  fi
}

# ── Phase 6: Skills Recommendation ───────────────────────────────────────────
phase6_skills() {
  header "Phase 6" "Recommended Claude Code Skills"
  echo ""

  local has_rec=false

  if [[ "$STACK_SPRING_SECURITY" == true ]]; then
    echo -e "  ${C_CYAN}security-best-practices${C_RESET}"
    echo    "    Spring Security + JWT detected. Catches common auth pitfalls."
    echo    "    Use before implementing any auth, token handling, or API endpoint."
    has_rec=true
  fi

  if [[ "$STACK_REACT" == true ]]; then
    echo -e "  ${C_CYAN}react-best-practices${C_RESET}"
    echo    "    React 19 + Vite benefits from Vercel's performance guidelines."
    echo    "    Use for any component or hook work."
    has_rec=true
  fi

  if [[ "$STACK_ANGULAR" == true ]]; then
    echo -e "  ${C_CYAN}accessibility${C_RESET}"
    echo    "    WCAG 2.1 audit for Angular components."
    has_rec=true
  fi

  if [[ "$STACK_MULTIMODULE" == true ]]; then
    echo -e "  ${C_CYAN}technical-design-doc-creator${C_RESET}"
    echo    "    Multi-module project detected. Useful before starting new modules."
    has_rec=true
  fi

  if [[ "$STACK_JAVA" == true ]]; then
    echo -e "  ${C_CYAN}security-threat-model${C_RESET}"
    echo    "    Run once per project to map trust boundaries and attack surface."
    has_rec=true
  fi

  [[ "$has_rec" == false ]] && info "No specific skill recommendations for this stack."
}

# ── Entry Point ───────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${C_BOLD}AI Dev Kit v${AIKIT_VERSION}${C_RESET}"
  echo "================================"

  local cmd="${1:-help}"

  case "$cmd" in
    init)
      phase0_preflight
      phase1_detect
      phase2_claude_md
      phase3_settings
      phase4_commands
      phase5_auditor
      phase6_skills

      echo ""
      echo "================================"
      echo -e "${C_GREEN}Setup complete.${C_RESET}"
      echo "Start Claude Code in this directory: claude"
      echo "Run /project:review to validate the current codebase."
      ;;

    audit-test)
      # Run auditor manually against a file for testing
      local file="${2:-}"
      [[ -z "$file" ]] && echo "Usage: ai-kit.sh audit-test <file>" && exit 1
      local content
      content=$(cat "$file")
      echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$file\",\"content\":$(echo "$content" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}}" \
        | bash .claude/hooks/auditor.sh
      ;;

    commit)
      shift
      bash "$AIKIT_DIR/hooks/smart-commit.sh" "$@"
      ;;

    help|*)
      echo "Usage: bash ai-kit.sh <command>"
      echo ""
      echo "Commands:"
      echo "  init          Bootstrap AI tooling for the current project"
      echo "  audit-test    Run the auditor manually against a file"
      echo "  commit        Review staged diff, gerar mensagem e commitar"
      echo "                Flags: --push (faz push após commit), --dry-run"
      ;;
  esac
}

main "$@"
