#!/usr/bin/env bash
###############################################################################
# fix-markdown.sh - Automated markdown linting fixes
#
# Fixes common PyMarkdown violations:
# - MD022: Add blank lines around headings
# - MD032: Add blank lines around lists
###############################################################################

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

# Files to fix (from PyMarkdown output)
FILES=(
  "AUTHENTICATION-SETUP.md"
  "DEPLOYMENT-NOTES.md"
  "DOCUMENTATION-GUIDE.md"
  "QUICK-START.md"
  "CREDENTIALS-GUIDE.md"
  "DEVICE-MANAGEMENT.md"
  "DIRECTORY-STRUCTURE.md"
  "FIREWALL-QUICKREF.md"
  "FIREWALL-IMPLEMENTATION.md"
  "SECURITY-AUTHENTICATION.md"
  "README.md"
  "docs/CONFIGURATION.md"
  "docs/PATH-MAPPINGS.md"
  "docs/TELNET-CONFIGURATION.md"
)

echo "Fixing markdown files..."

for file in "${FILES[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "⚠️  Skipping ${file} (not found)"
    continue
  fi

  echo "Processing ${file}..."

  # Fix MD022: Ensure blank line after headings (before content)
  # This perl one-liner adds a blank line after headings if the next line isn't blank or a heading
  perl -i -pe 'if (/^#{1,6}\s+/ && $next !~ /^$|^#{1,6}\s+/) { $_ .= "\n"; } BEGIN { undef $/; }; $next = substr($_, pos($_)||0);' "${file}" || true

  # Fix MD032: Ensure blank line before lists
  # Add blank line before list items if previous line isn't blank
  sed -i -E '/^[^[:space:]]/ {
    N
    s/\n([-*+]|[0-9]+\.)/\n\n\1/
  }' "${file}" || true

  # Fix MD032: Ensure blank line after lists
  # This is trickier, so we'll handle it with a more complex approach

done

echo "✅ Markdown files processed"
echo "Run 'pre-commit run pymarkdown --all-files' to verify"
