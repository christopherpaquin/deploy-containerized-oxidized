#!/usr/bin/env bash
set -euo pipefail

# Force Oxidized Device Backup Script
# Triggers immediate backup of a specific device or all devices

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

# API endpoint (internal, behind nginx)
readonly API_HOST="localhost"
readonly API_PORT="8889"
readonly API_URL="http://${API_HOST}:${API_PORT}"

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

# Show usage
usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [DEVICE_NAME]

Force immediate backup of device(s) in Oxidized.

ARGUMENTS:
    DEVICE_NAME         Name of device to backup (optional)
                        If omitted, backs up ALL devices

OPTIONS:
    -w, --wait          Wait for backup to complete and show result
    -l, --list          List all devices and their status
    -s, --status NAME   Show status of specific device
    -v, --verbose       Show detailed output
    -h, --help          Show this help message

EXAMPLES:
    # Backup specific device
    $(basename "$0") s3560g-2

    # Backup specific device and wait for result
    $(basename "$0") --wait s3560g-2

    # Backup all devices
    $(basename "$0")

    # List all devices
    $(basename "$0") --list

    # Check device status
    $(basename "$0") --status s3560g-2

NOTES:
    - Backs up immediately, bypassing the normal poll interval
    - Useful after adding a new device or making config changes
    - Check logs with: podman logs -f oxidized
    - Check results in: /var/lib/oxidized/repo/

EOF
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

# Check if Oxidized is running
check_service() {
  if ! systemctl is-active --quiet oxidized.service; then
    log_error "Oxidized service is not running"
    log_error "Start it with: sudo systemctl start oxidized.service"
    exit 1
  fi
}

# List all devices
list_devices() {
  log_info "Fetching device list from Oxidized..."

  local response
  if ! response=$(curl -s -f "${API_URL}/nodes.json" 2>&1); then
    log_error "Failed to fetch device list from Oxidized API"
    log_error "Error: ${response}"
    log_info "Is the service running? Check: systemctl status oxidized.service"
    exit 1
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "                    OXIDIZED DEVICES"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  # Parse JSON and display device info
  echo "${response}" | jq -r '
    ["NAME", "IP", "MODEL", "GROUP", "STATUS", "LAST UPDATE"],
    ["────", "──", "─────", "─────", "──────", "───────────"],
    (.[] | [
      .name,
      .ip,
      .model,
      .group,
      (.status // "unknown"),
      (.last.end // "never")
    ]) | @tsv
  ' | column -t -s $'\t'

  echo ""

  # Count devices
  local total
  total=$(echo "${response}" | jq '. | length')
  log_info "Total devices: ${total}"
}

# Show device status
device_status() {
  local device_name="$1"

  log_info "Fetching status for device: ${device_name}"

  local response
  if ! response=$(curl -s -f "${API_URL}/node/show/${device_name}.json" 2>&1); then
    log_error "Failed to fetch device status from Oxidized API"
    log_error "Device: ${device_name}"
    log_error "Error: ${response}"
    exit 1
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "            DEVICE STATUS: ${device_name}"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  echo "${response}" | jq -r '
    "Name:           \(.name)",
    "IP:             \(.ip)",
    "Model:          \(.model)",
    "Group:          \(.group)",
    "Last Status:    \(.last.status // "unknown")",
    "Last Updated:   \(.last.end // "never")",
    "Last Duration:  \(if .last.time then (.last.time | tostring + "s") else "n/a" end)",
    "Full Name:      \(.full_name // "n/a")"
  '

  echo ""
}

# Trigger backup for specific device
backup_device() {
  local device_name="$1"
  local wait_for_result="${2:-false}"

  log_info "Triggering backup for device: ${device_name}"

  local response
  local http_code

  # Make API request (use /node/next/DEVICE.json endpoint)
  response=$(curl -s -w "\n%{http_code}" "${API_URL}/node/next/${device_name}.json" 2>&1)
  http_code=$(echo "${response}" | tail -n1)
  response=$(echo "${response}" | sed '$d')

  if [[ "${http_code}" != "200" ]]; then
    log_error "Failed to trigger backup for device: ${device_name}"
    log_error "HTTP Status: ${http_code}"
    log_error "Response: ${response}"
    exit 1
  fi

  log_success "Backup job queued for device: ${device_name}"

  if [[ "${wait_for_result}" == "true" ]]; then
    log_info "Waiting for backup to complete..."
    log_info "This may take up to 30 seconds depending on device timeout..."

    # Wait a bit for the job to start and complete
    sleep 5

    # Check logs for the result
    log_info "Checking logs..."
    local logs
    logs=$(podman logs oxidized 2>&1 | grep -E "${device_name}" | tail -10)

    if echo "${logs}" | grep -q "update"; then
      log_success "Backup appears successful!"
      log_info "Check git log: cd ${OXIDIZED_ROOT}/repo && git log --oneline | head -5"
    elif echo "${logs}" | grep -q "raised"; then
      log_warn "Backup may have failed - check logs:"
      log_info "podman logs oxidized 2>&1 | grep '${device_name}' | tail -20"
    else
      log_info "Backup in progress or completed - check logs for details"
    fi
  else
    log_info "Backup job queued - check progress with:"
    echo "  podman logs -f oxidized"
  fi
}

# Trigger backup for all devices
backup_all() {
  local wait_for_result="${1:-false}"

  log_info "Triggering backup for ALL devices"

  local response
  local http_code

  # Reload all nodes (use /reload endpoint without .json)
  response=$(curl -s -w "\n%{http_code}" "${API_URL}/reload" 2>&1)
  http_code=$(echo "${response}" | tail -n1)
  response=$(echo "${response}" | sed '$d')

  if [[ "${http_code}" != "200" ]]; then
    log_error "Failed to trigger reload"
    log_error "HTTP Status: ${http_code}"
    log_error "Response: ${response}"
    exit 1
  fi

  log_success "Reload triggered - all devices will be backed up"

  if [[ "${wait_for_result}" == "true" ]]; then
    log_info "Waiting for backups to complete..."
    log_info "Monitoring logs for 30 seconds..."

    sleep 3
    podman logs oxidized --tail 0 -f &
    local log_pid=$!

    sleep 30
    kill "${log_pid}" 2> /dev/null || true

    log_info "Check results with:"
    echo "  cd ${OXIDIZED_ROOT}/repo && git log --oneline | head -10"
  else
    log_info "Backups queued - monitor progress with:"
    echo "  podman logs -f oxidized"
  fi
}

# Main function
main() {
  local device_name=""
  local wait_for_result=false
  local list_mode=false
  local status_mode=false
  local verbose=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -w | --wait)
        wait_for_result=true
        shift
        ;;
      -l | --list)
        list_mode=true
        shift
        ;;
      -s | --status)
        status_mode=true
        shift
        if [[ $# -gt 0 ]]; then
          device_name="$1"
          shift
        else
          log_error "Option --status requires a device name"
          usage
          exit 1
        fi
        ;;
      -v | --verbose)
        verbose=true
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        device_name="$1"
        shift
        ;;
    esac
  done

  # Banner
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "           Oxidized Force Backup Script"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  # Load environment and check service
  load_env
  check_service

  # Execute appropriate action
  if [[ "${list_mode}" == "true" ]]; then
    list_devices
  elif [[ "${status_mode}" == "true" ]]; then
    if [[ -z "${device_name}" ]]; then
      log_error "Device name required for --status"
      usage
      exit 1
    fi
    device_status "${device_name}"
  elif [[ -n "${device_name}" ]]; then
    backup_device "${device_name}" "${wait_for_result}"
  else
    backup_all "${wait_for_result}"
  fi

  echo ""
}

# Run main function
main "$@"
