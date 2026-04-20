# AI Dev Kit

Full AI bootstrap for Java/Spring Boot, Angular, and React projects — with a real-time quality and security auditor.

## What is it

A single command (`ai-kit init`) that configures your project for efficient AI-assisted development:

- **Real-time auditor** — intercepts every file write and blocks critical issues before they hit disk
- **Generated CLAUDE.md** — real project context injected into every AI session
- **Ready-to-use hooks** — compile check, type check, test reminder, Docker status
- **Slash commands** — `/project:endpoint`, `/project:test`, `/project:secure` and more
- **Smart Commit** — diff review + Conventional Commit message generation via AI
- **Custom rules** — define your team's rules in `.aikit-rules.yml`

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
│   ├── endpoint.md         # /project:endpoint  (Spring Boot)
│   ├── dto.md              # /project:dto        (Spring Boot)
│   ├── migration.md        # /project:migration  (Flyway)
│   └── component.md        # /project:component  (Angular/React)
└── hooks/
    ├── auditor.sh           # PreToolUse — blocks critical issues
    ├── post-java-write.sh   # PostToolUse — mvnw compile after .java writes
    ├── post-ts-write.sh     # PostToolUse — tsc --noEmit after .ts writes
    ├── session-start.sh     # SessionStart — git + docker status
    ├── stop-test-reminder.sh # Stop — reminds to run tests
    └── lib/
        ├── detect.sh
        ├── java_rules.sh
        ├── frontend_rules.sh
        ├── universal_rules.sh
        ├── custom_rules.sh
        └── reporter.sh

smart-commit.sh              # AI-powered smart commit at project root
.aikit-rules.yml             # team custom rules
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

### Angular / React rules

| ID | Severity | Description |
|----|----------|-------------|
| F-001 | LOW | `console.log` in production code |
| F-002 | MEDIUM | TypeScript `any` |
| F-003 | HIGH | `.subscribe()` without unsubscribe strategy (Angular memory leak) |
| F-004 | CRITICAL | Secret in `environment.ts` or `.env` file |

### Universal rules

| ID | Severity | Description |
|----|----------|-------------|
| U-001 | CRITICAL | Hardcoded password, token, or API key |
| U-002 | LOW | `TODO` / `FIXME` in new code |

### Inline suppression

For intentional exceptions, add a comment to the file:

```java
// ai-kit:ignore J-002 — public endpoint by design
@GetMapping("/health")
public ResponseEntity<String> health() { ... }
```

---

## Smart Commit

```bash
# After git add:
bash smart-commit.sh           # review + commit
bash smart-commit.sh --push    # review + commit + push
bash smart-commit.sh --dry-run # preview only

# Or via ai-kit:
bash ai-kit.sh commit --push
```

**Flow:**
1. Reads `git diff --cached`
2. Sends to `claude -p` for review: secrets, debug logs, SQL injection, unprotected endpoints
3. If approved → generates a [Conventional Commits](https://www.conventionalcommits.org/) message
4. Asks for confirmation → commits (and pushes if `--push`)

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

  - id: C-002
    severity: MEDIUM
    files: "*.tsx,*.ts"
    pattern: '^\s*fetch\s*\('
    message: "Use the useApi() hook instead of calling fetch() directly."
```

Rules are applied automatically by the auditor on every file write.

---

## Configured hooks

| Hook | Script | When it fires |
|------|--------|---------------|
| `PreToolUse` | `auditor.sh` | Before writing any file |
| `PostToolUse` | `post-java-write.sh` | After writing `.java` → runs `mvnw compile` |
| `PostToolUse` | `post-ts-write.sh` | After writing `.ts/.tsx` → runs `tsc --noEmit` |
| `SessionStart` | `session-start.sh` | On Claude Code open — shows git + docker status |
| `Stop` | `stop-test-reminder.sh` | On session close — reminds to run tests |

---

## Available commands

```bash
bash ai-kit.sh init              # bootstrap the project
bash ai-kit.sh commit            # smart commit
bash ai-kit.sh commit --push     # smart commit + push
bash ai-kit.sh audit-test <file> # test the auditor against a file
```

---

## Supported stack

- **Backend:** Java 17+, Spring Boot 3.x/4.x, Spring Security, Lombok, MapStruct, JPA, Flyway, PostgreSQL
- **Frontend:** Angular 17+ (standalone), React 18/19, TypeScript, Vite
- **Infra:** Docker Compose, Maven Wrapper
- **OS:** Linux, macOS, Windows (Git Bash)

---

## License

MIT
