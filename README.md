# AI Dev Kit

Bootstrap completo de IA para projetos Java/Spring Boot, Angular e React — com auditor de qualidade e segurança em tempo real.

## O que é

Um único comando (`ai-kit init`) que configura seu projeto para usar o Claude Code com máxima eficiência:

- **Auditor automático** — intercepta toda escrita de arquivo e bloqueia problemas críticos antes de chegar no disco
- **CLAUDE.md gerado** — contexto real do seu projeto injetado em toda sessão de IA
- **Hooks prontos** — compile check, type check, lembrete de testes, status do Docker
- **Slash commands** — `/project:endpoint`, `/project:test`, `/project:secure` e mais
- **Smart Commit** — review de diff + geração de mensagem conventional commit via IA
- **Regras customizadas** — seu time define as regras em `.aikit-rules.yml`

---

## Instalação

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/ai-dev-kit.git

# Entre na raiz do seu projeto
cd meu-projeto

# Rode o bootstrapper
bash /caminho/para/ai-dev-kit/ai-kit.sh init
```

> **Requisitos:** Claude Code CLI instalado, bash (Git Bash no Windows), python3, git

---

## O que o `init` configura

### Fases

| Fase | O que faz |
|------|-----------|
| 0 — Pre-flight | Verifica dependências (claude CLI, git, python3) |
| 1 — Detecção | Lê `pom.xml`, `package.json`, `angular.json` e detecta o stack |
| 2 — CLAUDE.md | Gera via `claude -p` com contexto real do projeto |
| 3 — settings.json | Registra todos os hooks no Claude Code |
| 4 — Slash Commands | Instala comandos específicos para o stack detectado |
| 5 — Auditor | Deploy dos scripts de hook em `.claude/hooks/` |
| 6 — Skills | Recomenda skills do harness relevantes ao projeto |

### Estrutura gerada no projeto

```
.claude/
├── settings.json          # hooks registrados
├── CLAUDE.md              # contexto do projeto para IA
├── commands/              # slash commands
│   ├── review.md          # /project:review
│   ├── test.md            # /project:test
│   ├── secure.md          # /project:secure
│   ├── endpoint.md        # /project:endpoint  (Spring Boot)
│   ├── dto.md             # /project:dto        (Spring Boot)
│   ├── migration.md       # /project:migration  (Flyway)
│   └── component.md       # /project:component  (Angular/React)
└── hooks/
    ├── auditor.sh          # PreToolUse — bloqueia problemas críticos
    ├── post-java-write.sh  # PostToolUse — mvnw compile após .java
    ├── post-ts-write.sh    # PostToolUse — tsc --noEmit após .ts
    ├── session-start.sh    # SessionStart — status git + docker
    ├── stop-test-reminder.sh # Stop — lembra de rodar testes
    └── lib/
        ├── detect.sh
        ├── java_rules.sh
        ├── frontend_rules.sh
        ├── universal_rules.sh
        ├── custom_rules.sh
        └── reporter.sh

smart-commit.sh            # commit inteligente com review de IA
.aikit-rules.yml           # regras customizadas do time
```

---

## Auditor de Qualidade e Segurança

Roda automaticamente em toda escrita de arquivo pelo Claude Code via hook `PreToolUse`.

### Severidades

| Severidade | Comportamento |
|------------|---------------|
| `CRITICAL` | Bloqueia a escrita, mostra o problema e o fix |
| `HIGH`     | Bloqueia a escrita, mostra o problema e o fix |
| `MEDIUM`   | Permite a escrita, imprime aviso no terminal |
| `LOW`      | Permite a escrita, registra silenciosamente em `audit.log` |

### Regras Java / Spring Boot

| ID | Severidade | Descrição |
|----|------------|-----------|
| J-001 | CRITICAL | SQL Injection por concatenação de string |
| J-002 | HIGH | `@RestController` sem `@PreAuthorize` em nenhum endpoint |
| J-003 | MEDIUM | `System.out.println` em código de produção |
| J-004 | HIGH | `@Transactional` em método privado (sem efeito no Spring) |
| J-005 | MEDIUM | `@Entity` JPA sem `equals/hashCode` adequado |
| J-006 | CRITICAL | JWT secret hardcoded |

### Regras Angular / React

| ID | Severidade | Descrição |
|----|------------|-----------|
| F-001 | LOW | `console.log` em código de produção |
| F-002 | MEDIUM | TypeScript `any` |
| F-003 | HIGH | `.subscribe()` sem estratégia de unsubscribe (memory leak) |
| F-004 | CRITICAL | Secret em arquivo `environment.ts` ou `.env` |

### Regras Universais

| ID | Severidade | Descrição |
|----|------------|-----------|
| U-001 | CRITICAL | Hardcoded password, token, API key |
| U-002 | LOW | `TODO` / `FIXME` em código novo |

### Supressão pontual

Para casos intencionais, adicione um comentário no arquivo:

```java
// ai-kit:ignore J-002 — endpoint público por design
@GetMapping("/health")
public ResponseEntity<String> health() { ... }
```

---

## Smart Commit

```bash
# Após git add:
bash smart-commit.sh           # review + commit
bash smart-commit.sh --push    # review + commit + push
bash smart-commit.sh --dry-run # só mostra o que faria

# Ou via ai-kit:
bash ai-kit.sh commit --push
```

**Fluxo:**
1. Lê o `git diff --cached`
2. Envia para `claude -p` para revisar: secrets, debug logs, SQL injection, endpoints desprotegidos
3. Se aprovado → gera mensagem no padrão [Conventional Commits](https://www.conventionalcommits.org/)
4. Pede confirmação → faz o commit (e push se `--push`)

---

## Regras Customizadas

Edite o `.aikit-rules.yml` gerado na raiz do projeto:

```yaml
rules:
  - id: C-001
    severity: HIGH
    files: "*.java"
    pattern: 'System\.exit\('
    message: "System.exit() não deve ser usado. Lance uma exceção adequada."

  - id: C-002
    severity: MEDIUM
    files: "*.tsx,*.ts"
    pattern: '^\s*fetch\s*\('
    message: "Use o hook useApi() em vez de fetch() direto em componentes."
```

As regras são aplicadas automaticamente pelo auditor em toda escrita de arquivo.

---

## Hooks configurados

| Hook | Script | Quando dispara |
|------|--------|----------------|
| `PreToolUse` | `auditor.sh` | Antes de escrever qualquer arquivo |
| `PostToolUse` | `post-java-write.sh` | Após escrever `.java` → `mvnw compile` |
| `PostToolUse` | `post-ts-write.sh` | Após escrever `.ts/.tsx` → `tsc --noEmit` |
| `SessionStart` | `session-start.sh` | Ao abrir o Claude Code — mostra status git + docker |
| `Stop` | `stop-test-reminder.sh` | Ao fechar sessão — lembra de rodar testes |

---

## Comandos disponíveis

```bash
bash ai-kit.sh init              # configura o projeto
bash ai-kit.sh commit            # smart commit
bash ai-kit.sh commit --push     # smart commit + push
bash ai-kit.sh audit-test <file> # testa o auditor em um arquivo
```

---

## Stack suportado

- **Backend:** Java 17+, Spring Boot 3.x/4.x, Spring Security, Lombok, MapStruct, JPA, Flyway, PostgreSQL
- **Frontend:** Angular 17+ (standalone), React 18/19, TypeScript, Vite
- **Infra:** Docker Compose, Maven Wrapper
- **SO:** Linux, macOS, Windows (Git Bash)

---

## Licença

MIT
