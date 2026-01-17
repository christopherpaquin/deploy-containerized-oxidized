#!/usr/bin/env bash
###############################################################################
# run-precommit.sh
#
# Authoritative wrapper for running pre-commit checks.
#
# Responsibilities:
# - Run all pre-commit hooks
# - Capture full output to an AI-readable log file
# - Preserve correct exit codes
# - Never modify git state silently
#
# See docs/ai/CONTEXT.md Section 11 for required usage.
###############################################################################

set -euo pipefail

# Resolve repository root (works regardless of CWD)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARTIFACTS_DIR="${REPO_ROOT}/artifacts"
LOG_FILE="${ARTIFACTS_DIR}/pre-commit.log"

# Ensure artifacts directory exists (ignored by git)
mkdir -p "${ARTIFACTS_DIR}"

echo "Running pre-commit checks..."
echo "Log file: ${LOG_FILE}"
echo "Repository: ${REPO_ROOT}"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "------------------------------------------------------------" > "${LOG_FILE}"

# Run pre-commit and capture output
set +e
pre-commit run --all-files 2>&1 | tee -a "${LOG_FILE}"
PRECOMMIT_RC="${PIPESTATUS[0]}"
set -e

echo "------------------------------------------------------------" >> "${LOG_FILE}"
echo "Exit code: ${PRECOMMIT_RC}" >> "${LOG_FILE}"

if [[ "${PRECOMMIT_RC}" -ne 0 ]]; then
  echo
  echo "❌ pre-commit failed"
  echo "Review and remediate failures in:"
  echo "  ${LOG_FILE}"
  echo
else
  echo
  echo "✅ pre-commit passed successfully"
fi

exit "${PRECOMMIT_RC}"
