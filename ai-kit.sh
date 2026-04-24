#!/usr/bin/env bash
# AI Dev Kit — Bootstrapper
# Usage: bash ai-kit.sh init
# Run from the root of your project.

set -euo pipefail

AIKIT_VERSION="1.0.0"
AIKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect working Python 3 — on Windows/Git Bash, python3 may be a Store stub
_detect_python() {
  if python3 -c "import sys; sys.exit(0)" 2>/dev/null; then echo "python3"
  elif python -c "import sys; sys.exit(0)" 2>/dev/null; then echo "python"
  else echo ""; fi
}
PYTHON_CMD="$(_detect_python)"

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

  if [[ -n "$PYTHON_CMD" ]]; then
    ok "$PYTHON_CMD found (used for JSON parsing in auditor)"
  else
    warn "python3/python not found — auditor will use grep fallback for JSON parsing"
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

  [[ "$STACK_JAVA" == true ]]           && ok "Java${STACK_SPRING_BOOT_VERSION:+ + Spring Boot $STACK_SPRING_BOOT_VERSION}  (pom.xml)" || true
  [[ "$STACK_SPRING_SECURITY" == true ]] && ok "Spring Security"   || true
  [[ "$STACK_LOMBOK" == true ]]          && ok "Lombok"            || true
  [[ "$STACK_MAPSTRUCT" == true ]]       && ok "MapStruct"         || true
  [[ "$STACK_JPA" == true ]]             && ok "JPA / Hibernate"   || true
  [[ "$STACK_JUNIT5" == true ]]          && ok "JUnit 5 + Mockito" || true
  [[ "$STACK_FLYWAY" == true ]]          && ok "Flyway migrations"  || true
  [[ "$STACK_ANGULAR" == true ]]         && ok "Angular"           || true
  [[ "$STACK_REACT" == true ]]           && ok "React"             || true
  [[ "$STACK_TYPESCRIPT" == true ]]      && ok "TypeScript"        || true
  [[ "$STACK_VITE" == true ]]            && ok "Vite"              || true
  [[ "$STACK_POSTGRESQL" == true ]]      && ok "PostgreSQL"        || true
  [[ "$STACK_KAFKA" == true ]]           && ok "Kafka"             || true
  [[ "$STACK_REDIS" == true ]]           && ok "Redis"             || true
  [[ "$STACK_KEYCLOAK" == true ]]        && ok "Keycloak"          || true
  [[ "$STACK_DOCKER_COMPOSE" == true ]]  && ok "Docker Compose"    || true
  [[ "$STACK_MULTIMODULE" == true ]]     && ok "Multi-module Maven (${STACK_MODULE_LIST})" || true
}

# ── Phase 2: Context files ────────────────────────────────────────────────────
phase2_claude_md() {
  header "Phase 2" "Generating context files"

  local ctx_dir=".claude/context"
  local already_exists=false
  [[ -f "CLAUDE.md" || -d "$ctx_dir" ]] && already_exists=true

  if [[ "$already_exists" == true ]]; then
    echo -n "  Context files already exist. Regenerate? [y/N] "
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
      info "Skipped context generation"
      return 0
    fi
  fi

  mkdir -p "$ctx_dir"

  local tree
  tree=$(find . -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/target/*' -not -path '*/.claude/*' -not -path '*/.aikit-specs/*' \
    -maxdepth 4 | sort | head -80 | sed 's|^\./||')

  local pom_snippet=""
  if [[ -f "pom.xml" ]]; then pom_snippet=$(head -60 pom.xml); fi

  local pkg_snippet=""
  if [[ -f "package.json" ]]; then pkg_snippet=$(cat package.json); fi

  local stack_flags="Java:$STACK_JAVA Spring Boot:$STACK_SPRING_BOOT($STACK_SPRING_BOOT_VERSION) Security:$STACK_SPRING_SECURITY Lombok:$STACK_LOMBOK MapStruct:$STACK_MAPSTRUCT JPA:$STACK_JPA JUnit5:$STACK_JUNIT5 Flyway:$STACK_FLYWAY Angular:$STACK_ANGULAR React:$STACK_REACT TypeScript:$STACK_TYPESCRIPT Vite:$STACK_VITE PostgreSQL:$STACK_POSTGRESQL Kafka:$STACK_KAFKA Redis:$STACK_REDIS Docker:$STACK_DOCKER_COMPOSE Multimodule:$STACK_MULTIMODULE"

  # ── stack.md ─────────────────────────────────────────────────────────────
  info "Generating .claude/context/stack.md..."
  claude -p "$(cat <<PROMPT
You are a technical writer. Generate ONLY the content for a stack.md file (~25 lines max).

## Detected Stack
$stack_flags

## pom.xml excerpt
$pom_snippet

## package.json
$pkg_snippet

## Instructions
Output ONLY this structure, nothing else:
# Stack

## Technologies
- [tech name] [version if known] — [one-line purpose]
(list every detected technology; skip false ones)

## Key versions
- [dependency]: [version]
(only if version is detectable from pom.xml or package.json; omit section if unknown)

## Commands
- Run: [exact command to start the app]
- Test: [exact command to run tests]
- Build: [exact command to build]

Rules: terse, imperative, no marketing. Every line useful to an AI writing code.
PROMPT
)" > "$ctx_dir/stack.md" || true

  local stack_size
  stack_size=$(wc -c < "$ctx_dir/stack.md" 2>/dev/null || echo 0)
  if [[ "$stack_size" -lt 50 ]]; then
    # Fallback: write minimal stack.md from detected flags
    {
      echo "# Stack"
      echo ""
      echo "## Technologies"
      [[ "$STACK_JAVA" == true ]]          && echo "- Java${STACK_SPRING_BOOT_VERSION:+ + Spring Boot $STACK_SPRING_BOOT_VERSION}"
      [[ "$STACK_SPRING_SECURITY" == true ]] && echo "- Spring Security"
      [[ "$STACK_LOMBOK" == true ]]        && echo "- Lombok"
      [[ "$STACK_MAPSTRUCT" == true ]]     && echo "- MapStruct"
      [[ "$STACK_JPA" == true ]]           && echo "- JPA / Hibernate"
      [[ "$STACK_JUNIT5" == true ]]        && echo "- JUnit 5 + Mockito"
      [[ "$STACK_FLYWAY" == true ]]        && echo "- Flyway"
      [[ "$STACK_ANGULAR" == true ]]       && echo "- Angular"
      [[ "$STACK_REACT" == true ]]         && echo "- React"
      [[ "$STACK_TYPESCRIPT" == true ]]    && echo "- TypeScript"
      [[ "$STACK_POSTGRESQL" == true ]]    && echo "- PostgreSQL"
      [[ "$STACK_KAFKA" == true ]]         && echo "- Kafka"
      [[ "$STACK_REDIS" == true ]]         && echo "- Redis"
      [[ "$STACK_DOCKER_COMPOSE" == true ]] && echo "- Docker Compose"
      echo ""
      echo "## Commands"
      [[ "$STACK_JAVA" == true ]]    && echo "- Run:   ./mvnw spring-boot:run"
      [[ "$STACK_JAVA" == true ]]    && echo "- Test:  ./mvnw test"
      [[ "$STACK_JAVA" == true ]]    && echo "- Build: ./mvnw package -DskipTests"
      [[ "$STACK_ANGULAR" == true ]] && echo "- Run:   ng serve"
      [[ "$STACK_ANGULAR" == true ]] && echo "- Test:  ng test"
      [[ "$STACK_REACT" == true ]]   && echo "- Run:   npm run dev"
      [[ "$STACK_REACT" == true ]]   && echo "- Test:  npm test"
      [[ "$STACK_DOCKER_COMPOSE" == true ]] && echo "- Docker: docker compose up -d"
    } > "$ctx_dir/stack.md"
  fi
  ok "stack.md ($(wc -c < "$ctx_dir/stack.md") bytes)"

  # ── architecture.md ───────────────────────────────────────────────────────
  info "Generating .claude/context/architecture.md..."
  claude -p "$(cat <<PROMPT
You are a technical writer. Generate ONLY the content for an architecture.md file (~40 lines max).

## Project tree
$tree

## Stack
$stack_flags

## Instructions
Output ONLY this structure:
# Architecture

## Folder structure
[annotated tree of the main source directories]
Show each folder with a short comment explaining its purpose.
For Java/Spring: show controller, service, repository, entity, dto, mapper layers.
For Angular: show features/, core/, shared/ structure.
For React: show components/, hooks/, pages/ or similar.
Skip build output folders (target/, dist/, node_modules/).
Max 30 lines for the tree.

## Layer responsibilities
- [LayerName]: [one sentence on what belongs here]
(list all architectural layers: controller, service, repository, dto, entity, etc.)

Rules: terse, imperative, no marketing. Every line useful to an AI writing code.
PROMPT
)" > "$ctx_dir/architecture.md" || true

  local arch_size
  arch_size=$(wc -c < "$ctx_dir/architecture.md" 2>/dev/null || echo 0)
  if [[ "$arch_size" -lt 50 ]]; then
    {
      echo "# Architecture"
      echo ""
      echo "## Folder structure"
      echo "$tree" | head -30 | sed 's/^/  /'
      echo ""
      echo "## Layer responsibilities"
      [[ "$STACK_JAVA" == true ]] && cat <<'LAYERS'
- controller: HTTP endpoints, request/response mapping only — no business logic
- service: business logic, transaction boundaries
- repository: JPA queries, database access only
- entity: JPA entities — no business logic, no DTOs
- dto: request/response data classes — no JPA annotations
- mapper: MapStruct interfaces for entity ↔ DTO conversion
LAYERS
    } > "$ctx_dir/architecture.md"
  fi
  ok "architecture.md ($(wc -c < "$ctx_dir/architecture.md") bytes)"

  # ── rules.md ──────────────────────────────────────────────────────────────
  info "Generating .claude/context/rules.md..."
  claude -p "$(cat <<PROMPT
You are a senior software engineer. Generate ONLY the content for a rules.md file (~25 lines max).

## Stack
$stack_flags

## Instructions
Output ONLY this structure:
# Non-Negotiable Rules

- [imperative rule — one line each]
(8-12 rules total, derived from the detected stack)

Examples for Spring Boot:
- Never write getters/setters manually — use Lombok @Data or @Value
- Never put business logic in controllers — delegate to @Service
- Always use constructor injection via @RequiredArgsConstructor
- Every public endpoint must have @PreAuthorize or explicit permit

Examples for Angular:
- Never use document.getElementById — use @ViewChild with ElementRef
- Always unsubscribe with takeUntilDestroyed() or async pipe

Rules for writing: imperative tone, no explanations, no marketing. One rule per line.
Only include rules relevant to the detected stack.
PROMPT
)" > "$ctx_dir/rules.md" || true

  local rules_size
  rules_size=$(wc -c < "$ctx_dir/rules.md" 2>/dev/null || echo 0)
  if [[ "$rules_size" -lt 50 ]]; then
    {
      echo "# Non-Negotiable Rules"
      echo ""
      [[ "$STACK_JAVA" == true ]] && cat <<'RULES'
- Never write getters/setters manually — use Lombok @Data or @Value
- Never put business logic in controllers — delegate to @Service
- Always use constructor injection via @RequiredArgsConstructor
- Every public REST endpoint must have @PreAuthorize or explicit permit
- Never use System.out.println — use SLF4J Logger
- Never catch (Exception e) — catch specific exceptions or rethrow
- JPA entities never expose DTOs — use MapStruct mappers
- @Transactional only on public service methods — not on private ones
RULES
      [[ "$STACK_ANGULAR" == true ]] && cat <<'RULES'
- Never use document.getElementById — use @ViewChild with ElementRef
- Always unsubscribe with takeUntilDestroyed() or async pipe
- No TypeScript `any` — define proper interfaces or use `unknown`
- Never hardcode route strings — use a typed Routes constant
RULES
      [[ "$STACK_REACT" == true ]] && cat <<'RULES'
- No TypeScript `any` — define proper interfaces or use `unknown`
- Every useEffect must declare its dependency array
- No direct DOM manipulation — use refs
RULES
    } > "$ctx_dir/rules.md"
  fi
  ok "rules.md ($(wc -c < "$ctx_dir/rules.md") bytes)"

  # ── CLAUDE.md index ───────────────────────────────────────────────────────
  cat > "CLAUDE.md" <<'CLAUDEMD'
# Project Context

@.claude/context/stack.md
@.claude/context/architecture.md
@.claude/context/rules.md

<!-- If a task is active, TASK.md will appear here automatically -->
CLAUDEMD

  # Append TASK.md import if a spec is active
  if [[ -f ".aikit-specs/.active-spec" ]]; then
    echo "" >> CLAUDE.md
    echo "@TASK.md" >> CLAUDE.md
  fi

  echo ""
  ok "CLAUDE.md → thin index (imports stack.md + architecture.md + rules.md)"
  info "Edit .claude/context/*.md to customize the context for this project"
  echo ""
}

# ── Phase 3: settings.json ────────────────────────────────────────────────────
phase3_settings() {
  header "Phase 3" "Writing .claude/settings.json"

  mkdir -p .claude

  local existing="{}"
  if [[ -f ".claude/settings.json" ]]; then existing=$(cat .claude/settings.json); fi

  # Build permissions allow list based on stack
  local allow_list='"Bash(git *)"'
  if [[ "$STACK_JAVA" == true ]];          then allow_list="$allow_list, \"Bash(./mvnw *)\", \"Bash(mvn *)\""; fi
  if [[ "$STACK_ANGULAR" == true ]];       then allow_list="$allow_list, \"Bash(ng *)\", \"Bash(npm *)\""; fi
  if [[ "$STACK_REACT" == true ]];         then allow_list="$allow_list, \"Bash(npm *)\", \"Bash(npx *)\""; fi
  if [[ "$STACK_VITE" == true ]];          then allow_list="$allow_list, \"Bash(npx vite *)\""; fi
  if [[ "$STACK_DOCKER_COMPOSE" == true ]]; then allow_list="$allow_list, \"Bash(docker compose *)\""; fi

  ("${PYTHON_CMD:-python3}" - "$existing" "$allow_list" <<'PYEOF'
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

  if [[ "$STACK_JAVA" == true ]]; then
    _install_command "endpoint"
    _install_command "dto"
    if [[ "$STACK_FLYWAY" == true ]]; then _install_command "migration"; fi
  fi

  if [[ "$STACK_ANGULAR" == true ]]; then _install_command "component-angular"; fi
  if [[ "$STACK_REACT" == true ]];   then _install_command "component-react";   fi

  # Always install generic commands
  _install_command "refactor"
  _install_command "debug"
  _install_command "pr"
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
  cp "$hook_src/lib/python_cmd.sh"       .claude/hooks/lib/python_cmd.sh
  cp "$hook_src/lib/reporter.sh"         .claude/hooks/lib/reporter.sh

  chmod +x .claude/hooks/*.sh
  chmod +x .claude/hooks/lib/*.sh

  touch .claude/hooks/logs/audit.log

  ok "auditor.sh, post-java-write.sh, post-ts-write.sh  installed"
  ok "session-start.sh, stop-test-reminder.sh           installed"
  ok "lib/*.sh                                          installed"

  # Copy .aikit-rules.yml example if none exists
  if [[ ! -f ".aikit-rules.yml" ]]; then
    cp "$AIKIT_DIR/aikit-rules.example.yml" ".aikit-rules.yml"
    ok ".aikit-rules.yml created (edit to add your team's custom rules)"
  fi

  # Copy .aikit-ignore example if none exists
  if [[ ! -f ".aikit-ignore" ]]; then
    cp "$AIKIT_DIR/.aikit-ignore.example" ".aikit-ignore"
    ok ".aikit-ignore created (add rule IDs to suppress globally)"
  fi

  # Install smart-commit as a standalone script at project root
  cp "$hook_src/smart-commit.sh" "./smart-commit.sh"
  chmod +x "./smart-commit.sh"
  ok "smart-commit.sh installed at project root"

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

  if [[ "$STACK_KAFKA" == true ]]; then
    echo -e "  ${C_CYAN}technical-design-doc-creator${C_RESET}"
    echo    "    Kafka detected. Document consumer/producer contracts before implementing."
    has_rec=true
  fi

  if [[ "$STACK_KEYCLOAK" == true ]]; then
    echo -e "  ${C_CYAN}security-best-practices${C_RESET}"
    echo    "    Keycloak detected. Review token validation, realm config, and role mapping."
    has_rec=true
  fi

  if [[ "$has_rec" == false ]]; then info "No specific skill recommendations for this stack."; fi
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
      echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$file\",\"content\":$(echo "$content" | "${PYTHON_CMD:-python3}" -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}}" \
        | AIKIT_AUDIT_TEST=true bash .claude/hooks/auditor.sh
      ;;

    commit)
      shift
      bash "$AIKIT_DIR/hooks/smart-commit.sh" "$@"
      ;;

    update)
      _cmd_update
      ;;

    doctor)
      _cmd_doctor
      ;;

    audit-report)
      _cmd_audit_report "${2:-}"
      ;;

    stats)
      _cmd_stats
      ;;

    install-git-hook)
      _cmd_install_git_hook
      ;;

    spec)
      local subcmd="${2:-help}"
      case "$subcmd" in
        new)     _cmd_spec_new        "${@:3}" ;;
        approve) _cmd_spec_approve   "${3:-}" ;;
        start)   _cmd_spec_start     "${3:-}" ;;
        check)   _cmd_spec_check     "${3:-}" ;;
        update)  _cmd_spec_update    "${3:-}" "${4:-}" ;;
        review)  _cmd_spec_review    "${3:-}" ;;
        close)   _cmd_spec_close     "${@:3}" ;;
        list)    _cmd_spec_list ;;
        show)    _cmd_spec_show      "${3:-}" ;;
        *)
          echo "Usage: ai-kit spec <subcommand>"
          echo ""
          echo "Subcommands:"
          echo "  new [description]        Create a new spec file"
          echo "  approve <id>             Validate and approve a spec"
          echo "  start <id>               Activate spec, generate TASK.md"
          echo "  check [id]               Show progress without AI (fast)"
          echo "  update add-file [path]   Add a file to spec scope"
          echo "  update add-task [desc]   Add a task to spec checklist"
          echo "  update tick [n|keyword]  Mark a checklist task as done"
          echo "  review [id]              AI review of implementation vs spec"
          echo "  close [id]               Review + archive spec with commit links"
          echo "  list                     List all specs"
          echo "  show <id>                Print a spec"
          ;;
      esac
      ;;

    tui)
      _cmd_tui
      ;;

    upgrade)
      _cmd_upgrade
      ;;

    help|*)
      echo "Usage: bash ai-kit.sh <command>"
      echo ""
      echo "Commands:"
      echo "  init                   Bootstrap AI tooling for the current project"
      echo "  update                 Update hooks and commands from the ai-dev-kit repo"
      echo "  doctor                 Diagnose hook installation and configuration"
      echo "  tui                    Open the interactive terminal UI"
      echo "  upgrade                Pull latest ai-dev-kit and reapply hooks"
      echo "  stats                  Show audit statistics from audit.log"
      echo "  audit-test <file>      Run the auditor manually against a file"
      echo "  audit-report [file]    Generate a markdown report from audit.log"
      echo "  install-git-hook       Install auditor as a git pre-commit hook"
      echo "  commit                 Review staged diff, generate commit message and commit"
      echo "                         Flags: --push, --dry-run, --no-review"
      echo "  spec new [description]       Create a spec for a task"
      echo "  spec approve <id>            Approve a spec for implementation"
      echo "  spec start <id>              Activate spec and generate TASK.md"
      echo "  spec check [id]              Show progress without AI (fast)"
      echo "  spec update add-file [path]  Add a file to spec scope"
      echo "  spec update add-task [desc]  Add a task to spec checklist"
      echo "  spec update tick [n|kw]      Mark a checklist task as done"
      echo "  spec review [id]             AI review of implementation vs spec"
      echo "  spec close [id]              Review + archive with commit links"
      echo "  spec list                    List all specs"
      echo "  spec show <id>               Print a spec"
      ;;
  esac
}

# ── Command: upgrade ─────────────────────────────────────────────────────────
_cmd_upgrade() {
  header "upgrade" "Upgrading AI Dev Kit"

  if ! git -C "$AIKIT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
    fail "AI Dev Kit directory is not a git repo: $AIKIT_DIR"
    fail "Clone it from GitHub to enable upgrades."
    exit 1
  fi

  local before
  before=$(git -C "$AIKIT_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")

  local branch
  branch=$(git -C "$AIKIT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

  info "Pulling latest changes on branch '$branch'..."
  if ! git -C "$AIKIT_DIR" pull; then
    fail "git pull failed — resolve conflicts manually in $AIKIT_DIR"
    exit 1
  fi

  local after
  after=$(git -C "$AIKIT_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")

  if [[ "$before" == "$after" ]]; then
    ok "Already up to date."
  else
    ok "Updated: ${before:0:7} → ${after:0:7}"
    git -C "$AIKIT_DIR" log --oneline "${before}..${after}" 2>/dev/null | while read -r line; do
      info "  $line"
    done
  fi

  # Reapply hooks to current project if initialized
  if [[ -d ".claude/hooks" ]]; then
    echo ""
    info "Reapplying hooks to current project..."
    _cmd_update
  else
    echo ""
    info "No .claude/hooks found in current directory — run 'ai-kit init' to initialize."
  fi
}

# ── Command: update ───────────────────────────────────────────────────────────
_cmd_update() {
  header "update" "Updating AI Dev Kit hooks and commands"

  if [[ ! -d ".claude/hooks" ]]; then
    fail "No .claude/hooks directory found. Run 'ai-kit init' first."
    exit 1
  fi

  local hook_src="$AIKIT_DIR/hooks"

  # Update hook scripts
  cp "$hook_src/auditor.sh"              .claude/hooks/auditor.sh
  cp "$hook_src/post-java-write.sh"      .claude/hooks/post-java-write.sh
  cp "$hook_src/post-ts-write.sh"        .claude/hooks/post-ts-write.sh
  cp "$hook_src/session-start.sh"        .claude/hooks/session-start.sh
  cp "$hook_src/stop-test-reminder.sh"   .claude/hooks/stop-test-reminder.sh
  cp "$hook_src/lib/detect.sh"           .claude/hooks/lib/detect.sh
  cp "$hook_src/lib/java_rules.sh"       .claude/hooks/lib/java_rules.sh
  cp "$hook_src/lib/frontend_rules.sh"   .claude/hooks/lib/frontend_rules.sh
  cp "$hook_src/lib/universal_rules.sh"  .claude/hooks/lib/universal_rules.sh
  cp "$hook_src/lib/custom_rules.sh"     .claude/hooks/lib/custom_rules.sh
  cp "$hook_src/lib/reporter.sh"         .claude/hooks/lib/reporter.sh
  chmod +x .claude/hooks/*.sh .claude/hooks/lib/*.sh
  ok "Hooks updated"

  # Update slash commands (preserve user-created ones)
  mkdir -p .claude/commands
  for cmd_file in "$AIKIT_DIR"/commands/*.md; do
    local name
    name=$(basename "$cmd_file")
    cp "$cmd_file" ".claude/commands/$name"
  done
  ok "Slash commands updated"

  # Update smart-commit
  cp "$hook_src/smart-commit.sh" "./smart-commit.sh"
  chmod +x "./smart-commit.sh"
  ok "smart-commit.sh updated"

  # Invalidate stack cache so next session re-detects
  rm -f ".claude/hooks/.stack-cache"
  ok "Stack cache cleared"

  echo ""
  echo -e "${C_GREEN}Update complete.${C_RESET} Restart Claude Code to apply changes."
}

# ── Command: doctor ───────────────────────────────────────────────────────────
_cmd_doctor() {
  header "doctor" "Diagnosing AI Dev Kit installation"

  local errors=0
  local warnings=0

  # Check required tools
  echo ""
  echo "  Dependencies"
  command -v claude   &>/dev/null && ok "claude CLI"    || { fail "claude CLI not found";  errors=$((errors+1)); }
  command -v git      &>/dev/null && ok "git"           || { fail "git not found";          errors=$((errors+1)); }
  [[ -n "$PYTHON_CMD" ]] && ok "$PYTHON_CMD" || { warn "python3/python not found (auditor will use grep fallback)"; warnings=$((warnings+1)); }
  command -v jq       &>/dev/null && ok "jq"            || warn "jq not found (grep fallback active)"

  # Check hook files
  echo ""
  echo "  Hook files"
  local hooks=(
    ".claude/hooks/auditor.sh"
    ".claude/hooks/post-java-write.sh"
    ".claude/hooks/post-ts-write.sh"
    ".claude/hooks/session-start.sh"
    ".claude/hooks/stop-test-reminder.sh"
    ".claude/hooks/lib/detect.sh"
    ".claude/hooks/lib/java_rules.sh"
    ".claude/hooks/lib/frontend_rules.sh"
    ".claude/hooks/lib/universal_rules.sh"
    ".claude/hooks/lib/custom_rules.sh"
    ".claude/hooks/lib/reporter.sh"
  )
  for h in "${hooks[@]}"; do
    if [[ -f "$h" ]]; then
      [[ -x "$h" ]] && ok "$h" || { warn "$h exists but is not executable"; warnings=$((warnings+1)); }
    else
      fail "$h missing"
      errors=$((errors+1))
    fi
  done

  # Check settings.json
  echo ""
  echo "  settings.json"
  if [[ -f ".claude/settings.json" ]]; then
    if grep -q "auditor.sh" ".claude/settings.json" 2>/dev/null; then
      ok "PreToolUse hook registered"
    else
      fail "auditor.sh not found in .claude/settings.json"
      errors=$((errors+1))
    fi
    grep -q "post-java-write" ".claude/settings.json" && ok "PostToolUse hooks registered" || warn "PostToolUse hooks not found"
  else
    fail ".claude/settings.json not found"
    errors=$((errors+1))
  fi

  # Check audit log
  echo ""
  echo "  Logs"
  if [[ -f ".claude/hooks/logs/audit.log" ]]; then
    local count
    count=$(wc -l < ".claude/hooks/logs/audit.log" | tr -d ' ')
    ok "audit.log exists ($count entries)"
  else
    warn "audit.log not found (will be created on first write)"
  fi

  # Validate .aikit-rules.yml
  echo ""
  echo "  .aikit-rules.yml"
  if [[ -f ".aikit-rules.yml" ]]; then
    if [[ -n "$PYTHON_CMD" ]]; then
      local validate_result
      validate_result=$("${PYTHON_CMD:-python3}" - ".aikit-rules.yml" <<'PYEOF' 2>&1
import sys, re
rules_file = sys.argv[1]
errors = []
try:
    with open(rules_file) as f:
        content = f.read()
    current = {}
    in_rules = False
    rule_num = 0
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
                if 'pattern' in current:
                    try:
                        re.compile(current['pattern'])
                    except re.error as e:
                        errors.append(f"Rule {current.get('id','?')}: invalid regex — {e}")
            current = {'id': stripped.split(':', 1)[1].strip()}
            rule_num += 1
        elif stripped.startswith('severity:'):
            sev = stripped.split(':', 1)[1].strip().strip('"\'')
            if sev not in ('CRITICAL','HIGH','MEDIUM','LOW'):
                errors.append(f"Rule {current.get('id','?')}: invalid severity '{sev}'")
            current['severity'] = sev
        elif stripped.startswith('pattern:'):
            current['pattern'] = stripped.split(':', 1)[1].strip().strip('"\'')
    if current and 'pattern' in current:
        try:
            re.compile(current['pattern'])
        except re.error as e:
            errors.append(f"Rule {current.get('id','?')}: invalid regex — {e}")
    if errors:
        print('ERRORS:' + '|'.join(errors))
    else:
        print(f'OK:{rule_num}')
except Exception as e:
    print(f'ERRORS:Parse error — {e}')
PYEOF
)
      if echo "$validate_result" | grep -q "^OK:"; then
        local rc
        rc=$(echo "$validate_result" | grep -oP '(?<=OK:)\d+')
        ok "$rc rule(s) — YAML valid, all regex patterns compile"
      else
        echo "$validate_result" | grep -oP '(?<=ERRORS:).*' | tr '|' '\n' | while read -r e; do
          fail "$e"
          errors=$((errors+1))
        done
      fi
    else
      warn "python3/python not found — skipping .aikit-rules.yml validation"
    fi
  else
    warn ".aikit-rules.yml not found (optional — skipping)"
  fi

  # Auditor self-test
  echo ""
  echo "  Auditor self-test"
  local test_input='{"tool_name":"Write","tool_input":{"file_path":"test.txt","content":"hello world"}}'
  if echo "$test_input" | bash .claude/hooks/auditor.sh &>/dev/null; then
    ok "Safe input: allowed (exit 0)"
  else
    fail "Auditor returned non-zero on safe input"
    errors=$((errors+1))
  fi

  # Test that a known-bad input is blocked
  local bad_input='{"tool_name":"Write","tool_input":{"file_path":"test.java","content":"String q = \"SELECT * FROM users WHERE id = \" + id;"}}'
  if echo "$bad_input" | bash .claude/hooks/auditor.sh &>/dev/null; then
    warn "SQL Injection input was NOT blocked (J-001 may be disabled)"
    warnings=$((warnings+1))
  else
    ok "Known-bad input: blocked (exit 1)"
  fi

  # Summary
  echo ""
  echo "================================"
  if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
    echo -e "${C_GREEN}All checks passed.${C_RESET}"
  elif [[ $errors -eq 0 ]]; then
    echo -e "${C_YELLOW}$warnings warning(s). No blocking errors.${C_RESET}"
  else
    echo -e "${C_RED}$errors error(s), $warnings warning(s). Run 'ai-kit init' to repair.${C_RESET}"
  fi
}

# ── Command: audit-report ─────────────────────────────────────────────────────
_cmd_audit_report() {
  local output_file="${1:-audit-report.md}"
  local log=".claude/hooks/logs/audit.log"

  if [[ ! -f "$log" ]]; then
    fail "audit.log not found at $log"
    exit 1
  fi

  info "Generating audit report from $log..."

  local total critical high medium low
  total=$(wc -l < "$log" | tr -d ' ')
  critical=$(grep -c "|CRITICAL|" "$log" 2>/dev/null || echo 0)
  high=$(grep -c "|HIGH|" "$log" 2>/dev/null || echo 0)
  medium=$(grep -c "|MEDIUM|" "$log" 2>/dev/null || echo 0)
  low=$(grep -c "|LOW|" "$log" 2>/dev/null || echo 0)

  {
    echo "# AI Dev Kit — Audit Report"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Severity | Count |"
    echo "|----------|-------|"
    echo "| CRITICAL | $critical |"
    echo "| HIGH     | $high |"
    echo "| MEDIUM   | $medium |"
    echo "| LOW      | $low |"
    echo "| **Total**| **$total** |"
    echo ""

    if [[ "$critical" -gt 0 || "$high" -gt 0 ]]; then
      echo "## Critical & High Findings"
      echo ""
      echo "| Date | Rule | File | Line | Message |"
      echo "|------|------|------|------|---------|"
      grep -E "\|(CRITICAL|HIGH)\|" "$log" 2>/dev/null | while IFS='|' read -r date sev rule file line msg _; do
        echo "| $date | \`$rule\` | \`$file\` | $line | $msg |"
      done
      echo ""
    fi

    if [[ "$medium" -gt 0 ]]; then
      echo "## Medium Findings"
      echo ""
      echo "| Date | Rule | File | Line | Message |"
      echo "|------|------|------|------|---------|"
      grep "|MEDIUM|" "$log" 2>/dev/null | while IFS='|' read -r date sev rule file line msg _; do
        echo "| $date | \`$rule\` | \`$file\` | $line | $msg |"
      done
      echo ""
    fi

    echo "## Most Frequent Rules"
    echo ""
    echo "| Rule | Count |"
    echo "|------|-------|"
    grep -oP '(?<=\|)[A-Z]-\d+(?=\|)' "$log" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | \
      while read -r count rule; do echo "| \`$rule\` | $count |"; done
    echo ""
    echo "_Report generated by [AI Dev Kit](https://github.com/jeffev/ai-dev-kit)_"
  } > "$output_file"

  ok "Report written to $output_file ($total total findings)"
}

# ── Command: stats ────────────────────────────────────────────────────────────
_cmd_stats() {
  local log=".claude/hooks/logs/audit.log"

  if [[ ! -f "$log" || ! -s "$log" ]]; then
    info "No audit.log found or file is empty."
    exit 0
  fi

  header "stats" "Audit statistics"

  local total critical high medium low
  total=$(wc -l < "$log" | tr -d ' ')
  critical=$(grep -c "|CRITICAL|" "$log" 2>/dev/null || echo 0)
  high=$(grep -c "|HIGH|" "$log" 2>/dev/null || echo 0)
  medium=$(grep -c "|MEDIUM|" "$log" 2>/dev/null || echo 0)
  low=$(grep -c "|LOW|" "$log" 2>/dev/null || echo 0)

  echo ""
  echo "  Findings by severity"
  echo "  ├─ CRITICAL : $critical"
  echo "  ├─ HIGH     : $high"
  echo "  ├─ MEDIUM   : $medium"
  echo "  ├─ LOW      : $low"
  echo "  └─ TOTAL    : $total"

  echo ""
  echo "  Top rules triggered"
  grep -oP '(?<=\|)[A-Z]-\d+(?=\|)' "$log" 2>/dev/null | sort | uniq -c | sort -rn | head -8 | \
    while read -r count rule; do
      printf "  ├─ %-8s %s finding(s)\n" "$rule" "$count"
    done

  echo ""
  echo "  Most affected files"
  grep -oP '(?<=\|)[^|]+(?=\|\d+\|)' "$log" 2>/dev/null | sort | uniq -c | sort -rn | head -5 | \
    while read -r count file; do
      printf "  ├─ %s  (%s finding(s))\n" "$(basename "$file")" "$count"
    done

  echo ""
  echo "  Activity by day (last 7 days)"
  for i in 6 5 4 3 2 1 0; do
    local day
    day=$(date -d "$i days ago" '+%Y-%m-%d' 2>/dev/null || date -v-${i}d '+%Y-%m-%d' 2>/dev/null || echo "")
    [[ -z "$day" ]] && continue
    local count
    count=$(grep -c "$day" "$log" 2>/dev/null || echo 0)
    local bar
    bar=$(printf '%0.s#' $(seq 1 $((count > 40 ? 40 : count))))
    printf "  %s  %3d  %s\n" "$day" "$count" "$bar"
  done

  echo ""
}

# ── Command: tui ─────────────────────────────────────────────────────────────
_cmd_tui() {
  local tui_script="$AIKIT_DIR/tui/aikit_tui.py"

  if [[ ! -f "$tui_script" ]]; then
    fail "TUI script not found: $tui_script"
    fail "Try: ai-kit update"
    exit 1
  fi

  # Ensure textual is installed
  if ! "${PYTHON_CMD:-python3}" -c "import textual" 2>/dev/null; then
    info "Installing textual (one-time)…"
    "${PYTHON_CMD:-python3}" -m pip install textual --quiet || {
      fail "Could not install textual. Run: pip install textual"
      exit 1
    }
    ok "textual installed."
  fi

  local launch_file="$HOME/.aikit-claude-launch"
  rm -f "$launch_file"

  while true; do
    AIKIT_SCRIPT="$(cd "$AIKIT_DIR" && pwd)/ai-kit.sh" \
      "${PYTHON_CMD:-python3}" "$tui_script"

    # Check if TUI exited to launch Claude
    if [[ -f "$launch_file" ]]; then
      local project_dir claude_prompt
      project_dir=$(head -1 "$launch_file")
      claude_prompt=$(tail -n +2 "$launch_file")
      rm -f "$launch_file"

      echo ""
      info "Launching Claude Code in: $project_dir"
      echo ""

      if command -v claude &>/dev/null; then
        (cd "$project_dir" && claude "$claude_prompt")
      else
        warn "claude CLI not found — install Claude Code first."
      fi

      echo ""
      info "Returning to AI Dev Kit TUI…"
      echo ""
      # Loop continues → relaunches TUI
    else
      break
    fi
  done
}

# ── Command: install-git-hook ─────────────────────────────────────────────────
_cmd_install_git_hook() {
  header "install-git-hook" "Installing auditor as git pre-commit hook"

  if ! git rev-parse --git-dir &>/dev/null 2>&1; then
    fail "Not a git repository."
    exit 1
  fi

  if [[ ! -f ".claude/hooks/auditor.sh" ]]; then
    fail ".claude/hooks/auditor.sh not found. Run 'ai-kit init' first."
    exit 1
  fi

  local hook_file=".git/hooks/pre-commit"

  if [[ -f "$hook_file" ]]; then
    if grep -q "ai-dev-kit\|aikit\|auditor" "$hook_file" 2>/dev/null; then
      ok "AI Dev Kit pre-commit hook already installed."
      exit 0
    fi
    warn "Existing pre-commit hook found — appending AI Dev Kit block."
    echo "" >> "$hook_file"
  else
    printf '#!/usr/bin/env bash\n' > "$hook_file"
    chmod +x "$hook_file"
  fi

  cat >> "$hook_file" <<'HOOK'

# ── AI Dev Kit — pre-commit auditor ──────────────────────────────────────────
# Runs the auditor on every staged file before committing.
# To skip: git commit --no-verify
if [[ -f ".claude/hooks/auditor.sh" ]]; then
  BLOCKED=0
  while IFS= read -r staged_file; do
    [[ -f "$staged_file" ]] || continue
    CONTENT=$(git show ":$staged_file" 2>/dev/null) || continue
    INPUT=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s}}' \
      "$staged_file" "$(echo "$CONTENT" | "${PYTHON_CMD:-python3}" -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '""')")
    if ! echo "$INPUT" | bash .claude/hooks/auditor.sh; then
      BLOCKED=$((BLOCKED + 1))
    fi
  done < <(git diff --cached --name-only)
  if [[ "$BLOCKED" -gt 0 ]]; then
    echo ""
    echo "[pre-commit] $BLOCKED file(s) blocked by AI Dev Kit auditor."
    echo "[pre-commit] Fix the issues above or use --no-verify to skip."
    exit 1
  fi
fi
# ── end AI Dev Kit ────────────────────────────────────────────────────────────
HOOK

  ok "Pre-commit hook installed at $hook_file"
  info "The auditor will now run on every git commit."
  info "To bypass: git commit --no-verify"
}

# ── Spec helpers ─────────────────────────────────────────────────────────────

SPEC_DIR=".aikit-specs"

_spec_next_id() {
  local counter_file="$SPEC_DIR/.spec-counter"
  local n=1
  if [[ -f "$counter_file" ]]; then
    n=$(cat "$counter_file")
    n=$((n + 1))
  fi
  echo "$n" > "$counter_file"
  printf "SPEC-%03d" "$n"
}

_spec_slug() {
  echo "$*" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-40
}

_spec_find_file() {
  local id="$1"
  local f
  f=$(find "$SPEC_DIR" -name "${id}-*.md" 2>/dev/null | head -1)
  echo "$f"
}

_spec_get_status() {
  local file="$1"
  grep -oP '(?<=^## Status\n).*' "$file" 2>/dev/null || \
    awk '/^## Status/{getline; print}' "$file" | tr -d '[:space:]'
}

_spec_set_status() {
  local file="$1"
  local new_status="$2"
  local current
  current=$(_spec_get_status "$file")
  sed -i "s/^$current$/$new_status/" "$file"
}

_spec_extract_section() {
  local file="$1"
  local section="$2"
  awk "/^## $section/{found=1; next} found && /^## /{exit} found{print}" "$file"
}

_spec_context_from_claude_md() {
  if [[ ! -f "CLAUDE.md" ]]; then echo ""; return; fi
  awk '/^## Stack/{p=1} /^## Architecture/{p=1} /^## (Running|Non-Negotiable|Adding|Testing)/{p=0} p{print}' CLAUDE.md | head -60
}

# ── Command: spec new ─────────────────────────────────────────────────────────
_cmd_spec_new() {
  header "spec new" "Creating a new spec"

  local description="$*"

  if [[ -z "$description" ]]; then
    echo -n "  Describe the task: "
    read -r description
  fi

  [[ -z "$description" ]] && fail "Description is required." && exit 1

  mkdir -p "$SPEC_DIR/active" "$SPEC_DIR/done"

  local id
  id=$(_spec_next_id)
  local slug
  slug=$(_spec_slug "$description")
  local filename="${id}-${slug}.md"
  local filepath="$SPEC_DIR/active/$filename"

  local stack_context
  stack_context=$(_spec_context_from_claude_md)

  info "Calling claude -p to draft spec..."

  local spec_content
  spec_content=$(claude -p "$(cat <<PROMPT
You are a senior software engineer writing a concise task spec.

## Project context
$stack_context

## Task description
$description

## Instructions
Generate a spec file in EXACTLY this markdown format. Fill every section based on the task description and project context. Be specific and concrete. If you don't have enough info for a section, write a clear placeholder in brackets.

# ${id} — ${description}

## Status
draft

## What
[One sentence: the specific deliverable, e.g. "Add GET /users/search?email= endpoint returning paginated UserSummaryDTO list."]

## Scope
- [ ] [File or class]: [what changes]
- [ ] [File or class]: [what changes]
(list every file that needs to change — be specific)

## Out of scope
- [thing that will NOT be touched]
- [thing that will NOT be touched]

## Contracts
### Request
[HTTP method + path + query params, or method signature, or event schema]

### Response
[Response body structure or return type]

## Stack context
[2-3 bullet points about relevant patterns, naming conventions, or frameworks from the project context above]

## Files expected to change
- [exact relative path to file 1]
- [exact relative path to file 2]
(one per line, use (new) suffix for new files)

## Approved by
<!-- sign off here before running: ai-kit spec approve ${id} -->
PROMPT
)" 2>/dev/null || echo "")

  if [[ -z "$spec_content" ]]; then
    warn "claude -p returned empty output — writing template instead."
    spec_content="# ${id} — ${description}

## Status
draft

## What
[Fill in: one sentence describing the deliverable]

## Scope
- [ ] [File or class]: [what changes]

## Out of scope
- [what will NOT be touched]

## Contracts
### Request
[HTTP method + path + params, or method signature]

### Response
[Response body or return type]

## Stack context
- [Relevant pattern or convention]

## Files expected to change
- [path/to/file.ext]

## Approved by
<!-- sign off here before running: ai-kit spec approve ${id} -->"
  fi

  echo "$spec_content" > "$filepath"

  echo ""
  ok  "Spec created: $filepath"
  info "Review and edit the spec, then run:"
  echo ""
  echo -e "    ${C_CYAN}ai-kit spec approve ${id}${C_RESET}"
  echo ""
}

# ── Command: spec approve ─────────────────────────────────────────────────────
_cmd_spec_approve() {
  local id="${1:-}"
  [[ -z "$id" ]] && fail "Usage: ai-kit spec approve <id>" && exit 1

  header "spec approve" "Approving $id"

  local file
  file=$(_spec_find_file "$id")
  if [[ -z "$file" ]]; then
    fail "Spec $id not found in $SPEC_DIR/"
    exit 1
  fi

  # Validate required sections
  local errors=0

  local what
  what=$(_spec_extract_section "$file" "What")
  if [[ -z "$what" || "$what" == *"[Fill in"* ]]; then
    fail "## What section is empty or unfilled."
    errors=$((errors+1))
  fi

  local scope_items
  scope_items=$(grep -c '^\- \[' "$file" 2>/dev/null || true)
  if [[ "${scope_items:-0}" -eq 0 ]]; then
    fail "## Scope has no checklist items (add at least one '- [ ] ...' line)."
    errors=$((errors+1))
  fi

  local files_section
  files_section=$(_spec_extract_section "$file" "Files expected to change")
  local file_count
  file_count=$(echo "$files_section" | grep -c '^- ' 2>/dev/null || true)
  if [[ "${file_count:-0}" -eq 0 ]]; then
    fail "## Files expected to change has no entries."
    errors=$((errors+1))
  fi

  if ! grep -q "^## Out of scope" "$file" 2>/dev/null; then
    fail "## Out of scope section is missing."
    errors=$((errors+1))
  fi

  if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Fix the issues above in: $file"
    exit 1
  fi

  # Set status to approved
  "${PYTHON_CMD:-python3}" - "$file" <<'PYEOF'
import sys, re
path = sys.argv[1]
with open(path) as f:
    content = f.read()
content = re.sub(r'(## Status\n)\S+', r'\1approved', content)
with open(path, 'w') as f:
    f.write(content)
PYEOF

  local new_tasks
  new_tasks=$(grep -c '(new)' "$file" 2>/dev/null || echo 0)

  echo ""
  ok  "$id approved"
  info "Scope: $file_count file(s) ($new_tasks new), $scope_items task(s)"
  info "Run:   ai-kit spec start $id"
  echo ""
}

# ── Command: spec start ───────────────────────────────────────────────────────
_cmd_spec_start() {
  local id="${1:-}"
  local no_header="${2:-}"
  [[ -z "$id" ]] && fail "Usage: ai-kit spec start <id>" && exit 1

  [[ "$no_header" != "--no-header" ]] && header "spec start" "Activating $id"

  local file
  file=$(_spec_find_file "$id")
  if [[ -z "$file" ]]; then
    fail "Spec $id not found."
    exit 1
  fi

  local status
  status=$(_spec_get_status "$file")
  if [[ "$status" != "approved" ]]; then
    fail "Spec is '$status' — run 'ai-kit spec approve $id' first."
    exit 1
  fi

  # Warn if another spec is already in-progress
  local active_spec_file="$SPEC_DIR/.active-spec"
  if [[ -f "$active_spec_file" ]]; then
    local current_active
    current_active=$(cat "$active_spec_file")
    if [[ "$current_active" != "$id" ]]; then
      warn "Another spec is already active: $current_active"
      echo -n "  Continue and replace it? [y/N] "
      read -r answer
      [[ "$answer" != "y" && "$answer" != "Y" ]] && exit 0
    fi
  fi

  # Set status to in-progress
  "${PYTHON_CMD:-python3}" - "$file" <<'PYEOF'
import sys, re
path = sys.argv[1]
with open(path) as f:
    content = f.read()
content = re.sub(r'(## Status\n)\S+', r'\1in-progress', content)
with open(path, 'w') as f:
    f.write(content)
PYEOF

  # Write active spec pointer + start commit hash
  echo "$id" > "$active_spec_file"
  git rev-parse HEAD 2>/dev/null > "$SPEC_DIR/.spec-start-commit" || true

  _generate_task_md "$id" "$file"

  echo ""
  ok  "$id is now active"
  ok  "TASK.md written at project root"
  info "Claude Code will read TASK.md automatically on session start"
  info "Auditor will log writes to files outside this spec's scope"
  info "When done: ai-kit spec close $id"
  echo ""
}

# ── Internal: generate TASK.md from spec (no status check) ───────────────────
_generate_task_md() {
  local id="$1"
  local file="$2"

  local title
  title=$(head -1 "$file" | sed 's/^# //')

  local what
  what=$(_spec_extract_section "$file" "What")

  local files_section
  files_section=$(_spec_extract_section "$file" "Files expected to change")

  local scope_section
  scope_section=$(_spec_extract_section "$file" "Scope")

  local oos_section
  oos_section=$(_spec_extract_section "$file" "Out of scope")

  local stack_section
  stack_section=$(_spec_extract_section "$file" "Stack context")

  cat > "TASK.md" <<TASKMD
<!-- AUTO-GENERATED by ai-kit spec start — edit the spec instead: $file -->
# Current Task: ${title}

## Objective
${what}

## Files to touch
${files_section}

## Checklist
${scope_section}

## Stack rules for this task
${stack_section}

## Out of scope — do not touch
${oos_section}

---
*Spec: ${file} | Run \`ai-kit spec close ${id}\` when done.*
TASKMD

  # Ensure CLAUDE.md imports TASK.md
  if [[ -f "CLAUDE.md" ]]; then
    if ! grep -q "@TASK.md" "CLAUDE.md" 2>/dev/null; then
      printf '\n@TASK.md\n' >> "CLAUDE.md"
      ok  "CLAUDE.md updated with @TASK.md import"
    fi
  fi
}

# ── Spec diff helper — smart diff (summarizes large diffs) ───────────────────
_spec_build_diff() {
  local start_commit="${1:-}"
  local diff=""

  if ! git rev-parse --git-dir &>/dev/null 2>&1; then
    echo "(not a git repo)"
    return 0
  fi

  local base="${start_commit:-HEAD~1}"
  local stat
  stat=$(git diff "${base}..HEAD" --stat 2>/dev/null || true)

  if [[ -z "$stat" ]]; then
    echo "(no commits since spec start)"
    return 0
  fi

  # Count changed lines to decide: full diff vs per-file summaries
  local total_lines
  total_lines=$(git diff "${base}..HEAD" -- '*.java' '*.ts' '*.tsx' '*.js' '*.jsx' '*.py' 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$total_lines" -le 350 ]]; then
    # Small diff — send full content
    echo "$stat"
    echo ""
    git diff "${base}..HEAD" -- '*.java' '*.ts' '*.tsx' '*.js' '*.jsx' '*.py' 2>/dev/null
  else
    # Large diff — send stat + per-file summaries to avoid truncation
    echo "$stat"
    echo ""
    echo "--- Per-file summaries (diff too large for full content) ---"
    git diff "${base}..HEAD" --name-only -- '*.java' '*.ts' '*.tsx' '*.js' '*.jsx' '*.py' 2>/dev/null | \
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      local added removed
      added=$(git diff "${base}..HEAD" -- "$f" 2>/dev/null | grep -c '^+[^+]' || echo 0)
      removed=$(git diff "${base}..HEAD" -- "$f" 2>/dev/null | grep -c '^-[^-]' || echo 0)
      echo ""
      echo "### $f  (+$added/-$removed)"
      # New functions / classes added
      git diff "${base}..HEAD" -- "$f" 2>/dev/null | grep '^+' | grep -E '(class |def |function |public |private |@GetMapping|@PostMapping|@Service|@Repository|@Component)' | head -8 | sed 's/^+/  /'
    done
  fi
}

# ── Command: spec check (lightweight, no AI) ──────────────────────────────────
_cmd_spec_check() {
  local id="${1:-}"

  if [[ -z "$id" ]]; then
    [[ -f "$SPEC_DIR/.active-spec" ]] && id=$(cat "$SPEC_DIR/.active-spec") || { fail "No active spec."; exit 1; }
  fi

  header "spec check" "$id — no AI"

  local file
  file=$(_spec_find_file "$id")
  [[ -z "$file" ]] && fail "Spec $id not found." && exit 1

  local start_commit=""
  [[ -f "$SPEC_DIR/.spec-start-commit" ]] && start_commit=$(cat "$SPEC_DIR/.spec-start-commit")

  # Files touched since spec start
  local touched_files=""
  if git rev-parse --git-dir &>/dev/null 2>&1 && [[ -n "$start_commit" ]]; then
    touched_files=$(git diff "${start_commit}..HEAD" --name-only 2>/dev/null || true)
  fi

  echo ""

  # ── Checklist progress ────────────────────────────────────────────────────
  echo "  Checklist"
  local total=0 done=0
  while IFS= read -r line; do
    if echo "$line" | grep -qP '^\s*- \[x\]'; then
      done=$((done+1)); total=$((total+1))
      echo -e "  ${C_GREEN}✔${C_RESET} $(echo "$line" | sed 's/^\s*- \[x\] //')"
    elif echo "$line" | grep -qP '^\s*- \[ \]'; then
      total=$((total+1))
      echo -e "  ${C_YELLOW}○${C_RESET} $(echo "$line" | sed 's/^\s*- \[ \] //')"
    fi
  done < "$file"
  echo ""
  echo "  Progress: $done/$total tasks marked done"

  # ── Expected files coverage ───────────────────────────────────────────────
  echo ""
  echo "  Expected files"
  local files_section
  files_section=$(_spec_extract_section "$file" "Files expected to change")

  while IFS= read -r line; do
    [[ "$line" =~ ^-\ (.+)$ ]] || continue
    local expected="${BASH_REMATCH[1]}"
    expected=$(echo "$expected" | sed 's/ *(new)//; s/ *← NEW//' | tr -d ' ')
    local exp_base
    exp_base=$(basename "$expected")
    local found=false
    while IFS= read -r touched; do
      local t_base
      t_base=$(basename "$touched")
      if [[ "$t_base" == "$exp_base" ]] || echo "$touched" | grep -qF "$expected"; then
        found=true; break
      fi
    done <<< "$touched_files"
    if [[ "$found" == true ]]; then
      echo -e "  ${C_GREEN}✔${C_RESET} $expected"
    else
      echo -e "  ${C_YELLOW}○${C_RESET} $expected  ${C_YELLOW}(not touched yet)${C_RESET}"
    fi
  done <<< "$files_section"

  # ── Out-of-scope changes ──────────────────────────────────────────────────
  if [[ -n "$touched_files" ]]; then
    local oos_found=false
    while IFS= read -r touched; do
      [[ -z "$touched" ]] && continue
      local t_base
      t_base=$(basename "$touched")
      local in_scope=false
      while IFS= read -r line; do
        [[ "$line" =~ ^-\ (.+)$ ]] || continue
        local expected="${BASH_REMATCH[1]}"
        expected=$(echo "$expected" | sed 's/ *(new)//; s/ *← NEW//' | tr -d ' ')
        local exp_base
        exp_base=$(basename "$expected")
        if [[ "$t_base" == "$exp_base" ]] || echo "$touched" | grep -qF "$expected"; then
          in_scope=true; break
        fi
      done <<< "$files_section"
      if [[ "$in_scope" == false ]]; then
        if [[ "$oos_found" == false ]]; then
          echo ""
          echo "  Out-of-scope changes detected"
          oos_found=true
        fi
        echo -e "  ${C_YELLOW}!${C_RESET} $touched"
      fi
    done <<< "$touched_files"
  fi

  echo ""
}

# ── Command: spec update ──────────────────────────────────────────────────────
_cmd_spec_update() {
  local subcmd="${1:-}"
  local value="${2:-}"

  local id=""
  [[ -f "$SPEC_DIR/.active-spec" ]] && id=$(cat "$SPEC_DIR/.active-spec") || { fail "No active spec."; exit 1; }

  local file
  file=$(_spec_find_file "$id")
  [[ -z "$file" ]] && fail "Spec $id not found." && exit 1

  case "$subcmd" in
    add-file)
      [[ -z "$value" ]] && echo -n "  File path to add: " && read -r value
      [[ -z "$value" ]] && fail "File path required." && exit 1
      # Append to Files expected to change section
      "${PYTHON_CMD:-python3}" - "$file" "$value" <<'PYEOF'
import sys, re
path, new_file = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
# Insert after the last item in Files expected to change
content = re.sub(
    r'(## Files expected to change\n(?:- .+\n)*)',
    lambda m: m.group(0) + f'- {new_file}\n',
    content
)
with open(path, 'w') as f:
    f.write(content)
PYEOF
      ok "Added file to spec: $value"
      ;;
    add-task)
      [[ -z "$value" ]] && echo -n "  Task description: " && read -r value
      [[ -z "$value" ]] && fail "Task description required." && exit 1
      "${PYTHON_CMD:-python3}" - "$file" "$value" <<'PYEOF'
import sys, re
path, task = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
content = re.sub(
    r'(## Scope\n(?:- \[.\] .+\n)*)',
    lambda m: m.group(0) + f'- [ ] {task}\n',
    content
)
with open(path, 'w') as f:
    f.write(content)
PYEOF
      ok "Added task to spec: $value"
      ;;
    tick)
      # Mark a task as done by number or partial match
      [[ -z "$value" ]] && echo -n "  Task number or keyword: " && read -r value
      [[ -z "$value" ]] && fail "Task identifier required." && exit 1
      "${PYTHON_CMD:-python3}" - "$file" "$value" <<'PYEOF'
import sys, re
path, query = sys.argv[1], sys.argv[2].lower()
with open(path) as f:
    lines = f.readlines()
count = 0
for i, line in enumerate(lines):
    if re.match(r'^\s*- \[ \]', line):
        count += 1
        try:
            n = int(query)
            if count == n:
                lines[i] = line.replace('- [ ]', '- [x]', 1)
                break
        except ValueError:
            if query in line.lower():
                lines[i] = line.replace('- [ ]', '- [x]', 1)
                break
with open(path, 'w') as f:
    f.writelines(lines)
PYEOF
      ok "Task marked as done."
      ;;
    *)
      echo "Usage: ai-kit spec update <subcommand>"
      echo ""
      echo "  add-file [path]    Add a file to 'Files expected to change'"
      echo "  add-task [desc]    Add a task to Scope checklist"
      echo "  tick [n|keyword]   Mark a checklist task as done (- [ ] → - [x])"
      return 0
      ;;
  esac

  # Regenerate TASK.md to reflect changes
  if [[ -f "TASK.md" ]]; then
    info "Regenerating TASK.md..."
    _generate_task_md "$id" "$file"
    ok "TASK.md updated"
  fi
}

# ── Command: spec review ─────────────────────────────────────────────────────
_cmd_spec_review() {
  local id="${1:-}"

  # Resolve ID from active spec if not provided
  if [[ -z "$id" ]]; then
    if [[ -f "$SPEC_DIR/.active-spec" ]]; then
      id=$(cat "$SPEC_DIR/.active-spec")
    else
      fail "No active spec. Provide an ID: ai-kit spec review <id>"
      exit 1
    fi
  fi

  header "spec review" "Reviewing $id"

  local file
  file=$(_spec_find_file "$id")
  if [[ -z "$file" ]]; then
    fail "Spec $id not found."
    exit 1
  fi

  local start_commit=""
  [[ -f "$SPEC_DIR/.spec-start-commit" ]] && start_commit=$(cat "$SPEC_DIR/.spec-start-commit")

  local diff
  diff=$(_spec_build_diff "$start_commit")

  if [[ "$diff" == "(no commits since spec start)" || "$diff" == "(not a git repo)" ]]; then
    warn "No git diff found since spec start — review will be based on spec alone."
  fi

  local spec_content
  spec_content=$(cat "$file")

  info "Calling claude -p to review implementation..."

  local review_output
  review_output=$(claude -p "$(cat <<PROMPT
You are a senior engineer doing a spec compliance review.

## Spec
$spec_content

## Git diff since spec was activated
$diff

## Your task
Review whether the implementation covers the spec. Be concise and direct.

Respond in this exact format:

### Coverage
For each item in ## Scope, mark it as:
- ✅ DONE — [item] — [brief evidence from diff]
- ⚠️ PARTIAL — [item] — [what's missing]
- ❌ MISSING — [item] — [not found in diff]

### Out-of-scope changes
List any files changed that are NOT in ## Files expected to change.
If none, write: (none detected)

### Verdict
One of: READY TO CLOSE | NEEDS WORK | CANNOT ASSESS (no diff)

### Issues (if any)
- [specific thing missing or wrong]

Keep each line short. No filler text.
PROMPT
)" 2>/dev/null || echo "")

  if [[ -z "$review_output" ]]; then
    fail "claude -p returned empty output."
    exit 1
  fi

  echo ""
  echo "$review_output"
  echo ""

  # Auto-update checklist: mark DONE items as [x] in spec
  local done_items
  done_items=$(echo "$review_output" | grep -oP '(?<=✅ DONE — )[^—]+' | sed 's/[[:space:]]*$//' || true)
  if [[ -n "$done_items" ]]; then
    local updated=0
    while IFS= read -r done_item; do
      [[ -z "$done_item" ]] && continue
      # Match against checklist items in spec file
      local keyword
      keyword=$(echo "$done_item" | awk '{print $1, $2}' | tr -d ':')
      if grep -q "^\- \[ \].*$(echo "$keyword" | head -c 20)" "$file" 2>/dev/null; then
        "${PYTHON_CMD:-python3}" - "$file" "$done_item" <<'PYEOF'
import sys, re
path, item = sys.argv[1], sys.argv[2].lower().strip()
with open(path) as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if re.match(r'^\s*- \[ \]', line):
        # Match by first significant words of the item
        words = [w for w in item.split() if len(w) > 3][:3]
        if any(w in line.lower() for w in words):
            lines[i] = line.replace('- [ ]', '- [x]', 1)
            break
with open(path, 'w') as f:
    f.writelines(lines)
PYEOF
        updated=$((updated+1))
      fi
    done <<< "$done_items"
    [[ "$updated" -gt 0 ]] && ok "Auto-updated $updated checklist item(s) to [x] in spec" || true
  fi

  # Return exit code based on verdict so spec close can gate on it
  if echo "$review_output" | grep -q "READY TO CLOSE"; then
    return 0
  else
    return 1
  fi
}

# ── Command: spec close ───────────────────────────────────────────────────────
_cmd_spec_close() {
  local id="${1:-}"
  local force=false
  # Parse flags (--force skips the interactive [y/N] prompt)
  for arg in "$@"; do
    [[ "$arg" == "--force" ]] && force=true && id="${id/--force/}"
  done
  id="${id:-}"

  header "spec close" "Closing spec"

  local active_spec_file="$SPEC_DIR/.active-spec"

  if [[ -z "$id" ]]; then
    if [[ -f "$active_spec_file" ]]; then
      id=$(cat "$active_spec_file")
    else
      fail "No active spec. Provide an ID: ai-kit spec close <id>"
      exit 1
    fi
  fi

  local file
  file=$(_spec_find_file "$id")
  if [[ -z "$file" ]]; then
    fail "Spec $id not found."
    exit 1
  fi

  # Run review as gate before closing
  echo ""
  if ! _cmd_spec_review "$id"; then
    echo ""
    warn "Review found issues or incomplete scope."
    if [[ "$force" == true ]]; then
      warn "Closing anyway (--force)."
    else
      echo -n "  Close anyway? [y/N] "
      read -r answer
      [[ "$answer" != "y" && "$answer" != "Y" ]] && exit 0
    fi
  else
    echo ""
    ok "Review passed — proceeding to close."
  fi

  # Collect commits since start marker (use TASK.md creation time as proxy)
  local commits=""
  if git rev-parse --git-dir &>/dev/null 2>&1; then
    commits=$(git log --oneline -10 2>/dev/null || true)
  fi

  # Set status to done and append commits
  "${PYTHON_CMD:-python3}" - "$file" "$commits" <<'PYEOF'
import sys, re
path = sys.argv[1]
commits = sys.argv[2]
with open(path) as f:
    content = f.read()
content = re.sub(r'(## Status\n)\S+', r'\1done', content)
if commits and '## Commits' not in content:
    content = content.rstrip() + '\n\n## Commits\n' + '\n'.join(
        '- ' + line for line in commits.strip().splitlines()
    ) + '\n'
with open(path, 'w') as f:
    f.write(content)
PYEOF

  # Move to done/
  local dest="$SPEC_DIR/done/$(basename "$file")"
  mv "$file" "$dest"

  # Remove TASK.md
  if [[ -f "TASK.md" ]]; then
    rm "TASK.md"
    ok "TASK.md removed"
  fi

  # Remove @TASK.md import from CLAUDE.md
  if [[ -f "CLAUDE.md" ]] && grep -q "@TASK.md" "CLAUDE.md" 2>/dev/null; then
    "${PYTHON_CMD:-python3}" - "CLAUDE.md" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()
cleaned = [l for l in lines if l.strip() != '@TASK.md']
# Remove trailing blank lines added when @TASK.md was appended
while cleaned and not cleaned[-1].strip():
    cleaned.pop()
cleaned.append('\n')
with open(path, 'w') as f:
    f.writelines(cleaned)
PYEOF
    ok "CLAUDE.md @TASK.md import removed"
  fi

  # Clear active spec pointer and start commit
  rm -f "$active_spec_file" "$SPEC_DIR/.spec-start-commit"

  echo ""
  ok  "$id closed"
  ok  "Moved to $dest"
  [[ -n "$commits" ]] && info "Linked commits: $(echo "$commits" | head -3 | tr '\n' ' ')" || true
  echo ""
}

# ── Command: spec list ────────────────────────────────────────────────────────
_cmd_spec_list() {
  header "spec list" "All specs"

  if [[ ! -d "$SPEC_DIR" ]]; then
    info "No specs yet. Run: ai-kit spec new"
    return 0
  fi

  local active_id=""
  if [[ -f "$SPEC_DIR/.active-spec" ]]; then
    active_id=$(cat "$SPEC_DIR/.active-spec")
  fi

  echo ""

  local active_specs=()
  while IFS= read -r f; do active_specs+=("$f"); done < <(find "$SPEC_DIR/active" -name "SPEC-*.md" 2>/dev/null | sort)

  if [[ ${#active_specs[@]} -gt 0 ]]; then
    echo "  Active"
    for f in "${active_specs[@]}"; do
      local sid
      sid=$(basename "$f" .md | grep -oP '^SPEC-\d+')
      local title
      title=$(head -1 "$f" | sed 's/^# //')
      local status
      status=$(_spec_get_status "$f")
      local marker=""
      [[ "$sid" == "$active_id" ]] && marker="${C_GREEN} ◀ current${C_RESET}"
      printf "  ├─ ${C_CYAN}%-10s${C_RESET}  %-12s  %s%b\n" "$sid" "$status" "$title" "$marker"
    done
  else
    echo "  Active  (none)"
  fi

  echo ""

  local done_specs=()
  while IFS= read -r f; do done_specs+=("$f"); done < <(find "$SPEC_DIR/done" -name "SPEC-*.md" 2>/dev/null | sort -r | head -5)

  echo "  Done (last 5)"
  if [[ ${#done_specs[@]} -gt 0 ]]; then
    for f in "${done_specs[@]}"; do
      local sid
      sid=$(basename "$f" .md | grep -oP '^SPEC-\d+')
      local title
      title=$(head -1 "$f" | sed 's/^# //')
      printf "  └─ ${C_CYAN}%-10s${C_RESET}  %-12s  %s\n" "$sid" "done" "$title"
    done
  else
    echo "  └─ (none)"
  fi

  echo ""
  info "Run 'ai-kit spec show <id>' for details."
  echo ""
}

# ── Command: spec show ────────────────────────────────────────────────────────
_cmd_spec_show() {
  local id="${1:-}"
  [[ -z "$id" ]] && fail "Usage: ai-kit spec show <id>" && exit 1

  local file
  file=$(_spec_find_file "$id")
  if [[ -z "$file" ]]; then
    fail "Spec $id not found."
    exit 1
  fi

  echo ""
  cat "$file"
  echo ""
}

main "$@"
