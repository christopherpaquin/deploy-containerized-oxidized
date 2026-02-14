#!/usr/bin/env bash
set -euo pipefail

# Oxidized Uninstallation Script
# Removes containerized Oxidized deployment from RHEL 10
# See docs/INSTALL.md for installation steps

# Exit codes
readonly EXIT_SUCCESS=0
# shellcheck disable=SC2034  # EXIT_GENERAL_FAILURE reserved for consistency
readonly EXIT_GENERAL_FAILURE=1
readonly EXIT_INVALID_USAGE=2

# Configuration
# shellcheck disable=SC2155  # Separate declaration is unnecessary for readonly
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${REPO_ROOT}/.env"
readonly QUADLET_DIR="/etc/containers/systemd"
readonly LOGROTATE_DIR="/etc/logrotate.d"

# Load .env if it exists (for path/user configuration)
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

# Set defaults if not loaded from .env
readonly OXIDIZED_ROOT="${OXIDIZED_ROOT:-/var/lib/oxidized}"
readonly OXIDIZED_USER="${OXIDIZED_USER:-oxidized}"
readonly OXIDIZED_GROUP="${OXIDIZED_GROUP:-oxidized}"
readonly PODMAN_NETWORK="${PODMAN_NETWORK:-oxidized-net}"
readonly CONTAINER_NAME="${CONTAINER_NAME:-oxidized}"

# Colors for output
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_CYAN=$'\033[0;36m'
readonly COLOR_RESET=$'\033[0m'

# Flags
DRY_RUN=false
PRESERVE_DATA=true
FORCE=false
VERBOSE=false

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

log_step() {
  echo ""
  echo -e "${COLOR_GREEN}==>${COLOR_RESET} $*"
}

# Show usage
usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Removes containerized Oxidized deployment from the system.

OPTIONS:
    -d, --dry-run           Show what would be done without making changes
    -r, --remove-data       Remove all data including configs and Git repository
    -f, --force             Skip confirmation prompts
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    # Uninstall but keep data
    sudo $(basename "$0")

    # Uninstall and remove all data (DESTRUCTIVE!)
    sudo $(basename "$0") --remove-data --force

    # Dry-run to see what would be removed
    sudo $(basename "$0") --dry-run --remove-data

NOTES:
    - Must be run as root (or with sudo)
    - By default, data in ${OXIDIZED_ROOT} is PRESERVED
    - Use --remove-data to delete configs, inventory, and Git repository
    - When removing data, you will be prompted to backup router.db
    - Backup is saved to your home directory with timestamp

EOF
}

# Check if running as root
check_root() {
  if [[ ${EUID} -ne 0 ]]; then
    log_error "This script must be run as root (or with sudo)"
    exit ${EXIT_INVALID_USAGE}
  fi
}

# Confirm destructive actions
confirm_action() {
  if [[ "${FORCE}" == "true" ]]; then
    return 0
  fi

  log_warn "This will uninstall Oxidized from your system"

  if [[ "${PRESERVE_DATA}" == "false" ]]; then
    log_error "WARNING: --remove-data flag is set!"
    log_error "This will DELETE all configs, inventory, logs, and Git repository!"
    log_error "Location: ${OXIDIZED_ROOT}"
    echo ""
  fi

  read -rp "Are you sure you want to continue? (yes/NO): " confirm

  if [[ "${confirm}" != "yes" ]]; then
    log_info "Uninstallation cancelled"
    exit ${EXIT_SUCCESS}
  fi
}

# Stop and disable service
stop_service() {
  log_step "Stopping Oxidized services"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would stop and disable oxidized.service and oxidized-logger.service"
    return
  fi

  # Stop oxidized.service
  if systemctl is-active --quiet oxidized.service 2> /dev/null; then
    systemctl stop oxidized.service 2> /dev/null || log_warn "Failed to stop oxidized.service"
    log_success "Stopped oxidized.service"
  else
    log_info "oxidized.service is not running"
  fi

  if systemctl is-enabled --quiet oxidized.service 2> /dev/null; then
    systemctl disable oxidized.service 2> /dev/null || log_warn "Failed to disable oxidized.service"
    log_success "Disabled oxidized.service"
  else
    log_info "oxidized.service is not enabled"
  fi

  # Stop oxidized-logger.service
  if systemctl is-active --quiet oxidized-logger.service 2> /dev/null; then
    systemctl stop oxidized-logger.service 2> /dev/null || log_warn "Failed to stop oxidized-logger.service"
    log_success "Stopped oxidized-logger.service"
  else
    log_info "oxidized-logger.service is not running"
  fi

  if systemctl is-enabled --quiet oxidized-logger.service 2> /dev/null; then
    systemctl disable oxidized-logger.service 2> /dev/null || log_warn "Failed to disable oxidized-logger.service"
    log_success "Disabled oxidized-logger.service"
  else
    log_info "oxidized-logger.service is not enabled"
  fi
}

# Remove container
remove_container() {
  log_step "Removing Podman container"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove container: ${CONTAINER_NAME}"
    return
  fi

  # Stop container if running
  if podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    podman stop "${CONTAINER_NAME}"
    log_success "Stopped container: ${CONTAINER_NAME}"
  else
    log_info "Container is not running"
  fi

  # Remove container
  if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    podman rm "${CONTAINER_NAME}"
    log_success "Removed container: ${CONTAINER_NAME}"
  else
    log_info "Container does not exist"
  fi
}

# Remove Quadlet configuration
remove_quadlet() {
  log_step "Removing Quadlet configuration"

  local quadlet_file="${QUADLET_DIR}/oxidized.container"

  if [[ -f "${quadlet_file}" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would remove: ${quadlet_file}"
    else
      rm -f "${quadlet_file}"
      log_success "Removed: ${quadlet_file}"
    fi
  else
    log_info "Quadlet file not found: ${quadlet_file}"
  fi

  # Clean up backup files
  local backup_count
  backup_count=$(find "${QUADLET_DIR}" -name "oxidized.container.backup.*" 2> /dev/null | wc -l)

  if [[ ${backup_count} -gt 0 ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would remove ${backup_count} backup file(s)"
    else
      find "${QUADLET_DIR}" -name "oxidized.container.backup.*" -delete
      log_success "Removed ${backup_count} Quadlet backup file(s)"
    fi
  fi

  if [[ "${DRY_RUN}" == "false" ]]; then
    systemctl daemon-reload
    # Reset any failed unit state
    systemctl reset-failed oxidized.service 2> /dev/null || true
    log_success "Reloaded systemd daemon"
  fi
}

# Remove logrotate configuration
remove_logrotate() {
  log_step "Removing logrotate configuration"

  local logrotate_file="${LOGROTATE_DIR}/oxidized"

  if [[ -f "${logrotate_file}" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would remove: ${logrotate_file}"
    else
      rm -f "${logrotate_file}"
      log_success "Removed: ${logrotate_file}"
    fi
  else
    log_info "Logrotate file not found: ${logrotate_file}"
  fi
}

# Remove log tailer service
remove_log_tailer() {
  log_step "Removing log tailer service"

  local logger_service="/etc/systemd/system/oxidized-logger.service"
  local logger_script="/usr/local/bin/oxidized-log-tailer.sh"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove logger service and script"
    return
  fi

  # Remove systemd service file
  if [[ -f "${logger_service}" ]]; then
    rm -f "${logger_service}"
    log_success "Removed: ${logger_service}"
  else
    log_info "Logger service file not found: ${logger_service}"
  fi

  # Remove log tailer script
  if [[ -f "${logger_script}" ]]; then
    rm -f "${logger_script}"
    log_success "Removed: ${logger_script}"
  else
    log_info "Logger script not found: ${logger_script}"
  fi

  # Reload systemd and reset failed state
  if [[ -f "${logger_service}" ]] || systemctl list-units --all | grep -q oxidized-logger; then
    systemctl daemon-reload 2> /dev/null || true
    systemctl reset-failed oxidized-logger.service 2> /dev/null || true
    log_success "Reloaded systemd daemon"
  fi
}

# Remove helper scripts
remove_helper_scripts() {
  log_step "Removing helper scripts"

  local scripts_dir="${OXIDIZED_ROOT}/scripts"

  if [[ -d "${scripts_dir}" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would remove: ${scripts_dir}"
    else
      rm -rf "${scripts_dir}"
      log_success "Removed: ${scripts_dir}"
    fi
  else
    log_info "Helper scripts directory not found: ${scripts_dir}"
  fi
}

# Remove documentation
remove_documentation() {
  log_step "Removing documentation"

  local docs_dir="${OXIDIZED_ROOT}/docs"

  if [[ -d "${docs_dir}" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would remove: ${docs_dir}"
    else
      rm -rf "${docs_dir}"
      log_success "Removed: ${docs_dir}"
    fi
  else
    log_info "Documentation directory not found: ${docs_dir}"
  fi
}

# Remove MOTD
remove_motd() {
  log_step "Removing MOTD"

  local motd_file="/etc/profile.d/99-oxidized.sh"

  if [[ -f "${motd_file}" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would remove: ${motd_file}"
    else
      rm -f "${motd_file}"
      log_success "Removed: ${motd_file}"
    fi
  else
    log_info "MOTD not found: ${motd_file}"
  fi
}

# Remove firewall rule
remove_firewall() {
  log_step "Removing firewall configuration"

  # Check if firewalld is installed and running
  if ! command -v firewall-cmd &> /dev/null; then
    log_info "firewalld not installed, skipping firewall cleanup"
    return
  fi

  if ! systemctl is-active --quiet firewalld 2> /dev/null; then
    log_info "firewalld not running, skipping firewall cleanup"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove firewall rule for port ${OXIDIZED_API_PORT:-8888}/tcp"
    return
  fi

  local port="${OXIDIZED_API_PORT:-8888}"

  # Check if port is in firewall
  if firewall-cmd --list-ports 2> /dev/null | grep -q "${port}/tcp"; then
    log_info "Removing port ${port}/tcp from firewall..."
    if firewall-cmd --permanent --remove-port="${port}/tcp" &> /dev/null; then
      if firewall-cmd --reload &> /dev/null; then
        log_success "Removed port ${port}/tcp from firewall"
      else
        log_warn "Failed to reload firewall (non-fatal)"
      fi
    else
      log_warn "Failed to remove port from firewall (non-fatal)"
    fi
  else
    log_info "Port ${port}/tcp not found in firewall"
  fi
}

# Stop and disable nginx
stop_nginx() {
  log_step "Stopping nginx"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would stop and disable nginx"
    return
  fi

  # Check if nginx is installed
  if ! command -v nginx &> /dev/null; then
    log_info "nginx not installed, skipping"
    return
  fi

  # Stop nginx if running
  if systemctl is-active --quiet nginx; then
    if systemctl stop nginx &> /dev/null; then
      log_success "Stopped nginx"
    else
      log_warn "Failed to stop nginx (non-fatal)"
    fi
  else
    log_info "nginx not running"
  fi

  # Disable nginx
  if systemctl is-enabled --quiet nginx 2> /dev/null; then
    if systemctl disable nginx &> /dev/null; then
      log_success "Disabled nginx"
    else
      log_warn "Failed to disable nginx (non-fatal)"
    fi
  fi
}

# Remove nginx configuration
remove_nginx_config() {
  log_step "Removing nginx configuration"

  local nginx_config="/etc/nginx/conf.d/oxidized.conf"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove ${nginx_config}"
    return
  fi

  if [[ -f "${nginx_config}" ]]; then
    rm -f "${nginx_config}"
    log_success "Removed: ${nginx_config}"
  else
    log_info "nginx config not found: ${nginx_config}"
  fi

  # Restore original nginx.conf if it exists
  if [[ -f /etc/nginx/nginx.conf.original ]]; then
    log_info "Restoring original nginx.conf"
    cp /etc/nginx/nginx.conf.original /etc/nginx/nginx.conf
    log_success "Restored original nginx.conf"
  fi
}

# Remove nginx authentication data
remove_nginx_auth() {
  log_step "Removing nginx authentication data"

  local nginx_dir="${NGINX_DATA_DIR:-${OXIDIZED_ROOT}/nginx}"

  if [[ ! -d "${nginx_dir}" ]]; then
    log_info "nginx directory does not exist: ${nginx_dir}"
    return
  fi

  if [[ "${PRESERVE_DATA}" == "true" ]]; then
    log_warn "nginx authentication data PRESERVED: ${nginx_dir}"
    log_warn "This includes the .htpasswd file"
    log_warn "To remove, run with --remove-data flag"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove: ${nginx_dir}"
    return
  fi

  rm -rf "${nginx_dir}"
  log_success "Removed: ${nginx_dir}"
}

# Remove SELinux configuration
remove_selinux_config() {
  log_step "Removing SELinux port labels"

  # Check if SELinux tools are available
  if ! command -v semanage &> /dev/null; then
    log_info "semanage not available, skipping SELinux cleanup"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove SELinux port labels for 8888/tcp and 8889/tcp"
    return
  fi

  local removed=0

  # Remove port 8888 (nginx frontend)
  if semanage port -l 2> /dev/null | grep -qE "http_port_t.*\b8888\b"; then
    if semanage port -d -t http_port_t -p tcp 8888 2> /dev/null; then
      log_success "Removed SELinux label for port 8888/tcp"
      ((removed++))
    else
      log_warn "Failed to remove SELinux label for port 8888/tcp"
    fi
  fi

  # Remove port 8889 (Oxidized backend) if it was added
  if semanage port -l 2> /dev/null | grep -qE "http_port_t.*\b8889\b"; then
    if semanage port -d -t http_port_t -p tcp 8889 2> /dev/null; then
      log_success "Removed SELinux label for port 8889/tcp"
      ((removed++))
    else
      log_warn "Failed to remove SELinux label for port 8889/tcp"
    fi
  fi

  if [[ ${removed} -eq 0 ]]; then
    log_info "No SELinux port labels to remove"
  fi
}

# Remove data directory
remove_data() {
  log_step "Handling data directory"

  if [[ ! -d "${OXIDIZED_ROOT}" ]]; then
    log_info "Data directory does not exist: ${OXIDIZED_ROOT}"
    return
  fi

  if [[ "${PRESERVE_DATA}" == "true" ]]; then
    log_warn "Data directory PRESERVED: ${OXIDIZED_ROOT}"
    log_warn "This includes configs, inventory, logs, and Git repository"
    log_warn "To remove data, run with --remove-data flag"
    return
  fi

  # Calculate size
  local dir_size
  dir_size=$(du -sh "${OXIDIZED_ROOT}" 2> /dev/null | awk '{print $1}' || echo "unknown")

  log_warn "About to DELETE ${OXIDIZED_ROOT} (${dir_size})"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove: ${OXIDIZED_ROOT}"
    return
  fi

  # Offer to backup router.db before deletion (only if not using --force)
  local router_db="${OXIDIZED_ROOT}/config/router.db"

  if [[ -f "${router_db}" && "${FORCE}" == "false" ]]; then
    echo ""
    log_warn "Found device inventory: ${router_db}"

    # Get the actual user (not root if running via sudo)
    local actual_user="${SUDO_USER:-${USER}}"
    local user_home

    if [[ "${actual_user}" == "root" ]]; then
      user_home="/root"
    else
      user_home=$(getent passwd "${actual_user}" | cut -d: -f6)
    fi

    # Generate timestamped backup filename
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${user_home}/router.db.backup.${timestamp}"

    echo ""
    echo -e "${COLOR_YELLOW}Would you like to backup router.db before deletion?${COLOR_RESET}"
    echo -e "Backup location: ${COLOR_CYAN}${backup_path}${COLOR_RESET}"
    echo ""
    read -rp "Backup router.db? [Y/n]: " backup_choice

    # Default to yes if empty
    backup_choice="${backup_choice:-Y}"

    if [[ "${backup_choice}" =~ ^[Yy]$ ]]; then
      if cp "${router_db}" "${backup_path}" 2> /dev/null; then
        # Set ownership to actual user (not root)
        if [[ "${actual_user}" != "root" ]]; then
          chown "${actual_user}:${actual_user}" "${backup_path}" 2> /dev/null || true
        fi
        chmod 600 "${backup_path}" 2> /dev/null || true
        log_success "Backed up router.db to: ${backup_path}"
        echo ""
      else
        log_error "Failed to backup router.db"
        echo ""
        read -rp "Continue with deletion anyway? [y/N]: " continue_choice
        if [[ ! "${continue_choice}" =~ ^[Yy]$ ]]; then
          log_info "Uninstall cancelled"
          exit 0
        fi
      fi
    else
      log_info "Skipping router.db backup"
      echo ""
    fi
  fi

  # Final confirmation for data removal (only if not using --force)
  if [[ "${FORCE}" == "false" ]]; then
    echo ""
    log_error "FINAL WARNING: About to delete all Oxidized data!"
    read -rp "Type 'DELETE' to confirm data removal: " confirm_delete

    if [[ "${confirm_delete}" != "DELETE" ]]; then
      log_info "Data removal cancelled"
      log_warn "Data preserved at: ${OXIDIZED_ROOT}"
      return
    fi
  fi

  # Remove the directory
  if rm -rf "${OXIDIZED_ROOT}" 2> /dev/null; then
    log_success "Removed: ${OXIDIZED_ROOT}"
  else
    log_error "Failed to remove ${OXIDIZED_ROOT}"
    log_error "You may need to remove it manually: sudo rm -rf ${OXIDIZED_ROOT}"
  fi
}

# Remove Podman network
remove_network() {
  log_step "Removing Podman network"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove network: ${PODMAN_NETWORK}"
    return
  fi

  if podman network exists "${PODMAN_NETWORK}" 2> /dev/null; then
    podman network rm "${PODMAN_NETWORK}"
    log_success "Removed network: ${PODMAN_NETWORK}"
  else
    log_info "Network does not exist: ${PODMAN_NETWORK}"
  fi
}

# Remove oxidized user and group
remove_user() {
  log_step "Removing oxidized user and group"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove user/group: ${OXIDIZED_USER}"
    return
  fi

  # With --remove-data and --force, remove user without prompting
  # Otherwise, prompt for confirmation
  local should_remove_user=false

  if [[ "${PRESERVE_DATA}" == "false" && "${FORCE}" == "true" ]]; then
    should_remove_user=true
    log_info "Removing user ${OXIDIZED_USER} (--remove-data --force flags set)"
  elif [[ "${FORCE}" == "true" ]]; then
    should_remove_user=true
    log_info "Removing user ${OXIDIZED_USER} (--force flag set)"
  else
    read -rp "Remove system user ${OXIDIZED_USER}? (y/N): " remove_usr
    if [[ "${remove_usr}" =~ ^[Yy]$ ]]; then
      should_remove_user=true
    else
      log_info "User ${OXIDIZED_USER} preserved"
      return
    fi
  fi

  if [[ "${should_remove_user}" == "true" ]]; then
    # Remove home directory first (before removing user)
    if [[ -d "/home/${OXIDIZED_USER}" ]]; then
      rm -rf "/home/${OXIDIZED_USER:?}" 2> /dev/null || log_warn "Failed to remove /home/${OXIDIZED_USER}"
      log_success "Removed home directory: /home/${OXIDIZED_USER}"
    fi

    # Remove user
    if id "${OXIDIZED_USER}" > /dev/null 2>&1; then
      userdel "${OXIDIZED_USER}" 2> /dev/null || log_warn "Failed to remove user (may still own files)"
      log_success "Removed user: ${OXIDIZED_USER}"
    else
      log_info "User does not exist: ${OXIDIZED_USER}"
    fi

    # Remove group
    if getent group "${OXIDIZED_GROUP}" > /dev/null 2>&1; then
      groupdel "${OXIDIZED_GROUP}" 2> /dev/null || log_warn "Failed to remove group (may still be in use)"
      log_success "Removed group: ${OXIDIZED_GROUP}"
    else
      log_info "Group does not exist: ${OXIDIZED_GROUP}"
    fi
  fi
}

# Remove container image (optional)
remove_image() {
  log_step "Checking container image"

  # Check if any oxidized images exist (any version)
  if podman images | grep -q "oxidized/oxidized"; then
    log_info "Container image(s) found"

    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would optionally remove image"
      return
    fi

    if [[ "${FORCE}" == "false" ]]; then
      read -rp "Remove container image(s)? (y/N): " remove_img
      if [[ "${remove_img}" =~ ^[Yy]$ ]]; then
        # Remove all oxidized images (force removal)
        podman images | grep "oxidized/oxidized" | awk '{print $3}' | xargs -r podman rmi -f 2>&1 | grep -v "Error" || true
        log_success "Removed container images"
      else
        log_info "Container image preserved"
      fi
    else
      # Remove all oxidized images (force removal)
      podman images | grep "oxidized/oxidized" | awk '{print $3}' | xargs -r podman rmi -f 2>&1 | grep -v "Error" || true
      log_success "Removed container images"
    fi
  else
    log_info "No container images found"
  fi
}

# Show summary
show_summary() {
  log_step "Uninstallation Summary"

  cat << EOF

${COLOR_GREEN}✅ Oxidized has been uninstalled${COLOR_RESET}

${COLOR_BLUE}What was removed:${COLOR_RESET}
  ✓ Systemd services (oxidized.service, oxidized-logger.service)
  ✓ Podman container
  ✓ Podman network (${PODMAN_NETWORK})
  ✓ Quadlet configuration (${QUADLET_DIR}/oxidized.container)
  ✓ Logrotate configuration (${LOGROTATE_DIR}/oxidized)
  ✓ Log tailer script (/usr/local/bin/oxidized-log-tailer.sh)

EOF

  if [[ "${PRESERVE_DATA}" == "true" ]]; then
    cat << EOF
${COLOR_YELLOW}What was preserved:${COLOR_RESET}
  ℹ Data directory: ${OXIDIZED_ROOT}
    - Configuration files
    - Router database (device inventory)
    - Git repository (backup history)
    - SSH keys
    - Output files
  ℹ System user: ${OXIDIZED_USER}:${OXIDIZED_GROUP}

${COLOR_BLUE}To remove preserved data:${COLOR_RESET}
  sudo rm -rf ${OXIDIZED_ROOT}

${COLOR_BLUE}To remove system user:${COLOR_RESET}
  sudo userdel ${OXIDIZED_USER}
  sudo groupdel ${OXIDIZED_GROUP}

${COLOR_BLUE}To backup data before removal:${COLOR_RESET}
  sudo tar -czf oxidized-backup-\$(date +%Y%m%d).tar.gz ${OXIDIZED_ROOT}

EOF
  else
    cat << EOF
${COLOR_RED}What was deleted:${COLOR_RESET}
  ✗ Data directory: ${OXIDIZED_ROOT}
  ✗ Configuration files
  ✗ Router database
  ✗ Git repository (all backup history)
  ✗ SSH keys
  ✗ Output files

EOF
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_warn "DRY-RUN MODE: No actual changes were made"
  fi
}

# Main function
main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -d | --dry-run)
        DRY_RUN=true
        shift
        ;;
      -r | --remove-data)
        PRESERVE_DATA=false
        shift
        ;;
      -f | --force)
        FORCE=true
        shift
        ;;
      -v | --verbose)
        # shellcheck disable=SC2034  # VERBOSE reserved for future enhancements
        VERBOSE=true
        set -x
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
  echo ""
  echo "========================================"
  echo "  Oxidized Uninstallation Script"
  echo "========================================"
  echo ""

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_warn "DRY-RUN MODE: No changes will be made"
  fi

  # Execute uninstallation steps
  check_root
  confirm_action
  stop_service
  remove_container
  remove_network
  remove_quadlet
  remove_logrotate
  remove_log_tailer
  remove_motd
  remove_documentation
  remove_helper_scripts
  remove_firewall
  stop_nginx
  remove_nginx_config
  remove_nginx_auth
  remove_selinux_config
  remove_data
  remove_user
  remove_image
  show_summary

  exit ${EXIT_SUCCESS}
}

# Run main function
main "$@"
