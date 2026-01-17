#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="."

# Directories to create
DIRS=(
  "docs"
  "docs/ai"
  "docs/governance"
  ".github"
  ".github/workflows"
  ".github/ISSUE_TEMPLATE"
  "scripts"
)

# Files to create (empty placeholders only)
FILES=(
  "README.md"
  "LICENSE"
  ".gitignore"
  ".pre-commit-config.yaml"
  ".pymarkdown.json"
  "docs/ai/CONTEXT.md"
  "docs/requirements.md"
  "docs/ci-and-precommit.md"
  ".github/workflows/ci.yaml"
  ".github/pull_request_template.md"
  ".github/ISSUE_TEMPLATE/feature_request.yml"
  ".github/ISSUE_TEMPLATE/bug_report.yml"
  "scripts/run-precommit.sh"
  "scripts/detect-secrets.sh"
)

echo "==> Creating directory structure (no overwrite)"

for dir in "${DIRS[@]}"; do
  if [[ -d "${ROOT_DIR}/${dir}" ]]; then
    echo "SKIP dir exists: ${dir}"
  else
    mkdir -p "${ROOT_DIR}/${dir}"
    echo "CREATED dir: ${dir}"
  fi
done

echo
echo "==> Creating files if missing (no overwrite)"

for file in "${FILES[@]}"; do
  if [[ -f "${ROOT_DIR}/${file}" ]]; then
    echo "SKIP file exists: ${file}"
  else
    mkdir -p "$(dirname "${ROOT_DIR}/${file}")"
    touch "${ROOT_DIR}/${file}"
    echo "CREATED file: ${file}"
  fi
done

echo
echo "==> Bootstrap complete"
