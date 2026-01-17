#!/usr/bin/env bash
set -euo pipefail

# validate-env.sh - Validate .env configuration file
# Checks for required variables, security issues, and common mistakes

# shellcheck disable=SC2155  # Declare and assign separately (not critical for readonly)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155  # Declare and assign separately (not critical for readonly)
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${REPO_ROOT}/.env"
readonly ENV_EXAMPLE="${REPO_ROOT}/env.example"

# Colors
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Counters
ERRORS=0
WARNINGS=0
INFO=0

# Logging functions
log_error() {
  echo -e "${COLOR_RED}✗ ERROR:${COLOR_RESET} $*" >&2
  ((ERRORS++))
}

log_warn() {
  echo -e "${COLOR_YELLOW}⚠ WARNING:${COLOR_RESET} $*"
  ((WARNINGS++))
}

log_info() {
  echo -e "${COLOR_BLUE}ℹ INFO:${COLOR_RESET} $*"
  ((INFO++))
}

log_success() {
  echo -e "${COLOR_GREEN}✓ ${COLOR_RESET}$*"
}

# Check if .env file exists
check_file_exists() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  .env File Validation"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if [[ ! -f "${ENV_FILE}" ]]; then
    log_error ".env file not found: ${ENV_FILE}"
    echo ""
    echo "To create from template:"
    echo "  cp ${ENV_EXAMPLE} ${ENV_FILE}"
    echo "  vim ${ENV_FILE}"
    echo "  chmod 600 ${ENV_FILE}"
    exit 1
  fi

  log_success ".env file exists: ${ENV_FILE}"
}

# Check file permissions
check_permissions() {
  local perms
  perms=$(stat -c "%a" "${ENV_FILE}" 2> /dev/null || stat -f "%A" "${ENV_FILE}" 2> /dev/null || echo "000")

  if [[ "${perms}" != "600" ]]; then
    log_warn "Insecure permissions: ${perms} (should be 600)"
    echo "  Fix: chmod 600 ${ENV_FILE}"
  else
    log_success "File permissions: ${perms}"
  fi

  # Check ownership
  local owner
  owner=$(stat -c "%U" "${ENV_FILE}" 2> /dev/null || stat -f "%Su" "${ENV_FILE}" 2> /dev/null || echo "unknown")

  if [[ "${owner}" == "root" ]] && [[ "${EUID}" -ne 0 ]]; then
    log_warn "File owned by root, but running as ${USER}"
  else
    log_success "File ownership: ${owner}"
  fi
}

# Load and validate required variables
check_required_variables() {
  echo ""
  echo "Checking required variables..."
  echo ""

  # Source the .env file
  # shellcheck disable=SC1090
  source "${ENV_FILE}"

  local required_vars=(
    "OXIDIZED_USER"
    "OXIDIZED_GROUP"
    "OXIDIZED_UID"
    "OXIDIZED_GID"
    "OXIDIZED_ROOT"
    "OXIDIZED_IMAGE"
    "CONTAINER_NAME"
    "PODMAN_NETWORK"
    "OXIDIZED_USERNAME"
    "OXIDIZED_PASSWORD"
  )

  local missing=0

  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      log_error "Missing required variable: ${var}"
      ((missing++))
    else
      log_success "${var} is set"
    fi
  done

  if [[ ${missing} -gt 0 ]]; then
    echo ""
    log_error "${missing} required variable(s) missing"
    echo "  Check: diff env.example .env"
  fi
}

# Check for security issues
check_security() {
  echo ""
  echo "Security checks..."
  echo ""

  # shellcheck disable=SC1090
  source "${ENV_FILE}"

  # Check for default password
  if [[ "${OXIDIZED_PASSWORD:-}" == "changeme" ]]; then
    log_error "Default password detected: OXIDIZED_PASSWORD='changeme'"
    echo "  CRITICAL: Change this before deployment!"
  else
    log_success "OXIDIZED_PASSWORD is not default"
  fi

  # Check password strength
  if [[ -n "${OXIDIZED_PASSWORD:-}" ]] && [[ ${#OXIDIZED_PASSWORD} -lt 8 ]]; then
    log_warn "OXIDIZED_PASSWORD is short (< 8 characters)"
    echo "  Recommendation: Use at least 12 characters"
  fi

  # Check for latest image tag
  if [[ "${OXIDIZED_IMAGE:-}" == *":latest" ]]; then
    log_warn "Image uses 'latest' tag: ${OXIDIZED_IMAGE}"
    echo "  Recommendation: Pin to specific version (e.g., :0.30.1)"
  else
    log_success "Image is pinned to version: ${OXIDIZED_IMAGE}"
  fi

  # Check API host binding
  if [[ "${OXIDIZED_API_HOST:-}" == "0.0.0.0" ]]; then
    log_info "API listening on all interfaces (0.0.0.0)"
    echo "  Consider: Use 127.0.0.1 for localhost-only access"
  else
    log_success "API host: ${OXIDIZED_API_HOST}"
  fi

  # Check Web UI enabled
  if [[ "${OXIDIZED_WEB_UI:-false}" == "true" ]]; then
    log_info "Web UI is enabled"
    echo "  Ensure: Firewall is configured appropriately"
  fi
}

# Check for common mistakes
check_common_mistakes() {
  echo ""
  echo "Checking for common mistakes..."
  echo ""

  # shellcheck disable=SC1090
  source "${ENV_FILE}"

  # Check UID/GID are numeric
  if ! [[ "${OXIDIZED_UID:-0}" =~ ^[0-9]+$ ]]; then
    log_error "OXIDIZED_UID is not numeric: ${OXIDIZED_UID}"
  else
    log_success "OXIDIZED_UID is numeric: ${OXIDIZED_UID}"
  fi

  if ! [[ "${OXIDIZED_GID:-0}" =~ ^[0-9]+$ ]]; then
    log_error "OXIDIZED_GID is not numeric: ${OXIDIZED_GID}"
  else
    log_success "OXIDIZED_GID is numeric: ${OXIDIZED_GID}"
  fi

  # Check poll interval is reasonable
  if [[ "${POLL_INTERVAL:-3600}" -lt 300 ]]; then
    log_warn "POLL_INTERVAL is very short: ${POLL_INTERVAL} seconds"
    echo "  Warning: May cause high CPU/network load"
  fi

  # Check threads is reasonable
  if [[ "${THREADS:-30}" -gt 100 ]]; then
    log_warn "THREADS is very high: ${THREADS}"
    echo "  Warning: May cause excessive resource usage"
  fi

  # Check memory limit format
  if [[ -n "${MEMORY_LIMIT:-}" ]] && ! [[ "${MEMORY_LIMIT}" =~ ^[0-9]+[KMG]$ ]]; then
    log_error "Invalid MEMORY_LIMIT format: ${MEMORY_LIMIT}"
    echo "  Expected: Number with K/M/G suffix (e.g., 1G, 512M)"
  fi

  # Check CPU quota format
  if [[ -n "${CPU_QUOTA:-}" ]] && ! [[ "${CPU_QUOTA}" =~ ^[0-9]+%$ ]]; then
    log_error "Invalid CPU_QUOTA format: ${CPU_QUOTA}"
    echo "  Expected: Number with % suffix (e.g., 100%, 200%)"
  fi

  # Check for trailing whitespace in critical variables
  if [[ "${OXIDIZED_PASSWORD:-}" != "${OXIDIZED_PASSWORD// /}" ]]; then
    log_warn "OXIDIZED_PASSWORD contains spaces"
    echo "  Verify: This is intentional"
  fi
}

# Check directory paths
check_paths() {
  echo ""
  echo "Checking directory paths..."
  echo ""

  # shellcheck disable=SC1090
  source "${ENV_FILE}"

  # Check OXIDIZED_ROOT is absolute path
  if [[ "${OXIDIZED_ROOT:0:1}" != "/" ]]; then
    log_error "OXIDIZED_ROOT must be absolute path: ${OXIDIZED_ROOT}"
  else
    log_success "OXIDIZED_ROOT is absolute: ${OXIDIZED_ROOT}"
  fi

  # Check if OXIDIZED_ROOT exists (if running as root)
  if [[ "${EUID}" -eq 0 ]] && [[ -d "${OXIDIZED_ROOT}" ]]; then
    log_info "OXIDIZED_ROOT exists: ${OXIDIZED_ROOT}"

    # Check ownership if exists
    local owner_uid
    owner_uid=$(stat -c "%u" "${OXIDIZED_ROOT}" 2> /dev/null || stat -f "%u" "${OXIDIZED_ROOT}" 2> /dev/null || echo "0")

    if [[ "${owner_uid}" != "${OXIDIZED_UID:-2000}" ]]; then
      log_warn "OXIDIZED_ROOT ownership mismatch"
      echo "  Current: UID ${owner_uid}, Expected: UID ${OXIDIZED_UID}"
    else
      log_success "OXIDIZED_ROOT ownership correct"
    fi
  fi
}

# Summary report
print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Validation Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if [[ ${ERRORS} -eq 0 ]] && [[ ${WARNINGS} -eq 0 ]]; then
    echo -e "${COLOR_GREEN}✓ All checks passed!${COLOR_RESET}"
    echo ""
    echo "Your .env file is ready for deployment."
    echo ""
    echo "Next steps:"
    echo "  1. Review configuration: cat .env"
    echo "  2. Run deployment: sudo ./scripts/deploy.sh"
    echo "  3. Check health: sudo ./scripts/health-check.sh"
  else
    if [[ ${ERRORS} -gt 0 ]]; then
      echo -e "${COLOR_RED}✗ ${ERRORS} error(s) found${COLOR_RESET}"
      echo "  Fix errors before deployment"
    fi

    if [[ ${WARNINGS} -gt 0 ]]; then
      echo -e "${COLOR_YELLOW}⚠ ${WARNINGS} warning(s) found${COLOR_RESET}"
      echo "  Review warnings and adjust if needed"
    fi

    echo ""
    echo "Recommendations:"
    echo "  1. Address errors and warnings above"
    echo "  2. Compare with template: diff env.example .env"
    echo "  3. Re-run validation: ./scripts/validate-env.sh"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main execution
main() {
  check_file_exists
  check_permissions
  check_required_variables
  check_security
  check_common_mistakes
  check_paths
  print_summary

  # Exit with error if any errors found
  if [[ ${ERRORS} -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
