#!/usr/bin/env bash
set -euo pipefail

# Oxidized Uninstallation Script
# Removes containerized Oxidized deployment from RHEL 10
# See docs/INSTALL.md for installation steps

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_FAILURE=1
readonly EXIT_INVALID_USAGE=2

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OXIDIZED_ROOT="/srv/oxidized"
readonly QUADLET_DIR="/etc/containers/systemd"
readonly LOGROTATE_DIR="/etc/logrotate.d"

# Colors for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

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
    cat <<EOF
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
    - Backups are recommended before uninstallation

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
    log_step "Stopping Oxidized service"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would stop and disable oxidized.service"
        return
    fi
    
    if systemctl is-active --quiet oxidized.service 2>/dev/null; then
        systemctl stop oxidized.service
        log_success "Stopped oxidized.service"
    else
        log_info "Service is not running"
    fi
    
    if systemctl is-enabled --quiet oxidized.service 2>/dev/null; then
        systemctl disable oxidized.service
        log_success "Disabled oxidized.service"
    else
        log_info "Service is not enabled"
    fi
}

# Remove container
remove_container() {
    log_step "Removing Podman container"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would remove container: oxidized"
        return
    fi
    
    # Stop container if running
    if podman ps --format "{{.Names}}" | grep -q "^oxidized$"; then
        podman stop oxidized
        log_success "Stopped container: oxidized"
    else
        log_info "Container is not running"
    fi
    
    # Remove container
    if podman ps -a --format "{{.Names}}" | grep -q "^oxidized$"; then
        podman rm oxidized
        log_success "Removed container: oxidized"
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
    
    if [[ "${DRY_RUN}" == "false" ]]; then
        systemctl daemon-reload
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
    dir_size=$(du -sh "${OXIDIZED_ROOT}" 2>/dev/null | awk '{print $1}' || echo "unknown")
    
    log_warn "About to DELETE ${OXIDIZED_ROOT} (${dir_size})"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would remove: ${OXIDIZED_ROOT}"
        return
    fi
    
    # Final confirmation for data removal
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
    
    rm -rf "${OXIDIZED_ROOT}"
    log_success "Removed: ${OXIDIZED_ROOT}"
}

# Remove container image (optional)
remove_image() {
    log_step "Checking container image"
    
    local image_name="docker.io/oxidized/oxidized"
    
    if podman images --format "{{.Repository}}" | grep -q "^${image_name}$"; then
        log_info "Container image found: ${image_name}"
        
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] Would optionally remove image"
            return
        fi
        
        if [[ "${FORCE}" == "false" ]]; then
            read -rp "Remove container image? (y/N): " remove_img
            if [[ "${remove_img}" =~ ^[Yy]$ ]]; then
                podman rmi "${image_name}" || log_warn "Failed to remove some images"
                log_success "Removed container images"
            else
                log_info "Container image preserved"
            fi
        else
            podman rmi "${image_name}" || log_warn "Failed to remove some images"
            log_success "Removed container images"
        fi
    else
        log_info "No container images found"
    fi
}

# Show summary
show_summary() {
    log_step "Uninstallation Summary"
    
    cat <<EOF

${COLOR_GREEN}✅ Oxidized has been uninstalled${COLOR_RESET}

${COLOR_BLUE}What was removed:${COLOR_RESET}
  ✓ Systemd service (oxidized.service)
  ✓ Podman container
  ✓ Quadlet configuration (${QUADLET_DIR}/oxidized.container)
  ✓ Logrotate configuration (${LOGROTATE_DIR}/oxidized)

EOF

    if [[ "${PRESERVE_DATA}" == "true" ]]; then
        cat <<EOF
${COLOR_YELLOW}What was preserved:${COLOR_RESET}
  ℹ Data directory: ${OXIDIZED_ROOT}
    - Configuration files
    - Device inventory
    - Git repository (backup history)
    - Log files

${COLOR_BLUE}To remove preserved data:${COLOR_RESET}
  sudo rm -rf ${OXIDIZED_ROOT}

${COLOR_BLUE}To backup data before removal:${COLOR_RESET}
  sudo tar -czf oxidized-backup-\$(date +%Y%m%d).tar.gz ${OXIDIZED_ROOT}

EOF
    else
        cat <<EOF
${COLOR_RED}What was deleted:${COLOR_RESET}
  ✗ Data directory: ${OXIDIZED_ROOT}
  ✗ Configuration files
  ✗ Device inventory
  ✗ Git repository (all backup history)
  ✗ Log files

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
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -r|--remove-data)
                PRESERVE_DATA=false
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            -h|--help)
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
    remove_quadlet
    remove_logrotate
    remove_data
    remove_image
    show_summary
    
    exit ${EXIT_SUCCESS}
}

# Run main function
main "$@"
