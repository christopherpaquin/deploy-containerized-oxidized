#!/usr/bin/env bash
set -euo pipefail

# Oxidized Device Connection Tester
# Tests connectivity and triggers backup for a specific device
#
# Usage:
#   ./test-device.sh <device-name>
#
# Example:
#   ./test-device.sh core-router01

# Colors for output
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_CYAN=$'\033[0;36m'
readonly COLOR_RESET=$'\033[0m'

# Configuration
readonly CONTAINER_NAME="oxidized"
readonly ROUTER_DB="/var/lib/oxidized/config/router.db"
readonly API_URL="http://127.0.0.1:8889"
readonly OXIDIZED_CONFIG="/var/lib/oxidized/config/config"

# Functions
log_error() {
  echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

log_warn() {
  echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

log_success() {
  echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

log_info() {
  echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_step() {
  echo ""
  echo -e "${COLOR_CYAN}==>${COLOR_RESET} $*"
}

# Extract global credentials from Oxidized config
get_global_credentials() {
  local config_file="$1"
  local field="$2"

  if [[ ! -f "${config_file}" ]]; then
    echo ""
    return 1
  fi

  # Parse YAML to extract username or password
  # This handles the simple case where username/password are at the root level
  if [[ "${field}" == "username" ]]; then
    grep "^username:" "${config_file}" 2> /dev/null | head -1 | sed 's/^username:[[:space:]]*//' | tr -d '"' || echo ""
  elif [[ "${field}" == "password" ]]; then
    grep "^password:" "${config_file}" 2> /dev/null | head -1 | sed 's/^password:[[:space:]]*//' | tr -d '"' || echo ""
  fi
}

usage() {
  cat << EOF
Usage: $(basename "$0") <device-name>

Test connectivity and trigger backup for a specific device.

Arguments:
  device-name    Name of the device as defined in router.db

Examples:
  $(basename "$0") core-router01
  $(basename "$0") switch-floor1

Options:
  -h, --help     Show this help message

Device Information:
  Router DB: ${ROUTER_DB}
  API URL:   ${API_URL}
  Container: ${CONTAINER_NAME}

EOF
  exit 0
}

# Check arguments
if [[ $# -eq 0 ]] || [[ ${1:-} == "-h" ]] || [[ ${1:-} == "--help" ]]; then
  usage
fi

DEVICE_NAME="$1"

# Main test function
main() {
  echo ""
  echo -e "${COLOR_CYAN}╔══════════════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_CYAN}║              Oxidized Device Connection Test                         ║${COLOR_RESET}"
  echo -e "${COLOR_CYAN}╚══════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
  echo ""
  log_info "Testing device: ${DEVICE_NAME}"
  echo ""

  # Step 1: Check if container is running
  log_step "Checking Oxidized container status"
  if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_error "Container '${CONTAINER_NAME}' is not running"
    log_error "Start it with: systemctl start oxidized.service"
    exit 1
  fi
  log_success "Container is running"

  # Step 2: Check if device exists in router.db
  log_step "Checking if device exists in router.db"
  if ! grep -q "^${DEVICE_NAME}:" "${ROUTER_DB}" 2> /dev/null; then
    log_error "Device '${DEVICE_NAME}' not found in ${ROUTER_DB}"
    echo ""
    log_info "Available devices:"
    grep -v '^#' "${ROUTER_DB}" | grep -v '^[[:space:]]*$' | cut -d':' -f1 | sed 's/^/  - /'
    exit 1
  fi

  # Extract device details
  local device_line
  device_line=$(grep "^${DEVICE_NAME}:" "${ROUTER_DB}")
  IFS=':' read -r _ device_ip device_model device_group device_username device_password <<< "${device_line}"

  log_success "Device found in router.db"
  echo ""
  log_info "Device details:"
  echo "  Name:  ${DEVICE_NAME}"
  echo "  IP:    ${device_ip}"
  echo "  Model: ${device_model}"
  echo "  Group: ${device_group}"
  if [[ -n "${device_username}" ]]; then
    echo "  Auth:  Device-specific credentials (${device_username})"
  else
    echo "  Auth:  Global credentials from config file"
  fi

  # Step 3: Check if device is reachable via API
  log_step "Checking if Oxidized knows about this device"
  if curl -sf "${API_URL}/nodes.json" 2> /dev/null | jq -e ".[] | select(.name == \"${DEVICE_NAME}\")" &> /dev/null; then
    log_success "Device is registered in Oxidized"

    # Get device status from API
    local device_status
    device_status=$(curl -sf "${API_URL}/nodes.json" 2> /dev/null | jq -r ".[] | select(.name == \"${DEVICE_NAME}\")")

    echo ""
    log_info "Current device status:"
    echo "${device_status}" | jq '.'
  else
    log_warn "Device not yet loaded by Oxidized"
    log_info "It may take a few minutes for Oxidized to discover new devices"
    log_info "Try restarting: systemctl restart oxidized.service"
  fi

  # Step 4: Test network connectivity
  log_step "Testing network connectivity to ${device_ip}"
  if ping -c 1 -W 2 "${device_ip}" &> /dev/null; then
    log_success "Device is reachable via ping"
  else
    log_warn "Device is not responding to ping (may be blocked by firewall)"
  fi

  # Step 5: Test SSH connectivity and authentication
  log_step "Testing SSH connectivity and authentication"

  # Test if SSH port is open
  if timeout 3 bash -c "echo > /dev/tcp/${device_ip}/22" 2> /dev/null; then
    log_success "SSH port (22) is open"

    # Test actual SSH authentication
    # Determine credentials to use (device-specific or global)
    local test_username="${device_username}"
    local test_password="${device_password}"
    local cred_source="device-specific credentials"

    if [[ -z "${test_username}" ]]; then
      test_username=$(get_global_credentials "${OXIDIZED_CONFIG}" "username")
      test_password=$(get_global_credentials "${OXIDIZED_CONFIG}" "password")
      cred_source="global credentials from config file"
    fi

    if [[ -n "${test_username}" ]]; then
      echo ""
      log_info "Testing SSH login as '${test_username}' (using ${cred_source})"

      # Try SSH connection with timeout
      local ssh_test_output

      # Use password authentication if password is provided, otherwise try key auth
      if [[ -n "${test_password}" ]]; then
        if command -v sshpass &> /dev/null; then
          log_info "Using password authentication"
          ssh_test_output=$(timeout 10 sshpass -p "${test_password}" ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=5 \
            -o PubkeyAuthentication=no \
            -o PreferredAuthentications=password \
            "${test_username}@${device_ip}" "echo SSH_OK" 2>&1 || true)
        else
          log_warn "sshpass not installed - cannot test password authentication"
          log_info "Install sshpass: dnf install -y sshpass"
          ssh_test_output=""
        fi
      else
        log_info "Using SSH key authentication"
        ssh_test_output=$(timeout 10 ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout=5 \
          -o BatchMode=yes \
          "${test_username}@${device_ip}" "echo SSH_OK" 2>&1 || true)
      fi

      if [[ -z "${ssh_test_output}" ]]; then
        log_warn "SSH test skipped (sshpass required for password authentication)"
      elif echo "${ssh_test_output}" | grep -q "SSH_OK"; then
        log_success "SSH authentication successful"
      elif echo "${ssh_test_output}" | grep -qi "no matching.*cipher\|no matching.*key exchange\|no matching.*host key\|no matching.*mac"; then
        log_warn "SSH cipher/algorithm mismatch detected"
        log_warn "Legacy device uses old SSH ciphers not supported by modern OpenSSH"
        echo ""
        echo -e "${COLOR_YELLOW}SSH Error Details:${COLOR_RESET}"
        echo "${ssh_test_output}" | grep -i "no matching" | sed 's/^/  /'
        echo ""
        log_info "✓ Oxidized can still connect (uses different SSH library)"
        log_info "✓ Telnet may be available as alternative for manual access"
      elif echo "${ssh_test_output}" | grep -qi "permission denied\|authentication.*fail"; then
        log_error "SSH authentication failed"
        if [[ -n "${test_password}" ]]; then
          log_error "Password authentication rejected - check credentials in router.db"
          log_info "Device entry: ${DEVICE_NAME}:${device_ip}:${device_model}:${device_group}:${test_username}:***"
        else
          log_error "Key authentication failed - check SSH keys in /var/lib/oxidized/ssh/"
        fi
      elif echo "${ssh_test_output}" | grep -qi "connection.*refused\|connection.*closed"; then
        log_error "SSH connection refused by device"
      elif echo "${ssh_test_output}" | grep -qi "timeout\|timed out"; then
        log_warn "SSH connection timeout"
        log_warn "Device may be slow to respond or SSH is disabled"
      else
        log_warn "SSH test inconclusive (see details below)"
        echo "${ssh_test_output}" | head -3 | sed 's/^/  /'
      fi
    else
      log_warn "No credentials available for SSH testing"
      log_warn "Configure credentials in ${OXIDIZED_CONFIG} or router.db"
    fi
  else
    log_error "SSH port (22) is not reachable"
    log_error "Check firewall rules and device configuration"
  fi

  # Step 5b: Test Telnet availability and authentication
  echo ""
  log_step "Testing Telnet connectivity on port 23"
  if timeout 3 bash -c "echo > /dev/tcp/${device_ip}/23" 2> /dev/null; then
    log_success "Telnet port (23) is open"

    # Test telnet authentication if credentials are available
    if [[ -n "${test_username}" ]] && [[ -n "${test_password}" ]]; then
      echo ""
      log_info "Testing Telnet login as '${test_username}' (using ${cred_source})"

      if command -v expect &> /dev/null; then
        local telnet_result
        telnet_result=$(expect -c "
          set timeout 10
          log_user 0
          spawn telnet ${device_ip}
          expect {
            timeout { puts \"TIMEOUT\"; exit 1 }
            eof { puts \"CONNECTION_CLOSED\"; exit 1 }
            \"ogin:\" { send \"${test_username}\r\" }
            \"sername:\" { send \"${test_username}\r\" }
          }
          expect {
            timeout { puts \"TIMEOUT_PASSWORD\"; exit 1 }
            eof { puts \"CONNECTION_CLOSED\"; exit 1 }
            \"assword:\" { send \"${test_password}\r\" }
          }
          expect {
            timeout { puts \"TIMEOUT_PROMPT\"; exit 1 }
            eof { puts \"AUTH_FAILED\"; exit 1 }
            \"#\" { puts \"TELNET_OK\"; exit 0 }
            \">\" { puts \"TELNET_OK\"; exit 0 }
            \"denied\" { puts \"AUTH_FAILED\"; exit 1 }
            \"incorrect\" { puts \"AUTH_FAILED\"; exit 1 }
          }
        " 2>&1)

        if echo "${telnet_result}" | grep -q "TELNET_OK"; then
          log_success "Telnet authentication successful"
          log_info "Device responds to telnet - Oxidized can use this as transport"
        elif echo "${telnet_result}" | grep -q "AUTH_FAILED"; then
          log_error "Telnet authentication failed"
          log_error "Check username/password - credentials may be incorrect"
        elif echo "${telnet_result}" | grep -q "TIMEOUT"; then
          log_warn "Telnet connection timeout"
          log_warn "Device may be slow or using non-standard prompts"
        else
          log_warn "Telnet test inconclusive"
          log_info "Telnet is available - configure in router.db with :telnet suffix"
        fi
      else
        log_warn "expect not installed - cannot test telnet authentication"
        log_info "Install expect: dnf install -y expect"
      fi
    else
      log_info "Telnet is available as fallback for legacy SSH issues"
      log_info "Configure in router.db: ${DEVICE_NAME}:${device_ip}:${device_model}:${device_group}:${test_username}:${test_password}:telnet"
    fi
  else
    log_info "Telnet port (23) is not open (this is normal for secure configurations)"
  fi

  # Step 6: Trigger backup via API
  log_step "Triggering backup for ${DEVICE_NAME}"

  # Check if device has been backed up before
  local backup_exists=false
  if [[ -d "/var/lib/oxidized/repo/.git" ]]; then
    if sudo -u oxidized git -C /var/lib/oxidized/repo log --all --oneline 2> /dev/null | grep -q "${DEVICE_NAME}"; then
      backup_exists=true
      local last_backup
      last_backup=$(sudo -u oxidized git -C /var/lib/oxidized/repo log --all --grep="${DEVICE_NAME}" --format="%ar" 2> /dev/null | head -1)
      log_info "Last successful backup: ${last_backup}"
    fi
  fi

  # Trigger backup
  log_info "Sending API request to trigger backup..."
  local http_code
  http_code=$(curl -sf -o /dev/null -w "%{http_code}" -X GET "${API_URL}/node/next/${DEVICE_NAME}.json" 2> /dev/null || echo "000")

  if [[ ${http_code} == "200" ]]; then
    log_success "Backup request accepted"
    log_info "Waiting for backup to complete..."
    sleep 5

    # Check if backup was successful
    if sudo -u oxidized git -C /var/lib/oxidized/repo log --all --oneline --since="1 minute ago" 2> /dev/null | grep -q "${DEVICE_NAME}"; then
      log_success "Backup completed successfully!"

      # Show latest commit
      echo ""
      log_info "Latest backup commit:"
      sudo -u oxidized git -C /var/lib/oxidized/repo log --all --grep="${DEVICE_NAME}" --format="%h - %s (%ar)" 2> /dev/null | head -1 | sed 's/^/  /'

      # Show config file location
      echo ""
      log_info "Backup location:"
      echo "  /var/lib/oxidized/repo/${DEVICE_NAME}"

    else
      log_warn "Backup may still be in progress or failed"
      log_info "Check logs for details"
    fi
  elif [[ ${http_code} == "404" ]]; then
    log_error "Device not found via API"
    log_error "Oxidized may not have loaded the device yet"
    log_info "Try: systemctl restart oxidized.service"
  else
    log_error "API request failed (HTTP ${http_code})"
    log_error "Check if Oxidized API is running on ${API_URL}"
  fi

  # Step 7: Check for connection errors in logs
  log_step "Checking connection logs for ${DEVICE_NAME}"
  echo ""

  local log_file="/var/lib/oxidized/data/oxidized.log"
  local has_errors=false

  # Check if log file exists and is readable
  if [[ -f "${log_file}" ]]; then
    # Look for SSH-specific errors
    if grep -qi "ssh.*${DEVICE_NAME}" "${log_file}" 2> /dev/null | tail -20 | grep -qiE "error|fail|timeout|cipher|algorithm|key exchange"; then
      echo -e "${COLOR_YELLOW}[CONNECTION ERRORS DETECTED]${COLOR_RESET}"
      echo ""

      # Show SSH errors
      echo "SSH Connection Attempts:"
      grep -i "${DEVICE_NAME}" "${log_file}" 2> /dev/null | tail -30 | grep -iE "ssh.*error|ssh.*fail|cipher|algorithm|key.exchange" | tail -5 | sed 's/^/  /'
      has_errors=true
    fi

    # Check for Telnet fallback
    if grep -qi "telnet.*${DEVICE_NAME}" "${log_file}" 2> /dev/null; then
      echo ""
      echo "Telnet Fallback Attempts:"
      grep -i "${DEVICE_NAME}" "${log_file}" 2> /dev/null | tail -30 | grep -i telnet | tail -5 | sed 's/^/  /'
      has_errors=true
    fi

    # Check for authentication errors
    if grep -i "${DEVICE_NAME}" "${log_file}" 2> /dev/null | tail -30 | grep -qiE "auth.*fail|permission denied|invalid.*password|login.*incorrect"; then
      echo ""
      echo -e "${COLOR_RED}Authentication Errors:${COLOR_RESET}"
      grep -i "${DEVICE_NAME}" "${log_file}" 2> /dev/null | tail -30 | grep -iE "auth.*fail|permission denied|invalid.*password|login.*incorrect" | tail -5 | sed 's/^/  /'
      has_errors=true
    fi

    # Check for timeout errors
    if grep -i "${DEVICE_NAME}" "${log_file}" 2> /dev/null | tail -30 | grep -qiE "timeout|timed out|connection.*refused"; then
      echo ""
      echo -e "${COLOR_RED}Timeout/Connection Errors:${COLOR_RESET}"
      grep -i "${DEVICE_NAME}" "${log_file}" 2> /dev/null | tail -30 | grep -iE "timeout|timed out|connection.*refused" | tail -5 | sed 's/^/  /'
      has_errors=true
    fi

    # Show recent successful/failed updates
    echo ""
    echo "Recent Activity:"
    grep -i "${DEVICE_NAME}" "${log_file}" 2> /dev/null | tail -10 | sed 's/^/  /'

    if [[ ${has_errors} == false ]]; then
      log_info "No connection errors found in recent logs"
    fi
  else
    log_warn "Log file not found: ${log_file}"
    log_info "Container may still be initializing"
  fi

  # Step 8: Show podman logs as fallback
  echo ""
  log_step "Recent container logs for ${DEVICE_NAME}"
  echo ""

  local container_logs
  container_logs=$(podman logs --since 5m "${CONTAINER_NAME}" 2>&1 | grep -i "${DEVICE_NAME}" | tail -10)

  if [[ -n "${container_logs}" ]]; then
    while IFS= read -r line; do
      echo "  ${line}"
    done <<< "${container_logs}"
  else
    log_info "No recent container log entries found"
  fi

  # Summary
  echo ""
  echo -e "${COLOR_CYAN}╔══════════════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_CYAN}║                            Summary                                   ║${COLOR_RESET}"
  echo -e "${COLOR_CYAN}╚══════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
  echo ""
  echo "Device: ${DEVICE_NAME}"
  echo "IP:     ${device_ip}"
  echo "Model:  ${device_model}"
  echo ""

  if [[ ${backup_exists} == true ]]; then
    echo -e "${COLOR_GREEN}✓ Device has successful backups${COLOR_RESET}"
  else
    echo -e "${COLOR_YELLOW}⚠ No backups found yet${COLOR_RESET}"
    if [[ ${has_errors} == true ]]; then
      echo -e "${COLOR_RED}⚠ Connection errors detected (see above)${COLOR_RESET}"
    fi
  fi
  echo ""
  echo -e "${COLOR_YELLOW}Log Locations:${COLOR_RESET}"
  log_info "Main log: ${log_file}"
  log_info "Container logs: podman logs -f ${CONTAINER_NAME}"
  log_info "Live tail: tail -f ${log_file}"
  echo ""
  echo -e "${COLOR_YELLOW}Verification:${COLOR_RESET}"
  log_info "View backups: ls -la /var/lib/oxidized/repo/"
  log_info "Check service: systemctl status oxidized"
  echo ""
}

# Run main function
main "$@"
