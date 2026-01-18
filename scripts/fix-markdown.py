#!/usr/bin/env python3
"""
Fix common PyMarkdown violations in markdown files.

Fixes:
- MD022: Add blank lines around headings
- MD032: Add blank lines around lists
"""

import re
import sys
from pathlib import Path


def fix_md022_headings(lines):
    """Add blank lines around headings."""
    result = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # Check if current line is a heading
        is_heading = bool(re.match(r"^#{1,6}\s+", line))

        if is_heading:
            # Add blank line before heading if previous line isn't blank
            if result and result[-1].strip():
                result.append("")

            result.append(line)

            # Add blank line after heading if next line exists and isn't blank/heading
            if i + 1 < len(lines):
                next_line = lines[i + 1]
                if next_line.strip() and not re.match(r"^#{1,6}\s+", next_line):
                    result.append("")
        else:
            result.append(line)

        i += 1

    return result


def fix_md032_lists(lines):
    """Add blank lines around lists."""
    result = []
    i = 0
    in_list = False

    while i < len(lines):
        line = lines[i]

        # Check if current line is a list item
        is_list_item = bool(re.match(r"^(\s{0,3})([-*+]|\d+\.)\s+", line))

        if is_list_item:
            # Add blank line before list starts if previous line isn't blank
            if not in_list and result and result[-1].strip():
                result.append("")

            result.append(line)
            in_list = True
        else:
            # If we were in a list and current line isn't blank, add blank line
            if (
                in_list
                and line.strip()
                and not re.match(r"^(\s{0,3})([-*+]|\d+\.)\s+", line)
            ):
                if (
                    result and result[-1].strip()
                ):  # Only if last line wasn't already blank
                    result.append("")
                in_list = False
            elif not line.strip():
                in_list = False

            result.append(line)

        i += 1

    return result


def fix_file(filepath):
    """Fix markdown violations in a file."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        lines = content.splitlines(keepends=False)

        # Apply fixes
        lines = fix_md022_headings(lines)
        lines = fix_md032_lists(lines)

        # Write back
        with open(filepath, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
            if content.endswith("\n"):
                f.write("\n")

        return True
    except Exception as e:
        print(f"Error processing {filepath}: {e}", file=sys.stderr)
        return False


def main():
    repo_root = Path(__file__).parent.parent

    files = [
        "AUTHENTICATION-SETUP.md",
        "DEPLOYMENT-NOTES.md",
        "DOCUMENTATION-GUIDE.md",
        "QUICK-START.md",
        "CREDENTIALS-GUIDE.md",
        "DEVICE-MANAGEMENT.md",
        "DIRECTORY-STRUCTURE.md",
        "FIREWALL-QUICKREF.md",
        "FIREWALL-IMPLEMENTATION.md",
        "SECURITY-AUTHENTICATION.md",
        "README.md",
        "docs/CONFIGURATION.md",
        "docs/PATH-MAPPINGS.md",
        "docs/TELNET-CONFIGURATION.md",
    ]

    print("Fixing markdown files...")
    success_count = 0

    for file_path in files:
        full_path = repo_root / file_path
        if not full_path.exists():
            print(f"⚠️  Skipping {file_path} (not found)")
            continue

        print(f"Processing {file_path}...")
        if fix_file(full_path):
            success_count += 1

    print(f"\n✅ Processed {success_count}/{len(files)} files")
    print("Run 'pre-commit run pymarkdown --all-files' to verify")


if __name__ == "__main__":
    main()
