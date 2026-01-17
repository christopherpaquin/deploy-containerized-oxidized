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
readonly OXIDIZED_API="http://localhost:${OXIDIZED_API_PORT}"
# shellcheck disable=SC2034  # Reserved for future use
readonly QUADLET_FILE="/etc/containers/systemd/oxidized.container"

# Colors for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Flags
VERBOSE=false
JSON_OUTPUT=false
NAGIOS_MODE=false
QUIET=false

# Health check results
declare -A CHECKS
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Logging functions
# shellcheck disable=SC2317  # Function invoked via trap/conditionals
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

  ((TOTAL_CHECKS++))

  case "${status}" in
    "OK")
      ((PASSED_CHECKS++))
      CHECKS["${message}"]="OK"
      log_success "${message}"
      ;;
    "WARNING")
      ((WARNING_CHECKS++))
      CHECKS["${message}"]="WARNING"
      log_warn "${message}"
      ;;
    "CRITICAL")
      ((FAILED_CHECKS++))
      CHECKS["${message}"]="CRITICAL"
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
    -j, --json              Output results as JSON
    -n, --nagios            Nagios-compatible output
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

    # JSON output for monitoring
    $(basename "$0") --json

    # Nagios plugin mode
    $(basename "$0") --nagios

NOTES:
    - Checks service status, container health, API, and data
    - Can be run by any user (some checks require root)
    - Suitable for monitoring integration (Zabbix, Nagios, etc.)

EOF
}

# Check if systemd service exists and is active
check_service() {
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo "==> Checking Systemd Service"
  fi

  # Service exists
  if systemctl list-unit-files | grep -q "oxidized.service"; then
    log_check "OK" "Service unit file exists"
  else
    log_check "CRITICAL" "Service unit file not found"
    return
  fi

  # Service is enabled
  if systemctl is-enabled --quiet oxidized.service 2> /dev/null; then
    log_check "OK" "Service is enabled (starts on boot)"
  else
    log_check "WARNING" "Service is not enabled"
  fi

  # Service is active
  if systemctl is-active --quiet oxidized.service 2> /dev/null; then
    log_check "OK" "Service is active (running)"
  else
    log_check "CRITICAL" "Service is not active"
    return
  fi

  # Service has no failed state
  if systemctl is-failed --quiet oxidized.service 2> /dev/null; then
    log_check "CRITICAL" "Service is in failed state"
  else
    log_check "OK" "Service is not failed"
  fi
}

# Check Podman container
check_container() {
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo "==> Checking Podman Container"
  fi

  # Container exists
  if podman ps -a --format "{{.Names}}" | grep -q "^oxidized$"; then
    log_check "OK" "Container exists"
  else
    log_check "CRITICAL" "Container not found"
    return
  fi

  # Container is running
  if podman ps --format "{{.Names}}" | grep -q "^oxidized$"; then
    log_check "OK" "Container is running"
  else
    log_check "CRITICAL" "Container is not running"
    return
  fi

  # Container health status (if health check defined)
  local health_status
  health_status=$(podman inspect oxidized --format "{{.State.Health.Status}}" 2> /dev/null || echo "none")

  if [[ "${health_status}" == "healthy" ]]; then
    log_check "OK" "Container health check: healthy"
  elif [[ "${health_status}" == "starting" ]]; then
    log_check "WARNING" "Container health check: starting"
  elif [[ "${health_status}" == "unhealthy" ]]; then
    log_check "CRITICAL" "Container health check: unhealthy"
  else
    log_check "OK" "Container health check: not configured"
  fi

  # Container restart count
  local restart_count
  restart_count=$(podman inspect oxidized --format "{{.RestartCount}}" 2> /dev/null || echo "0")

  if [[ ${restart_count} -eq 0 ]]; then
    log_check "OK" "Container has not restarted"
  elif [[ ${restart_count} -lt 5 ]]; then
    log_check "WARNING" "Container has restarted ${restart_count} times"
  else
    log_check "CRITICAL" "Container has restarted ${restart_count} times (excessive)"
  fi
}

# Check REST API
check_api() {
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo "==> Checking REST API"
  fi

  # API is reachable
  if curl -sf "${OXIDIZED_API}/" > /dev/null 2>&1; then
    log_check "OK" "API is reachable"
  else
    log_check "CRITICAL" "API is not reachable"
    return
  fi

  # API returns valid JSON
  if curl -sf "${OXIDIZED_API}/nodes.json" | jq -e '.' > /dev/null 2>&1; then
    log_check "OK" "API returns valid JSON"
  else
    log_check "CRITICAL" "API does not return valid JSON"
    return
  fi

  # Get node statistics
  local total_nodes success_nodes
  total_nodes=$(curl -sf "${OXIDIZED_API}/nodes.json" | jq '. | length' 2> /dev/null || echo "0")
  success_nodes=$(curl -sf "${OXIDIZED_API}/nodes.json" | jq '[.[] | select(.status == "success")] | length' 2> /dev/null || echo "0")
  # shellcheck disable=SC2034  # Reserved for future use
  local failed_nodes=$((total_nodes - success_nodes))

  if [[ ${total_nodes} -gt 0 ]]; then
    log_check "OK" "Found ${total_nodes} devices in inventory"
  else
    log_check "WARNING" "No devices in inventory"
  fi

  # Success rate check
  if [[ ${total_nodes} -gt 0 ]]; then
    local success_rate=$((success_nodes * 100 / total_nodes))

    if [[ ${success_rate} -ge 90 ]]; then
      log_check "OK" "Backup success rate: ${success_rate}% (${success_nodes}/${total_nodes})"
    elif [[ ${success_rate} -ge 70 ]]; then
      log_check "WARNING" "Backup success rate: ${success_rate}% (${success_nodes}/${total_nodes})"
    else
      log_check "CRITICAL" "Backup success rate: ${success_rate}% (${success_nodes}/${total_nodes})"
    fi
  fi
}

# Check persistent storage
check_storage() {
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo "==> Checking Persistent Storage"
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

  # Check directories exist
  local dirs=("config" "ssh" "data" "output" "repo")

  for dir in "${dirs[@]}"; do
    if [[ -d "${OXIDIZED_ROOT}/${dir}" ]]; then
      log_check "OK" "Directory exists: ${OXIDIZED_ROOT}/${dir}"

      # Check ownership
      local dir_owner
      dir_owner=$(stat -c "%u:%g" "${OXIDIZED_ROOT}/${dir}" 2> /dev/null || echo "unknown")
      if [[ "${dir_owner}" == "${OXIDIZED_UID}:${OXIDIZED_GID}" ]]; then
        log_check "OK" "Correct ownership on ${dir}: ${dir_owner}"
      else
        log_check "WARNING" "Incorrect ownership on ${dir}: ${dir_owner}, expected ${OXIDIZED_UID}:${OXIDIZED_GID}"
      fi
    else
      log_check "CRITICAL" "Directory missing: ${OXIDIZED_ROOT}/${dir}"
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

    # Check if router.db is not empty
    local device_count
    device_count=$(wc -l < "${OXIDIZED_ROOT}/config/router.db" 2> /dev/null || echo "0")

    if [[ ${device_count} -gt 1 ]]; then
      log_check "OK" "Router database has $((device_count - 1)) devices (excluding header)"
    else
      log_check "WARNING" "Router database is empty or only has header"
    fi
  else
    log_check "WARNING" "Router database missing"
  fi

  # Check Git repository
  if [[ -d "${OXIDIZED_ROOT}/repo/.git" ]]; then
    log_check "OK" "Git repository initialized"

    # Check if there are commits
    if cd "${OXIDIZED_ROOT}/repo" 2> /dev/null && sudo -u "${OXIDIZED_USER}" git log --oneline -1 &> /dev/null; then
      local commit_count
      commit_count=$(sudo -u "${OXIDIZED_USER}" git rev-list --count HEAD 2> /dev/null || echo "0")
      log_check "OK" "Git repository has ${commit_count} commits"
      cd - > /dev/null
    else
      log_check "WARNING" "Git repository has no commits yet"
    fi
  else
    log_check "WARNING" "Git repository not initialized"
  fi

  # Check log file
  if [[ -f "${OXIDIZED_ROOT}/data/oxidized.log" ]]; then
    log_check "OK" "Log file exists"

    # Check log file size
    local log_size
    log_size=$(stat -c%s "${OXIDIZED_ROOT}/data/oxidized.log" 2> /dev/null || echo "0")
    local log_size_mb=$((log_size / 1024 / 1024))

    if [[ ${log_size_mb} -lt 100 ]]; then
      log_check "OK" "Log file size: ${log_size_mb}MB"
    else
      log_check "WARNING" "Log file size: ${log_size_mb}MB (consider rotation)"
    fi
  else
    log_check "WARNING" "Log file not found (may not have started yet)"
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

# Check container resources
check_resources() {
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo "==> Checking Container Resources"
  fi

  # Get container stats
  local stats
  stats=$(podman stats oxidized --no-stream --format "{{.MemUsage}} {{.CPUPerc}}" 2> /dev/null || echo "0B / 0B 0.00%")

  local mem_usage mem_limit cpu_usage
  mem_usage=$(echo "${stats}" | awk '{print $1}' | sed 's/[^0-9.]//g')
  mem_limit=$(echo "${stats}" | awk '{print $3}' | sed 's/[^0-9.]//g')
  cpu_usage=$(echo "${stats}" | awk '{print $4}' | sed 's/%//')

  if [[ -n "${mem_usage}" && -n "${mem_limit}" ]]; then
    log_check "OK" "Memory usage: ${mem_usage}MB / ${mem_limit}MB"
  fi

  if [[ -n "${cpu_usage}" ]]; then
    local cpu_int=${cpu_usage%.*}
    if [[ ${cpu_int} -lt 50 ]]; then
      log_check "OK" "CPU usage: ${cpu_usage}%"
    elif [[ ${cpu_int} -lt 80 ]]; then
      log_check "WARNING" "CPU usage: ${cpu_usage}% (elevated)"
    else
      log_check "CRITICAL" "CPU usage: ${cpu_usage}% (high)"
    fi
  fi
}

# Output results in JSON format
output_json() {
  local status="OK"

  if [[ ${FAILED_CHECKS} -gt 0 ]]; then
    status="CRITICAL"
  elif [[ ${WARNING_CHECKS} -gt 0 ]]; then
    status="WARNING"
  fi

  cat << EOF
{
  "status": "${status}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "summary": {
    "total_checks": ${TOTAL_CHECKS},
    "passed": ${PASSED_CHECKS},
    "warnings": ${WARNING_CHECKS},
    "failed": ${FAILED_CHECKS}
  },
  "checks": {
EOF

  local first=true
  for check in "${!CHECKS[@]}"; do
    if [[ "${first}" == "true" ]]; then
      first=false
    else
      echo ","
    fi
    echo -n "    \"${check}\": \"${CHECKS[$check]}\""
  done

  cat << EOF

  }
}
EOF
}

# Output results in Nagios format
output_nagios() {
  local status="OK"
  local exit_code=${EXIT_SUCCESS}

  if [[ ${FAILED_CHECKS} -gt 0 ]]; then
    status="CRITICAL"
    exit_code=${EXIT_GENERAL_FAILURE}
  elif [[ ${WARNING_CHECKS} -gt 0 ]]; then
    status="WARNING"
    exit_code=${EXIT_GENERAL_FAILURE}
  fi

  echo "OXIDIZED ${status} - ${PASSED_CHECKS}/${TOTAL_CHECKS} checks passed | passed=${PASSED_CHECKS} warnings=${WARNING_CHECKS} failed=${FAILED_CHECKS}"

  return ${exit_code}
}

# Show summary
show_summary() {
  if [[ "${QUIET}" == "true" ]]; then
    return
  fi

  echo ""
  echo "========================================="
  echo "  Health Check Summary"
  echo "========================================="
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
      -j | --json)
        JSON_OUTPUT=true
        QUIET=true
        shift
        ;;
      -n | --nagios)
        NAGIOS_MODE=true
        QUIET=true
        shift
        ;;
      -h | --help)
        usage
        exit ${EXIT_SUCCESS}
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit ${EXIT_INVALID_USAGE}
        ;;
    esac
  done

  # Banner
  if [[ "${QUIET}" == "false" ]]; then
    echo ""
    echo "========================================="
    echo "  Oxidized Health Check"
    echo "========================================="
  fi

  # Run health checks
  check_service
  check_container
  check_api
  check_storage
  check_resources

  # Output results
  if [[ "${JSON_OUTPUT}" == "true" ]]; then
    output_json
  elif [[ "${NAGIOS_MODE}" == "true" ]]; then
    output_nagios
    exit $?
  else
    show_summary
  fi

  # Exit with appropriate code
  if [[ ${FAILED_CHECKS} -gt 0 ]]; then
    exit ${EXIT_GENERAL_FAILURE}
  else
    exit ${EXIT_SUCCESS}
  fi
}

# Run main function
main "$@"
