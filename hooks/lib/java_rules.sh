#!/usr/bin/env bash
# Java / Spring Boot analysis rules
# Functions: run_java_rules <file_path> <content_file>
# Appends findings to FINDINGS array (defined in auditor.sh)

run_java_rules() {
  local file_path="$1"
  local content_file="$2"

  local is_test=false
  echo "$file_path" | grep -qiE '(/test/|Test\.java$)' && is_test=true

  _java_sql_injection "$file_path" "$content_file"

  if [[ "$is_test" == false ]]; then
    _java_unauthenticated_endpoint "$file_path" "$content_file"
    _java_system_out_println "$file_path" "$content_file"
    _java_transactional_private "$file_path" "$content_file"
    _java_entity_missing_equals "$file_path" "$content_file"
    _java_hardcoded_jwt_secret "$file_path" "$content_file"
    _java_generic_catch "$file_path" "$content_file"
    _java_scheduled_without_async "$file_path" "$content_file"
    _java_value_secret_injection "$file_path" "$content_file"
  fi
}

_java_sql_injection() {
  local file_path="$1"
  local content_file="$2"

  local match
  match=$(grep -inP '(createNativeQuery|createQuery|executeQuery)\s*\(\s*"[^"]*"\s*\+' "$content_file" 2>/dev/null | head -1)
  if [[ -z "$match" ]]; then
    match=$(grep -inP '"(SELECT|INSERT|UPDATE|DELETE|WHERE)[^"]*"\s*\+' "$content_file" 2>/dev/null | head -1)
  fi

  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("CRITICAL|J-001|$file_path|$line_num|SQL Injection risk: user input concatenated into SQL string. Use @Query with named parameters or JdbcTemplate with PreparedStatement.|")
  fi
}

_java_unauthenticated_endpoint() {
  local file_path="$1"
  local content_file="$2"

  # Only applies to @RestController or @Controller files
  grep -q "@RestController\|@Controller" "$content_file" 2>/dev/null || return

  # Check for HTTP mapping annotations
  local has_mapping
  has_mapping=$(grep -cP '@(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping|RequestMapping)' "$content_file" 2>/dev/null || echo 0)
  [[ "$has_mapping" -eq 0 ]] && return

  # If no @PreAuthorize anywhere in the file, flag it
  if ! grep -qP '@PreAuthorize|@Secured|permitAll|@Public' "$content_file" 2>/dev/null; then
    local line_num
    line_num=$(grep -nP '@(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping)' "$content_file" 2>/dev/null | head -1 | grep -oP '^\d+')
    FINDINGS+=("HIGH|J-002|$file_path|${line_num:-1}|Controller has HTTP endpoints but no @PreAuthorize annotation. Add @PreAuthorize or document why endpoints are public with: // ai-kit:ignore J-002|")
  fi
}

_java_system_out_println() {
  local file_path="$1"
  local content_file="$2"

  local match
  match=$(grep -inP 'System\.(out|err)\.print' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("MEDIUM|J-003|$file_path|$line_num|System.out.println found. Use SLF4J: private static final Logger log = LoggerFactory.getLogger(getClass());|")
  fi
}

_java_transactional_private() {
  local file_path="$1"
  local content_file="$2"

  # Look for @Transactional immediately above a private method
  local match
  match=$(grep -nP '@Transactional' "$content_file" 2>/dev/null | while read -r line; do
    local ln
    ln=$(echo "$line" | grep -oP '^\d+')
    local next_line
    next_line=$(sed -n "$((ln+1))p" "$content_file" 2>/dev/null)
    if echo "$next_line" | grep -qP '^\s*private\s+'; then
      echo "$line"
      break
    fi
  done | head -1)

  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("HIGH|J-004|$file_path|$line_num|@Transactional on a private method has no effect in Spring (Spring AOP cannot proxy private methods). Make the method package-private or protected.|")
  fi
}

_java_entity_missing_equals() {
  local file_path="$1"
  local content_file="$2"

  grep -q "@Entity" "$content_file" 2>/dev/null || return

  local has_equals
  has_equals=$(grep -cP 'equals\s*\(|@EqualsAndHashCode|@Data' "$content_file" 2>/dev/null || echo 0)

  if [[ "$has_equals" -eq 0 ]]; then
    local line_num
    line_num=$(grep -nP '@Entity' "$content_file" 2>/dev/null | head -1 | grep -oP '^\d+')
    FINDINGS+=("MEDIUM|J-005|$file_path|${line_num:-1}|JPA @Entity is missing equals/hashCode. Add @EqualsAndHashCode(onlyExplicitlyIncluded = true) with @EqualsAndHashCode.Include on the @Id field.|")
  fi
}

_java_hardcoded_jwt_secret() {
  local file_path="$1"
  local content_file="$2"

  local match
  match=$(grep -inP '(jwt[_-]?secret|jwtSecret|secret[_-]?key)\s*[=:]\s*["'"'"'][^"'"'"'$\{]{8,}["'"'"']' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("CRITICAL|J-006|$file_path|$line_num|Hardcoded JWT secret detected. Move to application.yml and inject with @Value(\"\${jwt.secret}\").|")
  fi
}

_java_generic_catch() {
  local file_path="$1"
  local content_file="$2"

  local match
  match=$(grep -inP '}\s*catch\s*\(\s*(Exception|Throwable)\s+\w+\s*\)\s*\{' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("MEDIUM|J-007|$file_path|$line_num|Generic catch(Exception) swallows all errors silently. Catch specific exceptions or re-throw as a domain exception.|")
  fi
}

_java_scheduled_without_async() {
  local file_path="$1"
  local content_file="$2"

  grep -q "@Scheduled" "$content_file" 2>/dev/null || return
  grep -q "@Async\|@EnableAsync" "$content_file" 2>/dev/null && return

  local match
  match=$(grep -nP '@Scheduled' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("MEDIUM|J-008|$file_path|$line_num|@Scheduled method without @Async. Long-running tasks block the scheduler thread pool. Add @Async and @EnableAsync on the config class.|")
  fi
}

_java_value_secret_injection() {
  local file_path="$1"
  local content_file="$2"

  # Detect @Value injecting a secret directly into a String field (not @ConfigurationProperties)
  local match
  match=$(grep -inP '@Value\s*\(\s*"\$\{(secret|password|token|api[._-]?key|jwt)[^}]*\}"\s*\)' "$content_file" 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    local line_num
    line_num=$(echo "$match" | grep -oP '^\d+')
    FINDINGS+=("MEDIUM|J-009|$file_path|$line_num|@Value injecting a secret into a single field. Prefer @ConfigurationProperties with a dedicated config class for grouping and validation.|")
  fi
}
