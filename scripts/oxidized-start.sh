#!/usr/bin/env bash
set -euo pipefail

# Oxidized Service Start Script
# Handles PID file cleanup before starting the service
# This prevents startup failures due to stale PID files

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

# Remove stale PID file
remove_pid_file() {
  local pid_file="${OXIDIZED_ROOT}/data/oxidized.pid"

  if [[ -f "${pid_file}" ]]; then
    log_warn "Found existing PID file: ${pid_file}"

    # Check if the process is actually running
    if [[ -r "${pid_file}" ]]; then
      local pid
      pid=$(cat "${pid_file}" 2> /dev/null || echo "")

      if [[ -n "${pid}" ]] && kill -0 "${pid}" 2> /dev/null; then
        log_warn "Process ${pid} is still running - this might not be a stale PID file"
        log_info "Checking if oxidized service is already running..."

        if systemctl is-active --quiet "${SERVICE_NAME}"; then
          log_error "Service ${SERVICE_NAME} is already running"
          log_info "Use 'systemctl restart ${SERVICE_NAME}' to restart the service"
          exit 1
        fi
      fi
    fi

    log_info "Removing stale PID file..."
    if rm -f "${pid_file}"; then
      log_success "Removed PID file: ${pid_file}"
    else
      log_error "Failed to remove PID file: ${pid_file}"
      exit 1
    fi
  else
    log_info "No PID file found (clean start)"
  fi
}

# Start the service
start_service() {
  log_info "Starting ${SERVICE_NAME}..."

  if systemctl start "${SERVICE_NAME}"; then
    log_success "Service started successfully"

    # Wait a moment for service to initialize
    sleep 2

    # Verify service is running
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
      log_success "${SERVICE_NAME} is active"

      # Show brief status
      systemctl status "${SERVICE_NAME}" --no-pager -l | head -n 10
    else
      log_error "Service failed to start"
      log_error "Check logs with: journalctl -u ${SERVICE_NAME} -n 50"
      exit 1
    fi
  else
    log_error "Failed to start service"
    log_error "Check logs with: journalctl -u ${SERVICE_NAME} -n 50"
    exit 1
  fi
}

# Main function
main() {
  echo ""
  echo "========================================"
  echo "  Oxidized Service Start"
  echo "========================================"
  echo ""

  check_root
  load_env
  remove_pid_file
  start_service

  echo ""
  log_success "Oxidized service started successfully!"
  echo ""
  log_info "Useful commands:"
  echo "  systemctl status ${SERVICE_NAME}    # Check service status"
  echo "  podman logs -f oxidized             # View container logs"
  echo "  journalctl -u ${SERVICE_NAME} -f    # View service logs"
  echo ""
}

# Run main function
main "$@"
