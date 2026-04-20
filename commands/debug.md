# /project:debug

Systematically debug the issue described in $ARGUMENTS.

## Step 1 — Reproduce

- Identify the exact input / request / state that triggers the bug.
- Confirm you can reproduce it consistently before changing anything.
- Note the environment: local, staging, prod? Which JVM/Node version?

## Step 2 — Narrow the blast radius

- Is this a regression? Run `git log --oneline -20` to find recent changes.
- Bisect if needed: `git bisect start && git bisect bad HEAD && git bisect good <last-good-sha>`
- Isolate the layer: HTTP request → controller → service → repository → DB?
  - Add a log at each boundary to pinpoint where the wrong value appears.

## Step 3 — Form hypotheses (before reading code)

List 3 likely root causes before opening any file. Common culprits:
- Off-by-one / null reference / wrong default value
- Transaction boundary issue (data committed in a different tx than expected)
- Race condition / shared mutable state
- Caching returning stale data
- Wrong environment variable / config value
- Type coercion / serialization mismatch

## Step 4 — Verify hypotheses

For each hypothesis, write the **smallest possible check**:
- A unit test that fails if the hypothesis is true
- A targeted log statement at the suspected line
- A SQL query against the DB to check the actual stored value

Do NOT add broad logging everywhere — it makes the output unreadable.

## Step 5 — Fix

- Fix the root cause, not the symptom.
- If the fix requires changing a public API, check all callers first.
- Write a regression test that fails before the fix and passes after.

## Step 6 — Verify

- Run the full test suite: `./mvnw test` or `ng test --watch=false`
- Remove all debug logs added during investigation.
- Confirm the original reproduction case no longer triggers the bug.
