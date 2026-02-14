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
# shellcheck disable=SC2155  # Separate declaration is unnecessary for readonly
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${REPO_ROOT}/.env"
readonly ENV_EXAMPLE="${REPO_ROOT}/env.example"
readonly QUADLET_DIR="/etc/containers/systemd"
readonly LOGROTATE_DIR="/etc/logrotate.d"

# Colors for output
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_RESET=$'\033[0m'

# Flags
DRY_RUN=false
SKIP_CREDENTIALS=false
VERBOSE=false

# Load environment configuration
load_env() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    log_error ".env file not found: ${ENV_FILE}"
    log_error ""
    log_error "Please create your .env file from the template:"
    log_error "  cp ${ENV_EXAMPLE} ${ENV_FILE}"
    log_error "  vim ${ENV_FILE}  # Edit configuration values"
    log_error "  chmod 600 ${ENV_FILE}  # Restrict permissions"
    log_error ""
    log_error "See env.example for all available configuration options"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  # Check .env file permissions (should not be world-readable)
  local env_perms
  env_perms=$(stat -c "%a" "${ENV_FILE}" 2> /dev/null || stat -f "%A" "${ENV_FILE}" 2> /dev/null || echo "000")
  if [[ "${env_perms: -1}" -gt 0 ]]; then
    log_warn ".env file is world-readable (permissions: ${env_perms})"
    log_warn "Restricting permissions: chmod 600 ${ENV_FILE}"
    chmod 600 "${ENV_FILE}"
  fi

  # Source the .env file
  # shellcheck disable=SC1090
  source "${ENV_FILE}"

  log_info "Loaded configuration from ${ENV_FILE}"
}

# Validate required environment variables
validate_env() {
  local required_vars=(
    "OXIDIZED_USER"
    "OXIDIZED_GROUP"
    "OXIDIZED_UID"
    "OXIDIZED_GID"
    "OXIDIZED_ROOT"
    "OXIDIZED_IMAGE"
    "CONTAINER_NAME"
    "PODMAN_NETWORK"
    "NGINX_USERNAME"
    "NGINX_PASSWORD"
  )

  local missing_vars=()

  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      missing_vars+=("${var}")
    fi
  done

  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    log_error "Missing required environment variables in ${ENV_FILE}:"
    for var in "${missing_vars[@]}"; do
      log_error "  - ${var}"
    done
    log_error ""
    log_error "Please check your .env file against .env.example"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  # Validate UID/GID are numeric
  if ! [[ "${OXIDIZED_UID}" =~ ^[0-9]+$ ]]; then
    log_error "OXIDIZED_UID must be numeric: ${OXIDIZED_UID}"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  if ! [[ "${OXIDIZED_GID}" =~ ^[0-9]+$ ]]; then
    log_error "OXIDIZED_GID must be numeric: ${OXIDIZED_GID}"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  log_success "Environment variables validated"
}

# Cleanup function
# shellcheck disable=SC2317  # Function invoked via trap
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
  cat << EOF
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

  # Check disk space (parent directory of OXIDIZED_ROOT)
  local parent_dir
  parent_dir=$(dirname "${OXIDIZED_ROOT}")
  local available_space
  available_space=$(df -BG "${parent_dir}" 2> /dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")
  log_info "Available space in ${parent_dir}: ${available_space}GB"

  if [[ ${available_space} -lt 10 ]]; then
    log_warn "Less than 10GB available in ${parent_dir}"
    log_warn "You may run out of space for Git repository and logs"
  fi
}

# Create oxidized user and group
# Migrate existing oxidized user from old UID to new UID
migrate_user_uid() {
  local old_uid="$1"
  local new_uid="$2"
  local old_gid="$3"
  local new_gid="$4"

  log_step "Migrating oxidized user from UID ${old_uid} to ${new_uid}"

  # Stop oxidized service if running
  if systemctl is-active --quiet oxidized.service 2> /dev/null; then
    log_info "Stopping oxidized service for migration..."
    systemctl stop oxidized.service
    systemctl stop oxidized-logger.service 2> /dev/null || true
  fi

  # Modify user UID/GID
  log_info "Updating user ${OXIDIZED_USER}: UID ${old_uid} → ${new_uid}, GID ${old_gid} → ${new_gid}"
  usermod -u "${new_uid}" "${OXIDIZED_USER}" 2> /dev/null || true
  groupmod -g "${new_gid}" "${OXIDIZED_GROUP}" 2> /dev/null || true

  # Update home directory if needed
  local current_home
  current_home=$(getent passwd "${OXIDIZED_USER}" | cut -d: -f6)
  if [[ "${current_home}" != "${OXIDIZED_HOME}" ]]; then
    log_info "Changing home directory: ${current_home} → ${OXIDIZED_HOME}"
    usermod -d "${OXIDIZED_HOME}" "${OXIDIZED_USER}"

    # Move SSH keys if they exist in old home
    if [[ -d "${current_home}/.ssh" ]] && [[ "${current_home}" != "${OXIDIZED_HOME}" ]]; then
      log_info "Migrating SSH keys from ${current_home}/.ssh to ${OXIDIZED_HOME}/.ssh"
      mkdir -p "${OXIDIZED_HOME}/.ssh"
      cp -a "${current_home}/.ssh/"* "${OXIDIZED_HOME}/.ssh/" 2> /dev/null || true
      chown -R "${new_uid}:${new_gid}" "${OXIDIZED_HOME}/.ssh"
      chmod 700 "${OXIDIZED_HOME}/.ssh"
      chmod 600 "${OXIDIZED_HOME}/.ssh/id_"* 2> /dev/null || true
      chmod 644 "${OXIDIZED_HOME}/.ssh/id_"*.pub 2> /dev/null || true
      log_success "SSH keys migrated to ${OXIDIZED_HOME}/.ssh"
    fi
  fi

  # Update file ownership across the entire oxidized directory tree
  log_info "Updating file ownership for all oxidized files..."
  log_info "This may take a moment..."

  # Find and update all files owned by old UID
  if [[ -d "${OXIDIZED_ROOT}" ]]; then
    find "${OXIDIZED_ROOT}" -user "${old_uid}" -exec chown "${new_uid}:${new_gid}" {} + 2> /dev/null || true
    find "${OXIDIZED_ROOT}" -group "${old_gid}" -exec chown ":${new_gid}" {} + 2> /dev/null || true
  fi

  log_success "Migration complete: oxidized user now has UID ${new_uid} / GID ${new_gid}"
  log_success "All files updated to new ownership"
}

create_user() {
  log_step "Creating oxidized user and group"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would create user/group ${OXIDIZED_USER}:${OXIDIZED_GROUP} (${OXIDIZED_UID}:${OXIDIZED_GID})"
    return
  fi

  # Check if user exists and needs migration
  if id "${OXIDIZED_USER}" > /dev/null 2>&1; then
    local existing_uid
    local existing_gid
    local existing_home
    existing_uid=$(id -u "${OXIDIZED_USER}")
    existing_gid=$(id -g "${OXIDIZED_USER}")
    existing_home=$(getent passwd "${OXIDIZED_USER}" | cut -d: -f6)

    # Migration: Old UID was 2000, new UID is 30000
    if [[ "${existing_uid}" == "2000" ]] && [[ "${OXIDIZED_UID}" == "30000" ]]; then
      log_warn "Found oxidized user with old UID 2000"
      log_warn "Migrating to new UID 30000 to match container UID"
      migrate_user_uid "2000" "30000" "2000" "30000"
      return 0
    fi

    # Check if UID/GID match expected values
    if [[ "${existing_uid}" != "${OXIDIZED_UID}" ]]; then
      log_error "User ${OXIDIZED_USER} exists with UID ${existing_uid} (expected: ${OXIDIZED_UID})"
      log_error "Manual intervention required"
      exit ${EXIT_GENERAL_FAILURE}
    fi

    if [[ "${existing_gid}" != "${OXIDIZED_GID}" ]]; then
      log_error "User ${OXIDIZED_USER} has GID ${existing_gid} (expected: ${OXIDIZED_GID})"
      log_error "Manual intervention required"
      exit ${EXIT_GENERAL_FAILURE}
    fi

    log_info "User ${OXIDIZED_USER} already exists with correct UID ${OXIDIZED_UID}"

    # Check if home directory needs updating
    if [[ "${existing_home}" != "${OXIDIZED_HOME}" ]]; then
      log_warn "Home directory mismatch: ${existing_home} → ${OXIDIZED_HOME}"
      log_info "Updating home directory..."
      usermod -d "${OXIDIZED_HOME}" "${OXIDIZED_USER}"

      # Move SSH keys if they exist in old home
      if [[ -d "${existing_home}/.ssh" ]] && [[ "${existing_home}" != "${OXIDIZED_HOME}" ]]; then
        log_info "Migrating SSH keys from ${existing_home}/.ssh"
        mkdir -p "${OXIDIZED_HOME}/.ssh"
        cp -a "${existing_home}/.ssh/"* "${OXIDIZED_HOME}/.ssh/" 2> /dev/null || true
        chown -R "${OXIDIZED_UID}:${OXIDIZED_GID}" "${OXIDIZED_HOME}/.ssh"
        chmod 700 "${OXIDIZED_HOME}/.ssh"
        chmod 600 "${OXIDIZED_HOME}/.ssh/id_"* 2> /dev/null || true
        chmod 644 "${OXIDIZED_HOME}/.ssh/id_"*.pub 2> /dev/null || true
        log_success "SSH keys migrated to ${OXIDIZED_HOME}/.ssh"
      fi

      log_success "Home directory updated to ${OXIDIZED_HOME}"
    fi

    return 0
  fi

  # Create group if it doesn't exist
  if ! getent group "${OXIDIZED_GROUP}" > /dev/null 2>&1; then
    groupadd -g "${OXIDIZED_GID}" "${OXIDIZED_GROUP}"
    log_success "Created group: ${OXIDIZED_GROUP} (GID: ${OXIDIZED_GID})"
  else
    local existing_gid
    existing_gid=$(getent group "${OXIDIZED_GROUP}" | cut -d: -f3)
    if [[ "${existing_gid}" != "${OXIDIZED_GID}" ]]; then
      log_error "Group ${OXIDIZED_GROUP} exists with different GID: ${existing_gid} (expected: ${OXIDIZED_GID})"
      exit ${EXIT_GENERAL_FAILURE}
    fi
    log_info "Group ${OXIDIZED_GROUP} already exists with correct GID ${OXIDIZED_GID}"
  fi

  # Create user
  useradd -u "${OXIDIZED_UID}" -g "${OXIDIZED_GID}" \
    -d "${OXIDIZED_HOME}" -s /usr/sbin/nologin \
    -c "Oxidized Network Backup Service" "${OXIDIZED_USER}"
  log_success "Created user: ${OXIDIZED_USER} (UID: ${OXIDIZED_UID})"
}

# Create directory structure
create_directories() {
  log_step "Creating directory structure"

  local directories=(
    "${OXIDIZED_ROOT}"
    "${OXIDIZED_ROOT}/config"
    "${OXIDIZED_ROOT}/ssh"
    "${OXIDIZED_ROOT}/data"
    "${OXIDIZED_ROOT}/output"
    "${OXIDIZED_ROOT}/repo"
  )

  for dir in "${directories[@]}"; do
    if [[ -d "${dir}" ]]; then
      log_info "Directory exists: ${dir}"
    else
      if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would create: ${dir}"
      else
        mkdir -p "${dir}"
        log_success "Created: ${dir}"
      fi
    fi
  done

  if [[ "${DRY_RUN}" == "false" ]]; then
    # Set initial ownership to oxidized:oxidized for deployment scripts
    # NOTE: This will be changed to 30000:30000 by fix_ownership() after container starts
    chown -R "${OXIDIZED_UID}:${OXIDIZED_GID}" "${OXIDIZED_ROOT}"
    log_success "Set ownership: ${OXIDIZED_USER}:${OXIDIZED_GROUP} on ${OXIDIZED_ROOT}"

    # Set directory permissions (755 = rwxr-xr-x)
    find "${OXIDIZED_ROOT}" -type d -exec chmod 755 {} \;
    log_success "Set directory permissions: 755"

    # Create symlink from .ssh to ssh directory (for SSH client to find keys)
    # Host: /var/lib/oxidized/.ssh -> /var/lib/oxidized/ssh
    # Container mount: /var/lib/oxidized/ssh -> /home/oxidized/.ssh (inside container)
    if [[ ! -L "${OXIDIZED_ROOT}/.ssh" ]]; then
      if [[ -d "${OXIDIZED_ROOT}/.ssh" ]] && [[ ! -L "${OXIDIZED_ROOT}/.ssh" ]]; then
        # If .ssh exists as a directory, move contents to ssh/ first
        log_info "Moving existing .ssh directory contents to ssh/"
        cp -a "${OXIDIZED_ROOT}/.ssh/"* "${OXIDIZED_ROOT}/ssh/" 2> /dev/null || true
        rm -rf "${OXIDIZED_ROOT}/.ssh"
      fi
      ln -sf "${OXIDIZED_ROOT}/ssh" "${OXIDIZED_ROOT}/.ssh"
      log_success "Created symlink: ${OXIDIZED_ROOT}/.ssh -> ${OXIDIZED_ROOT}/ssh"
    fi

    # Set file permissions (644 = rw-r--r--)
    find "${OXIDIZED_ROOT}" -type f -exec chmod 644 {} \;
    log_success "Set file permissions: 644"

    # SSH directory needs stricter permissions
    if [[ -d "${OXIDIZED_ROOT}/ssh" ]]; then
      chmod 700 "${OXIDIZED_ROOT}/ssh"
      log_success "Set SSH directory permissions: 700"
    fi
  fi
}

# Create Podman network
create_network() {
  log_step "Creating Podman network"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would create network: ${PODMAN_NETWORK}"
    return
  fi

  # Check if network exists
  if podman network exists "${PODMAN_NETWORK}" 2> /dev/null; then
    log_info "Network already exists: ${PODMAN_NETWORK}"
  else
    podman network create "${PODMAN_NETWORK}"
    log_success "Created network: ${PODMAN_NETWORK}"
  fi
}

# Deploy configuration files
deploy_config() {
  log_step "Deploying configuration files"

  # Generate Oxidized config from template
  local config_template="${REPO_ROOT}/config/oxidized/config.template"
  local dst_config="${OXIDIZED_ROOT}/config/config"

  if [[ ! -f "${config_template}" ]]; then
    log_error "Config template not found: ${config_template}"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  if [[ -f "${dst_config}" ]]; then
    log_warn "Config already exists: ${dst_config}"
    if [[ "${DRY_RUN}" == "false" ]]; then
      # Create backup directory if it doesn't exist
      local backup_dir="${OXIDIZED_ROOT}/config/backup-config-file"
      mkdir -p "${backup_dir}"
      chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${backup_dir}"
      chmod 755 "${backup_dir}"

      local backup_file
      backup_file="${backup_dir}/config.backup.$(date +%Y%m%d_%H%M%S)"
      cp "${dst_config}" "${backup_file}"
      chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${backup_file}"
      log_warn "Backed up to: ${backup_file}"
    fi
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would generate config from template"
  else
    log_info "Generating Oxidized config from template..."

    # Substitute variables in template
    sed \
      -e "s|{{OXIDIZED_USERNAME}}|${OXIDIZED_USERNAME:-admin}|g" \
      -e "s|{{OXIDIZED_PASSWORD}}|${OXIDIZED_PASSWORD:-changeme}|g" \
      -e "s|{{POLL_INTERVAL}}|${POLL_INTERVAL:-3600}|g" \
      -e "s|{{DEBUG}}|${DEBUG:-false}|g" \
      -e "s|{{THREADS}}|${THREADS:-30}|g" \
      -e "s|{{TIMEOUT}}|${TIMEOUT:-20}|g" \
      -e "s|{{RETRIES}}|${RETRIES:-3}|g" \
      -e "s|{{INPUT_METHODS}}|${INPUT_METHODS:-ssh, telnet}|g" \
      -e "s|{{DEBUG}}|${DEBUG:-false}|g" \
      -e "s|{{OXIDIZED_API_HOST}}|${OXIDIZED_API_HOST:-0.0.0.0}|g" \
      -e "s|{{OXIDIZED_WEB_UI}}|${OXIDIZED_WEB_UI:-false}|g" \
      -e "s|{{GIT_USER_NAME}}|${GIT_USER_NAME:-Oxidized}|g" \
      -e "s|{{GIT_USER_EMAIL}}|${GIT_USER_EMAIL:-oxidized@example.com}|g" \
      "${config_template}" > "${dst_config}"

    chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${dst_config}"
    chmod 640 "${dst_config}"
    log_success "Generated and deployed: ${dst_config}"
  fi

  # Deploy inventory template (if not exists)
  local src_inventory="${REPO_ROOT}/inventory/router.db.template"
  local dst_inventory="${OXIDIZED_ROOT}/config/router.db"

  if [[ -f "${dst_inventory}" ]]; then
    # Backup existing router.db before any changes
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would backup: ${dst_inventory}"
    else
      # Create backup directory if it doesn't exist
      local backup_dir="${OXIDIZED_ROOT}/config/backup-routerdb"
      mkdir -p "${backup_dir}"
      chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${backup_dir}"
      chmod 755 "${backup_dir}"

      local backup_file
      backup_file="${backup_dir}/router.db.backup.$(date +%Y%m%d_%H%M%S)"
      cp "${dst_inventory}" "${backup_file}"
      chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${backup_file}"
      log_success "Backed up router.db: ${backup_file}"
    fi
    log_info "Router database exists: ${dst_inventory} (keeping existing)"
  else
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would copy: ${src_inventory} -> ${dst_inventory}"
    else
      if [[ -f "${src_inventory}" ]]; then
        cp "${src_inventory}" "${dst_inventory}"
        chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${dst_inventory}"
        chmod 600 "${dst_inventory}"
        log_success "Deployed inventory template: ${dst_inventory}"
        log_warn "IMPORTANT: Edit ${dst_inventory} with your network devices"
        log_warn "Format: name:ip:model:group:username:password (colon-delimited)"
      else
        log_warn "Inventory template not found: ${src_inventory}"
        log_info "Create ${dst_inventory} manually with format: name:ip:model:group:username:password"
      fi
    fi
  fi

  # Create SSH directory with proper permissions
  if [[ "${DRY_RUN}" == "false" ]]; then
    chmod 700 "${OXIDIZED_ROOT}/ssh"
    chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${OXIDIZED_ROOT}/ssh"

    # Create SSH known_hosts file if it doesn't exist
    local known_hosts="${OXIDIZED_ROOT}/ssh/${SSH_KNOWN_HOSTS:-known_hosts}"
    if [[ ! -f "${known_hosts}" ]]; then
      touch "${known_hosts}"
      chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${known_hosts}"
      chmod 644 "${known_hosts}"
      log_success "Created: ${known_hosts}"
    fi

    # Create .gitconfig for proper Git commits in container
    local gitconfig="${OXIDIZED_ROOT}/ssh/.gitconfig"
    if [[ ! -f "${gitconfig}" ]]; then
      cat > "${gitconfig}" << 'GITCONFIG'
[user]
	name = Oxidized
	email = oxidized@example.com
[safe]
	directory = /home/oxidized/.config/oxidized/repo
GITCONFIG
      chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${gitconfig}"
      chmod 644 "${gitconfig}"
      log_success "Created: ${gitconfig}"
    fi

    # Create minimal runtime .env file for management scripts
    log_info "Creating runtime configuration file..."
    create_runtime_env
  fi
}

# Create minimal runtime .env file
# This file contains only the essential variables needed by management scripts
# (oxidized-start.sh, oxidized-stop.sh, oxidized-restart.sh)
create_runtime_env() {
  local runtime_env="${OXIDIZED_ROOT}/.env"

  cat > "${runtime_env}" << EOF
###############################################################################
# Oxidized Runtime Configuration
# Auto-generated by deploy.sh - DO NOT EDIT MANUALLY
#
# This file contains minimal runtime configuration needed by management scripts.
# To change these values, edit the main .env file in the repository and re-run:
#   sudo ./scripts/deploy.sh
#
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
###############################################################################

# Root directory for all Oxidized data
OXIDIZED_ROOT="${OXIDIZED_ROOT}"

# Dedicated system user/group for Oxidized
OXIDIZED_USER="${OXIDIZED_USER}"
OXIDIZED_GROUP="${OXIDIZED_GROUP}"
OXIDIZED_UID=${OXIDIZED_UID}
OXIDIZED_GID=${OXIDIZED_GID}

# Container name (for management scripts)
CONTAINER_NAME="${CONTAINER_NAME}"

###############################################################################
# END OF RUNTIME CONFIGURATION
###############################################################################
EOF

  chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${runtime_env}"
  chmod 640 "${runtime_env}"
  log_success "Created runtime configuration: ${runtime_env}"
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

  log_warn "Default credentials from .env: username=${OXIDIZED_USERNAME:-admin}, password=${OXIDIZED_PASSWORD:-changeme}"

  # Check if stdin is a terminal (interactive)
  if [[ -t 0 ]]; then
    read -rp "Do you want to update device credentials now? (y/N): " -n 1 REPLY
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
  else
    log_info "Non-interactive deployment - using credentials from .env"
    log_warn "Edit ${config_file} to change credentials after deployment"
  fi
}

# Initialize Git repository
initialize_git() {
  log_step "Initializing Git repository"

  local git_repo="${OXIDIZED_ROOT}/repo"

  if [[ -d "${git_repo}/.git" ]]; then
    log_info "Git repository already initialized: ${git_repo}"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would initialize Git repo: ${git_repo}"
    return
  fi

  # Initialize as oxidized user
  sudo -u "${OXIDIZED_USER}" git init "${git_repo}"

  # Configure Git (use variables from .env)
  cd "${git_repo}"
  sudo -u "${OXIDIZED_USER}" git config user.name "${GIT_USER_NAME:-Oxidized}"
  sudo -u "${OXIDIZED_USER}" git config user.email "${GIT_USER_EMAIL:-oxidized@example.com}"

  # Create comprehensive README.md
  sudo -u "${OXIDIZED_USER}" tee README.md > /dev/null << 'EOF'
# 🔧 Network Device Configuration Backups

> Automated network device configuration backups managed by [Oxidized](https://github.com/ytti/oxidized)

[![Automated Backups](https://img.shields.io/badge/backups-automated-success)](https://github.com/ytti/oxidized)
[![Git Versioned](https://img.shields.io/badge/versioning-git-blue)](https://git-scm.com/)

## 📋 Overview

This repository contains automated backups of network device configurations collected by Oxidized. Each device's configuration is stored as a separate file and tracked with full version history, allowing you to:

- 📊 Track configuration changes over time
- 🔍 Compare configurations between different points in time
- 📝 Review who made changes and when
- ⏮️ Restore previous configurations if needed
- 🔎 Search for specific configuration parameters across devices

## 🚀 Deployment Code

This Oxidized instance was deployed using the containerized deployment system available at:

**📦 [deploy-containerized-oxidized](https://github.com/christopherpaquin/deploy-containerized-oxidized)**

The deployment repository contains:
- 🐳 Podman/container configuration for Oxidized
- ⚙️ Automated deployment scripts (`deploy.sh`)
- 🔧 Configuration templates and management tools
- 📝 Complete documentation for setup and maintenance
- 🛠️ Device management utilities (`add-device.sh`, `test-device.sh`)
- 🔄 Remote repository setup automation (`setup-remote-repo.sh`)

### Quick Links

| Resource | Description |
|----------|-------------|
| [Main README](https://github.com/christopherpaquin/deploy-containerized-oxidized#readme) | Complete deployment documentation |
| [Quick Start Guide](https://github.com/christopherpaquin/deploy-containerized-oxidized/blob/main/docs/QUICK-START.md) | Get started in minutes |
| [Management Scripts](https://github.com/christopherpaquin/deploy-containerized-oxidized/tree/main/scripts) | All automation scripts |
| [Documentation](https://github.com/christopherpaquin/deploy-containerized-oxidized/tree/main/docs) | Full docs directory |

If you need to modify the Oxidized configuration, add devices, or troubleshoot the deployment, refer to the deployment repository above.

## 📁 Repository Structure

```
.
├── README.md                    # This file
├── device1.example.com          # Device configuration file
├── device2.example.com          # Device configuration file
└── router.lab                   # Device configuration file
```

Each file contains the complete running configuration for a network device. Files are named using the device's hostname or FQDN as defined in Oxidized's `router.db`.

## 🌐 Viewing Configurations via GitHub Web UI

### View Current Configuration

1. **Browse to this repository** on GitHub
2. **Click on any device file** (e.g., `router.lab`)
3. The current configuration will be displayed with syntax highlighting

### View Configuration History

1. **Click on a device file** to open it
2. **Click "History"** button (top right, next to "Blame")
3. View all configuration changes with timestamps and commit messages
4. **Click any commit** to see exactly what changed

### Compare Configurations

#### Compare Different Time Points (Same Device)

1. **Open the device file** → Click **"History"**
2. **Find two commits** you want to compare
3. Click the **commit hash** (e.g., `abc1234`) of the older commit
4. Click **"Browse files"** button → Navigate back to the device file
5. In the URL bar, you'll see `github.com/user/repo/blob/COMMIT_HASH/device`
6. **Open a new tab** and navigate to the newer commit or current version
7. Use GitHub's **compare feature**: `github.com/user/repo/compare/OLD_COMMIT...NEW_COMMIT`

#### Quick Compare (Last Change)

1. **Click on device file** → **"History"**
2. **Click the latest commit** to see most recent changes
3. Red lines = removed configuration
4. Green lines = added configuration

#### Compare Two Devices (Current Configs)

GitHub doesn't have a built-in side-by-side file comparison, but you can:
1. **Open device 1** in one browser tab
2. **Open device 2** in another browser tab
3. Manually compare, or use browser extensions like "Tab Compare"

## 💻 Working with Git Command Line

### Prerequisites

```bash
# Clone this repository (if not already done)
git clone git@github.com:username/repo.git
cd repo
```

### View Configuration Files

```bash
# List all device configurations
ls -1

# View a device's current configuration
cat device.example.com

# View with syntax highlighting (if 'bat' is installed)
bat device.example.com

# View with pagination
less device.example.com
```

### View Configuration History

```bash
# View all changes to a specific device
git log --oneline device.example.com

# View detailed history with diffs
git log -p device.example.com

# View history with statistics
git log --stat device.example.com

# View commits from last 7 days
git log --since="7 days ago" device.example.com

# View commits by date range
git log --since="2024-01-01" --until="2024-01-31" device.example.com

# Show the last 10 commits
git log -10 --oneline device.example.com
```

### Compare Configurations

#### Compare Current vs Previous Commit

```bash
# Show what changed in the last commit
git diff HEAD~1 device.example.com

# Show last change with context
git show HEAD:device.example.com
```

#### Compare Specific Commits

```bash
# Compare two specific commits
git diff COMMIT1 COMMIT2 device.example.com

# Example with actual hashes
git diff abc1234 def5678 device.example.com

# Compare with specific date
git diff "main@{2024-01-01}" main device.example.com
```

#### Compare Current vs Specific Time

```bash
# Compare current config vs 7 days ago
git diff "HEAD@{7 days ago}" HEAD device.example.com

# Compare current config vs specific date
git diff "main@{2024-01-15}" main device.example.com

# Compare current config vs specific commit
git diff abc1234 HEAD device.example.com
```

#### Side-by-Side Comparison

```bash
# Side-by-side diff (requires 'diff-so-fancy' or similar)
git diff --color-words HEAD~1 device.example.com

# Using git difftool (if configured)
git difftool HEAD~1 device.example.com

# Word-level diff
git diff --word-diff HEAD~1 device.example.com
```

#### Compare Two Different Devices

```bash
# Compare configurations of two different devices
diff device1.example.com device2.example.com

# Side-by-side comparison
diff -y device1.example.com device2.example.com

# Unified diff format
diff -u device1.example.com device2.example.com

# Using git to compare (treats as different files)
git diff --no-index device1.example.com device2.example.com
```

### Search Configurations

```bash
# Search for a specific term across all devices
grep -r "ntp server" .

# Search with line numbers
grep -rn "snmp-server community" .

# Search case-insensitive
grep -ri "enable secret" .

# Search for IP addresses
grep -rE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" .

# Search with context (3 lines before and after)
grep -rn -C 3 "interface GigabitEthernet" .
```

### View Specific Past Configuration

```bash
# View a device's config from a specific commit
git show COMMIT_HASH:device.example.com

# View a device's config from 30 days ago
git show "HEAD@{30 days ago}":device.example.com

# View a device's config from specific date
git show "main@{2024-01-15}":device.example.com

# Save historical config to a file
git show abc1234:device.example.com > device-backup-2024-01-15.txt
```

### Advanced Git Log Options

```bash
# View compact log with graph
git log --oneline --graph --all

# View log with file change statistics
git log --stat device.example.com

# View log with actual changes (full diff)
git log -p device.example.com

# View only merge commits
git log --merges

# View only commits that modified specific text
git log -S "ntp server" device.example.com

# View log with custom format
git log --pretty=format:"%h - %an, %ar : %s" device.example.com

# View who changed what (blame)
git blame device.example.com
```

## 🔍 Common Use Cases

### "What changed on this device yesterday?"

```bash
# Via Git
git log --since="yesterday" --until="today" -p device.example.com

# Via GitHub UI
1. Open device file → History
2. Filter commits by date
```

### "What was the configuration on January 15th?"

```bash
# Via Git
git show "main@{2024-01-15}":device.example.com

# Via GitHub UI
1. Open device file → History
2. Find commit closest to Jan 15th
3. Click commit to view
```

### "Compare this device's config from last week to now"

```bash
# Via Git
git diff "HEAD@{1 week ago}" HEAD device.example.com

# Via GitHub UI
1. Open device file → History
2. Note commit hash from last week (e.g., abc1234)
3. Use compare: github.com/user/repo/compare/abc1234...main
```

### "Find all devices with NTP server configured"

```bash
# Via Git
grep -r "ntp server" .

# Via GitHub UI
Use GitHub's search feature: Press 't' to search files, or use the search bar
```

### "Restore device to configuration from 2 weeks ago"

```bash
# View the old configuration
git show "HEAD@{2 weeks ago}":device.example.com > restore-config.txt

# Review the file
cat restore-config.txt

# Manually apply to device (copy/paste or use TFTP/SCP)
```

## 📊 Configuration Change Tracking

All configuration changes are automatically tracked:

- **Who**: Git commits show which user account made changes (usually "oxidized")
- **When**: Timestamps show exactly when the backup was taken
- **What**: Full diffs show exactly what configuration lines changed

## 🔐 Security Notes

- ⚠️ **Keep this repository PRIVATE** - configurations may contain sensitive information
- 🔑 Configurations may include passwords, SNMP communities, and other secrets
- 🚫 Never make this repository public
- 👥 Only grant access to authorized network administrators

## 🤖 Automation

- 🕐 Backups run automatically every hour (configurable in Oxidized)
- 📤 Changes are automatically committed to this repository
- 🔄 Git push occurs every 5 minutes (if auto-push is enabled)
- 📧 (Optional) Configure notifications for configuration changes

## 📚 Additional Resources

- [Oxidized Documentation](https://github.com/ytti/oxidized)
- [Git Documentation](https://git-scm.com/doc)
- [GitHub Docs: Comparing Commits](https://docs.github.com/en/pull-requests/committing-changes-to-your-project/viewing-and-comparing-commits/comparing-commits)
- [Git Diff Cheat Sheet](https://git-scm.com/docs/git-diff)
- [Deploy Containerized Oxidized](https://github.com/christopherpaquin/deploy-containerized-oxidized) - Deployment code for this instance

## 💡 Tips

- Use `git log --all --full-history --grep="pattern"` to search commit messages
- Use `git log -S "search string"` to find when specific configuration was added/removed
- Create git aliases for commonly used commands
- Consider using a git GUI tool like GitKraken or SourceTree for visual comparisons

---

**Generated by Oxidized** | Last updated: $(date '+%Y-%m-%d %H:%M:%S %Z')
EOF

  sudo -u "${OXIDIZED_USER}" git add README.md
  sudo -u "${OXIDIZED_USER}" git commit -m "Initial commit"

  # Set proper permissions
  chown -R "${OXIDIZED_UID}:${OXIDIZED_GID}" "${git_repo}"
  find "${git_repo}" -type d -exec chmod 750 {} \;
  find "${git_repo}" -type f -exec chmod 640 {} \;

  log_success "Initialized Git repository: ${git_repo}"
  cd - > /dev/null
}

# Install Quadlet
install_quadlet() {
  log_step "Installing Quadlet configuration"

  local template_file="${REPO_ROOT}/containers/quadlet/oxidized.container.template"
  local dst_quadlet="${QUADLET_DIR}/oxidized.container"

  if [[ ! -f "${template_file}" ]]; then
    log_error "Quadlet template not found: ${template_file}"
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
      local backup_file
      backup_file="${dst_quadlet}.backup.$(date +%Y%m%d_%H%M%S)"
      cp "${dst_quadlet}" "${backup_file}"
      # Quadlet is in /etc, keep as root:root
    fi
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would generate Quadlet from template"
    return
  fi

  # Generate Quadlet from template with environment variable substitution
  log_info "Generating Quadlet from template..."

  # Determine port publishing based on configuration
  # When nginx authentication is configured, bind to localhost only
  local port_publish=""
  if [[ "${OXIDIZED_WEB_UI:-false}" == "true" ]] || [[ -n "${OXIDIZED_API_PORT:-}" ]]; then
    if [[ -n "${NGINX_USERNAME:-}" ]] && [[ -n "${NGINX_PASSWORD:-}" ]]; then
      # nginx authentication enabled - bind to localhost:8889
      port_publish="PublishPort=127.0.0.1:8889:8888"
      log_info "Port binding: 127.0.0.1:8889 (nginx reverse proxy will handle external access)"
    else
      # No nginx - expose directly
      port_publish="PublishPort=${OXIDIZED_API_HOST:-0.0.0.0}:${OXIDIZED_API_PORT:-8888}:8888"
    fi
  else
    port_publish="# PublishPort disabled (API/Web UI not exposed)"
  fi

  # Substitute variables in template
  sed \
    -e "s|{{OXIDIZED_IMAGE}}|${OXIDIZED_IMAGE}|g" \
    -e "s|{{CONTAINER_NAME}}|${CONTAINER_NAME}|g" \
    -e "s|{{PODMAN_NETWORK}}|${PODMAN_NETWORK}|g" \
    -e "s|{{OXIDIZED_UID}}|${OXIDIZED_UID}|g" \
    -e "s|{{OXIDIZED_GID}}|${OXIDIZED_GID}|g" \
    -e "s|{{OXIDIZED_ROOT}}|${OXIDIZED_ROOT}|g" \
    -e "s|{{MOUNT_CONFIG}}|${MOUNT_CONFIG:-/home/oxidized/.config/oxidized}|g" \
    -e "s|{{MOUNT_SSH}}|${MOUNT_SSH:-/home/oxidized/.ssh}|g" \
    -e "s|{{MOUNT_DATA}}|${MOUNT_DATA:-/home/oxidized/.config/oxidized/data}|g" \
    -e "s|{{MOUNT_OUTPUT}}|${MOUNT_OUTPUT:-/home/oxidized/.config/oxidized/output}|g" \
    -e "s|{{MOUNT_REPO}}|${MOUNT_REPO:-/home/oxidized/.config/oxidized/repo}|g" \
    -e "s|{{SELINUX_MOUNT_OPTION}}|${SELINUX_MOUNT_OPTION:-:Z}|g" \
    -e "s|{{TZ}}|${TZ:-UTC}|g" \
    -e "s|{{PORT_PUBLISH}}|${port_publish}|g" \
    -e "s|{{MEMORY_LIMIT}}|${MEMORY_LIMIT:-1G}|g" \
    -e "s|{{CPU_QUOTA}}|${CPU_QUOTA:-100%}|g" \
    "${template_file}" > "${dst_quadlet}"

  chmod 644 "${dst_quadlet}"
  log_success "Generated and installed: ${dst_quadlet}"
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

# Install log tailer service
install_log_tailer() {
  log_step "Installing Oxidized log tailer"

  local src_script="${REPO_ROOT}/containers/quadlet/oxidized-log-tailer.sh"
  local dst_script="/usr/local/bin/oxidized-log-tailer.sh"
  local src_service="${REPO_ROOT}/containers/quadlet/oxidized-logger.service"
  local dst_service="/etc/systemd/system/oxidized-logger.service"

  if [[ ! -f "${src_script}" ]]; then
    log_error "Log tailer script not found: ${src_script}"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  if [[ ! -f "${src_service}" ]]; then
    log_error "Log tailer service not found: ${src_service}"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would install log tailer script and service"
    return
  fi

  # Install script
  cp "${src_script}" "${dst_script}"
  chmod 755 "${dst_script}"
  log_success "Installed: ${dst_script}"

  # Install service
  cp "${src_service}" "${dst_service}"
  chmod 644 "${dst_service}"
  log_success "Installed: ${dst_service}"

  # Reload systemd and enable service
  systemctl daemon-reload
  log_success "Reloaded systemd daemon"

  if systemctl enable oxidized-logger.service 2> /dev/null; then
    log_success "Enabled oxidized-logger.service"
  fi
}

# Install MOTD (Message of the Day)
install_motd() {
  log_step "Installing MOTD"

  local src_motd="${REPO_ROOT}/config/motd/99-oxidized"
  local dst_motd="/etc/profile.d/99-oxidized.sh"

  if [[ ! -f "${src_motd}" ]]; then
    log_warn "Source MOTD not found: ${src_motd}"
    return 0
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would copy: ${src_motd} -> ${dst_motd}"
  else
    cp "${src_motd}" "${dst_motd}"
    chmod 755 "${dst_motd}"
    log_success "Installed: ${dst_motd}"
    log_info "MOTD will display on next login"
  fi
}

# Install documentation to Oxidized root
install_documentation() {
  log_step "Installing documentation"

  local docs_dir="${OXIDIZED_ROOT}/docs"

  # Create docs directory if it doesn't exist
  if [[ ! -d "${docs_dir}" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would create: ${docs_dir}"
    else
      mkdir -p "${docs_dir}"
      chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${docs_dir}"
      chmod 755 "${docs_dir}"
      log_success "Created: ${docs_dir}"
    fi
  fi

  # List of documentation files to copy (user guides and references)
  local doc_files=(
    "QUICK-START.md"
    "DEVICE-MANAGEMENT.md"
    "CREDENTIALS-GUIDE.md"
    "DIRECTORY-STRUCTURE.md"
    "docs/GIT-REPOSITORY-STRUCTURE.md"
    "docs/TELNET-CONFIGURATION.md"
  )

  for doc in "${doc_files[@]}"; do
    local src_doc="${REPO_ROOT}/${doc}"
    local filename
    filename=$(basename "${doc}")
    local dst_doc="${docs_dir}/${filename}"

    if [[ ! -f "${src_doc}" ]]; then
      log_warn "Source documentation not found: ${src_doc}"
      continue
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would copy: ${src_doc} -> ${dst_doc}"
    else
      cp "${src_doc}" "${dst_doc}"
      chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${dst_doc}"
      chmod 644 "${dst_doc}"
      log_success "Installed: ${dst_doc}"
    fi
  done

  if [[ "${DRY_RUN}" == "false" ]]; then
    log_info "Documentation available at: ${docs_dir}"
  fi
}

# Install helper scripts to Oxidized root
install_helper_scripts() {
  log_step "Installing helper scripts"

  local scripts_dir="${OXIDIZED_ROOT}/scripts"

  # Create scripts directory if it doesn't exist
  if [[ ! -d "${scripts_dir}" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would create: ${scripts_dir}"
    else
      mkdir -p "${scripts_dir}"
      chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${scripts_dir}"
      chmod 755 "${scripts_dir}"
      log_success "Created: ${scripts_dir}"
    fi
  fi

  # Copy helper scripts
  local helper_scripts=(
    "health-check.sh"
    "validate-router-db.sh"
    "test-device.sh"
    "add-device.sh"
    "oxidized-start.sh"
    "oxidized-stop.sh"
    "oxidized-restart.sh"
    "force-backup.sh"
    "setup-remote-repo.sh"
  )

  for script in "${helper_scripts[@]}"; do
    local src_script="${SCRIPT_DIR}/${script}"
    local dst_script="${scripts_dir}/${script}"

    if [[ ! -f "${src_script}" ]]; then
      log_warn "Source script not found: ${src_script}"
      continue
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[DRY-RUN] Would copy: ${src_script} -> ${dst_script}"
    else
      cp "${src_script}" "${dst_script}"
      chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${dst_script}"
      chmod 755 "${dst_script}"
      log_success "Installed: ${dst_script}"
    fi
  done

  log_info "Helper scripts available at: ${scripts_dir}/"
}

# Pull container image
pull_image() {
  log_step "Pulling container image"

  log_info "Image: ${OXIDIZED_IMAGE}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would pull: ${OXIDIZED_IMAGE}"
    return
  fi

  if podman pull "${OXIDIZED_IMAGE}"; then
    log_success "Pulled image: ${OXIDIZED_IMAGE}"
  else
    log_error "Failed to pull image: ${OXIDIZED_IMAGE}"
    log_error "Check network connectivity and image name in .env"
    exit ${EXIT_GENERAL_FAILURE}
  fi
}

# Configure firewall
configure_firewall() {
  log_step "Configuring Firewall"

  # Check if firewalld is installed and running
  if ! command -v firewall-cmd &> /dev/null; then
    log_info "firewalld not installed, skipping firewall configuration"
    return
  fi

  if ! systemctl is-active --quiet firewalld 2> /dev/null; then
    log_info "firewalld not running, skipping firewall configuration"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would add firewall rule for port ${OXIDIZED_API_PORT}/tcp"
    return
  fi

  # Check if port is already allowed
  if firewall-cmd --list-ports 2> /dev/null | grep -q "${OXIDIZED_API_PORT}/tcp"; then
    log_info "Port ${OXIDIZED_API_PORT}/tcp already allowed in firewall"
    return
  fi

  # Add port to firewall
  log_info "Adding port ${OXIDIZED_API_PORT}/tcp to firewall..."
  if firewall-cmd --permanent --add-port="${OXIDIZED_API_PORT}/tcp" &> /dev/null; then
    if firewall-cmd --reload &> /dev/null; then
      log_success "Added port ${OXIDIZED_API_PORT}/tcp to firewall (permanent)"
    else
      log_warn "Failed to reload firewall (non-fatal)"
    fi
  else
    log_warn "Failed to add port to firewall (non-fatal, may need manual configuration)"
  fi
}

# Install nginx
install_nginx() {
  log_step "Installing nginx"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would install nginx and httpd-tools"
    return
  fi

  # Check if nginx is already installed
  if command -v nginx &> /dev/null; then
    log_info "nginx already installed: $(nginx -v 2>&1)"
    return
  fi

  log_info "Installing nginx, httpd-tools, sshpass, and expect..."
  if dnf install -y nginx httpd-tools sshpass expect &> /dev/null; then
    log_success "Installed nginx $(nginx -v 2>&1 | cut -d/ -f2)"
    log_success "Installed sshpass (required for SSH password authentication testing)"
    log_success "Installed expect (required for telnet authentication testing)"
  else
    log_error "Failed to install required packages"
    exit ${EXIT_GENERAL_FAILURE}
  fi
}

# Configure nginx authentication
configure_nginx_auth() {
  log_step "Configuring nginx authentication"

  local nginx_dir="${NGINX_DATA_DIR:-${OXIDIZED_ROOT}/nginx}"
  local htpasswd_file="${nginx_dir}/.htpasswd"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would create htpasswd file at ${htpasswd_file}"
    log_info "[DRY-RUN] Username: ${NGINX_USERNAME}"
    return
  fi

  # Ensure parent directory is accessible by nginx
  if [[ -d "${OXIDIZED_ROOT}" ]]; then
    chmod 755 "${OXIDIZED_ROOT}"
    log_info "Set permissions on ${OXIDIZED_ROOT} for nginx access"
  fi

  # Create nginx directory if it doesn't exist
  if [[ ! -d "${nginx_dir}" ]]; then
    mkdir -p "${nginx_dir}"
    chmod 755 "${nginx_dir}"
    log_info "Created directory: ${nginx_dir}"
  else
    chmod 755 "${nginx_dir}"
    log_info "Updated permissions on ${nginx_dir}"
  fi

  # Set SELinux context for nginx to read files in this directory
  if command -v semanage &> /dev/null; then
    # Check if context already configured (suppress broken pipe errors)
    if ! semanage fcontext -l 2> /dev/null | grep -q "${nginx_dir}" 2> /dev/null; then
      semanage fcontext -a -t httpd_sys_content_t "${nginx_dir}(/.*)?" 2> /dev/null || true
    fi
    restorecon -R "${nginx_dir}" 2> /dev/null || true
    log_info "Set SELinux context for nginx access"
  fi

  # Create/update htpasswd file from .env credentials
  # Always regenerate to ensure .env is the source of truth
  if [[ -f "${htpasswd_file}" ]]; then
    log_info "Updating htpasswd file with credentials from .env"
  else
    log_info "Creating htpasswd file for user: ${NGINX_USERNAME}"
  fi

  # Generate htpasswd file (overwrite if exists)
  if echo "${NGINX_PASSWORD}" | htpasswd -i -c "${htpasswd_file}" "${NGINX_USERNAME}" 2> /dev/null; then
    chmod 640 "${htpasswd_file}"
    chown root:nginx "${htpasswd_file}"
    chcon -t httpd_sys_content_t "${htpasswd_file}" 2> /dev/null || true
    log_success "Configured htpasswd file: ${htpasswd_file}"
    log_info "Web UI login: ${NGINX_USERNAME} / ********"
  else
    log_error "Failed to create htpasswd file"
    exit ${EXIT_GENERAL_FAILURE}
  fi
}

# Deploy nginx configuration
deploy_nginx_config() {
  log_step "Deploying nginx configuration"

  local config_template="${REPO_ROOT}/config/nginx/oxidized.conf.template"
  local dst_config="/etc/nginx/conf.d/oxidized.conf"

  if [[ ! -f "${config_template}" ]]; then
    log_error "nginx config template not found: ${config_template}"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would deploy nginx config from template"
    return
  fi

  # Check if config already exists
  if [[ -f "${dst_config}" ]]; then
    log_warn "nginx config already exists: ${dst_config}"
    log_warn "Backing up to ${dst_config}.backup"
    cp "${dst_config}" "${dst_config}.backup"
    # nginx config is in /etc, keep as root:root
  fi

  # Generate config from template
  log_info "Generating nginx config from template..."
  sed -e "s|{{OXIDIZED_API_PORT}}|${OXIDIZED_API_PORT}|g" \
    -e "s|{{OXIDIZED_API_HOST}}|${OXIDIZED_API_HOST}|g" \
    -e "s|{{NGINX_DATA_DIR}}|${NGINX_DATA_DIR:-${OXIDIZED_ROOT}/nginx}|g" \
    "${config_template}" > "${dst_config}"

  # Fix nginx main config to avoid port 80 conflict
  if [[ ! -f /etc/nginx/nginx.conf.original ]]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.original
    log_info "Backed up original nginx.conf"
  fi

  # Create minimal nginx.conf without default server
  cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    include /etc/nginx/conf.d/*.conf;
}
NGINX_EOF

  # Test nginx configuration
  if nginx -t &> /dev/null; then
    log_success "nginx configuration is valid"
  else
    log_error "nginx configuration test failed"
    nginx -t
    exit ${EXIT_GENERAL_FAILURE}
  fi

  log_success "Deployed nginx configuration: ${dst_config}"
}

# Configure SELinux for nginx
configure_nginx_selinux() {
  log_step "Configuring SELinux for nginx"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would configure SELinux for nginx"
    return
  fi

  # Allow nginx to bind to port 8888
  log_info "Allowing nginx to bind to port ${OXIDIZED_API_PORT}..."

  # Check if port is already defined (suppress broken pipe errors)
  if semanage port -l 2> /dev/null | grep -qE "^http_port_t.*\b${OXIDIZED_API_PORT}\b" 2> /dev/null; then
    log_info "Port ${OXIDIZED_API_PORT} already configured as http_port_t"
  else
    # Try to add the port
    local add_output
    add_output=$(semanage port -a -t http_port_t -p tcp "${OXIDIZED_API_PORT}" 2>&1)
    local add_result=$?

    if [[ ${add_result} -eq 0 ]]; then
      log_success "Added port ${OXIDIZED_API_PORT} as http_port_t"
    elif echo "${add_output}" | grep -q "already defined"; then
      # Port exists but as different type, try to modify
      if semanage port -m -t http_port_t -p tcp "${OXIDIZED_API_PORT}" &> /dev/null; then
        log_success "Modified port ${OXIDIZED_API_PORT} to http_port_t"
      else
        log_warn "Port ${OXIDIZED_API_PORT} is defined with different type"
        log_warn "SELinux output: ${add_output}"
      fi
    else
      log_warn "Failed to configure SELinux port (non-fatal)"
      log_warn "SELinux output: ${add_output}"
    fi
  fi

  # Allow nginx to connect to network
  log_info "Allowing nginx to connect to backend..."
  if setsebool -P httpd_can_network_connect 1 &> /dev/null; then
    log_success "Configured SELinux: httpd_can_network_connect=1"
  else
    log_warn "Failed to set SELinux boolean (non-fatal)"
  fi
}

# Start nginx service
start_nginx() {
  log_step "Starting nginx"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would enable and start nginx"
    return
  fi

  # Enable nginx
  if systemctl enable nginx &> /dev/null; then
    log_success "Enabled nginx service"
  else
    log_warn "Failed to enable nginx (may already be enabled)"
  fi

  # Start nginx
  if systemctl is-active --quiet nginx; then
    log_info "nginx already running, restarting..."
    if systemctl restart nginx &> /dev/null; then
      log_success "Restarted nginx"
    else
      log_error "Failed to restart nginx"
      systemctl status nginx
      exit ${EXIT_GENERAL_FAILURE}
    fi
  else
    if systemctl start nginx &> /dev/null; then
      log_success "Started nginx"
    else
      log_error "Failed to start nginx"
      systemctl status nginx
      exit ${EXIT_GENERAL_FAILURE}
    fi
  fi

  # Verify nginx is running
  if systemctl is-active --quiet nginx; then
    log_success "nginx is active"
  else
    log_error "nginx failed to start"
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

  # Wait for Quadlet to generate the service file (up to 10 seconds)
  log_info "Waiting for Quadlet to generate service file..."
  local max_wait=10
  local count=0
  while [[ ${count} -lt ${max_wait} ]]; do
    if systemctl list-unit-files oxidized.service &> /dev/null; then
      log_success "Service file generated"
      break
    fi
    sleep 1
    ((count++))
  done

  if [[ ${count} -ge ${max_wait} ]]; then
    log_error "Timeout waiting for Quadlet to generate service file"
    log_error "Check Quadlet file: ${QUADLET_DIR}/oxidized.container"
    log_error "Check systemd logs: journalctl -xe"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  # Enable service (Quadlet services are auto-enabled via [Install] section)
  if systemctl enable oxidized.service 2> /dev/null; then
    log_success "Enabled oxidized.service"
  else
    log_info "Service auto-enabled via Quadlet [Install] section"
  fi

  # Start service
  if systemctl start oxidized.service; then
    log_success "Started oxidized.service"

    # Start log tailer service
    if systemctl start oxidized-logger.service 2> /dev/null; then
      log_success "Started oxidized-logger.service"
    else
      log_warn "Failed to start oxidized-logger.service (non-fatal)"
    fi
  else
    log_error "Failed to start oxidized.service"
    log_error "Check status with: systemctl status oxidized.service"
    log_error "Check logs with: journalctl -u oxidized.service -n 50"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  # Wait a moment for service to initialize
  sleep 3
}

# Fix ownership and SELinux labels after container creates files
fix_ownership() {
  log_step "Fixing file ownership and SELinux labels"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would fix ownership and SELinux labels on ${OXIDIZED_ROOT}"
    return
  fi

  # The container uses internal UID 30000 for the oxidized user
  # Files need to be owned by UID 30000 on the host for container access
  # NOTE: This is a known behavior with baseimage-docker containers
  log_info "Setting ownership to UID 30000 for container access..."

  # Container-accessed directories must be owned by UID 30000
  chown -R 30000:30000 "${OXIDIZED_ROOT}/config"
  chown -R 30000:30000 "${OXIDIZED_ROOT}/data"
  chown -R 30000:30000 "${OXIDIZED_ROOT}/output"
  chown -R 30000:30000 "${OXIDIZED_ROOT}/repo"
  chown -R 30000:30000 "${OXIDIZED_ROOT}/ssh"

  # Host-accessed directories can use the host's oxidized user
  chown -R "${OXIDIZED_UID}:${OXIDIZED_GID}" "${OXIDIZED_ROOT}/docs" 2> /dev/null || true
  chown -R "${OXIDIZED_UID}:${OXIDIZED_GID}" "${OXIDIZED_ROOT}/scripts" 2> /dev/null || true

  # Fix nginx directory (should be root:root)
  if [[ -d "${OXIDIZED_ROOT}/nginx" ]]; then
    chown -R root:root "${OXIDIZED_ROOT}/nginx"
    # But .htpasswd needs special ownership for nginx to read
    if [[ -f "${OXIDIZED_ROOT}/nginx/.htpasswd" ]]; then
      chown root:nginx "${OXIDIZED_ROOT}/nginx/.htpasswd"
      chmod 640 "${OXIDIZED_ROOT}/nginx/.htpasswd"
    fi
  fi

  # Remove SELinux MCS categories that prevent container access
  # MCS categories like c129,c639 isolate files and block the container
  log_info "Removing SELinux MCS categories..."
  if command -v chcon &> /dev/null && [[ "$(getenforce 2> /dev/null)" == "Enforcing" ]]; then
    chcon -R -l s0 "${OXIDIZED_ROOT}/config" 2> /dev/null || true
    chcon -R -l s0 "${OXIDIZED_ROOT}/data" 2> /dev/null || true
    chcon -R -l s0 "${OXIDIZED_ROOT}/output" 2> /dev/null || true
    chcon -R -l s0 "${OXIDIZED_ROOT}/repo" 2> /dev/null || true
    chcon -R -l s0 "${OXIDIZED_ROOT}/ssh" 2> /dev/null || true
    log_success "SELinux labels reset to s0 (no MCS categories)"
  fi

  log_success "File ownership and SELinux labels corrected"
}

# Validate source file (router.db)
validate_source_file() {
  log_step "Validating device inventory (router.db)"

  local router_db="${OXIDIZED_ROOT}/config/router.db"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would validate: ${router_db}"
    return
  fi

  # Check if router.db exists
  if [[ ! -f "${router_db}" ]]; then
    log_error "Device inventory file not found: ${router_db}"
    log_error "This file is required for Oxidized to know which devices to backup"
    log_info "Create it with format: name:ip:model:group:username:password"
    log_info "Example: switch01:10.1.1.1:ios:datacenter:admin:password"
    log_info "Leave username:password blank to use global credentials from .env"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  # Check if file is readable
  if [[ ! -r "${router_db}" ]]; then
    log_error "Cannot read ${router_db} - check permissions"
    exit ${EXIT_GENERAL_FAILURE}
  fi

  # Count non-comment, non-empty lines
  local device_count
  device_count=$(grep -cv -e '^#' -e '^[[:space:]]*$' "${router_db}")

  if [[ ${device_count} -eq 0 ]]; then
    log_warn "No devices configured in ${router_db}"
    log_warn "Oxidized will start but won't back up any devices"
    log_info "Add devices with format: name:ip:model:group:username:password"
  else
    log_success "Found ${device_count} device(s) in inventory"
  fi

  # Run validation script if available
  local validate_script="${OXIDIZED_ROOT}/scripts/validate-router-db.sh"
  if [[ -f "${validate_script}" && -x "${validate_script}" ]]; then
    log_info "Running inventory validation..."
    if "${validate_script}"; then
      log_success "Inventory validation passed"
    else
      log_error "Inventory validation failed"
      log_error "Fix errors in ${router_db} and re-run deployment"
      exit ${EXIT_GENERAL_FAILURE}
    fi
  fi
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

  # Check backend API (Oxidized on 127.0.0.1:8889) - with retry
  local max_attempts=3
  local attempt=1
  local backend_responding=false

  log_info "Checking if Oxidized backend (127.0.0.1:8889) is ready..."

  while [[ ${attempt} -le ${max_attempts} ]]; do
    if curl -sf http://127.0.0.1:8889/ > /dev/null 2>&1; then
      log_success "Oxidized backend is responding on 127.0.0.1:8889"
      backend_responding=true
      break
    else
      if [[ ${attempt} -lt ${max_attempts} ]]; then
        sleep 2
      fi
      ((attempt++))
    fi
  done

  if [[ "${backend_responding}" == "false" ]]; then
    log_warn "Backend is not responding (this is normal if no devices are in router.db)"
    log_info "The API will start automatically when you add devices to the inventory"
  fi

  # Check frontend (nginx on port 8888)
  log_info "Checking if nginx frontend (localhost:8888) is ready..."
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/ 2> /dev/null || echo "000")

  if [[ "${http_code}" == "401" ]]; then
    log_success "nginx frontend is responding on localhost:8888 (authentication enabled)"
  elif [[ "${http_code}" == "303" ]] || [[ "${http_code}" == "200" ]]; then
    log_success "nginx frontend is responding on localhost:8888"
  else
    log_warn "nginx frontend returned HTTP ${http_code} (check nginx status)"
  fi

  # Check Git repository
  if [[ -d "${OXIDIZED_ROOT}/repo/.git" ]]; then
    log_success "Git repository initialized"
  else
    log_warn "Git repository not found (non-fatal)"
  fi

  log_success "Deployment verification complete"
}

# Show next steps
show_next_steps() {
  log_step "Deployment Complete!"

  cat << EOF

${COLOR_GREEN}✅ Oxidized has been successfully deployed!${COLOR_RESET}

${COLOR_BLUE}Deployment Details:${COLOR_RESET}
  User/Group: ${OXIDIZED_USER}:${OXIDIZED_GROUP} (UID/GID: ${OXIDIZED_UID}/${OXIDIZED_GID})
  Data Directory: ${OXIDIZED_ROOT}
  Network: ${PODMAN_NETWORK}
  Security: Non-root container, read-only rootfs, all capabilities dropped

${COLOR_BLUE}Next Steps:${COLOR_RESET}

1. ${COLOR_YELLOW}Configure device inventory (router.db):${COLOR_RESET}
   sudo vim ${OXIDIZED_ROOT}/config/router.db
   Format: name:ip:model:group:username:password (colon-delimited)
   Note: Leave username/password blank to use global credentials from .env

2. ${COLOR_YELLOW}Verify device credentials:${COLOR_RESET}
   sudo vim ${OXIDIZED_ROOT}/config/config
   Update username/password for your devices

3. ${COLOR_YELLOW}Add SSH keys (if needed):${COLOR_RESET}
   sudo cp ~/.ssh/id_rsa ${OXIDIZED_ROOT}/ssh/
   sudo chown ${OXIDIZED_UID}:${OXIDIZED_GID} ${OXIDIZED_ROOT}/ssh/id_rsa
   sudo chmod 600 ${OXIDIZED_ROOT}/ssh/id_rsa

4. ${COLOR_YELLOW}Check service status:${COLOR_RESET}
   sudo systemctl status oxidized.service

5. ${COLOR_YELLOW}View container logs:${COLOR_RESET}
   podman logs -f oxidized

6. ${COLOR_YELLOW}Run health check:${COLOR_RESET}
   ${OXIDIZED_ROOT}/scripts/health-check.sh

7. ${COLOR_YELLOW}Add and manage devices:${COLOR_RESET}
   ${OXIDIZED_ROOT}/scripts/add-device.sh          # Interactive device addition
   ${OXIDIZED_ROOT}/scripts/validate-router-db.sh  # Validate router.db syntax
   ${OXIDIZED_ROOT}/scripts/test-device.sh <device-name>  # Test specific device

8. ${COLOR_YELLOW}Setup remote repository (optional):${COLOR_RESET}
   ${OXIDIZED_ROOT}/scripts/setup-remote-repo.sh   # Configure GitHub/GitLab backup
   See: ${REPO_ROOT}/docs/QUICK_START_REMOTE_REPO.md

${COLOR_BLUE}Data Locations:${COLOR_RESET}
  Configuration: ${OXIDIZED_ROOT}/config/
  Device List:   ${OXIDIZED_ROOT}/config/router.db (colon-delimited CSV)
  Logs:          ${OXIDIZED_ROOT}/data/oxidized.log
  SSH Keys:      ${OXIDIZED_ROOT}/ssh/
  Git Backups:   ${OXIDIZED_ROOT}/repo/
  Output:        ${OXIDIZED_ROOT}/output/
  Helper Scripts: ${OXIDIZED_ROOT}/scripts/

${COLOR_BLUE}Useful Commands:${COLOR_RESET}
  systemctl status oxidized.service    # Check service status
  podman logs oxidized                 # View container logs
  podman restart oxidized              # Restart container
  podman network inspect ${PODMAN_NETWORK}  # View network details

${COLOR_BLUE}Troubleshooting:${COLOR_RESET}
  If permission errors occur:
    - Check file ownership: ls -la ${OXIDIZED_ROOT}
    - Verify UID/GID: id ${OXIDIZED_USER}
    - Check SELinux contexts: ls -laZ ${OXIDIZED_ROOT}

${COLOR_BLUE}Documentation:${COLOR_RESET}
  ${REPO_ROOT}/docs/INSTALL.md                  # Installation guide
  ${REPO_ROOT}/docs/UPGRADE.md                  # Upgrade procedures
  ${REPO_ROOT}/docs/QUICK_START_REMOTE_REPO.md  # Remote repository quick start
  ${REPO_ROOT}/docs/REMOTE_REPOSITORY.md        # Remote repository full guide
  ${REPO_ROOT}/docs/monitoring/ZABBIX.md        # Monitoring setup

${COLOR_GREEN}Happy backing up! 🎉${COLOR_RESET}

EOF
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
      -s | --skip-credentials)
        SKIP_CREDENTIALS=true
        shift
        ;;
      -v | --verbose)
        # shellcheck disable=SC2034  # VERBOSE used for future enhancements
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
  echo "  Oxidized Deployment Script"
  echo "========================================"
  echo ""

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_warn "DRY-RUN MODE: No changes will be made"
  fi

  # Execute deployment steps
  check_root
  load_env
  validate_env
  check_prerequisites
  create_user
  create_directories
  deploy_config
  configure_credentials
  initialize_git
  create_network
  install_quadlet
  install_logrotate
  install_log_tailer
  install_motd
  install_documentation
  install_helper_scripts
  pull_image
  configure_firewall
  install_nginx
  configure_nginx_auth
  deploy_nginx_config
  configure_nginx_selinux
  start_nginx
  start_service
  fix_ownership
  validate_source_file
  verify_deployment
  show_next_steps

  # Run health check to verify deployment
  log_step "Running Health Check"
  if [[ -f "${SCRIPT_DIR}/health-check.sh" ]]; then
    echo ""
    "${SCRIPT_DIR}/health-check.sh" || log_warn "Health check completed with warnings"
  else
    log_warn "Health check script not found"
  fi

  exit ${EXIT_SUCCESS}
}

# Run main function
main "$@"
