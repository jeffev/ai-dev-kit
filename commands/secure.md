Perform a security audit of the file or feature specified by the user.

Steps:
1. Read all relevant files (controller, service, entity, config)
2. Check authentication: every @RestController endpoint must have @PreAuthorize or be explicitly documented as public
3. Check authorization: verify role-based access matches the business rules
4. Check input validation: all @RequestBody and @RequestParam must have @Valid or explicit null checks
5. Check SQL: no string concatenation in queries — only @Query with named parameters or JdbcTemplate PreparedStatement
6. Check secrets: no hardcoded passwords, tokens, or keys anywhere
7. Check JWT: secret must come from @Value, expiration must be set, algorithm must be HS256 or RS256
8. Check CORS: verify corsConfiguration does not use allowedOrigins("*") in production profiles
9. Report each issue with: file, line, severity, and exact fix

Rules:
- Do not modify files during audit
- CRITICAL issues must be fixed before any merge
- For each finding, show the vulnerable line and the corrected version
