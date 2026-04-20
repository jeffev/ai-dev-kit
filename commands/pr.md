# /project:pr

Generate a pull request for the current branch and open it on GitHub.

## Pre-PR Checklist

Before creating the PR, verify:

- [ ] All tests pass locally
- [ ] No debug logs or `TODO`s left in changed files
- [ ] Compile check is green (`./mvnw compile -q` or `tsc --noEmit`)
- [ ] Branch is up to date with the base branch

## Steps

1. Review the full diff:

```bash
git diff main...HEAD
```

2. Check for issues in the diff:
   - Hardcoded secrets, tokens, or API keys
   - `console.log` / `System.out.println` in production paths
   - Commented-out code blocks
   - Files that should not be committed (`.env`, `*.log`, IDE configs)

3. Generate the PR with a structured description:

```bash
gh pr create \
  --title "<type>(<scope>): <short summary>" \
  --body "$(cat <<'EOF'
## What changed
- <bullet point summary of each change>

## Why
<motivation — link to issue if applicable>

## How to test
- <step-by-step reproduction / test scenario>

## Checklist
- [ ] Tests pass
- [ ] No secrets in diff
- [ ] Reviewed by AI Dev Kit auditor
EOF
)"
```

4. If the branch needs a rebase first:

```bash
git fetch origin
git rebase origin/main
git push --force-with-lease
```

## Commit message convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change with no behaviour change |
| `test` | Adding or updating tests |
| `chore` | Build, CI, dependency updates |
| `docs` | Documentation only |
