#!/usr/bin/env bash
set -euo pipefail

# Oxidized Health Check Script
# Performs comprehensive health checks on Oxidized deployment
# Returns 0 if healthy, non-zero if issues detected

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_FAILURE=1
readonly EXIT_INVALID_USAGE=2

# Configuration (load from .env if available, else use defaults)
# shellcheck disable=SC2155  # Separate declaration is unnecessary for readonly
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${REPO_ROOT}/.env"

# Load .env if it exists
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

# Set defaults if not loaded from .env
readonly OXIDIZED_ROOT="${OXIDIZED_ROOT:-/var/lib/oxidized}"
readonly OXIDIZED_USER="${OXIDIZED_USER:-oxidized}"
readonly OXIDIZED_UID="${OXIDIZED_UID:-2000}"
readonly OXIDIZED_GID="${OXIDIZED_GID:-2000}"
readonly PODMAN_NETWORK="${PODMAN_NETWORK:-oxidized-net}"
readonly OXIDIZED_API_PORT="${OXIDIZED_API_PORT:-8888}"
readonly OXIDIZED_API_HOST="${OXIDIZED_API_HOST:-0.0.0.0}"
readonly CONTAINER_NAME="${CONTAINER_NAME:-oxidized}"

# Colors for output
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_CYAN=$'\033[0;36m'
readonly COLOR_RESET=$'\033[0m'

# Flags
VERBOSE=false
QUIET=false

# Health check results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Logging functions
log_info() {
  if [[ "${QUIET}" == "false" ]]; then
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
  fi
}

log_success() {
  if [[ "${QUIET}" == "false" ]]; then
    echo -e "${COLOR_GREEN}[✓]${COLOR_RESET} $*"
  fi
}

log_warn() {
  if [[ "${QUIET}" == "false" ]]; then
    echo -e "${COLOR_YELLOW}[⚠]${COLOR_RESET} $*"
  fi
}

log_error() {
  if [[ "${QUIET}" == "false" ]]; then
    echo -e "${COLOR_RED}[✗]${COLOR_RESET} $*" >&2
  fi
}

log_check() {
  local status=$1
  local message=$2

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  case "${status}" in
    "OK")
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
      log_success "${message}"
      ;;
    "WARNING")
      WARNING_CHECKS=$((WARNING_CHECKS + 1))
      log_warn "${message}"
      ;;
    "CRITICAL")
      FAILED_CHECKS=$((FAILED_CHECKS + 1))
      log_error "${message}"
      ;;
  esac
}

# Show usage
usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Performs health checks on Oxidized deployment.

OPTIONS:
    -v, --verbose           Show detailed output
    -q, --quiet             Suppress output (exit code only)
    -h, --help              Show this help message

EXIT CODES:
    0    All checks passed
    1    Critical failures detected
    2    Invalid usage

EXAMPLES:
    # Standard health check
    $(basename "$0")

    # Verbose output
    $(basename "$0") --verbose

EOF
}

# Check if systemd service exists and is active
check_service() {
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo -e "${COLOR_CYAN}==> Checking Systemd Service${COLOR_RESET}"
  fi

  # Service exists (check both unit files and loaded units for Quadlet)
  if systemctl list-unit-files 2> /dev/null | grep -q "oxidized.service"; then
    log_check "OK" "Service unit file exists (Quadlet-generated)"
  elif systemctl status oxidized.service &> /dev/null || systemctl list-units --all 2> /dev/null | grep -q "oxidized.service"; then
    log_check "OK" "Service exists"
  else
    log_check "CRITICAL" "Service not found"
    return
  fi

  # Service is enabled (Quadlet services show as "generated" or "indirect")
  if systemctl is-enabled oxidized.service 2>&1 | grep -qE "enabled|generated|indirect"; then
    log_check "OK" "Service is enabled (auto-start configured)"
  else
    log_check "WARNING" "Service is not enabled for auto-start"
  fi

  # Service is active
  if systemctl is-active --quiet oxidized.service 2> /dev/null; then
    log_check "OK" "Service is active (running)"
  else
    log_check "CRITICAL" "Service is not active"
    return
  fi
}

# Check Podman container
check_container() {
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo -e "${COLOR_CYAN}==> Checking Podman Container${COLOR_RESET}"
  fi

  # Container exists
  if podman ps -a --format "{{.Names}}" 2> /dev/null | grep -q "^${CONTAINER_NAME}$"; then
    log_check "OK" "Container exists"
  else
    log_check "CRITICAL" "Container not found"
    return
  fi

  # Container is running
  if podman ps --format "{{.Names}}" 2> /dev/null | grep -q "^${CONTAINER_NAME}$"; then
    log_check "OK" "Container is running"

    # Show uptime
    local uptime
    uptime=$(podman ps --format "{{.Status}}" --filter "name=${CONTAINER_NAME}" 2> /dev/null | head -1)
    log_info "Container uptime: ${uptime}"
  else
    log_check "CRITICAL" "Container is not running"
    return
  fi
}

# Check REST API
check_api() {
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo -e "${COLOR_CYAN}==> Checking REST API${COLOR_RESET}"
  fi

  # Check backend directly (Oxidized on localhost:8889)
  local backend_url="http://127.0.0.1:8889"
  if timeout 5 curl -sf "${backend_url}/nodes.json" > /dev/null 2>&1; then
    log_check "OK" "Backend is reachable at ${backend_url}"

    # Get node statistics from backend
    local total_nodes
    total_nodes=$(curl -sf "${backend_url}/nodes.json" 2> /dev/null | jq '. | length' 2> /dev/null || echo "0")

    if [[ ${total_nodes} -gt 0 ]]; then
      log_check "OK" "Found ${total_nodes} devices in inventory"
    else
      log_check "WARNING" "No devices in inventory (empty router.db)"
    fi
  else
    log_check "WARNING" "Backend not responding (may be expected if no devices configured)"
  fi

  # Check frontend (nginx proxy on port 8888)
  local frontend_url="http://localhost:${OXIDIZED_API_PORT}"
  local http_code
  http_code=$(timeout 5 curl -s -o /dev/null -w "%{http_code}" "${frontend_url}/" 2> /dev/null || echo "000")

  if [[ "${http_code}" == "401" ]]; then
    log_check "OK" "Frontend (nginx) is reachable at ${frontend_url} (auth required)"
  elif [[ "${http_code}" == "303" ]] || [[ "${http_code}" == "200" ]]; then
    log_check "OK" "Frontend (nginx) is reachable at ${frontend_url}"
  else
    log_check "WARNING" "Frontend not responding (HTTP ${http_code})"
  fi
}

# Check persistent storage
check_storage() {
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo -e "${COLOR_CYAN}==> Checking Persistent Storage${COLOR_RESET}"
  fi

  # Check oxidized user exists
  if id "${OXIDIZED_USER}" > /dev/null 2>&1; then
    local actual_uid
    actual_uid=$(id -u "${OXIDIZED_USER}")
    if [[ "${actual_uid}" == "${OXIDIZED_UID}" ]]; then
      log_check "OK" "User ${OXIDIZED_USER} exists with correct UID ${OXIDIZED_UID}"
    else
      log_check "WARNING" "User ${OXIDIZED_USER} exists but has UID ${actual_uid}, expected ${OXIDIZED_UID}"
    fi
  else
    log_check "CRITICAL" "User ${OXIDIZED_USER} does not exist"
  fi

  # Check main directory
  if [[ -d "${OXIDIZED_ROOT}" ]]; then
    log_check "OK" "Main data directory exists: ${OXIDIZED_ROOT}"
  else
    log_check "CRITICAL" "Main data directory missing: ${OXIDIZED_ROOT}"
    return
  fi

  # Check subdirectories
  local dirs=("config" "ssh" "data" "output" "repo")
  for dir in "${dirs[@]}"; do
    if [[ -d "${OXIDIZED_ROOT}/${dir}" ]]; then
      log_check "OK" "Directory exists: ${dir}/"
    else
      log_check "CRITICAL" "Directory missing: ${dir}/"
    fi
  done

  # Check config file
  if [[ -f "${OXIDIZED_ROOT}/config/config" ]]; then
    log_check "OK" "Config file exists"
  else
    log_check "CRITICAL" "Config file missing"
  fi

  # Check router database
  if [[ -f "${OXIDIZED_ROOT}/config/router.db" ]]; then
    log_check "OK" "Router database exists"
  else
    log_check "WARNING" "Router database missing"
  fi

  # Check Git repository
  if [[ -d "${OXIDIZED_ROOT}/repo/.git" ]]; then
    log_check "OK" "Git repository initialized"
  else
    log_check "WARNING" "Git repository not initialized"
  fi

  # Check disk space
  local available_space
  available_space=$(df -BG "${OXIDIZED_ROOT}" 2> /dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")

  if [[ ${available_space} -gt 5 ]]; then
    log_check "OK" "Available disk space: ${available_space}GB"
  elif [[ ${available_space} -gt 2 ]]; then
    log_check "WARNING" "Available disk space: ${available_space}GB (low)"
  else
    log_check "CRITICAL" "Available disk space: ${available_space}GB (critical)"
  fi
}

# Show deployment information
show_deployment_info() {
  if [[ "${QUIET}" == "true" ]]; then
    return
  fi

  echo ""
  echo -e "${COLOR_CYAN}========================================="
  echo -e "  Deployment Information"
  echo -e "=========================================${COLOR_RESET}"
  echo ""

  # Access URLs
  echo -e "${COLOR_GREEN}Access URLs (Frontend - nginx):${COLOR_RESET}"
  if [[ "${OXIDIZED_API_HOST}" == "0.0.0.0" ]]; then
    local host_ip
    host_ip=$(hostname -I | awk '{print $1}')
    echo "  Web UI:    http://${host_ip}:${OXIDIZED_API_PORT}"
    echo "  API:       http://${host_ip}:${OXIDIZED_API_PORT}/nodes.json"
  else
    echo "  Web UI:    http://${OXIDIZED_API_HOST}:${OXIDIZED_API_PORT}"
    echo "  API:       http://${OXIDIZED_API_HOST}:${OXIDIZED_API_PORT}/nodes.json"
  fi
  echo "  Local:     http://localhost:${OXIDIZED_API_PORT}"
  echo ""
  echo -e "${COLOR_GREEN}Backend (Oxidized - Direct):${COLOR_RESET}"
  echo "  Direct:    http://127.0.0.1:8889"
  echo "  API:       http://127.0.0.1:8889/nodes.json"
  echo "  Note:      Backend only accessible from localhost (via nginx proxy)"
  echo ""

  # Running Containers
  echo -e "${COLOR_GREEN}Running Containers:${COLOR_RESET}"
  if podman ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2> /dev/null | grep -v "^NAMES"; then
    :
  else
    echo "  No oxidized containers running"
  fi
  echo ""

  # Container Bind Mounts
  echo -e "${COLOR_GREEN}Container Bind Mounts:${COLOR_RESET}"
  if podman inspect "${CONTAINER_NAME}" --format '{{range .Mounts}}  {{.Source}} -> {{.Destination}} ({{.Type}}, {{.Mode}}){{"\n"}}{{end}}' 2> /dev/null; then
    :
  else
    echo "  Container not running or not found"
  fi
  echo ""

  # Network Interfaces
  echo -e "${COLOR_GREEN}Network Listening:${COLOR_RESET}"
  if ss -tlnp 2> /dev/null | grep ":${OXIDIZED_API_PORT}" | head -3; then
    :
  else
    echo "  Port ${OXIDIZED_API_PORT} not listening"
  fi
  echo ""

  # Podman Network
  echo -e "${COLOR_GREEN}Podman Network:${COLOR_RESET}"
  if podman network exists "${PODMAN_NETWORK}" 2> /dev/null; then
    podman network inspect "${PODMAN_NETWORK}" --format "  Name: {{.Name}}, Driver: {{.Driver}}, Subnet: {{range .Subnets}}{{.Subnet}}{{end}}" 2> /dev/null || echo "  ${PODMAN_NETWORK} (exists)"
  else
    echo "  Network ${PODMAN_NETWORK} not found"
  fi
  echo ""

  # File Locations
  echo -e "${COLOR_GREEN}Important File Locations:${COLOR_RESET}"
  echo "  Config:        ${OXIDIZED_ROOT}/config/config"
  echo "  Inventory:     ${OXIDIZED_ROOT}/config/router.db"
  echo "  Git Repo:      ${OXIDIZED_ROOT}/repo/"
  echo "  Logs:          ${OXIDIZED_ROOT}/data/oxidized.log"
  echo "  SSH Keys:      ${OXIDIZED_ROOT}/ssh/"
  echo "  Quadlet:       /etc/containers/systemd/oxidized.container"
  echo ""
}

# Show summary
show_summary() {
  if [[ "${QUIET}" == "true" ]]; then
    return
  fi

  echo ""
  echo -e "${COLOR_CYAN}========================================="
  echo -e "  Health Check Summary"
  echo -e "=========================================${COLOR_RESET}"
  echo ""
  echo -e "Total Checks:    ${TOTAL_CHECKS}"
  echo -e "${COLOR_GREEN}Passed:${COLOR_RESET}          ${PASSED_CHECKS}"
  echo -e "${COLOR_YELLOW}Warnings:${COLOR_RESET}        ${WARNING_CHECKS}"
  echo -e "${COLOR_RED}Failed:${COLOR_RESET}          ${FAILED_CHECKS}"
  echo ""

  if [[ ${FAILED_CHECKS} -gt 0 ]]; then
    echo -e "${COLOR_RED}Status: CRITICAL${COLOR_RESET}"
    echo ""
    echo "Critical issues detected. Check the details above."
  elif [[ ${WARNING_CHECKS} -gt 0 ]]; then
    echo -e "${COLOR_YELLOW}Status: WARNING${COLOR_RESET}"
    echo ""
    echo "Some warnings detected. Review the details above."
  else
    echo -e "${COLOR_GREEN}Status: HEALTHY${COLOR_RESET}"
    echo ""
    echo "All checks passed successfully! 🎉"
  fi

  echo ""
}

# Main function
main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v | --verbose)
        # shellcheck disable=SC2034  # VERBOSE reserved for future enhancements
        VERBOSE=true
        shift
        ;;
      -q | --quiet)
        QUIET=true
        shift
        ;;
      -h | --help)
        usage
        exit ${EXIT_SUCCESS}
        ;;
      *)
        echo "Unknown option: $1"
        usage
        exit ${EXIT_INVALID_USAGE}
        ;;
    esac
  done

  # Banner
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo -e "${COLOR_CYAN}========================================="
    echo -e "  Oxidized Health Check"
    echo -e "=========================================${COLOR_RESET}"
  fi

  # Run health checks
  check_service
  check_container
  check_api
  check_storage

  # Show deployment info
  show_deployment_info

  # Show summary
  show_summary

  # Exit with appropriate code
  if [[ ${FAILED_CHECKS} -gt 0 ]]; then
    exit ${EXIT_GENERAL_FAILURE}
  else
    exit ${EXIT_SUCCESS}
  fi
}

# Run main function
main "$@"
