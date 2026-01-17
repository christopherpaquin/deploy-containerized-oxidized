#!/usr/bin/env bash
set -euo pipefail

# Oxidized Deployment Script
# Automates the installation of containerized Oxidized on RHEL 10
# See docs/INSTALL.md for manual installation steps

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_FAILURE=1
readonly EXIT_INVALID_USAGE=2
readonly EXIT_MISSING_DEPENDENCY=3

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
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
SKIP_CREDENTIALS=false
VERBOSE=false

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Deployment failed with exit code ${exit_code}"
    fi
}

trap cleanup EXIT

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

Automates the deployment of containerized Oxidized on RHEL 10.

OPTIONS:
    -d, --dry-run           Show what would be done without making changes
    -s, --skip-credentials  Skip prompting for device credentials
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    # Standard deployment
    sudo $(basename "$0")

    # Dry-run to see what would happen
    sudo $(basename "$0") --dry-run

    # Deploy without credential prompt (configure manually later)
    sudo $(basename "$0") --skip-credentials

NOTES:
    - Must be run as root (or with sudo)
    - Requires RHEL 9 or RHEL 10
    - See docs/PREREQUISITES.md for system requirements
    - See docs/INSTALL.md for manual installation steps

EOF
}

# Check if running as root
check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        log_error "This script must be run as root (or with sudo)"
        exit ${EXIT_INVALID_USAGE}
    fi
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites"
    
    local missing_deps=()
    local required_commands=("podman" "git" "systemctl" "curl" "jq")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_deps+=("${cmd}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Install with: sudo dnf install -y ${missing_deps[*]}"
        log_error "See docs/PREREQUISITES.md for details"
        exit ${EXIT_MISSING_DEPENDENCY}
    fi
    
    log_success "All required commands found"
    
    # Check OS version
    if [[ -f /etc/redhat-release ]]; then
        local os_version
        os_version=$(cat /etc/redhat-release)
        log_info "OS: ${os_version}"
    else
        log_warn "Not running on RHEL (best-effort support)"
    fi
    
    # Check SELinux status
    if command -v getenforce &> /dev/null; then
        local selinux_status
        selinux_status=$(getenforce)
        log_info "SELinux: ${selinux_status}"
        
        if [[ "${selinux_status}" != "Enforcing" ]]; then
            log_warn "SELinux is not in Enforcing mode"
            log_warn "This deployment is designed for SELinux enforcing"
        fi
    fi
    
    # Check systemd version (need >= 247 for Quadlets)
    local systemd_version
    systemd_version=$(systemctl --version | head -n1 | awk '{print $2}')
    log_info "systemd version: ${systemd_version}"
    
    if [[ ${systemd_version} -lt 247 ]]; then
        log_error "systemd version ${systemd_version} is too old"
        log_error "Quadlets require systemd >= 247"
        exit ${EXIT_MISSING_DEPENDENCY}
    fi
    
    # Check disk space
    local available_space
    available_space=$(df -BG /srv 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")
    log_info "Available space in /srv: ${available_space}GB"
    
    if [[ ${available_space} -lt 10 ]]; then
        log_warn "Less than 10GB available in /srv"
        log_warn "You may run out of space for Git repository and logs"
    fi
}

# Create directory structure
create_directories() {
    log_step "Creating directory structure"
    
    local directories=(
        "${OXIDIZED_ROOT}"
        "${OXIDIZED_ROOT}/config"
        "${OXIDIZED_ROOT}/inventory"
        "${OXIDIZED_ROOT}/data"
        "${OXIDIZED_ROOT}/git"
        "${OXIDIZED_ROOT}/logs"
    )
    
    for dir in "${directories[@]}"; do
        if [[ -d "${dir}" ]]; then
            log_info "Directory exists: ${dir}"
        else
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_info "[DRY-RUN] Would create: ${dir}"
            else
                mkdir -p "${dir}"
                chmod 755 "${dir}"
                log_success "Created: ${dir}"
            fi
        fi
    done
    
    if [[ "${DRY_RUN}" == "false" ]]; then
        chown -R root:root "${OXIDIZED_ROOT}"
        log_success "Set ownership: root:root on ${OXIDIZED_ROOT}"
    fi
}

# Deploy configuration files
deploy_config() {
    log_step "Deploying configuration files"
    
    # Deploy Oxidized config
    local src_config="${REPO_ROOT}/config/oxidized/config"
    local dst_config="${OXIDIZED_ROOT}/config/config"
    
    if [[ ! -f "${src_config}" ]]; then
        log_error "Source config not found: ${src_config}"
        exit ${EXIT_GENERAL_FAILURE}
    fi
    
    if [[ -f "${dst_config}" ]]; then
        log_warn "Config already exists: ${dst_config}"
        log_warn "Backing up to ${dst_config}.backup"
        if [[ "${DRY_RUN}" == "false" ]]; then
            cp "${dst_config}" "${dst_config}.backup.$(date +%Y%m%d_%H%M%S)"
        fi
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would copy: ${src_config} -> ${dst_config}"
    else
        cp "${src_config}" "${dst_config}"
        chmod 644 "${dst_config}"
        log_success "Deployed: ${dst_config}"
    fi
    
    # Deploy inventory example
    local src_inventory="${REPO_ROOT}/config/oxidized/inventory/devices.csv.example"
    local dst_inventory="${OXIDIZED_ROOT}/inventory/devices.csv"
    
    if [[ -f "${dst_inventory}" ]]; then
        log_info "Inventory already exists: ${dst_inventory} (keeping existing)"
    else
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] Would copy: ${src_inventory} -> ${dst_inventory}"
        else
            cp "${src_inventory}" "${dst_inventory}"
            chmod 644 "${dst_inventory}"
            log_success "Deployed: ${dst_inventory}"
            log_warn "IMPORTANT: Edit ${dst_inventory} with your devices"
        fi
    fi
}

# Configure credentials
configure_credentials() {
    if [[ "${SKIP_CREDENTIALS}" == "true" ]]; then
        log_info "Skipping credential configuration"
        return
    fi
    
    log_step "Configuring device credentials"
    
    local config_file="${OXIDIZED_ROOT}/config/config"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would prompt for credentials"
        return
    fi
    
    log_warn "Default credentials in config are: username=oxidized, password=oxidized"
    
    read -rp "Do you want to update device credentials now? (y/N): " -n 1
    echo
    
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
        read -rp "Enter device username: " username
        read -rsp "Enter device password: " password
        echo
        
        if [[ -n "${username}" && -n "${password}" ]]; then
            sed -i "s/^username:.*/username: ${username}/" "${config_file}"
            sed -i "s/^password:.*/password: ${password}/" "${config_file}"
            log_success "Updated credentials in ${config_file}"
        else
            log_warn "Empty username or password, skipping update"
        fi
    else
        log_info "Skipped credential update"
        log_warn "Remember to edit ${config_file} before starting service"
    fi
}

# Initialize Git repository
initialize_git() {
    log_step "Initializing Git repository"
    
    local git_repo="${OXIDIZED_ROOT}/git/configs.git"
    
    if [[ -d "${git_repo}/.git" ]]; then
        log_info "Git repository already initialized: ${git_repo}"
        return
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would initialize Git repo: ${git_repo}"
        return
    fi
    
    git init "${git_repo}"
    
    # Configure Git
    cd "${git_repo}"
    git config user.name "Oxidized"
    git config user.email "oxidized@example.com"
    
    # Create initial commit
    echo "# Network Device Configurations" > README.md
    echo "" >> README.md
    echo "This repository contains automated backups of network device configurations." >> README.md
    echo "Managed by Oxidized." >> README.md
    
    git add README.md
    git commit -m "Initial commit"
    
    log_success "Initialized Git repository: ${git_repo}"
    cd - > /dev/null
}

# Install Quadlet
install_quadlet() {
    log_step "Installing Quadlet configuration"
    
    local src_quadlet="${REPO_ROOT}/containers/quadlet/oxidized.container"
    local dst_quadlet="${QUADLET_DIR}/oxidized.container"
    
    if [[ ! -f "${src_quadlet}" ]]; then
        log_error "Source Quadlet not found: ${src_quadlet}"
        exit ${EXIT_GENERAL_FAILURE}
    fi
    
    if [[ ! -d "${QUADLET_DIR}" ]]; then
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] Would create: ${QUADLET_DIR}"
        else
            mkdir -p "${QUADLET_DIR}"
            log_success "Created: ${QUADLET_DIR}"
        fi
    fi
    
    if [[ -f "${dst_quadlet}" ]]; then
        log_warn "Quadlet already exists: ${dst_quadlet}"
        log_warn "Backing up to ${dst_quadlet}.backup"
        if [[ "${DRY_RUN}" == "false" ]]; then
            cp "${dst_quadlet}" "${dst_quadlet}.backup.$(date +%Y%m%d_%H%M%S)"
        fi
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would copy: ${src_quadlet} -> ${dst_quadlet}"
    else
        cp "${src_quadlet}" "${dst_quadlet}"
        chmod 644 "${dst_quadlet}"
        log_success "Installed: ${dst_quadlet}"
    fi
}

# Install logrotate configuration
install_logrotate() {
    log_step "Installing logrotate configuration"
    
    local src_logrotate="${REPO_ROOT}/config/logrotate/oxidized"
    local dst_logrotate="${LOGROTATE_DIR}/oxidized"
    
    if [[ ! -f "${src_logrotate}" ]]; then
        log_error "Source logrotate config not found: ${src_logrotate}"
        exit ${EXIT_GENERAL_FAILURE}
    fi
    
    if [[ -f "${dst_logrotate}" ]]; then
        log_info "Logrotate config already exists: ${dst_logrotate}"
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would copy: ${src_logrotate} -> ${dst_logrotate}"
    else
        cp "${src_logrotate}" "${dst_logrotate}"
        chmod 644 "${dst_logrotate}"
        log_success "Installed: ${dst_logrotate}"
        
        # Test logrotate configuration
        if logrotate -d "${dst_logrotate}" &> /dev/null; then
            log_success "Logrotate configuration is valid"
        else
            log_warn "Logrotate configuration validation failed (non-fatal)"
        fi
    fi
}

# Pull container image
pull_image() {
    log_step "Pulling container image"
    
    local image_name
    image_name=$(grep "^Image=" "${QUADLET_DIR}/oxidized.container" 2>/dev/null | cut -d= -f2 || echo "docker.io/oxidized/oxidized:0.30.1")
    
    log_info "Image: ${image_name}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would pull: ${image_name}"
        return
    fi
    
    if podman pull "${image_name}"; then
        log_success "Pulled image: ${image_name}"
    else
        log_error "Failed to pull image: ${image_name}"
        log_error "Check network connectivity and image name"
        exit ${EXIT_GENERAL_FAILURE}
    fi
}

# Enable and start service
start_service() {
    log_step "Starting Oxidized service"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would run: systemctl daemon-reload"
        log_info "[DRY-RUN] Would run: systemctl enable --now oxidized.service"
        return
    fi
    
    # Reload systemd
    systemctl daemon-reload
    log_success "Reloaded systemd daemon"
    
    # Enable service
    systemctl enable oxidized.service
    log_success "Enabled oxidized.service"
    
    # Start service
    if systemctl start oxidized.service; then
        log_success "Started oxidized.service"
    else
        log_error "Failed to start oxidized.service"
        log_error "Check status with: systemctl status oxidized.service"
        log_error "Check logs with: journalctl -u oxidized.service -n 50"
        exit ${EXIT_GENERAL_FAILURE}
    fi
    
    # Wait a moment for service to initialize
    sleep 3
}

# Verify deployment
verify_deployment() {
    log_step "Verifying deployment"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would verify deployment"
        return
    fi
    
    # Check service status
    if systemctl is-active --quiet oxidized.service; then
        log_success "Service is active"
    else
        log_error "Service is not active"
        systemctl status oxidized.service || true
        exit ${EXIT_GENERAL_FAILURE}
    fi
    
    # Check if container is running
    if podman ps --format "{{.Names}}" | grep -q "^oxidized$"; then
        log_success "Container is running"
    else
        log_error "Container is not running"
        exit ${EXIT_GENERAL_FAILURE}
    fi
    
    # Check API (with retry)
    local max_attempts=10
    local attempt=1
    
    log_info "Waiting for API to be ready..."
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        if curl -sf http://localhost:8888/ > /dev/null 2>&1; then
            log_success "API is responding"
            break
        else
            if [[ ${attempt} -eq ${max_attempts} ]]; then
                log_error "API is not responding after ${max_attempts} attempts"
                log_error "Check logs with: podman logs oxidized"
                exit ${EXIT_GENERAL_FAILURE}
            fi
            log_info "Waiting for API... (attempt ${attempt}/${max_attempts})"
            sleep 3
            ((attempt++))
        fi
    done
    
    # Check Git repository
    if [[ -d "${OXIDIZED_ROOT}/git/configs.git/.git" ]]; then
        log_success "Git repository initialized"
    else
        log_warn "Git repository not found (non-fatal)"
    fi
    
    log_success "Deployment verification complete"
}

# Show next steps
show_next_steps() {
    log_step "Deployment Complete!"
    
    cat <<EOF

${COLOR_GREEN}✅ Oxidized has been successfully deployed!${COLOR_RESET}

${COLOR_BLUE}Next Steps:${COLOR_RESET}

1. ${COLOR_YELLOW}Configure device inventory:${COLOR_RESET}
   sudo vim ${OXIDIZED_ROOT}/inventory/devices.csv

2. ${COLOR_YELLOW}Verify device credentials:${COLOR_RESET}
   sudo vim ${OXIDIZED_ROOT}/config/config

3. ${COLOR_YELLOW}Check service status:${COLOR_RESET}
   sudo systemctl status oxidized.service

4. ${COLOR_YELLOW}View container logs:${COLOR_RESET}
   podman logs -f oxidized

5. ${COLOR_YELLOW}Access Web UI:${COLOR_RESET}
   http://$(hostname -f 2>/dev/null || hostname):8888

6. ${COLOR_YELLOW}Check API:${COLOR_RESET}
   curl http://localhost:8888/nodes.json | jq '.'

7. ${COLOR_YELLOW}Run health check:${COLOR_RESET}
   sudo ${SCRIPT_DIR}/health-check.sh

${COLOR_BLUE}Useful Commands:${COLOR_RESET}
  systemctl status oxidized.service    # Check service status
  podman logs oxidized                 # View container logs
  podman restart oxidized              # Restart container

${COLOR_BLUE}Documentation:${COLOR_RESET}
  ${REPO_ROOT}/docs/INSTALL.md         # Installation guide
  ${REPO_ROOT}/docs/UPGRADE.md         # Upgrade procedures
  ${REPO_ROOT}/docs/monitoring/ZABBIX.md # Monitoring setup

${COLOR_GREEN}Happy backing up! 🎉${COLOR_RESET}

EOF
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
            -s|--skip-credentials)
                SKIP_CREDENTIALS=true
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
    echo "  Oxidized Deployment Script"
    echo "========================================"
    echo ""
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY-RUN MODE: No changes will be made"
    fi
    
    # Execute deployment steps
    check_root
    check_prerequisites
    create_directories
    deploy_config
    configure_credentials
    initialize_git
    install_quadlet
    install_logrotate
    pull_image
    start_service
    verify_deployment
    show_next_steps
    
    exit ${EXIT_SUCCESS}
}

# Run main function
main "$@"
