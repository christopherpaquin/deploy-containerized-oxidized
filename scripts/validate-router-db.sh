#!/usr/bin/env bash
# Note: Not using set -e due to bash bug with file redirection in functions
set -uo pipefail

# Oxidized Router Database Syntax Validator
# Validates router.db file format and checks for common errors
#
# Usage:
#   ./validate-router-db.sh [path-to-router.db]
#
# If no path provided, uses: /var/lib/oxidized/config/router.db

# Colors for output
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_RESET=$'\033[0m'

# Configuration
readonly DEFAULT_ROUTER_DB="/var/lib/oxidized/config/router.db"
ROUTER_DB="${1:-${DEFAULT_ROUTER_DB}}"

# Counters
TOTAL_LINES=0
VALID_DEVICES=0
ERRORS=0
WARNINGS=0

# Known device models (common ones)
declare -A KNOWN_MODELS=(
  [ios]=1 [iosxr]=1 [iosxe]=1 [nxos]=1 [asa]=1
  [junos]=1 [eos]=1 [procurve]=1 [comware]=1 [aoscx]=1
  [fortios]=1 [panos]=1 [powerconnect]=1 [arubaos]=1
  [vyos]=1 [edgeos]=1 [mikrotik]=1 [opengear]=1
)

# Functions
log_error() {
  echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"
  ((ERRORS++))
}

log_warn() {
  echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
  ((WARNINGS++))
}

log_success() {
  echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"
}

log_info() {
  echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

validate_ip() {
  local ip=$1
  # IPv4 or hostname/FQDN validation
  if [[ ${ip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    # Validate each octet
    IFS='.' read -ra octets <<< "${ip}"
    for octet in "${octets[@]}"; do
      if ((octet > 255)); then
        return 1
      fi
    done
    return 0
  elif [[ ${ip} =~ ^[a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    # Valid hostname/FQDN
    return 0
  else
    return 1
  fi
}

validate_name() {
  local name=$1
  # Check for valid hostname characters
  # Note: hyphen must be at start or end of character class to avoid being interpreted as range
  if [[ ${name} =~ ^[a-zA-Z0-9][-a-zA-Z0-9_.]*[a-zA-Z0-9]$ ]] || [[ ${name} =~ ^[a-zA-Z0-9]$ ]]; then
    return 0
  else
    return 1
  fi
}

# Main validation
main() {
  echo ""
  echo -e "${COLOR_BLUE}╔══════════════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_BLUE}║           Oxidized Router Database Syntax Validator                  ║${COLOR_RESET}"
  echo -e "${COLOR_BLUE}╚══════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
  echo ""

  # Check if file exists
  if [[ ! -f "${ROUTER_DB}" ]]; then
    log_error "Router database not found: ${ROUTER_DB}"
    exit 1
  fi

  log_info "Validating: ${ROUTER_DB}"
  log_info "Format: name:ip:model:group:username:password"
  log_info "Note: Empty username/password fields use global credentials from config"
  echo ""

  # Track unique names and IPs
  declare -A seen_names
  declare -A seen_ips

  # Read file line by line
  while IFS= read -r line || [[ -n ${line} ]]; do
    ((TOTAL_LINES++))

    # Skip empty lines
    [[ -z ${line} ]] && continue

    # Skip comments
    [[ ${line} =~ ^[[:space:]]*# ]] && continue

    # Count colons to determine field count (more reliable than array length)
    # Format: name:ip:model:group:username:password (5 colons = 6 fields)
    colon_count=$(echo "${line}" | tr -cd ':' | wc -c)

    # Must have exactly 5 colons (6 fields)
    if [[ ${colon_count} -ne 5 ]]; then
      log_error "Line ${TOTAL_LINES}: Invalid format (expected 5 colons, got ${colon_count})"
      log_error "  Line: ${line}"
      log_error "  Format: name:ip:model:group:username:password"
      log_error "  Note: Username and password can be empty (use global credentials)"
      continue
    fi

    # Extract fields (handle empty fields correctly)
    IFS=':' read -r name ip model group username password <<< "${line}"

    # Validate device name
    if [[ -z ${name} ]]; then
      log_error "Line ${TOTAL_LINES}: Empty device name"
      log_error "  Line: ${line}"
      continue
    fi

    if ! validate_name "${name}"; then
      log_error "Line ${TOTAL_LINES}: Invalid device name: ${name}"
      log_error "  Names must contain only letters, numbers, hyphens, underscores, and dots"
      continue
    fi

    # Check for duplicate names
    if [[ -n ${seen_names[${name}]:-} ]]; then
      log_error "Line ${TOTAL_LINES}: Duplicate device name: ${name}"
      log_error "  Previously defined on line ${seen_names[${name}]}"
      continue
    fi
    seen_names[${name}]=${TOTAL_LINES}

    # Validate IP address
    if [[ -z ${ip} ]]; then
      log_error "Line ${TOTAL_LINES}: Empty IP address for device: ${name}"
      continue
    fi

    if ! validate_ip "${ip}"; then
      log_error "Line ${TOTAL_LINES}: Invalid IP/hostname: ${ip}"
      log_error "  Device: ${name}"
      continue
    fi

    # Check for duplicate IPs (warning only)
    if [[ -n ${seen_ips[${ip}]:-} ]]; then
      log_warn "Line ${TOTAL_LINES}: Duplicate IP address: ${ip}"
      log_warn "  Device: ${name}, previously used by ${seen_ips[${ip}]} (may be intentional)"
    fi
    seen_ips[${ip}]="${name}"

    # Validate model
    if [[ -z ${model} ]]; then
      log_error "Line ${TOTAL_LINES}: Empty model for device: ${name}"
      continue
    fi

    # Check if model is known (warning only)
    if [[ -z ${KNOWN_MODELS[${model}]:-} ]]; then
      log_warn "Line ${TOTAL_LINES}: Unknown device model: ${model}"
      log_warn "  Device: ${name} (may still work if model is supported)"
    fi

    # Validate group (can be empty)
    if [[ -z ${group} ]]; then
      log_warn "Line ${TOTAL_LINES}: Empty group for device: ${name} (optional but recommended)"
    fi

    # Check credentials
    if [[ -z ${username} && -z ${password} ]]; then
      # Using global credentials - this is fine
      :
    elif [[ -n ${username} && -z ${password} ]]; then
      log_warn "Line ${TOTAL_LINES}: Username provided but password empty for device: ${name}"
    elif [[ -z ${username} && -n ${password} ]]; then
      log_warn "Line ${TOTAL_LINES}: Password provided but username empty for device: ${name}"
    fi

    # All checks passed
    ((VALID_DEVICES++))
    if [[ -z ${username} && -z ${password} ]]; then
      log_success "Line ${TOTAL_LINES}: ${name} (${ip}, ${model}) [using global credentials]"
    else
      log_success "Line ${TOTAL_LINES}: ${name} (${ip}, ${model}) [device-specific credentials]"
    fi

  done < "${ROUTER_DB}"

  # Summary
  echo ""
  echo -e "${COLOR_BLUE}╔══════════════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_BLUE}║                         Validation Summary                           ║${COLOR_RESET}"
  echo -e "${COLOR_BLUE}╚══════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
  echo ""
  echo "Total Lines: ${TOTAL_LINES}"
  echo -e "${COLOR_GREEN}Valid Devices: ${VALID_DEVICES}${COLOR_RESET}"
  echo -e "${COLOR_YELLOW}Warnings: ${WARNINGS}${COLOR_RESET}"
  echo -e "${COLOR_RED}Errors: ${ERRORS}${COLOR_RESET}"
  echo ""

  if [[ ${ERRORS} -eq 0 ]]; then
    echo -e "${COLOR_GREEN}✓ Validation PASSED${COLOR_RESET}"
    if [[ ${WARNINGS} -gt 0 ]]; then
      echo -e "${COLOR_YELLOW}  (with ${WARNINGS} warnings)${COLOR_RESET}"
    fi
    exit 0
  else
    echo -e "${COLOR_RED}✗ Validation FAILED${COLOR_RESET}"
    echo -e "${COLOR_RED}  Fix ${ERRORS} error(s) before using this router.db${COLOR_RESET}"
    exit 1
  fi
}

# Run validation
main "$@"
