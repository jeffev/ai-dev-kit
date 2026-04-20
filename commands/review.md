Review the current codebase for quality and security issues.

Steps:
1. List all recently modified files (git diff --name-only HEAD~1 or git status)
2. For each Java file: check for missing @PreAuthorize, System.out.println, hardcoded values, missing tests
3. For each TypeScript file: check for console.log, `any` types, subscribe leaks
4. Check all files for hardcoded secrets or tokens
5. List findings grouped by severity: CRITICAL → HIGH → MEDIUM → LOW
6. Suggest fixes for each finding

Rules:
- Do not modify any files during this review
- Report exact file and line number for each finding
- If nothing found, say "No issues found"
