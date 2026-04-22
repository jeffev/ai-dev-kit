# AI Dev Kit

Full AI bootstrap for any project — spec-driven workflow, real-time quality auditor, and a terminal UI for managing features end-to-end.

## What is it

A single command (`ai-kit init`) that configures your project for efficient AI-assisted development:

- **TUI** — visual terminal interface to manage the full spec lifecycle (`ai-kit tui`)
- **Spec-driven workflow** — define, approve, implement and close features with AI in a structured way
- **Real-time auditor** — intercepts every file write and blocks critical issues before they hit disk
- **Generated CLAUDE.md** — real project context injected into every AI session
- **Ready-to-use hooks** — compile check, type check, test reminder, Docker status, test coverage display
- **Slash commands** — `/project:endpoint`, `/project:test`, `/project:secure`, `/project:refactor`, `/project:debug`, `/project:pr` and more
- **Smart Commit** — diff review + Conventional Commit message generation via AI
- **Custom rules** — define your team's rules in `.aikit-rules.yml`
- **Global suppression** — `.aikit-ignore` file to silence rules project-wide
- **Desktop notifications** — build failure alerts on Linux, macOS, and Windows

---

## Installation

```bash
# Clone the repository
git clone https://github.com/jeffev/ai-dev-kit.git

# Navigate to your project root
cd my-project

# Run the bootstrapper
bash /path/to/ai-dev-kit/ai-kit.sh init
```

> **Requirements:** Claude Code CLI, bash (Git Bash on Windows), python3, git

---

## TUI — Terminal UI

Launch the visual interface from any project directory:

```bash
ai-kit tui
```

The TUI provides a full spec management workflow without typing commands:

```
┌─ SPECS ──────┐  ┌─ SPEC-003 ● ACTIVE ────────────────────────────┐  ┌─ STATUS ──────┐
│ — ACTIVE —   │  │  Add user bio field to the user model            │  │ Branch: main  │
│ ● SPEC-003   │  │  [████████░░] 3/4 tasks (75%)                   │  │ Modified: 2   │
│ — DRAFT —    │  │                                                   │  │ In sync       │
│ · SPEC-004   │  │  Checklist [1]  Activity [2]  Spec [3]  Log [4] │  │               │
│ — DONE —     │  │                                                   │  │ Audit Log     │
│ ✓ SPEC-001   │  │  ✔  Add bio field to User model                  │  │ No findings   │
│ ✓ SPEC-002   │  │  ✔  Create migration for bio column              │  │               │
│              │  │  ✔  Include bio in GET /api/users/me             │  │               │
│              │  │  ○  Allow PATCH /api/users/me to update bio      │  │               │
│              │  │                                                   │  │               │
│ + New Spec   │  │  Approve  Start  ✦ Claude  Review  Close         │  │               │
└──────────────┘  └───────────────────────────────────────────────────┘  └───────────────┘
```

### TUI actions

| Button / Key | What it does |
|---|---|
| `+ New Spec` / `n` | Describe a feature — AI generates the spec |
| `Approve` / `a` | Validate and approve a draft spec |
| `Start` / `s` | Activate the spec — generates `TASK.md` in the project root |
| `✦ Claude` / `c` | Suspend TUI, open Claude Code in the project directory with the task pre-loaded — TUI resumes when you exit Claude |
| `Review` / (button) | Run AI review of what was implemented |
| `Close` / (button) | Close the spec — moves to done, removes `TASK.md` |
| `1–4` | Switch between Checklist / Activity / Spec / Log tabs |
| `r` | Refresh spec list and git status |
| `q` | Quit |

### Typical workflow

```
New Spec → (edit spec if needed) → Approve → Start → ✦ Claude → Review → Close
```

1. **New Spec** — describe what you want to build; AI drafts the spec
2. **Approve** — review the scope and approve it
3. **Start** — activates the spec, writes `TASK.md` to the project root
4. **✦ Claude** — TUI suspends, Claude Code opens already focused on `TASK.md`; implement the tasks; exit Claude when done
5. **Review** — AI reviews the implementation against the spec
6. **Fix with Claude** — if review found issues, reopen Claude to fix them
7. **Close** — spec marked as done, `TASK.md` removed

---

## Spec-Driven Workflow

### File structure

```
.aikit-specs/
├── active/
│   └── SPEC-003-user-bio-field.md      # current in-progress spec
├── draft/
│   └── SPEC-004-notifications.md       # drafted, not yet approved
├── done/
│   └── SPEC-001-auth-refresh-token.md
│   └── SPEC-002-product-pagination.md
└── .spec-counter                        # auto-incremented ID
```

### Spec file format

```markdown
# SPEC-003 — Add bio field to user model

## Status
in-progress

## What
Add an optional `bio` field (short text) to the user model with update endpoint and profile response.

## Out of scope
- Profile photo upload
- Content moderation for bio text

## Scope
- [ ] Add bio field to User model
- [ ] Create migration for bio column
- [ ] Include bio in GET /api/users/me response
- [ ] Allow PATCH /api/users/me to update bio

## Files expected to change
- backend/app/models/user.py
- backend/app/routes/users.py
- backend/app/schemas/user.py
```

### CLI commands

```bash
ai-kit spec new "description"        # AI drafts a spec
ai-kit spec approve SPEC-003         # validate and approve
ai-kit spec start SPEC-003           # activate — writes TASK.md
ai-kit spec review SPEC-003          # AI reviews implementation
ai-kit spec update tick <N>          # mark task N as done
ai-kit spec close SPEC-003           # close — moves to done/
ai-kit spec list                     # list all specs
ai-kit spec show SPEC-003            # print spec to stdout
```

---

## What `init` sets up

### Phases

| Phase | What it does |
|-------|-------------|
| 0 — Pre-flight | Verifies dependencies (claude CLI, git, python3) |
| 1 — Detection | Reads `pom.xml`, `package.json`, `angular.json` and detects the stack |
| 2 — CLAUDE.md | Generates via `claude -p` with real project context |
| 3 — settings.json | Registers all hooks in Claude Code |
| 4 — Slash Commands | Installs commands specific to the detected stack |
| 5 — Auditor | Deploys hook scripts to `.claude/hooks/` |
| 6 — Skills | Recommends relevant harness skills for the project |

### Generated structure

```
.claude/
├── settings.json           # registered hooks
├── CLAUDE.md               # project context for the AI
├── commands/               # slash commands
│   ├── review.md           # /project:review
│   ├── test.md             # /project:test
│   ├── secure.md           # /project:secure
│   ├── refactor.md         # /project:refactor
│   ├── debug.md            # /project:debug
│   ├── pr.md               # /project:pr
│   ├── endpoint.md         # /project:endpoint  (Spring Boot)
│   ├── dto.md              # /project:dto        (Spring Boot)
│   ├── migration.md        # /project:migration  (Flyway)
│   └── component.md        # /project:component  (Angular/React)
└── hooks/
    ├── auditor.sh           # PreToolUse — blocks critical issues
    ├── post-java-write.sh   # PostToolUse — mvnw compile after .java writes
    ├── post-ts-write.sh     # PostToolUse — tsc --noEmit after .ts writes
    ├── session-start.sh     # SessionStart — git, docker, coverage status
    ├── stop-test-reminder.sh # Stop — shows ready-to-run test commands
    └── lib/
        ├── detect.sh
        ├── java_rules.sh
        ├── frontend_rules.sh
        ├── universal_rules.sh
        ├── custom_rules.sh
        └── reporter.sh

smart-commit.sh              # AI-powered smart commit at project root
.aikit-rules.yml             # team custom rules
.aikit-ignore                # global rule suppressions
```

---

## Quality & Security Auditor

Runs automatically on every file write by Claude Code via the `PreToolUse` hook.

### Severities

| Severity | Behavior |
|----------|----------|
| `CRITICAL` | Blocks the write, shows the issue and fix |
| `HIGH`     | Blocks the write, shows the issue and fix |
| `MEDIUM`   | Allows the write, prints a warning |
| `LOW`      | Allows the write, logs silently to `audit.log` |

### Java / Spring Boot rules

| ID | Severity | Description |
|----|----------|-------------|
| J-001 | CRITICAL | SQL Injection via string concatenation in queries |
| J-002 | HIGH | `@RestController` with no `@PreAuthorize` on any endpoint |
| J-003 | MEDIUM | `System.out.println` in production code |
| J-004 | HIGH | `@Transactional` on a private method (no effect in Spring AOP) |
| J-005 | MEDIUM | JPA `@Entity` missing proper `equals/hashCode` |
| J-006 | CRITICAL | Hardcoded JWT secret |
| J-007 | MEDIUM | Generic `catch(Exception)` that swallows errors |
| J-008 | MEDIUM | `@Scheduled` without `@Async` (blocks scheduler thread pool) |
| J-009 | MEDIUM | `@Value` injecting a secret field directly — prefer `@ConfigurationProperties` |

### Angular / React rules

| ID | Severity | Description |
|----|----------|-------------|
| F-001 | LOW | `console.log` in production code |
| F-002 | MEDIUM | TypeScript `any` |
| F-003 | HIGH | `.subscribe()` without unsubscribe strategy (Angular memory leak) |
| F-004 | CRITICAL | Secret in `environment.ts` or `.env` file |
| F-005 | MEDIUM | `useEffect` without dependency array (runs on every render) |
| F-006 | HIGH | Direct DOM manipulation in Angular component (`document.getElementById`) |
| F-007 | LOW | `router.navigate` with hardcoded string literal in Angular component |

### Universal rules

| ID | Severity | Description |
|----|----------|-------------|
| U-001 | CRITICAL | Hardcoded password, token, or API key |
| U-002 | LOW | `TODO` / `FIXME` in new code |
| U-003 | MEDIUM | Emoji in source code (`.java`, `.ts`, `.tsx`, `.js`) |

### Inline suppression

```java
// ai-kit:ignore J-002 — public endpoint by design
@GetMapping("/health")
public ResponseEntity<String> health() { ... }
```

### Global suppression (`.aikit-ignore`)

```
# .aikit-ignore — one rule ID per line
F-001   # Allow console.log (uses custom logger wrapper)
U-002   # TODOs tracked in Linear
```

---

## Smart Commit

```bash
bash smart-commit.sh              # review + commit
bash smart-commit.sh --push       # review + commit + push
bash smart-commit.sh --dry-run    # preview only
bash smart-commit.sh --no-review  # skip AI review

# Or via ai-kit:
ai-kit commit --push
```

**Flow:**
1. Reads `git diff --cached`
2. Checks `audit.log` — blocks if open CRITICAL/HIGH findings exist today
3. Sends diff to `claude -p` for review
4. If approved → generates a [Conventional Commits](https://www.conventionalcommits.org/) message
5. Asks for confirmation → commits (and pushes if `--push`)

---

## Custom Rules

Edit the generated `.aikit-rules.yml` at the project root:

```yaml
rules:
  - id: C-001
    severity: HIGH
    files: "*.java"
    pattern: 'System\.exit\('
    message: "System.exit() must not be used. Throw a proper exception instead."
    fix: "throw new IllegalStateException(\"reason\") or use Spring's ApplicationContext.close()"

  - id: C-002
    severity: MEDIUM
    files: "*.tsx,*.ts"
    pattern: '^\s*fetch\s*\('
    message: "Use the useApi() hook instead of calling fetch() directly."
    fix: "const { data } = useApi('/endpoint')"
```

---

## Configured hooks

| Hook | Script | When it fires |
|------|--------|---------------|
| `PreToolUse` | `auditor.sh` | Before writing any file |
| `PostToolUse` | `post-java-write.sh` | After writing `.java` → runs `mvnw compile`, desktop notification on failure |
| `PostToolUse` | `post-ts-write.sh` | After writing `.ts/.tsx` → runs `tsc --noEmit` |
| `SessionStart` | `session-start.sh` | On Claude Code open — shows git, docker, and test coverage status |
| `Stop` | `stop-test-reminder.sh` | On session close — shows ready-to-run test commands |

---

## Available commands

```bash
# Setup
ai-kit init                        # bootstrap the project
ai-kit update                      # update hooks and commands in-place
ai-kit doctor                      # diagnose installation issues

# TUI
ai-kit tui                         # open the terminal UI

# Spec workflow
ai-kit spec new "description"      # AI drafts a new spec
ai-kit spec list                   # list all specs
ai-kit spec show SPEC-003          # print spec to stdout
ai-kit spec approve SPEC-003       # validate and approve a spec
ai-kit spec start SPEC-003         # activate spec — writes TASK.md
ai-kit spec update tick <N>        # mark task N as done
ai-kit spec review SPEC-003        # AI reviews the implementation
ai-kit spec close SPEC-003         # close — moves to done/

# Commit
ai-kit commit                      # smart commit
ai-kit commit --push               # smart commit + push

# Audit
ai-kit stats                       # audit metrics + 7-day chart
ai-kit audit-test <file>           # test auditor against a file
ai-kit audit-report                # markdown report from audit.log
ai-kit audit-report report.md      # write report to a specific file
ai-kit install-git-hook            # install auditor as git pre-commit hook
```

---

## Stack detection

Detects 20+ technologies from `pom.xml`, `package.json`, `angular.json`, `docker-compose.yml`, and `application.yml`:

- **Backend:** Java 17+, Spring Boot 3.x/4.x, Spring Security, Lombok, MapStruct, JPA, Flyway, PostgreSQL, Kafka, Redis, Keycloak
- **Frontend:** Angular 17+ (standalone), React 18/19, TypeScript, Vite, ESLint
- **Infra:** Docker Compose, Maven Wrapper, multi-module Maven

---

## License

MIT
