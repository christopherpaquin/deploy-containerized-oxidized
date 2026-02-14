#!/usr/bin/env bash
set -euo pipefail

# Oxidized Service Stop Script
# Handles graceful service shutdown and PID file cleanup

# Colors for output
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_RESET=$'\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Look for .env in deployed location first, then fall back to repo
if [[ -f "/var/lib/oxidized/.env" ]]; then
  readonly ENV_FILE="/var/lib/oxidized/.env"
else
  readonly ENV_FILE="${REPO_ROOT}/.env"
fi

# Service name
readonly SERVICE_NAME="oxidized.service"

# Logging functions
log_info() {
  echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
  echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

log_warn() {
  echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

log_error() {
  echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# Check if running as root
check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    log_error "This script must be run as root (or with sudo)"
    exit 1
  fi
}

# Load environment configuration
load_env() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    log_error ".env file not found: ${ENV_FILE}"
    log_error "Cannot determine OXIDIZED_ROOT path"
    exit 1
  fi

  # Source the .env file
  # shellcheck disable=SC1090
  source "${ENV_FILE}"

  if [[ -z "${OXIDIZED_ROOT:-}" ]]; then
    log_error "OXIDIZED_ROOT not set in ${ENV_FILE}"
    exit 1
  fi
}

# Stop the service
stop_service() {
  log_info "Checking service status..."

  if systemctl is-active --quiet "${SERVICE_NAME}"; then
    log_info "Stopping ${SERVICE_NAME}..."

    if systemctl stop "${SERVICE_NAME}"; then
      log_success "Service stopped successfully"

      # Wait for service to fully stop
      local max_wait=30
      local count=0
      while systemctl is-active --quiet "${SERVICE_NAME}" && [[ ${count} -lt ${max_wait} ]]; do
        sleep 1
        ((count++))
      done

      if systemctl is-active --quiet "${SERVICE_NAME}"; then
        log_warn "Service did not stop within ${max_wait} seconds"
        log_info "Checking service status..."
        systemctl status "${SERVICE_NAME}" --no-pager || true
      else
        log_success "Service stopped cleanly"
      fi
    else
      log_error "Failed to stop service"
      log_error "Check logs with: journalctl -u ${SERVICE_NAME} -n 50"
      exit 1
    fi
  else
    log_info "Service is not running"
  fi
}

# Remove PID file
remove_pid_file() {
  local pid_file="${OXIDIZED_ROOT}/data/oxidized.pid"

  if [[ -f "${pid_file}" ]]; then
    log_info "Removing PID file: ${pid_file}"

    if rm -f "${pid_file}"; then
      log_success "Removed PID file"
    else
      log_error "Failed to remove PID file: ${pid_file}"
      log_warn "You may need to remove it manually before starting the service"
      exit 1
    fi
  else
    log_info "No PID file to remove"
  fi
}

# Verify container is stopped
verify_container_stopped() {
  log_info "Verifying container status..."

  if podman ps --format "{{.Names}}" | grep -q "^oxidized$"; then
    log_warn "Container is still running"
    log_info "Stopping container directly..."

    if podman stop oxidized; then
      log_success "Container stopped"
    else
      log_error "Failed to stop container"
      exit 1
    fi
  else
    log_info "Container is not running"
  fi
}

# Main function
main() {
  echo ""
  echo "========================================"
  echo "  Oxidized Service Stop"
  echo "========================================"
  echo ""

  check_root
  load_env
  stop_service
  verify_container_stopped
  remove_pid_file

  echo ""
  log_success "Oxidized service stopped successfully!"
  echo ""
  log_info "To start the service again, run:"
  echo "  sudo ${SCRIPT_DIR}/oxidized-start.sh"
  echo "  OR"
  echo "  sudo systemctl start ${SERVICE_NAME}"
  echo ""
}

# Run main function
main "$@"
