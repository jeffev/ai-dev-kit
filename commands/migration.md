Generate a Flyway migration SQL file for the schema change described by the user.

Steps:
1. Check the latest migration version in src/main/resources/db/migration/ (list files, find highest V number)
2. Determine the next version number (e.g., if latest is V5, next is V6)
3. Generate the SQL file: V{N}__{description_in_snake_case}.sql
4. Write safe, production-ready SQL:
   - CREATE TABLE: include all columns with correct types, NOT NULL constraints, DEFAULT values
   - ALTER TABLE: use ADD COLUMN IF NOT EXISTS where supported
   - Always include: created_at TIMESTAMP NOT NULL DEFAULT NOW(), updated_at TIMESTAMP NOT NULL DEFAULT NOW()
   - Add indexes for all foreign keys and commonly queried columns
   - For DROP or destructive operations: add a warning comment and ask for confirmation
5. Place the file in src/main/resources/db/migration/

Rules:
- Never modify existing migration files — always create a new version
- Never use database-specific syntax without a comment noting the DB requirement
- Always wrap multiple statements in a transaction when the DB supports it
- Test the migration locally with: ./mvnw flyway:migrate -Dflyway.url=... before committing
