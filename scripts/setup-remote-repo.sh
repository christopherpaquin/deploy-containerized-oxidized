#!/usr/bin/env bash
#
# setup-remote-repo.sh - Configure remote git repository for Oxidized backups
#
# Description:
#   Sets up a remote git repository (GitHub, GitLab, etc.) for Oxidized
#   configuration backups. Configures automatic pushing of commits.
#
# Usage:
#   ./setup-remote-repo.sh
#
# Requirements:
#   - Oxidized must be deployed and running
#   - Remote repository must exist and be accessible (preferably private)
#   - SSH key or personal access token for authentication
#
# Author: Generated for deploy-containerized-oxidized
# Version: 1.0.0

set -euo pipefail

# Color definitions for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Script directory and paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly OXIDIZED_ROOT="/var/lib/oxidized"
readonly OXIDIZED_REPO="${OXIDIZED_ROOT}/repo"
readonly OXIDIZED_CONFIG="${OXIDIZED_ROOT}/config/config"
readonly OXIDIZED_USER="oxidized"
readonly OXIDIZED_HOME="$(getent passwd "${OXIDIZED_USER}" | cut -d: -f6)"

# Detect actual UID/GID from the oxidized user
# Now that host UID matches container UID (30000), we can use the user directly
OXIDIZED_UID=$(id -u "${OXIDIZED_USER}" 2> /dev/null || echo "30000")
OXIDIZED_GID=$(id -g "${OXIDIZED_USER}" 2> /dev/null || echo "30000")
readonly OXIDIZED_UID
readonly OXIDIZED_GID

# Helper function to run commands as the oxidized user
# With matching UIDs, we can use sudo -u directly
run_as_oxidized() {
  sudo -u "${OXIDIZED_USER}" "$@"
}

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------

log_info() {
  echo -e "${BLUE}ℹ${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}✓${NC} $*" >&2
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $*" >&2
}

log_error() {
  echo -e "${RED}✗${NC} $*" >&2
}

log_header() {
  echo -e "\n${BOLD}${CYAN}$*${NC}\n" >&2
}

log_step() {
  echo -e "\n${GREEN}==>${NC} $*" >&2
}

#------------------------------------------------------------------------------
# Validation Functions
#------------------------------------------------------------------------------

check_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
  fi
}

check_oxidized_deployed() {
  if [[ ! -d "${OXIDIZED_REPO}" ]]; then
    log_error "Oxidized repository not found at ${OXIDIZED_REPO}"
    log_error "Please run deploy.sh first"
    exit 1
  fi

  if [[ ! -f "${OXIDIZED_CONFIG}" ]]; then
    log_error "Oxidized configuration not found at ${OXIDIZED_CONFIG}"
    log_error "Please run deploy.sh first"
    exit 1
  fi

  log_info "Detected: User=${OXIDIZED_USER} UID=${OXIDIZED_UID} GID=${OXIDIZED_GID}"
}

check_ssh_setup() {
  local ssh_dir="${OXIDIZED_HOME}/.ssh"
  local ssh_key="${ssh_dir}/id_ed25519"

  log_step "Checking SSH Key Configuration"

  if [[ ! -d "${ssh_dir}" ]] || [[ ! -f "${ssh_key}" ]]; then
    echo ""
    log_warning "SSH key not found for user '${OXIDIZED_USER}'"
    echo "" >&2
    echo -e "${CYAN}SSH Key Required for GitHub/GitLab Authentication${NC}" >&2
    echo "" >&2
    echo -e "${BOLD}What is needed:${NC}" >&2
    echo -e "  • An SSH key pair for the ${YELLOW}${OXIDIZED_USER}${NC} user" >&2
    echo -e "  • Location: ${YELLOW}${ssh_key}${NC}" >&2
    echo -e "  • This key will authenticate to GitHub/GitLab" >&2
    echo "" >&2
    echo -e "${BOLD}Next Steps:${NC}" >&2
    echo -e "  1. This script will generate the key as user '${OXIDIZED_USER}'" >&2
    echo -e "  2. You'll add the public key to your GitHub/GitLab account" >&2
    echo -e "  3. The script will test the connection" >&2
    echo "" >&2

    read -rp "$(echo -e "${BOLD}Generate SSH key for ${OXIDIZED_USER} now? [Y/n]:${NC} ")" choice
    case "${choice}" in
      [Nn]*)
        log_error "SSH key required to continue."
        echo "" >&2
        echo "${YELLOW}Manual generation (if preferred):${NC}" >&2
        echo "  sudo mkdir -p ${ssh_dir}" >&2
        echo "  sudo -u ${OXIDIZED_USER} ssh-keygen -t ed25519 -C 'oxidized@\$(hostname)' -f ${ssh_key} -N ''" >&2
        echo "  sudo chmod 700 ${ssh_dir}" >&2
        echo "  sudo chmod 600 ${ssh_key}" >&2
        echo "" >&2
        echo "Then re-run this script." >&2
        exit 1
        ;;
      *)
        generate_ssh_key
        ;;
    esac
  else
    log_success "SSH key found for user '${OXIDIZED_USER}'"
    log_info "Key location: ${ssh_key}"

    # Verify ownership
    local key_owner
    key_owner=$(stat -c '%U' "${ssh_key}")
    if [[ "${key_owner}" != "${OXIDIZED_USER}" ]]; then
      log_warning "SSH key owner is '${key_owner}' but should be '${OXIDIZED_USER}'"
      log_info "Fixing ownership..."
      chown -R "${OXIDIZED_UID}:${OXIDIZED_GID}" "${ssh_dir}"
      log_success "Fixed ownership"
    fi

    return 0
  fi
}

generate_ssh_key() {
  local ssh_dir="${OXIDIZED_HOME}/.ssh"
  local ssh_key="${ssh_dir}/id_ed25519"

  echo ""
  log_step "Generating SSH Key for User: ${OXIDIZED_USER}"

  # Create SSH directory
  log_info "Creating directory: ${ssh_dir}"
  mkdir -p "${ssh_dir}"
  chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${ssh_dir}"
  chmod 700 "${ssh_dir}"

  # Generate key
  log_info "Generating ED25519 key pair..."
  log_info "Running as user: ${OXIDIZED_USER} (UID: ${OXIDIZED_UID})"

  if run_as_oxidized ssh-keygen -t ed25519 -C "oxidized@$(hostname)" -f "${ssh_key}" -N ""; then
    chmod 600 "${ssh_key}"
    chmod 644 "${ssh_key}.pub"
    chown "${OXIDIZED_UID}:${OXIDIZED_GID}" "${ssh_key}"*

    log_success "SSH key generated successfully!"
    log_info "Private key: ${ssh_key} (permissions: 600, owner: ${OXIDIZED_USER})"
    log_info "Public key:  ${ssh_key}.pub (permissions: 644, owner: ${OXIDIZED_USER})"
    echo ""

    display_github_instructions "${ssh_key}.pub"
  else
    log_error "Failed to generate SSH key"
    exit 1
  fi
}

display_github_instructions() {
  local pub_key_file="$1"

  log_header "📋 Add SSH Key to GitHub/GitLab"

  echo "" >&2
  echo -e "${BOLD}Your Public SSH Key:${NC}" >&2
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
  cat "${pub_key_file}" >&2
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
  echo "" >&2
  echo -e "${BOLD}How to Add to GitHub:${NC}" >&2
  echo -e "  1. Copy the key above (select and Ctrl+C)" >&2
  echo -e "  2. Go to: ${YELLOW}https://github.com/settings/keys${NC}" >&2
  echo -e "  3. Click: ${GREEN}\"New SSH key\"${NC} (green button, top right)" >&2
  echo -e "  4. Fill in:" >&2
  echo -e "     • Title: ${CYAN}Oxidized Server - $(hostname)${NC}" >&2
  echo -e "     • Key type: ${CYAN}Authentication Key${NC}" >&2
  echo -e "     • Key: ${CYAN}Paste the public key here${NC}" >&2
  echo -e "  5. Click: ${GREEN}\"Add SSH key\"${NC}" >&2
  echo -e "  6. Confirm with your GitHub password if prompted" >&2
  echo "" >&2
  echo -e "${BOLD}How to Add to GitLab:${NC}" >&2
  echo -e "  1. Copy the key above" >&2
  echo -e "  2. Go to: ${YELLOW}https://gitlab.com/-/profile/keys${NC}" >&2
  echo -e "  3. Paste key in \"Key\" field" >&2
  echo -e "  4. Title: ${CYAN}Oxidized Server - $(hostname)${NC}" >&2
  echo -e "  5. Click: ${GREEN}\"Add key\"${NC}" >&2
  echo "" >&2
  echo -e "${BOLD}Important Notes:${NC}" >&2
  echo -e "  • This key belongs to user ${YELLOW}${OXIDIZED_USER}${NC} (not root)" >&2
  echo -e "  • Git pushes will authenticate using this key" >&2
  echo -e "  • You can view this key anytime: ${CYAN}sudo cat ${pub_key_file}${NC}" >&2
  echo "" >&2

  read -rp "$(echo -e "${BOLD}Press Enter after you've added the key to GitHub/GitLab...${NC} ")"
  echo "" >&2
}

check_git_installed() {
  if ! command -v git &> /dev/null; then
    log_error "git is not installed"
    exit 1
  fi
}

#------------------------------------------------------------------------------
# Input Functions
#------------------------------------------------------------------------------

prompt_remote_url() {
  log_header "Remote Repository Configuration"

  echo -e "${CYAN}Supported URL formats:${NC}" >&2
  echo "  SSH:   git@github.com:username/repo.git" >&2
  echo "  HTTPS: https://github.com/username/repo.git" >&2
  echo "" >&2
  echo -e "${YELLOW}Note:${NC} Ensure your repository is set to PRIVATE for security!" >&2
  echo "" >&2

  while true; do
    read -rp "$(echo -e "${BOLD}Enter remote repository URL:${NC} ")" remote_url

    if [[ -z "${remote_url}" ]]; then
      log_warning "URL cannot be empty"
      continue
    fi

    # Basic URL validation
    if [[ ! "${remote_url}" =~ ^(git@|https://) ]]; then
      log_warning "URL must start with 'git@' or 'https://'"
      continue
    fi

    break
  done

  echo "${remote_url}"
}

prompt_remote_name() {
  log_info "Enter a name for this remote (default: origin)"
  read -rp "$(echo -e "${BOLD}Remote name:${NC} ")" remote_name

  if [[ -z "${remote_name}" ]]; then
    remote_name="origin"
  fi

  echo "${remote_name}"
}

prompt_branch_name() {
  log_info "Enter the branch name to push to (default: main)"
  read -rp "$(echo -e "${BOLD}Branch name:${NC} ")" branch_name

  if [[ -z "${branch_name}" ]]; then
    branch_name="main"
  fi

  echo "${branch_name}"
}

prompt_enable_autopush() {
  echo "" >&2
  echo -e "${CYAN}Auto-Push Configuration${NC}" >&2
  echo "Enable automatic pushing to remote repository?" >&2
  echo "  - If enabled: Each backup will be automatically pushed" >&2
  echo "  - If disabled: Manual push required (git push)" >&2
  echo "" >&2

  while true; do
    read -rp "$(echo -e "${BOLD}Enable auto-push? [y/N]:${NC} ")" choice
    case "${choice}" in
      [Yy]*)
        echo "true"
        return
        ;;
      [Nn]* | "")
        echo "false"
        return
        ;;
      *) log_warning "Please answer y or n" ;;
    esac
  done
}

#------------------------------------------------------------------------------
# Git Operations
#------------------------------------------------------------------------------

add_git_remote() {
  local remote_name="$1"
  local remote_url="$2"

  cd "${OXIDIZED_REPO}"

  # Check if remote already exists (run as oxidized user)
  if run_as_oxidized git remote get-url "${remote_name}" &> /dev/null; then
    log_warning "Remote '${remote_name}' already exists"
    log_info "Current URL: $(run_as_oxidized git remote get-url "${remote_name}")"

    read -rp "$(echo -e "${BOLD}Update to new URL? [y/N]:${NC} ")" choice
    case "${choice}" in
      [Yy]*)
        run_as_oxidized git remote set-url "${remote_name}" "${remote_url}"
        log_success "Updated remote '${remote_name}' to: ${remote_url}"
        ;;
      *)
        log_info "Keeping existing remote configuration"
        return 0
        ;;
    esac
  else
    run_as_oxidized git remote add "${remote_name}" "${remote_url}"
    log_success "Added remote '${remote_name}': ${remote_url}"
  fi
}

configure_git_branch() {
  local remote_name="$1"
  local branch_name="$2"

  cd "${OXIDIZED_REPO}"

  # Get current branch (run as oxidized user)
  local current_branch
  current_branch="$(run_as_oxidized git branch --show-current)"

  if [[ "${current_branch}" != "${branch_name}" ]]; then
    log_info "Current branch: ${current_branch}"
    log_info "Renaming to: ${branch_name}"
    run_as_oxidized git branch -m "${current_branch}" "${branch_name}"
    log_success "Renamed branch to '${branch_name}'"
  fi

  # Set upstream
  run_as_oxidized git branch --set-upstream-to="${remote_name}/${branch_name}" "${branch_name}" 2> /dev/null || true
}

test_remote_connection() {
  local remote_name="$1"

  log_step "Testing Remote Connection (as user: ${OXIDIZED_USER})"

  cd "${OXIDIZED_REPO}"

  # First test SSH connection to git host
  local remote_url
  remote_url=$(run_as_oxidized git remote get-url "${remote_name}")

  if [[ "${remote_url}" =~ ^git@([^:]+): ]]; then
    local git_host="${BASH_REMATCH[1]}"

    echo ""
    log_info "Step 1/2: Testing SSH authentication to ${git_host}..."
    log_info "Running: sudo -u ${OXIDIZED_USER} ssh -T git@${git_host}"
    echo ""

    local ssh_test
    ssh_test=$(run_as_oxidized ssh -T -o StrictHostKeyChecking=accept-new "git@${git_host}" 2>&1)
    local ssh_exit=$?

    # Show actual SSH output for debugging
    while IFS= read -r line; do
      echo "  ${line}"
    done <<< "${ssh_test}"
    echo ""

    # GitHub returns exit code 1 but with success message
    if [[ "${ssh_test}" =~ "successfully authenticated" ]] || [[ "${ssh_test}" =~ "Welcome to GitLab" ]]; then
      log_success "✓ SSH authentication successful for user '${OXIDIZED_USER}'"
      log_info "GitHub/GitLab recognizes the SSH key"
    elif [[ ${ssh_exit} -eq 255 ]] || [[ "${ssh_test}" =~ "Permission denied" ]]; then
      log_error "✗ SSH authentication FAILED for user '${OXIDIZED_USER}'"
      echo ""
      log_error "The SSH key has NOT been added to ${git_host}, or is incorrect."
      echo ""

      display_github_instructions "${OXIDIZED_HOME}/.ssh/id_ed25519.pub"

      return 1
    fi
  fi

  # Now test git repository access
  echo ""
  log_info "Step 2/2: Testing repository access..."
  log_info "Running: sudo -u ${OXIDIZED_USER} git ls-remote ${remote_name}"
  echo ""

  local git_output
  if git_output=$(run_as_oxidized git ls-remote "${remote_name}" 2>&1); then
    log_success "✓ Successfully connected to remote repository"
    log_info "Repository is accessible and user '${OXIDIZED_USER}' has permissions"
    return 0
  else
    log_error "✗ Failed to connect to remote repository"
    echo ""
    log_error "Git error output:"
    while IFS= read -r line; do
      echo "  ${line}"
    done <<< "${git_output}"
    echo ""
    log_error "Common issues:"
    log_error "  1. Repository doesn't exist: ${remote_url}"
    log_error "  2. User '${OXIDIZED_USER}' doesn't have access (check GitHub repo settings)"
    log_error "  3. Repository name is misspelled"
    log_error "  4. Repository is private but SSH key not added"
    echo ""
    return 1
  fi
}

initial_push() {
  local remote_name="$1"
  local branch_name="$2"

  log_info "Performing initial push to remote repository..."

  cd "${OXIDIZED_REPO}"

  # Check if remote has any commits
  if run_as_oxidized git ls-remote --exit-code "${remote_name}" "${branch_name}" &> /dev/null; then
    log_warning "Remote branch '${branch_name}' already exists"
    log_info "Pulling existing history from remote to preserve device configs..."

    # Fetch remote branch
    if ! run_as_oxidized git fetch "${remote_name}" "${branch_name}"; then
      log_error "Failed to fetch from remote"
      return 1
    fi

    # Check if local and remote have diverged
    local local_commit
    local remote_commit
    local_commit=$(run_as_oxidized git rev-parse HEAD 2> /dev/null || echo "")
    remote_commit=$(run_as_oxidized git rev-parse "${remote_name}/${branch_name}" 2> /dev/null || echo "")

    if [[ "${local_commit}" == "${remote_commit}" ]]; then
      log_success "Local and remote are already in sync"
      return 0
    fi

    # Try to merge remote into local (allow unrelated histories for fresh deployments)
    log_info "Merging remote history into local repository..."

    # Use -X ours strategy to favor local README.md in case of conflicts
    if run_as_oxidized git merge "${remote_name}/${branch_name}" --allow-unrelated-histories --strategy-option=ours --no-edit -m "Merge remote history after fresh deployment"; then
      log_success "Successfully merged remote history"

      # Count device files restored
      local device_count
      device_count=$(find . -type f ! -path "./.git/*" ! -name "README.md" | wc -l)
      if [[ ${device_count} -gt 0 ]]; then
        log_success "Restored ${device_count} device configuration file(s) from remote"
      fi

      log_info "Pushing merged history to remote..."
      if run_as_oxidized git push -u "${remote_name}" "${branch_name}"; then
        log_success "Pushed to remote repository"
      else
        log_error "Push failed after merge"
        return 1
      fi
    else
      # Merge failed - try to auto-resolve README.md conflict
      log_warning "Merge had conflicts, attempting auto-resolution..."

      if run_as_oxidized git status | grep -q "README.md"; then
        log_info "README.md conflict detected - keeping local (enhanced) version"
        # Keep our (local) version of README.md
        run_as_oxidized git checkout --ours README.md
        run_as_oxidized git add README.md

        # Check if there are other conflicts
        if run_as_oxidized git diff --name-only --diff-filter=U | grep -qv "README.md"; then
          log_error "Additional conflicts detected beyond README.md"
          log_info "Manual resolution required:"
          log_info "  cd ${OXIDIZED_REPO}"
          log_info "  git status"
          return 1
        fi

        # Complete the merge
        if run_as_oxidized git commit --no-edit -m "Merge remote history (kept local README.md)"; then
          log_success "Auto-resolved conflicts and completed merge"

          local device_count
          device_count=$(find . -type f ! -path "./.git/*" ! -name "README.md" | wc -l)
          if [[ ${device_count} -gt 0 ]]; then
            log_success "Restored ${device_count} device configuration file(s) from remote"
          fi

          if run_as_oxidized git push -u "${remote_name}" "${branch_name}"; then
            log_success "Pushed to remote repository"
          else
            log_error "Push failed after merge"
            return 1
          fi
        else
          log_error "Failed to complete merge"
          return 1
        fi
      else
        log_error "Unexpected merge conflict"
        log_info "Manual resolution required:"
        log_info "  cd ${OXIDIZED_REPO}"
        log_info "  git status"
        return 1
      fi
    fi
  else
    run_as_oxidized git push -u "${remote_name}" "${branch_name}"
    log_success "Pushed to remote repository"
  fi
}

#------------------------------------------------------------------------------
# Oxidized Configuration
#------------------------------------------------------------------------------

update_oxidized_config() {
  local remote_name="$1"
  local branch_name="$2"
  local enable_autopush="$3"

  log_info "Updating Oxidized configuration for remote repository..."

  # Backup current config
  cp "${OXIDIZED_CONFIG}" "${OXIDIZED_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

  # Check if git remote config already exists
  if grep -q "remote_repo:" "${OXIDIZED_CONFIG}"; then
    log_info "Remote configuration already exists in config"
    log_info "Manual update required to change settings"
    return 0
  fi

  # Add remote configuration to git output section
  # This uses a temporary file to avoid complex sed operations
  python3 << EOF
import yaml
import sys

config_file = "${OXIDIZED_CONFIG}"

try:
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)

    # Update git output configuration
    if 'output' in config and 'git' in config['output']:
        config['output']['git']['remote_repo'] = '${remote_name}'

        if '${enable_autopush}' == 'true':
            config['output']['git']['type'] = 'gitcrypt'  # Enables auto-push

        # Save updated config
        with open(config_file, 'w') as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False)

        print("Configuration updated successfully", file=sys.stderr)
        sys.exit(0)
    else:
        print("Git output section not found in config", file=sys.stderr)
        sys.exit(1)

except Exception as e:
    print(f"Error updating config: {e}", file=sys.stderr)
    sys.exit(1)
EOF

  if python3 << EOF; then
import yaml
import sys

config_file = "${OXIDIZED_CONFIG}"

try:
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)

    # Update git output configuration
    if 'output' in config and 'git' in config['output']:
        config['output']['git']['remote_repo'] = '${remote_name}'

        if '${enable_autopush}' == 'true':
            config['output']['git']['type'] = 'gitcrypt'  # Enables auto-push

        # Save updated config
        with open(config_file, 'w') as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False)

        print("Configuration updated successfully", file=sys.stderr)
        sys.exit(0)
    else:
        print("Git output section not found in config", file=sys.stderr)
        sys.exit(1)

except Exception as e:
    print(f"Error updating config: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    log_success "Updated Oxidized configuration"
    log_info "Restart Oxidized for changes to take effect"
  else
    log_warning "Could not automatically update configuration"
    log_info "Manual configuration required (see documentation)"
  fi
}

#------------------------------------------------------------------------------
# Systemd Timer for Push (Alternative to built-in)
#------------------------------------------------------------------------------

create_push_timer() {
  local remote_name="$1"
  local branch_name="$2"

  log_info "Creating systemd timer for automatic git push..."

  # Create push script
  cat > "${OXIDIZED_ROOT}/scripts/git-push.sh" << 'EOF'
#!/usr/bin/env bash
# Auto-generated git push script for Oxidized

set -euo pipefail

OXIDIZED_REPO="/var/lib/oxidized/repo"
REMOTE_NAME="%%REMOTE_NAME%%"
BRANCH_NAME="%%BRANCH_NAME%%"
LOG_FILE="/var/lib/oxidized/data/git-push.log"

cd "${OXIDIZED_REPO}"

# Check if there are commits to push
if git rev-list "@{u}..HEAD" 2>/dev/null | grep -q .; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Pushing commits to ${REMOTE_NAME}" >> "${LOG_FILE}"

  if git push "${REMOTE_NAME}" "${BRANCH_NAME}" 2>&1 | tee -a "${LOG_FILE}"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Push successful" >> "${LOG_FILE}"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Push failed" >> "${LOG_FILE}"
    exit 1
  fi
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - No commits to push" >> "${LOG_FILE}"
fi
EOF

  # Substitute variables
  sed -i "s/%%REMOTE_NAME%%/${remote_name}/g" "${OXIDIZED_ROOT}/scripts/git-push.sh"
  sed -i "s/%%BRANCH_NAME%%/${branch_name}/g" "${OXIDIZED_ROOT}/scripts/git-push.sh"

  chmod +x "${OXIDIZED_ROOT}/scripts/git-push.sh"
  chown "${OXIDIZED_UID}":"${OXIDIZED_GID}" "${OXIDIZED_ROOT}/scripts/git-push.sh"

  # Create systemd service
  cat > /etc/systemd/system/oxidized-git-push.service << EOF
[Unit]
Description=Oxidized Git Push to Remote
After=oxidized.service

[Service]
Type=oneshot
User=${OXIDIZED_UID}
Group=${OXIDIZED_GID}
ExecStart=${OXIDIZED_ROOT}/scripts/git-push.sh
StandardOutput=journal
StandardError=journal
EOF

  # Create systemd timer (runs every 5 minutes)
  cat > /etc/systemd/system/oxidized-git-push.timer << EOF
[Unit]
Description=Oxidized Git Push Timer
Requires=oxidized.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  # Reload systemd and enable timer
  systemctl daemon-reload
  systemctl enable oxidized-git-push.timer
  systemctl start oxidized-git-push.timer

  log_success "Created and enabled git push timer"
  log_info "Pushes will occur every 5 minutes"
}

#------------------------------------------------------------------------------
# Display Summary
#------------------------------------------------------------------------------

display_summary() {
  local remote_name="$1"
  local remote_url="$2"
  local branch_name="$3"
  local autopush="$4"

  log_header "Configuration Summary"

  echo -e "${CYAN}Remote Repository:${NC}" >&2
  echo "  Name:   ${remote_name}" >&2
  echo "  URL:    ${remote_url}" >&2
  echo "  Branch: ${branch_name}" >&2
  echo "  Auto-push: ${autopush}" >&2
  echo "" >&2

  echo -e "${CYAN}Useful Commands:${NC}" >&2
  echo "  View remotes:        cd ${OXIDIZED_REPO} && git remote -v" >&2
  echo "  Manual push:         cd ${OXIDIZED_REPO} && git push" >&2
  echo "  View push log:       cat /var/lib/oxidized/data/git-push.log" >&2
  echo "  Timer status:        systemctl status oxidized-git-push.timer" >&2
  echo "" >&2

  echo -e "${CYAN}Next Steps:${NC}" >&2
  if [[ "${autopush}" == "true" ]]; then
    echo "  1. Verify timer is running: systemctl status oxidized-git-push.timer" >&2
    echo "  2. Monitor push log: tail -f /var/lib/oxidized/data/git-push.log" >&2
  else
    echo "  1. Manually push when ready: cd ${OXIDIZED_REPO} && git push" >&2
  fi
  echo "  2. Verify backups appear in remote repository" >&2
  echo "  3. Ensure repository is set to PRIVATE on hosting platform" >&2
  echo "" >&2

  log_success "Remote repository setup complete!"
}

#------------------------------------------------------------------------------
# Display User Context
#------------------------------------------------------------------------------

display_user_context() {
  log_header "User Context & Important Information"

  echo "" >&2
  echo -e "${CYAN}Who Runs Git Operations?${NC}" >&2
  echo -e "  • Git commits and pushes run as the ${BOLD}${OXIDIZED_USER}${NC} user (UID: ${OXIDIZED_UID})" >&2
  echo -e "  • This script runs as ${BOLD}root${NC} but executes git commands as ${BOLD}${OXIDIZED_USER}${NC}" >&2
  echo -e "  • SSH key will be generated for ${BOLD}${OXIDIZED_USER}${NC}, not root" >&2
  echo "" >&2
  echo -e "${CYAN}Why This Matters:${NC}" >&2
  echo -e "  • The Oxidized container runs as UID ${OXIDIZED_UID} and creates commits" >&2
  echo -e "  • The SSH key at ${YELLOW}${OXIDIZED_HOME}/.ssh/id_ed25519${NC} is owned by ${OXIDIZED_USER}" >&2
  echo -e "  • GitHub will authenticate using the ${OXIDIZED_USER}'s SSH key" >&2
  echo -e "  • All git operations (push/pull) happen as ${OXIDIZED_USER}" >&2
  echo "" >&2
  echo -e "${CYAN}What This Script Does:${NC}" >&2
  echo -e "  1. Checks for SSH key (generates if missing)" >&2
  echo -e "  2. Shows you the public key to add to GitHub" >&2
  echo -e "  3. Tests SSH connection to GitHub as ${OXIDIZED_USER}" >&2
  echo -e "  4. Configures git remote repository" >&2
  echo -e "  5. Merges existing remote history (preserves device configs)" >&2
  echo -e "  6. Pushes backups to remote" >&2
  echo -e "  7. Optionally sets up automatic push every 5 minutes" >&2
  echo "" >&2
  echo -e "${YELLOW}⚠  IMPORTANT - After Fresh Deployment:${NC}" >&2
  echo -e "  • If re-deploying after uninstall, this script will automatically" >&2
  echo -e "    merge your existing GitHub history to preserve device configs" >&2
  echo -e "  • No manual steps needed - just run this script normally" >&2
  echo "" >&2

  read -rp "$(echo -e "${BOLD}Press Enter to continue...${NC} ")"
  echo "" >&2
}

#------------------------------------------------------------------------------
# Main Function
#------------------------------------------------------------------------------

main() {
  log_header "Oxidized Remote Repository Setup"

  # Validation
  check_root
  check_git_installed
  check_oxidized_deployed

  # Display context before proceeding
  display_user_context

  check_ssh_setup

  # Gather information
  local remote_url
  remote_url=$(prompt_remote_url)

  local remote_name
  remote_name=$(prompt_remote_name)

  local branch_name
  branch_name=$(prompt_branch_name)

  local enable_autopush
  enable_autopush=$(prompt_enable_autopush)

  # Configure git remote
  add_git_remote "${remote_name}" "${remote_url}"
  configure_git_branch "${remote_name}" "${branch_name}"

  # Test connection
  if ! test_remote_connection "${remote_name}"; then
    log_error "Aborting due to connection failure"
    exit 1
  fi

  # Initial push
  if ! initial_push "${remote_name}" "${branch_name}"; then
    log_warning "Initial push failed, but remote is configured"
    log_info "You can manually push later: cd ${OXIDIZED_REPO} && git push"
  fi

  # Configure auto-push if requested
  if [[ "${enable_autopush}" == "true" ]]; then
    create_push_timer "${remote_name}" "${branch_name}"
  fi

  # Display summary
  display_summary "${remote_name}" "${remote_url}" "${branch_name}" "${enable_autopush}"
}

# Execute main function
main "$@"
