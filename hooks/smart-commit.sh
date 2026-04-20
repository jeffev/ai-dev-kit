#!/usr/bin/env bash
# AI Dev Kit — Smart Commit
# Usage: bash .claude/hooks/smart-commit.sh [--push] [--dry-run]
# Reviews staged diff via claude -p, generates conventional commit message, commits and pushes.

set -euo pipefail

C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

ok()   { echo -e "  ${C_GREEN}✔${C_RESET}  $*"; }
warn() { echo -e "  ${C_YELLOW}⚠${C_RESET}  $*"; }
fail() { echo -e "  ${C_RED}✘${C_RESET}  $*"; }
info() { echo -e "  ${C_CYAN}…${C_RESET}  $*"; }

# ── Args ──────────────────────────────────────────────────────────────────────
DO_PUSH=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --push)    DO_PUSH=true ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

echo ""
echo -e "${C_BOLD}Smart Commit${C_RESET}"
echo "─────────────────────────"

# ── Check staged changes ──────────────────────────────────────────────────────
if ! git diff --cached --quiet 2>/dev/null; then
  DIFF=$(git diff --cached)
else
  fail "Nada em stage. Rode: git add <arquivos>"
  exit 1
fi

STAGED_FILES=$(git diff --cached --name-only)
FILE_COUNT=$(echo "$STAGED_FILES" | wc -l | tr -d ' ')
info "$FILE_COUNT arquivo(s) em stage:"
echo "$STAGED_FILES" | sed 's/^/       /'
echo ""

# ── Review via claude -p ──────────────────────────────────────────────────────
info "Revisando alterações..."

REVIEW=$(echo "$DIFF" | claude -p "$(cat <<'PROMPT'
Você é um code reviewer experiente. Analise este git diff e verifique APENAS:

1. Segredos ou tokens hardcoded (passwords, API keys, JWT secrets)
2. console.log / System.out.println esquecidos em código de produção
3. Endpoints Spring Boot sem @PreAuthorize
4. SQL com concatenação de strings (risco de SQL Injection)
5. Código comentado em bloco que deveria ser deletado
6. Arquivos que claramente não deveriam ser commitados (.env, *.log, target/, node_modules/)

Responda com EXATAMENTE um dos dois formatos:

Se tudo OK:
APROVADO

Se encontrou problemas:
REPROVADO
- [CRÍTICO/ALTO/MÉDIO] Descrição do problema (arquivo:linha se possível)
- ...
PROMPT
)")

echo ""

if echo "$REVIEW" | grep -q "^APROVADO"; then
  ok "Review aprovado"
else
  echo -e "  ${C_RED}Review reprovado:${C_RESET}"
  echo "$REVIEW" | grep -v "^REPROVADO" | sed 's/^/  /'
  echo ""

  # Perguntar se quer forçar mesmo assim
  echo -n "  Commitar mesmo assim? [s/N] "
  read -r answer
  if [[ "$answer" != "s" && "$answer" != "S" ]]; then
    fail "Commit cancelado."
    exit 1
  fi
  warn "Commitando com ressalvas..."
fi

# ── Gerar mensagem de commit ──────────────────────────────────────────────────
info "Gerando mensagem de commit..."

COMMIT_MSG=$(echo "$DIFF" | claude -p "$(cat <<'PROMPT'
Gere uma mensagem de commit seguindo o padrão Conventional Commits.

Formato obrigatório:
<type>(<scope>): <descrição curta em português>

[corpo opcional — só inclua se houver múltiplas mudanças relevantes, máx 3 linhas]

Types permitidos: feat, fix, refactor, test, chore, docs, style, perf, ci
- scope: nome do módulo/componente afetado (ex: user, auth, payment)
- descrição: imperativo, minúsculo, sem ponto final, máx 72 chars

Responda APENAS com a mensagem de commit. Nenhum texto adicional.
PROMPT
)")

echo ""
echo -e "  ${C_BOLD}Mensagem gerada:${C_RESET}"
echo "  $COMMIT_MSG"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  warn "Modo dry-run — nenhum commit foi feito."
  exit 0
fi

# ── Confirmar e commitar ──────────────────────────────────────────────────────
echo -n "  Confirmar commit? [S/n] "
read -r confirm
if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
  fail "Commit cancelado."
  exit 1
fi

git commit -m "$COMMIT_MSG"
ok "Commit criado: $COMMIT_MSG"

# ── Push opcional ─────────────────────────────────────────────────────────────
if [[ "$DO_PUSH" == true ]]; then
  info "Fazendo push..."
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push origin "$BRANCH"
  ok "Push concluído → $BRANCH"
else
  echo ""
  echo "  Para fazer push: git push"
  echo "  Ou use --push na próxima vez: bash smart-commit.sh --push"
fi

echo ""
