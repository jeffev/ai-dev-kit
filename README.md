# AI Dev Kit

Full AI bootstrap for Java/Spring Boot, Angular, and React projects — with a real-time quality and security auditor.

## What is it

A single command (`ai-kit init`) that configures your project for efficient AI-assisted development:

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

For intentional exceptions, add a comment to the file:

```java
// ai-kit:ignore J-002 — public endpoint by design
@GetMapping("/health")
public ResponseEntity<String> health() { ... }
```

### Global suppression (`.aikit-ignore`)

To suppress a rule across the entire project, add it to `.aikit-ignore` at the project root:

```
# .aikit-ignore — one rule ID per line
# Lines starting with # are comments

# Allow console.log in this project (uses a custom logger wrapper)
F-001

# TODOs tracked in Linear, not blocking
U-002
```

---

## Smart Commit

```bash
# After git add:
bash smart-commit.sh              # review + commit
bash smart-commit.sh --push       # review + commit + push
bash smart-commit.sh --dry-run    # preview only
bash smart-commit.sh --no-review  # skip AI review (still blocks on CRITICAL/HIGH findings)

# Or via ai-kit:
bash ai-kit.sh commit --push
```

**Flow:**
1. Reads `git diff --cached`
2. Checks `audit.log` — blocks if open CRITICAL/HIGH findings exist today (prompts to override)
3. Sends diff to `claude -p` for review: secrets, debug logs, SQL injection, unprotected endpoints
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

The optional `fix:` field is appended to the auditor message to guide the developer on how to resolve the violation.

Rules are applied automatically by the auditor on every file write.

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
bash ai-kit.sh init                    # bootstrap the project
bash ai-kit.sh update                  # update hooks and commands in-place
bash ai-kit.sh doctor                  # diagnose installation issues
bash ai-kit.sh stats                   # show audit metrics + 7-day activity chart
bash ai-kit.sh commit                  # smart commit
bash ai-kit.sh commit --push           # smart commit + push
bash ai-kit.sh audit-test <file>       # test the auditor against a file
bash ai-kit.sh audit-report            # generate markdown report from audit.log
bash ai-kit.sh audit-report report.md  # write report to a specific file
bash ai-kit.sh install-git-hook        # install auditor as a git pre-commit hook
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
