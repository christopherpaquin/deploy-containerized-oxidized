#!/usr/bin/env bash
###############################################################################
# detect-secrets.sh
#
# Pre-commit hook to detect secrets, API keys, and access tokens in staged
# files. This script implements the requirements from docs/ai/CONTEXT.md
# Section 7.1.4 - Code and Script Scanning Requirements.
#
# This script distinguishes between:
# - Real secrets (high-entropy strings, known token patterns)
# - False positives (variable names, example values, API call patterns)
#
# Performance optimizations:
# - Combined regex patterns to reduce grep calls (O(n) instead of O(n*m))
# - Single-pass file scanning with grep
# - Optimized entropy calculation (pure bash, no subprocesses)
# - Early exit for files with no matches
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Combined secret pattern (all patterns OR'd together for single grep pass)
# This reduces O(files × lines × patterns) to O(files × lines)
SECRET_PATTERN='(sk_live_[a-zA-Z0-9]{24,}|sk_test_[a-zA-Z0-9]{24,}|pk_live_[a-zA-Z0-9]{24,}|pk_test_[a-zA-Z0-9]{24,}|AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{32,}|xox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[a-zA-Z0-9]{24,}|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|ghu_[a-zA-Z0-9]{36}|ghs_[a-zA-Z0-9]{36}|ghr_[a-zA-Z0-9]{36}|ASIA[0-9A-Z]{16}|[a-zA-Z0-9+/=]{40,}|eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}|-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----|ya29\.[a-zA-Z0-9_-]+|1//[a-zA-Z0-9_-]+)'

# Patterns that always indicate secrets (no entropy check needed)
HIGH_CONFIDENCE_PATTERN='(BEGIN|PRIVATE|KEY|ghp_|sk_|AIza|AKIA)'

# Combined allowlist pattern (for fast filtering)
ALLOWLIST_PATTERN='(YOUR_API_KEY_HERE|your-api-key-here|example\.com|test_key|demo_key|placeholder|CHANGE_ME|REPLACE_ME|api_key\s*=|API_KEY\s*=|access_token\s*=|secret\s*=|https?://[a-zA-Z0-9.-]+|api/v[0-9]+|/api/|^\s*#.*(api|key|token|secret)|^\s*//.*(api|key|token|secret)|^\s*\*.*(api|key|token|secret))'

# Files to exclude from scanning (compiled into single pattern for efficiency)
EXCLUDE_PATTERN='(\.git/|\.env\.example$|\.gitignore$|artifacts/|\.pre-commit-cache/|node_modules/|\.venv/|venv/|__pycache__/|\.pytest_cache/|\.mypy_cache/|dist/|build/)'

# Function to check if file should be excluded (optimized with single regex)
should_exclude_file() {
  local file="$1"
  [[ "${file}" =~ ${EXCLUDE_PATTERN} ]]
}

# Optimized entropy calculation (pure bash, no subprocesses)
# Uses associative array to count unique characters
calculate_entropy() {
  local str="$1"
  local len=${#str}
  if [[ ${len} -lt 16 ]]; then
    echo "0"
    return
  fi

  # Count unique characters using associative array (bash 4+)
  # This is much faster than fold | sort | wc
  declare -A chars
  local i
  for ((i = 0; i < len; i++)); do
    chars[${str:i:1}]=1
  done
  echo "${#chars[@]}"
}

# Main detection function (optimized)
detect_secrets() {
  local found_secrets=0
  local files_checked=0

  # Get list of staged files
  local staged_files
  staged_files=$(git diff --cached --name-only --diff-filter=ACM 2> /dev/null || true)

  if [[ -z "${staged_files}" ]]; then
    echo -e "${GREEN}✓ No staged files to check${NC}"
    return 0
  fi

  # Process files efficiently
  while IFS= read -r file; do
    [[ -z "${file}" ]] && continue

    # Skip excluded files (fast check)
    if should_exclude_file "${file}"; then
      continue
    fi

    # Skip if file doesn't exist (might be deleted)
    [[ ! -f "${file}" ]] && continue

    # Skip binary files (fast check - grep -I fails on binary files)
    if ! grep -qI . "${file}" 2> /dev/null; then
      continue
    fi

    files_checked=$((files_checked + 1))

    # Use grep to find all lines with potential secrets in one pass
    # This is much faster than reading the entire file line by line
    local matches
    matches=$(grep -nE "${SECRET_PATTERN}" "${file}" 2> /dev/null || true)

    # Early exit: if no matches, skip this file entirely
    if [[ -z "${matches}" ]]; then
      continue
    fi

    # Process only the matching lines (much smaller set than entire file)
    while IFS= read -r match_line; do
      [[ -z "${match_line}" ]] && continue

      # Extract line number and content
      local line_num="${match_line%%:*}"
      local line="${match_line#*:}"

      # Fast allowlist check (single grep call)
      if echo "${line}" | grep -qiE "${ALLOWLIST_PATTERN}"; then
        continue
      fi

      # Extract matched secret part
      local matched_part
      matched_part=$(echo "${line}" | grep -oE "${SECRET_PATTERN}" | head -1)

      # Check if it's a high-confidence pattern (skip entropy check for speed)
      if echo "${matched_part}" | grep -qE "${HIGH_CONFIDENCE_PATTERN}"; then
        echo -e "${RED}✗ Potential secret found in ${file}:${line_num}${NC}"
        echo -e "  ${YELLOW}Pattern:${NC} ${matched_part:0:50}..."
        echo -e "  ${YELLOW}Context:${NC} ${line:0:100}..."
        echo ""
        found_secrets=$((found_secrets + 1))
        continue
      fi

      # For generic patterns, check entropy (only when needed)
      local entropy
      entropy=$(calculate_entropy "${matched_part}")

      if [[ ${entropy} -gt 8 ]]; then
        echo -e "${RED}✗ Potential secret found in ${file}:${line_num}${NC}"
        echo -e "  ${YELLOW}Pattern:${NC} ${matched_part:0:50}..."
        echo -e "  ${YELLOW}Context:${NC} ${line:0:100}..."
        echo ""
        found_secrets=$((found_secrets + 1))
      fi
    done <<< "${matches}"
  done <<< "${staged_files}"

  if [[ ${found_secrets} -gt 0 ]]; then
    echo -e "${RED}❌ Found ${found_secrets} potential secret(s) in staged files${NC}"
    echo -e "${YELLOW}If these are false positives, add them to the allowlist in scripts/detect-secrets.sh${NC}"
    echo -e "${YELLOW}Or use example placeholders like: YOUR_API_KEY_HERE${NC}"
    return 1
  fi

  if [[ ${files_checked} -gt 0 ]]; then
    echo -e "${GREEN}✓ Checked ${files_checked} file(s) - no secrets detected${NC}"
  fi

  return 0
}

# Run detection
main() {
  detect_secrets
}

main "$@"
