#!/usr/bin/env bash
set -euo pipefail

# Oxidized Device Management Script
# Interactive script to add devices to router.db with validation
#
# Usage:
#   ./add-device.sh
#
# This script will interactively prompt for device details and safely
# add them to the router.db file with full validation.

# Colors for output
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_CYAN=$'\033[0;36m'
readonly COLOR_RESET=$'\033[0m'

# Configuration
readonly DEFAULT_ROUTER_DB="/var/lib/oxidized/config/router.db"
readonly BACKUP_DIR="/var/lib/oxidized/config/backup-routerdb"
readonly CONFIG_FILE="/var/lib/oxidized/config/config"
ROUTER_DB="${1:-${DEFAULT_ROUTER_DB}}"

# Supported device models - COMMON ONES FIRST (from user's lab)
declare -A DEVICE_MODELS=(
  # === COMMON MODELS (Lab Environment) ===
  [asa]="Cisco ASA Firewall"
  [ios]="Cisco IOS"
  [junos]="Juniper JunOS"
  [os10]="Dell OS10"
  [eos]="Arista EOS"
  [nxos]="Cisco Nexus"
  [comware]="HP Comware"
  [opengear]="Opengear Console Server"
  [sonicos]="SonicWALL SonicOS"

  # === OTHER CISCO ===
  [iosxr]="Cisco IOS XR"
  [iosxe]="Cisco IOS XE"
  [ciscosma]="Cisco SMA"

  # === OTHER JUNIPER ===
  [screenos]="Juniper ScreenOS"

  # === HP/HPE ===
  [procurve]="HP ProCurve"

  # === ARUBA ===
  [aoscx]="Aruba AOS-CX"
  [arubaos]="Aruba ArubaOS"
  [aosw]="Aruba AOS-W (Wireless)"

  # === FORTINET ===
  [fortios]="FortiGate FortiOS"

  # === PALO ALTO ===
  [panos]="Palo Alto PAN-OS"

  # === DELL ===
  [powerconnect]="Dell PowerConnect"
  [dlink]="D-Link"

  # === OPEN SOURCE ===
  [vyos]="VyOS"
  [edgeos]="Ubiquiti EdgeOS"

  # === MIKROTIK ===
  [mikrotik]="MikroTik RouterOS"
  [routeros]="MikroTik RouterOS (alt)"

  # === TP-LINK ===
  [tplink]="TP-Link (NOT tp-link)"

  # === BROCADE ===
  [ironware]="Brocade IronWare"
  [fastiron]="Brocade FastIron"

  # === F5 ===
  [f5]="F5 BIG-IP"

  # === EXTREME ===
  [extreme]="Extreme Networks"
  [extremeware]="Extreme ExtremeWare"
  [xos]="Extreme XOS"

  # === FIREWALLS ===
  [opnsense]="OPNsense"
  [pfsense]="pfSense"
  [sophos]="Sophos Firewall"
  [watchguard]="WatchGuard Firebox"
  [checkpoint]="Check Point"

  # === OTHERS ===
  [planet]="Planet switches"
  [zyxel]="Zyxel"
  [netgear]="Netgear"
  [netonix]="Netonix"
)

# Functions - ALL log functions write to stderr to avoid capture issues
log_error() {
  echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

log_warn() {
  echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2
}

log_success() {
  echo -e "${COLOR_GREEN}[✓]${COLOR_RESET} $*" >&2
}

log_info() {
  echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2
}

log_prompt() {
  echo -e "${COLOR_CYAN}[?]${COLOR_RESET} $*" >&2
}

# Validate IP address or hostname
validate_ip_or_hostname() {
  local ip=$1

  # IPv4 validation
  if [[ ${ip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    IFS='.' read -ra octets <<< "${ip}"
    for octet in "${octets[@]}"; do
      if ((octet > 255)); then
        return 1
      fi
    done
    return 0
  # Hostname/FQDN validation
  elif [[ ${ip} =~ ^[a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    return 0
  else
    return 1
  fi
}

# Validate device name
validate_device_name() {
  local name=$1

  # Check for valid hostname characters
  if [[ ${name} =~ ^[a-zA-Z0-9][-a-zA-Z0-9_.]*[a-zA-Z0-9]$ ]] || [[ ${name} =~ ^[a-zA-Z0-9]$ ]]; then
    return 0
  else
    return 1
  fi
}

# Check if device name already exists
check_duplicate_name() {
  local name=$1
  local router_db=$2

  if [[ ! -f "${router_db}" ]]; then
    return 1
  fi

  # Check for duplicate names (skip comments and empty lines)
  while IFS=':' read -r existing_name rest; do
    if [[ "${existing_name}" == "${name}" ]]; then
      return 0
    fi
  done < <(grep -v -e '^#' -e '^[[:space:]]*$' "${router_db}")

  return 1
}

# Get existing groups from router.db
get_existing_groups() {
  local router_db=$1
  local -a groups=()

  if [[ ! -f "${router_db}" ]]; then
    echo ""
    return
  fi

  # Extract unique groups (field 4)
  while IFS=':' read -r name ip model group rest; do
    if [[ -n "${group}" ]]; then
      groups+=("${group}")
    fi
  done < <(grep -v -e '^#' -e '^[[:space:]]*$' "${router_db}")

  # Remove duplicates and sort
  if [[ ${#groups[@]} -gt 0 ]]; then
    printf '%s\n' "${groups[@]}" | sort -u
  fi
}

# Get default username from config file
get_default_username() {
  local config_file=$1

  if [[ ! -f "${config_file}" ]]; then
    echo "admin"
    return
  fi

  # Extract username from config (format: "username: value")
  local username
  username=$(grep -E '^username:' "${config_file}" | sed 's/^username:[[:space:]]*//' | tr -d '"' || echo "admin")

  if [[ -z "${username}" ]]; then
    echo "admin"
  else
    echo "${username}"
  fi
}

# Display banner
show_banner() {
  echo "" >&2
  echo -e "${COLOR_BLUE}╔══════════════════════════════════════════════════════════════════════════╗${COLOR_RESET}" >&2
  echo -e "${COLOR_BLUE}║              Oxidized Device Management Tool                         ║${COLOR_RESET}" >&2
  echo -e "${COLOR_BLUE}║                  Add Device to router.db                             ║${COLOR_RESET}" >&2
  echo -e "${COLOR_BLUE}╚══════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}" >&2
  echo "" >&2
}

# Display common device models only
show_common_models() {
  echo "" >&2
  echo -e "${COLOR_CYAN}Common Device Models (Lab Environment):${COLOR_RESET}" >&2
  echo "" >&2

  # Common models first (in order)
  local -a common_models=("asa" "ios" "junos" "os10" "eos" "nxos" "comware" "opengear" "sonicos")
  local count=1

  for model in "${common_models[@]}"; do
    if [[ -n "${DEVICE_MODELS[${model}]:-}" ]]; then
      printf "  ${COLOR_YELLOW}%-3d${COLOR_RESET} %-15s - %s\n" ${count} "${model}" "${DEVICE_MODELS[${model}]}" >&2
      ((count++))
    fi
  done

  echo "" >&2
  log_info "Type 'list' to see all $(echo "${!DEVICE_MODELS[@]}" | wc -w) supported models"
  log_info "Type 'help' to see common typos"
  echo "" >&2
}

# Display all available device models
show_device_models() {
  echo "" >&2
  echo -e "${COLOR_CYAN}Common Device Models (Lab Environment):${COLOR_RESET}" >&2
  echo "" >&2

  # Common models first (in order)
  local -a common_models=("asa" "ios" "junos" "os10" "eos" "nxos" "comware" "opengear" "sonicos")
  local count=1

  for model in "${common_models[@]}"; do
    if [[ -n "${DEVICE_MODELS[${model}]:-}" ]]; then
      printf "  ${COLOR_YELLOW}%-3d${COLOR_RESET} %-15s - %s\n" ${count} "${model}" "${DEVICE_MODELS[${model}]}" >&2
      ((count++))
    fi
  done

  echo "" >&2
  echo -e "${COLOR_CYAN}Other Supported Models:${COLOR_RESET}" >&2
  echo "" >&2

  # All other models alphabetically
  for model in $(printf '%s\n' "${!DEVICE_MODELS[@]}" | sort); do
    # Skip if already shown in common
    local is_common=false
    for common in "${common_models[@]}"; do
      if [[ "${model}" == "${common}" ]]; then
        is_common=true
        break
      fi
    done

    if [[ "${is_common}" == "false" ]]; then
      printf "  ${COLOR_YELLOW}%-3d${COLOR_RESET} %-15s - %s\n" ${count} "${model}" "${DEVICE_MODELS[${model}]}" >&2
      ((count++))
    fi
  done

  echo "" >&2
  log_info "Complete list: https://github.com/ytti/oxidized/blob/master/docs/Supported-OS-Types.md"
  echo "" >&2
}

# Find similar model names (fuzzy matching for typos)
find_similar_models() {
  local input=$1
  local -a suggestions=()

  # Look for models that start with the same letter(s)
  for model in "${!DEVICE_MODELS[@]}"; do
    # Check if first 2-3 characters match
    if [[ "${model:0:2}" == "${input:0:2}" ]] || [[ "${model:0:3}" == "${input:0:3}" ]]; then
      suggestions+=("${model}")
    fi
  done

  # Also check for common typos and variations
  case "${input}" in
    # TP-Link variations
    "tp-link" | "tp_link" | "tplink-switch") suggestions+=("tplink") ;;

    # Cisco variations
    "cisco-ios" | "cisco_ios" | "ciscoios" | "iso") suggestions+=("ios") ;;
    "cisco-nxos" | "cisco_nxos" | "cisconxos" | "nexus") suggestions+=("nxos") ;;
    "cisco-asa" | "cisco_asa") suggestions+=("asa") ;;
    "cisco-iosxr" | "cisco_iosxr") suggestions+=("iosxr") ;;
    "cisco-iosxe" | "cisco_iosxe") suggestions+=("iosxe") ;;

    # Arista variations
    "arista" | "arista-eos" | "arista_eos") suggestions+=("eos") ;;

    # Juniper variations
    "juniper" | "juniper-junos" | "juniper_junos") suggestions+=("junos") ;;
    "juniper-screenos" | "juniper_screenos") suggestions+=("screenos") ;;

    # Fortinet variations
    "fortigate" | "fortinet" | "forti-os" | "forti_os") suggestions+=("fortios") ;;

    # Palo Alto variations
    "paloalto" | "palo-alto" | "palo_alto" | "palo-alto-panos" | "pan-os") suggestions+=("panos") ;;

    # HP variations
    "hp-procurve" | "hp_procurve" | "hpprocurve") suggestions+=("procurve") ;;
    "hp-comware" | "hp_comware" | "hpcomware") suggestions+=("comware") ;;

    # Dell variations
    "dell-os10" | "dell_os10" | "dellos10") suggestions+=("os10") ;;

    # Aruba variations
    "aruba-aoscx" | "aruba_aoscx" | "aruba-cx") suggestions+=("aoscx") ;;
    "aruba-aos" | "aruba_aos") suggestions+=("arubaos") ;;
    "aruba-aosw" | "aruba_aosw") suggestions+=("aosw") ;;

    # MikroTik variations
    "mikrotik-routeros" | "mikrotik_routeros" | "mikrotik-ros") suggestions+=("mikrotik" "routeros") ;;
    "router-os" | "router_os") suggestions+=("routeros") ;;

    # Brocade variations
    "brocade-ironware" | "brocade_ironware") suggestions+=("ironware") ;;
    "brocade-fastiron" | "brocade_fastiron") suggestions+=("fastiron") ;;

    # Dell variations
    "dell-powerconnect" | "dell_powerconnect") suggestions+=("powerconnect") ;;
    "dell") suggestions+=("powerconnect" "os10") ;;

    # Extreme variations
    "extreme-xos" | "extreme_xos" | "extremexos") suggestions+=("xos") ;;
    "extreme-ware" | "extreme_ware") suggestions+=("extremeware") ;;

    # Ubiquiti variations
    "ubiquiti" | "ubnt" | "ubiquiti-edgeos") suggestions+=("edgeos") ;;

    # Firewall variations
    "opn-sense" | "opn_sense") suggestions+=("opnsense") ;;
    "pf-sense" | "pf_sense") suggestions+=("pfsense") ;;
    "watchguard-firebox" | "watchguard_firebox") suggestions+=("watchguard") ;;
    "checkpoint" | "check-point" | "check_point") suggestions+=("checkpoint") ;;
    "sonicwall") suggestions+=("sonicos") ;;

    # F5 variations
    "f5-bigip" | "f5_bigip" | "bigip" | "big-ip") suggestions+=("f5") ;;
  esac

  # Return unique suggestions
  if [[ ${#suggestions[@]} -gt 0 ]]; then
    printf '%s\n' "${suggestions[@]}" | sort -u
  fi
}

# Prompt for device hostname
prompt_hostname() {
  local hostname=""

  while true; do
    log_prompt "Enter device hostname (e.g., switch01, core-router-01):"
    read -r hostname

    if [[ -z "${hostname}" ]]; then
      log_error "Hostname cannot be empty"
      continue
    fi

    if ! validate_device_name "${hostname}"; then
      log_error "Invalid hostname. Use only letters, numbers, hyphens, underscores, and dots."
      continue
    fi

    if check_duplicate_name "${hostname}" "${ROUTER_DB}"; then
      log_error "Device '${hostname}' already exists in router.db"
      read -rp "Do you want to enter a different name? (y/n): " -n 1 retry
      echo >&2
      if [[ ! "${retry}" =~ ^[Yy]$ ]]; then
        exit 1
      fi
      continue
    fi

    log_success "Hostname: ${hostname}"
    echo "${hostname}"
    return
  done
}

# Prompt for IP address
prompt_ip_address() {
  local ip=""

  while true; do
    log_prompt "Enter IP address (e.g., 10.1.1.1 - hostnames not recommended):"
    read -r ip

    if [[ -z "${ip}" ]]; then
      log_error "IP address cannot be empty"
      continue
    fi

    if ! validate_ip_or_hostname "${ip}"; then
      log_error "Invalid IP address or hostname format"
      continue
    fi

    log_success "IP Address: ${ip}"
    echo "${ip}"
    return
  done
}

# Prompt for device model/OS type
prompt_device_model() {
  local model=""
  local show_common=true

  while true; do
    if [[ "${show_common}" == "true" ]]; then
      show_common_models
      show_common=false
    fi

    log_prompt "Enter device model below (e.g., ios, nxos, junos, asa):"
    read -r model

    if [[ -z "${model}" ]]; then
      log_error "Device model cannot be empty"
      continue
    fi

    # Convert to lowercase
    model=$(echo "${model}" | tr '[:upper:]' '[:lower:]')

    # Handle special commands
    if [[ "${model}" == "list" ]]; then
      show_device_models
      continue
    fi

    if [[ "${model}" == "help" ]]; then
      echo "" >&2
      echo -e "${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}" >&2
      echo -e "${COLOR_CYAN}║       Common Typos and Correct Spellings                 ║${COLOR_RESET}" >&2
      echo -e "${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}" >&2
      echo "" >&2
      echo -e "${COLOR_YELLOW}Most Common Mistakes:${COLOR_RESET}" >&2
      echo "  ❌ iso              → ✅ ios" >&2
      echo "  ❌ tp-link          → ✅ tplink" >&2
      echo "  ❌ cisco-ios        → ✅ ios" >&2
      echo "  ❌ cisco-nxos       → ✅ nxos" >&2
      echo "  ❌ arista           → ✅ eos" >&2
      echo "  ❌ juniper          → ✅ junos" >&2
      echo "  ❌ fortigate        → ✅ fortios" >&2
      echo "  ❌ paloalto         → ✅ panos" >&2
      echo "  ❌ sonicwall        → ✅ sonicos" >&2
      echo "" >&2
      echo -e "${COLOR_YELLOW}Vendor Name vs. Model Name:${COLOR_RESET}" >&2
      echo "  ❌ cisco            → ✅ ios, nxos, asa, iosxr, iosxe" >&2
      echo "  ❌ arista           → ✅ eos" >&2
      echo "  ❌ juniper          → ✅ junos, screenos" >&2
      echo "  ❌ fortinet         → ✅ fortios" >&2
      echo "  ❌ dell             → ✅ os10, powerconnect" >&2
      echo "" >&2
      echo -e "${COLOR_YELLOW}Remember:${COLOR_RESET}" >&2
      echo "  • Model names are lowercase" >&2
      echo "  • No hyphens (except in rare cases)" >&2
      echo "  • Use the OS name, not the vendor name" >&2
      echo "" >&2
      continue
    fi

    # Check if it's a known model
    if [[ -n "${DEVICE_MODELS[${model}]:-}" ]]; then
      log_success "Device model: ${model} (${DEVICE_MODELS[${model}]})"
      echo "${model}"
      return
    fi

    # Model not found - check for similar models
    log_error "Model '${model}' not found in the common device list"

    local similar
    similar=$(find_similar_models "${model}")

    if [[ -n "${similar}" ]]; then
      echo "" >&2
      echo -e "${COLOR_YELLOW}Did you mean one of these?${COLOR_RESET}" >&2
      while IFS= read -r suggestion; do
        if [[ -n "${DEVICE_MODELS[${suggestion}]:-}" ]]; then
          echo "  → ${suggestion} (${DEVICE_MODELS[${suggestion}]})" >&2
        fi
      done <<< "${similar}"
      echo "" >&2
    fi

    echo -e "${COLOR_YELLOW}Options:${COLOR_RESET}" >&2
    echo "  1. Type 'list' to see all available models" >&2
    echo "  2. Type 'help' to see common typos" >&2
    echo "  3. Re-enter the model name" >&2
    echo "  4. Continue with '${model}' anyway (not recommended)" >&2
    echo "" >&2

    read -rp "Continue with '${model}' anyway? (y/N): " confirm
    echo >&2
    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
      log_warn "Using non-standard model: ${model}"
      log_warn "This may not work if Oxidized doesn't support this model"
      echo "${model}"
      return
    fi

    # Loop continues to prompt again
  done
}

# Prompt for group
prompt_group() {
  local group=""
  local existing_groups
  existing_groups=$(get_existing_groups "${ROUTER_DB}")

  echo "" >&2
  if [[ -n "${existing_groups}" ]]; then
    echo -e "${COLOR_CYAN}Existing groups in router.db:${COLOR_RESET}" >&2
    echo "" >&2
    while IFS= read -r grp; do
      echo "  - ${grp}" >&2
    done <<< "${existing_groups}"
    echo "" >&2
    log_info "You can select an existing group or create a new one"
  else
    log_info "No existing groups found. You can create a new group."
  fi

  echo "" >&2

  while true; do
    log_prompt "Enter group name (e.g., datacenter, branch, core, firewalls) or press Enter to skip:"
    read -r group

    if [[ -z "${group}" ]]; then
      log_warn "No group specified (optional but recommended)"
      read -rp "Continue without a group? (y/N): " confirm
      echo >&2
      if [[ "${confirm}" =~ ^[Yy]$ ]]; then
        log_success "No group assigned"
        echo ""
        return
      fi
      # If 'n' or anything else, continue the loop to ask for group again
      continue
    fi

    # Check if it's an existing group
    if echo "${existing_groups}" | grep -q "^${group}$"; then
      log_success "Using existing group: ${group}"
    else
      log_success "Creating new group: ${group}"
    fi

    echo "${group}"
    return
  done
}

# Prompt for credentials - RETURNS ONLY username:password
prompt_credentials() {
  local default_username
  default_username=$(get_default_username "${CONFIG_FILE}")

  log_info "Default credentials from config:"
  log_info "  Username: ${default_username}"
  log_info "  Password: ********** (hidden)"
  echo "" >&2

  read -rp "Do you want to override the default credentials for this device? (y/N): " use_custom_creds
  echo >&2

  if [[ "${use_custom_creds}" =~ ^[Yy]$ ]]; then
    local username=""
    local password=""

    # Prompt for username
    while true; do
      log_prompt "Enter device username:"
      read -r username

      if [[ -z "${username}" ]]; then
        log_error "Username cannot be empty when overriding credentials"
        continue
      fi

      log_success "Username: ${username}"
      break
    done

    # Prompt for password
    while true; do
      log_prompt "Enter device password:"
      read -rs password
      echo >&2

      if [[ -z "${password}" ]]; then
        log_error "Password cannot be empty when overriding credentials"
        continue
      fi

      # Confirm password
      log_prompt "Confirm password:"
      local password_confirm
      read -rs password_confirm
      echo >&2

      if [[ "${password}" != "${password_confirm}" ]]; then
        log_error "Passwords do not match"
        continue
      fi

      log_success "Password confirmed"
      break
    done

    # Return ONLY the credentials part
    echo "${username}:${password}"
  else
    log_success "Using default credentials from config"
    # Return EMPTY STRING to omit credential fields (4-field format)
    echo ""
  fi
}

# Validate router.db entry format
validate_entry() {
  local entry=$1

  # Count colons (should be 3 for global creds or 5 for device-specific)
  local colon_count
  colon_count=$(echo "${entry}" | tr -cd ':' | wc -c)

  if [[ ${colon_count} -ne 3 ]] && [[ ${colon_count} -ne 5 ]]; then
    log_error "Invalid entry format: expected 3 colons (global creds) or 5 colons (device creds), got ${colon_count}"
    log_error "Entry: ${entry}"
    return 1
  fi

  # Extract fields (works for both 4-field and 6-field format)
  IFS=':' read -r name ip model group username password <<< "${entry}"

  # Validate required fields
  if [[ -z "${name}" ]] || [[ -z "${ip}" ]] || [[ -z "${model}" ]]; then
    log_error "Missing required fields (name, ip, or model)"
    return 1
  fi

  return 0
}

# Create timestamped backup
create_backup() {
  local router_db=$1

  if [[ ! -f "${router_db}" ]]; then
    log_warn "No existing router.db found, skipping backup"
    return 0
  fi

  # Create backup directory if it doesn't exist
  if [[ ! -d "${BACKUP_DIR}" ]]; then
    mkdir -p "${BACKUP_DIR}"
    chmod 755 "${BACKUP_DIR}"
    log_info "Created backup directory: ${BACKUP_DIR}"
  fi

  # Create backup with timestamp
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="${BACKUP_DIR}/router.db.backup.${timestamp}"

  if cp "${router_db}" "${backup_file}"; then
    chmod 600 "${backup_file}"
    log_success "Backup created: ${backup_file}"
    return 0
  else
    log_error "Failed to create backup"
    return 1
  fi
}

# Add entry to router.db
add_entry() {
  local entry=$1
  local router_db=$2

  # Ensure router.db exists
  if [[ ! -f "${router_db}" ]]; then
    log_warn "router.db does not exist, creating new file"
    touch "${router_db}"
    chmod 600 "${router_db}"
  fi

  # Append entry to router.db
  if echo "${entry}" >> "${router_db}"; then
    log_success "Entry added to router.db"
    return 0
  else
    log_error "Failed to add entry to router.db"
    return 1
  fi
}

# Run validation script on router.db
run_validation() {
  local router_db=$1
  local script_dir
  script_dir=$(dirname "${router_db}")
  local validate_script="${script_dir}/../scripts/validate-router-db.sh"

  # Also check in /var/lib/oxidized/scripts
  if [[ ! -x "${validate_script}" ]]; then
    validate_script="/var/lib/oxidized/scripts/validate-router-db.sh"
  fi

  # Also check in current directory's parent
  if [[ ! -x "${validate_script}" ]]; then
    validate_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-router-db.sh"
  fi

  if [[ ! -x "${validate_script}" ]]; then
    log_warn "Validation script not found, skipping full validation"
    log_info "Run validation manually: validate-router-db.sh ${router_db}"
    return 0
  fi

  echo "" >&2
  log_info "Running full router.db validation..."
  echo "" >&2

  if "${validate_script}" "${router_db}"; then
    return 0
  else
    log_error "Validation found issues in router.db"
    log_warn "This may include pre-existing entries that were not validated"
    return 1
  fi
}

# Main function
main() {
  # Check if running as root or with appropriate permissions
  if [[ ! -w "${ROUTER_DB}" ]] && [[ ! -w "$(dirname "${ROUTER_DB}")" ]]; then
    log_error "Cannot write to ${ROUTER_DB}"
    log_error "Run with: sudo $(basename "$0")"
    exit 1
  fi

  # Show banner
  show_banner

  log_info "This tool will help you add a new device to the Oxidized inventory"
  log_info "Router database: ${ROUTER_DB}"
  echo "" >&2

  # Collect device information
  log_info "Step 1: Enter New Device Hostname Below"
  echo "" >&2
  local hostname
  hostname=$(prompt_hostname)
  echo "" >&2

  log_info "Step 2: Enter IP Address of the New Device"
  echo "" >&2
  local ip
  ip=$(prompt_ip_address)
  echo "" >&2

  log_info "Step 3: Enter Device Model/OS Type Below"
  echo "" >&2
  local model
  model=$(prompt_device_model)
  echo "" >&2

  log_info "Step 4: Choose Group Assignment"
  local group
  group=$(prompt_group)
  echo "" >&2

  log_info "Step 5: Device Credentials"
  echo "" >&2
  local credentials
  credentials=$(prompt_credentials)
  echo "" >&2

  # Build entry
  # If credentials is empty, use 4-field format (global credentials)
  # If credentials has value, use 6-field format (device-specific credentials)
  if [[ -z "${credentials}" ]]; then
    local entry="${hostname}:${ip}:${model}:${group}"
  else
    local entry="${hostname}:${ip}:${model}:${group}:${credentials}"
  fi

  # Display entry for review
  echo "" >&2
  echo -e "${COLOR_BLUE}╔══════════════════════════════════════════════════════════════════════════╗${COLOR_RESET}" >&2
  echo -e "${COLOR_BLUE}║                      Entry to be Added                               ║${COLOR_RESET}" >&2
  echo -e "${COLOR_BLUE}╚══════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}" >&2
  echo "" >&2
  echo -e "${COLOR_CYAN}Entry Details:${COLOR_RESET}" >&2
  echo "  Hostname: ${hostname}" >&2
  echo "  IP/FQDN:  ${ip}" >&2
  echo "  Model:    ${model}" >&2
  echo "  Group:    ${group:-<empty>}" >&2

  # Parse credentials for display
  IFS=':' read -r cred_user cred_pass <<< "${credentials}"
  if [[ -z "${cred_user}" ]] && [[ -z "${cred_pass}" ]]; then
    echo "  Credentials: Using global defaults" >&2
  else
    echo "  Credentials: Device-specific (username: ${cred_user})" >&2
  fi

  echo "" >&2
  echo -e "${COLOR_CYAN}Router.db format:${COLOR_RESET}" >&2
  # Mask password in display
  if [[ -z "${credentials}" ]]; then
    # 4-field format (global credentials)
    local display_entry="${hostname}:${ip}:${model}:${group}"
  else
    # 6-field format (device-specific credentials)
    local display_entry="${hostname}:${ip}:${model}:${group}:${cred_user}:********"
  fi
  echo "  ${display_entry}" >&2
  echo "" >&2

  # Validate entry format
  if ! validate_entry "${entry}"; then
    log_error "Entry validation failed"
    exit 1
  fi

  log_success "Entry format is valid"
  echo "" >&2

  # Confirm before adding
  read -rp "Add this device to router.db? (y/N): " confirm
  echo >&2

  if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    log_warn "Operation cancelled by user"
    exit 0
  fi

  # Create backup
  log_info "Creating backup..."
  if ! create_backup "${ROUTER_DB}"; then
    log_error "Backup failed, aborting"
    exit 1
  fi
  echo "" >&2

  # Add entry
  log_info "Adding entry to router.db..."
  if ! add_entry "${entry}" "${ROUTER_DB}"; then
    log_error "Failed to add entry"
    exit 1
  fi
  echo "" >&2

  # Run validation
  log_info "Validating router.db..."
  if ! run_validation "${ROUTER_DB}"; then
    log_warn "Validation completed with warnings or errors"
    log_info "Please review the output above"
    echo "" >&2
  fi

  # Success message
  echo "" >&2
  echo -e "${COLOR_GREEN}╔══════════════════════════════════════════════════════════════════════════╗${COLOR_RESET}" >&2
  echo -e "${COLOR_GREEN}║                    Device Added Successfully!                        ║${COLOR_RESET}" >&2
  echo -e "${COLOR_GREEN}╚══════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}" >&2
  echo "" >&2
  log_success "Device '${hostname}' has been added to router.db"
  log_info "Oxidized will pick up this device on the next poll cycle"
  echo "" >&2

  # Offer to test the device
  log_info "Would you like to test connectivity to this device now?"
  echo "" >&2
  read -rp "Run test-device.sh for '${hostname}'? (y/N): " run_test
  echo >&2

  if [[ "${run_test}" =~ ^[Yy]$ ]]; then
    local test_script
    test_script="$(dirname "${BASH_SOURCE[0]}")/test-device.sh"

    # Check if test-device.sh exists
    if [[ ! -x "${test_script}" ]]; then
      test_script="/var/lib/oxidized/scripts/test-device.sh"
    fi

    if [[ -x "${test_script}" ]]; then
      echo "" >&2
      log_info "Running connectivity test..."
      echo "" >&2
      "${test_script}" "${hostname}"
    else
      log_warn "test-device.sh not found or not executable"
      log_info "You can test manually with: test-device.sh ${hostname}"
    fi
  else
    echo "" >&2
    log_info "Next steps:"
    echo "  1. Test the device: test-device.sh ${hostname}" >&2
    echo "  2. Check Oxidized logs: tail -f /var/lib/oxidized/data/oxidized.log" >&2
    echo "  3. Restart Oxidized (if needed): systemctl restart oxidized.service" >&2
  fi

  echo "" >&2
}

# Run main function
main "$@"
