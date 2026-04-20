# /project:refactor

Safely refactor the code identified in $ARGUMENTS or the current file.

## Pre-Refactor Checklist

Before touching any code:

1. Confirm test coverage exists for the target code. If not, write tests first.
2. Identify all callers — search the codebase for usages of the method/class/module.
3. Confirm the refactor scope: method, class, module, or cross-cutting concern?

## Refactoring Steps

### If renaming
- Rename with IDE-safe search-and-replace across all files.
- Update tests, DTOs, API contracts, and documentation references.
- Check for string-based references (e.g., reflection, JPQL, Angular route paths).

### If extracting a method or class
- Keep the original signature intact temporarily; delegate to the new code.
- Verify all tests still pass after extraction.
- Remove the delegation layer only once tests confirm equivalence.

### If removing duplication
- Identify the canonical location for the shared logic.
- Move there; update all callers one at a time.
- Do NOT create a shared utility class unless 3+ callers exist.

### If simplifying logic
- Do not change observable behaviour — only implementation.
- Replace magic numbers/strings with named constants.
- Flatten nested ifs with early returns before trying to extract.

## Post-Refactor Checklist

- [ ] All existing tests pass without modification (if tests needed changes, the behaviour changed — review why)
- [ ] No new `any` types introduced (TypeScript)
- [ ] No new `@SuppressWarnings` introduced (Java)
- [ ] Compile check passes (`./mvnw compile -q` or `tsc --noEmit`)
- [ ] Diff is clean — no unrelated changes snuck in

## What NOT to do

- Do not refactor and add features in the same commit.
- Do not change method signatures without checking all callers.
- Do not add abstraction layers unless the duplication is proven (3+ copies).
