#!/usr/bin/env bash
###############################################################################
# check-commit-message.sh
#
# Pre-commit hook to detect secrets, credentials, and sensitive information
# in commit messages. This prevents accidental exposure of sensitive data
# in git history via commit messages.
#
# This script checks commit messages for:
# - Passwords and credentials
# - IP addresses (especially private/internal IPs)
# - API keys and tokens
# - Email addresses (may indicate sensitive accounts)
# - High-entropy strings that may be secrets
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Get commit message from COMMIT_EDITMSG or stdin
COMMIT_MSG_FILE="${1:-${GIT_DIR:-.git}/COMMIT_EDITMSG}"

# For commit-msg hook, pre-commit passes the file as first argument
# For direct testing, check if stdin has data first
if [[ -t 0 ]]; then
  # stdin is a terminal, not piped input - read from file
  if [[ -f "${COMMIT_MSG_FILE}" ]]; then
    COMMIT_MSG=$(cat "${COMMIT_MSG_FILE}" 2> /dev/null || echo "")
  else
    # Try to get from git (for pre-commit hook)
    if command -v git > /dev/null 2>&1; then
      COMMIT_MSG=$(git log -1 --pretty=%B 2> /dev/null || echo "")
    else
      COMMIT_MSG=""
    fi
  fi
else
  # stdin has data (piped input) - read from stdin for testing
  COMMIT_MSG=$(cat 2> /dev/null || echo "")
fi

# If still empty, exit silently (may be called in wrong context)
if [[ -z "${COMMIT_MSG}" ]]; then
  exit 0
fi

# Patterns to detect in commit messages
# IP addresses (especially private IP ranges)
# Using [0-9] instead of \d for POSIX grep compatibility
# Word boundaries removed as they can be unreliable with IPs
IP_PATTERN='(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})'

# Common password patterns (words that often appear with passwords)
PASSWORD_PATTERN='\b(password|passwd|pwd|secret|credential|token|key)\s*[:=]\s*[^\s]{8,}'

# High-entropy strings (potential secrets)
HIGH_ENTROPY_PATTERN='\b[a-zA-Z0-9+/=]{32,}\b'

# Known credential patterns
CREDENTIAL_PATTERN='\b(api[_-]?key|access[_-]?token|secret[_-]?key|auth[_-]?token)\s*[:=]\s*[^\s]{16,}'

# Email addresses (may indicate sensitive accounts)
EMAIL_PATTERN='\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'

# Function to check entropy (simplified)
calculate_entropy() {
  local str="$1"
  local len=${#str}
  if [[ ${len} -lt 16 ]]; then
    echo "0"
    return
  fi

  declare -A chars
  local i
  for ((i = 0; i < len; i++)); do
    chars[${str:i:1}]=1
  done
  echo "${#chars[@]}"
}

# Function to check for sensitive patterns
check_commit_message() {
  local found_issues=0
  local issues=()

  # Check for IP addresses
  if echo "${COMMIT_MSG}" | grep -qE "${IP_PATTERN}"; then
    local ips
    ips=$(echo "${COMMIT_MSG}" | grep -oE "${IP_PATTERN}" | sort -u | head -5)
    issues+=("IP addresses detected: ${ips}")
    found_issues=$((found_issues + 1))
  fi

  # Check for password patterns
  if echo "${COMMIT_MSG}" | grep -qiE "${PASSWORD_PATTERN}"; then
    issues+=("Password or credential pattern detected")
    found_issues=$((found_issues + 1))
  fi

  # Check for credential patterns
  if echo "${COMMIT_MSG}" | grep -qiE "${CREDENTIAL_PATTERN}"; then
    issues+=("API key or token pattern detected")
    found_issues=$((found_issues + 1))
  fi

  # Check for high-entropy strings (potential secrets)
  local high_entropy_matches
  high_entropy_matches=$(echo "${COMMIT_MSG}" | grep -oE "${HIGH_ENTROPY_PATTERN}" || true)
  if [[ -n "${high_entropy_matches}" ]]; then
    while IFS= read -r match; do
      [[ -z "${match}" ]] && continue
      local entropy
      entropy=$(calculate_entropy "${match}")
      if [[ ${entropy} -gt 10 ]]; then
        issues+=("High-entropy string detected (potential secret): ${match:0:20}...")
        found_issues=$((found_issues + 1))
        break # Only report first high-entropy match
      fi
    done <<< "${high_entropy_matches}"
  fi

  # Check for email addresses (warn but don't fail - may be legitimate)
  if echo "${COMMIT_MSG}" | grep -qE "${EMAIL_PATTERN}"; then
    local emails
    emails=$(echo "${COMMIT_MSG}" | grep -oE "${EMAIL_PATTERN}" | sort -u | head -3)
    echo -e "${YELLOW}⚠ Warning: Email addresses found in commit message:${NC}"
    echo -e "  ${emails}"
    echo -e "${YELLOW}  Ensure these are not sensitive accounts${NC}"
    echo ""
  fi

  # Report issues
  if [[ ${found_issues} -gt 0 ]]; then
    echo -e "${RED}❌ Commit message contains sensitive information!${NC}"
    echo ""
    echo -e "${RED}Issues found:${NC}"
    for issue in "${issues[@]}"; do
      echo -e "  ${RED}✗${NC} ${issue}"
    done
    echo ""
    echo -e "${YELLOW}Commit messages are permanent in git history.${NC}"
    echo -e "${YELLOW}Never include:${NC}"
    echo -e "  - Passwords or credentials"
    echo -e "  - IP addresses (especially private/internal IPs)"
    echo -e "  - API keys or tokens"
    echo -e "  - Any sensitive information"
    echo ""
    echo -e "${YELLOW}Use generic descriptions instead:${NC}"
    echo -e "  - 'Remove credentials' instead of 'Remove password xyz123'"
    echo -e "  - 'Update config' instead of 'Update 192.168.1.100 config'"
    echo -e "  - 'Fix authentication' instead of 'Fix login with user:pass'"
    echo ""
    return 1
  fi

  echo -e "${GREEN}✓ Commit message is safe${NC}"
  return 0
}

# Run check
main() {
  check_commit_message
}

main "$@"
