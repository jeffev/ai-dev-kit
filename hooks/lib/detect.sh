#!/usr/bin/env bash
# Stack detection library — sourced by auditor.sh and ai-kit.sh
# Populates STACK_* variables; uses cache file to avoid re-running on every hook call.

CACHE_FILE=".claude/hooks/.stack-cache"
CACHE_TTL=600  # 10 minutes

detect_stack() {
  local project_root="${1:-.}"

  # Use cache if fresh
  if [[ -f "$project_root/$CACHE_FILE" ]]; then
    local age=$(( $(date +%s) - $(date -r "$project_root/$CACHE_FILE" +%s 2>/dev/null || echo 0) ))
    if [[ $age -lt $CACHE_TTL ]]; then
      source "$project_root/$CACHE_FILE"
      return 0
    fi
  fi

  STACK_JAVA=false
  STACK_SPRING_BOOT=false
  STACK_SPRING_BOOT_VERSION=""
  STACK_SPRING_SECURITY=false
  STACK_LOMBOK=false
  STACK_MAPSTRUCT=false
  STACK_JPA=false
  STACK_JUNIT5=false
  STACK_FLYWAY=false
  STACK_ANGULAR=false
  STACK_REACT=false
  STACK_TYPESCRIPT=false
  STACK_VITE=false
  STACK_ESLINT=false
  STACK_POSTGRESQL=false
  STACK_DOCKER_COMPOSE=false
  STACK_MULTIMODULE=false
  STACK_MODULE_LIST=""

  # Maven / Java
  local pom="$project_root/pom.xml"
  if [[ -f "$pom" ]]; then
    STACK_JAVA=true
    grep -q "spring-boot-starter-parent" "$pom" && STACK_SPRING_BOOT=true
    STACK_SPRING_BOOT_VERSION=$(grep -oP '(?<=<version>)[0-9]+\.[0-9]+\.[0-9]+(?=</version>)' "$pom" | head -1)
    grep -q "spring-boot-starter-security" "$pom" && STACK_SPRING_SECURITY=true
    grep -q "lombok" "$pom" && STACK_LOMBOK=true
    grep -q "mapstruct" "$pom" && STACK_MAPSTRUCT=true
    grep -q "spring-boot-starter-data-jpa" "$pom" && STACK_JPA=true
    grep -q "junit-jupiter\|junit-platform" "$pom" && STACK_JUNIT5=true
    grep -q "flyway" "$pom" && STACK_FLYWAY=true
    grep -q "postgresql" "$pom" && STACK_POSTGRESQL=true
    grep -q "<modules>" "$pom" && STACK_MULTIMODULE=true
    if [[ "$STACK_MULTIMODULE" == true ]]; then
      STACK_MODULE_LIST=$(grep -oP '(?<=<module>)[^<]+' "$pom" | tr '\n' ',' | sed 's/,$//')
    fi
  fi

  # Node / Frontend
  local pkg="$project_root/package.json"
  if [[ -f "$pkg" ]]; then
    grep -q '"@angular/core"' "$pkg" && STACK_ANGULAR=true
    grep -q '"react"' "$pkg" && STACK_REACT=true
    grep -q '"typescript"' "$pkg" && STACK_TYPESCRIPT=true
    grep -q '"vite"' "$pkg" && STACK_VITE=true
    grep -q '"eslint"' "$pkg" && STACK_ESLINT=true
  fi

  [[ -f "$project_root/angular.json" ]] && STACK_ANGULAR=true
  [[ -f "$project_root/tsconfig.json" ]] && STACK_TYPESCRIPT=true
  [[ -f "$project_root/docker-compose.yml" || -f "$project_root/docker-compose.yaml" ]] && STACK_DOCKER_COMPOSE=true

  # PostgreSQL via application.yml
  local app_yml="$project_root/src/main/resources/application.yml"
  local app_props="$project_root/src/main/resources/application.properties"
  if [[ -f "$app_yml" ]]; then
    grep -q "postgresql\|postgres" "$app_yml" && STACK_POSTGRESQL=true
  fi
  if [[ -f "$app_props" ]]; then
    grep -q "postgresql\|postgres" "$app_props" && STACK_POSTGRESQL=true
  fi

  # Write cache
  mkdir -p "$(dirname "$project_root/$CACHE_FILE")"
  {
    echo "STACK_JAVA=$STACK_JAVA"
    echo "STACK_SPRING_BOOT=$STACK_SPRING_BOOT"
    echo "STACK_SPRING_BOOT_VERSION=$STACK_SPRING_BOOT_VERSION"
    echo "STACK_SPRING_SECURITY=$STACK_SPRING_SECURITY"
    echo "STACK_LOMBOK=$STACK_LOMBOK"
    echo "STACK_MAPSTRUCT=$STACK_MAPSTRUCT"
    echo "STACK_JPA=$STACK_JPA"
    echo "STACK_JUNIT5=$STACK_JUNIT5"
    echo "STACK_FLYWAY=$STACK_FLYWAY"
    echo "STACK_ANGULAR=$STACK_ANGULAR"
    echo "STACK_REACT=$STACK_REACT"
    echo "STACK_TYPESCRIPT=$STACK_TYPESCRIPT"
    echo "STACK_VITE=$STACK_VITE"
    echo "STACK_ESLINT=$STACK_ESLINT"
    echo "STACK_POSTGRESQL=$STACK_POSTGRESQL"
    echo "STACK_DOCKER_COMPOSE=$STACK_DOCKER_COMPOSE"
    echo "STACK_MULTIMODULE=$STACK_MULTIMODULE"
    echo "STACK_MODULE_LIST=$STACK_MODULE_LIST"
  } > "$project_root/$CACHE_FILE"
}

invalidate_stack_cache() {
  local project_root="${1:-.}"
  rm -f "$project_root/$CACHE_FILE"
}
