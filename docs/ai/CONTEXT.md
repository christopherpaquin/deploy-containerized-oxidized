# AI Engineering Context and Standards

This repository uses AI-assisted development.
All AI tools (Cursor, ChatGPT, Copilot, etc.) must follow this document.

If behavior is not explicitly allowed here or in docs/requirements.md,
it must not be implemented without clarification.

---

## 1. Design Principles

- Correctness over cleverness
- Explicit behavior over implicit assumptions
- Idempotent and safe by default
- Fail loudly, clearly, and early
- Prefer boring, maintainable solutions
- All code should be easily installed and uninstalled
- Adhere to Security best practices
- Adhere to SELinux best practices (semanage over chcon)

---

## 2. Supported Environments

- Primary OS: RHEL 9 / RHEL 10
- Secondary OS: Ubuntu 22.04 (best-effort)
- Shell: bash
- Python: 3.11+
- Do not assume additional tools are installed unless explicitly documented.

---

## 3. Bash Standards

- Use `#!/usr/bin/env bash`
- Scripts must start with:
  - `set -euo pipefail`
- Quote all variables
- Never use `eval`
- Validate all inputs early
- Use functions; avoid large monolithic scripts
- Use `trap` for cleanup when modifying system state

---

## 4. Python Standards

- Prefer standard library
- Use type hints for public functions
- Avoid global mutable state
- Use structured logging
- External calls must have timeouts
- Avoid `shell=True`
- CLI tools must support `--help`

---

## 5. Yaml and Json Standards

Configuration and data files must follow consistent, predictable formatting
to ensure readability, tooling compatibility, and long-term maintainability.

### 5.1 File Naming and Extensions

- YAML files **must** use the `.yaml` extension
  - `.yml` is **not allowed**
- JSON files **must** use the `.json` extension
- File extensions must accurately reflect file contents

### 5.2 YAML Standards

- YAML files must be valid YAML 1.2
- Indentation:
  - Use **2 spaces**
  - Never use tabs
- Use block-style YAML where possible
- Avoid implicit typing when ambiguity may exist:
  - Quote strings that could be misinterpreted (e.g., `yes`, `no`, `on`, `off`)
- Use explicit `null` instead of empty values when intentional
- Keys should use `snake_case` unless an external specification requires otherwise
- Lists should be written in expanded form (one item per line)
- Comments should explain *why*, not *what*

Example:

```yaml
log_level: "info"
enable_feature: false
retry_count: 3
servers:
  - host: example1.local
    port: 443
  - host: example2.local
    port: 443

```

---

### 5.3 JSON Standards

- JSON must be strictly valid
  - No comments
  - No trailing commas
- Use **2-space indentation**
- Use UTF-8 encoding
- Keys should use `snake_case` unless constrained by an external API
- Arrays and objects should be formatted for readability, not compactness
- Values must use explicit types (`true`, `false`, `null`)

Example:

```json
{
  "log_level": "info",
  "enable_feature": false,
  "retry_count": 3,
  "servers": [
    {
      "host": "example1.local",
      "port": 443
    },
    {
      "host": "example2.local",
      "port": 443
    }
  ]
}
```

---

## 6. Idempotency and Safety

- Scripts must be safe to re-run
- Existing state must be detected, not overwritten blindly
- Partial failures must be handled
- Destructive actions must be explicit and documented
- Provide `--dry-run` where reasonable

---

## 7. Security

### 7.1 Secrets Management - Summary: What Must Never Be Checked Into Git or Code

**The repository must never contain secrets** — any material that can be used to
authenticate, authorize, or bill against an account, service, or infrastructure.

This includes both files and inline values embedded in code or scripts.

#### 7.1.1 Definition of "Secrets"

A secret is any value that:

- Authenticates an identity
- Grants access to a system, API, or service
- Authorizes actions or permissions
- Enables billable usage
- Establishes cryptographic trust

If exposed, a secret can result in:

- Account compromise
- Unauthorized access
- Financial loss
- Infrastructure takeover

#### 7.1.2 Categories of Secrets That Must Never Be Committed

##### 7.1.2.1 API Keys

Static credentials used for programmatic access.

Examples:

- OpenAI API keys
- Stripe keys
- SendGrid keys
- Twilio keys

Risk:

- Immediate unauthorized API usage
- Direct financial impact

##### 7.1.2.2 Access Tokens and OAuth Tokens

Bearer tokens granting scoped or full access.

Examples:

- GitHub Personal Access Tokens (PATs)
- OAuth access tokens
- CI/CD tokens

Risk:

- Repository access
- Code modification
- Secret exfiltration

##### 7.1.2.3 Refresh Tokens

Long-lived tokens capable of minting new access tokens.

Risk:

- Persistent compromise
- Difficult to detect abuse

##### 7.1.2.4 Cloud Provider Credentials

Credentials granting infrastructure access.

Examples:

- AWS Access Key ID + Secret Key
- GCP service account JSON keys
- Azure client secrets

Risk:

- Infrastructure compromise
- Crypto-mining abuse
- Severe billing impact

##### 7.1.2.5 Cryptographic Private Keys

Keys establishing identity or trust.

Examples:

- SSH private keys (id_rsa, id_ed25519)
- TLS private keys (`*.pem`, `*.key`)
- Signing keys

Risk:

- Server access
- Trust chain compromise
- Man-in-the-middle attacks

##### 7.1.2.6 Service Account Credentials

Non-human credentials stored as files.

Examples:

- JSON/YAML credential files
- CI service secrets

Risk:

- Silent, high-privilege access

##### 7.1.2.7 Webhook Secrets and Shared Secrets

Used to validate inbound requests.

Examples:

- GitHub webhook secrets
- Stripe webhook signing secrets

Risk:

- Forged events
- Unauthorized state changes

#### 7.1.3 File Types and Locations That Must Be Excluded

The following must never be committed:

- `.env`, `.env.*` (except `.env.example`)
- `vars.env`, secret variable files
- Credential files (`*.pem`, `*.key`, `*.p12`, `*.json` keys)
- Generated logs containing sensitive values
- Tool caches that may contain secrets

These exclusions must be enforced via `.gitignore`.

#### 7.1.4 Code and Script Scanning Requirements

Secrets must not appear:

- Inline in source code
- In shell scripts
- In configuration files
- In comments
- In logs or debug output

Repositories must enforce:

- Pre-commit secret scanning via `scripts/detect-secrets.sh`
- CI-level secret detection via Gitleaks (scans full git history)
- SAST scanning via Semgrep (security audit and OWASP Top 10)
- Dependency vulnerability scanning via OSV-Scanner
- AI agent instructions prohibiting secret creation or logging

**Secret Detection Implementation**: This framework includes `scripts/detect-secrets.sh`, a
comprehensive secret detection script that:

- Scans staged files for API keys, tokens, credentials, and private keys
- Uses pattern matching for known secret formats (GitHub tokens, AWS keys, Stripe keys, etc.)
- Applies entropy analysis to detect high-entropy strings
- Filters false positives (variable names, example values, API endpoints, comments)
- Excludes test files, example files, and documentation from scanning
- Provides clear error messages with file location and context
- AI agents must understand that this script will block commits containing secrets
  and must never attempt to bypass or disable this protection.
- High-entropy strings and known token patterns must be treated as potential secrets until proven otherwise

#### 7.1.5 Security Posture Statement

**Secrets** — including API keys, access tokens, credentials, private keys, or any
material that grants authenticated or billable access — **must never be committed
to Git repositories** and must be actively scanned for in both code and configuration.

**⚠️ CRITICAL: Commit messages are permanent in git history and must NEVER contain:**
- Passwords, credentials, or secrets
- IP addresses (especially private/internal IPs)
- API keys or tokens
- Any sensitive information

Commit messages are scanned by `scripts/check-commit-message.sh` to prevent
accidental exposure of sensitive data in git history.

### 7.2 General Security Standards

- Never log secrets
- Credentials and IP addresses should never be hardcoded into scripts, should exist in `.env` file
- `.env` file should not be checked into any repo (`.gitignore`)
- An example `.env` file (`.env.example`) should be created and checked in via git
- Treat all inputs as untrusted
- Document required permissions
- Use least privilege
- Sanitize file paths and user input

---

## 8. Logging and Exit Codes

- Logs must be actionable and informative
- Logs should exist in /var/log
- Errors must explain what failed and why
- Exit codes:
  - 0: success
  - 1: general failure
  - 2: invalid usage or input
  - 3: missing dependency

---

## 9. Documentation Requirements

### 9.1 README Structure

README must include:
- Overview
- Include "tested on" shields [https://img.shields.io/]
- Requirements / dependencies
- Include high level architecture overview
- Installation
- Uninstall steps
- Usage examples
- Configuration
- Troubleshooting
- Security notes
- License (Apache 2.0)
- Documentation must be updated when features/functionality is updated

Operational tools must include docs/runbook.md.

### 9.2 Documentation Visual Standards

Documentation must be engaging, visually appealing, and easy to scan. The following
standards ensure consistency and improve readability.

#### 9.2.1 Visual Elements

- **Emojis**: Use relevant emojis for section headers and visual indicators
  - Examples: 🤖 for AI/automation, 🔒 for security, ✅ for success, ❌ for errors
  - Use emojis consistently throughout the document
  - Do not overuse emojis—aim for clarity, not clutter

- **Status Indicators**: Use checkmarks and X marks to show status
  - ✅ (checkmark) for positive states, included items, active features
  - ❌ (X mark) for negative states, excluded items, prohibited actions
  - ⚠️ (warning) for important cautions or best-effort items

- **Checkboxes**: Use markdown checkboxes for interactive lists
  - `- [ ]` for incomplete items
  - `- [x]` for completed items
  - Use in installation steps, troubleshooting checklists, and verification lists

- **Tables**: Use tables to organize structured information
  - Include status columns with visual indicators (✅/❌)
  - Use tables for comparisons, feature lists, and configuration options
  - Ensure tables are properly formatted and readable

- **Badges/Shields**: Use shields.io badges for key information
  - License, version, tested platforms, security status
  - Keep badges at the top of the README for visibility

#### 9.2.2 ASCII Diagrams

ASCII diagrams must be properly formatted with consistent spacing:

- Use consistent box-drawing characters (┌, ┐, └, ┘, ├, ┤, ┬, ┴, │, ─)
- Ensure proper alignment and spacing between elements
- Include emojis or symbols within diagram boxes for visual clarity
- Maintain consistent width across diagram elements
- Add blank lines before and after diagrams for readability

#### 9.2.3 Color and Formatting

- **Bold text**: Use for emphasis on important terms, file names, and key concepts
- **Code blocks**: Use appropriate language tags for syntax highlighting
- **Blockquotes**: Use `>` for important notes, warnings, or callouts
- **Horizontal rules**: Use `---` to separate major sections

#### 9.2.4 Lists and Checklists

- Use numbered lists for sequential steps (installation, configuration)
- Use bullet lists for feature lists, requirements, or non-sequential items
- Use checkboxes for interactive verification lists
- Include status indicators (✅/❌) in lists when showing feature status

#### 9.2.5 Table of Contents

- Include a table of contents with emoji indicators for major sections
- Use anchor links for easy navigation
- Keep the table of contents updated as the document evolves

#### 9.2.6 Section Headers

- Use emojis in section headers for visual identification
- Maintain consistent emoji usage across similar section types
- Examples:
  - 📋 for lists/contents
  - 🎯 for overviews
  - ⚙️ for configuration/operations
  - 🛡️ for security
  - 📚 for documentation
  - 🚀 for installation/deployment

#### 9.2.7 Code Examples

- Always include language tags in code fences
- Use comments to explain complex code
- Include expected output or results when relevant
- Format code blocks with proper indentation

#### 9.2.8 Visual Hierarchy

- Use appropriate heading levels (H1 for title, H2 for major sections, H3 for subsections)
- Maintain consistent spacing between sections
- Use visual separators (horizontal rules) between major sections
- Group related information together with consistent formatting

All documentation should follow these visual standards to ensure consistency,
readability, and engagement across all projects using this template.

---

## 10. Change Discipline

- Do not invent requirements
- If requirements are unclear, update docs/requirements.md first
- Implementation must map to acceptance criteria

## 11. AI Agent Operational Responsibilities

This section defines mandatory operational behavior for AI agents working
within this repository. These rules are authoritative.

### 11.1 File Handling and `.gitignore` Compliance

The `.gitignore` file is authoritative and must be strictly respected.

AI agents must:

- Read `.gitignore` before creating or modifying files
- Never create, move, or commit ignored files
- Never recommend committing ignored files
- Never log, echo, or persist secret values
- Use example files (e.g. `.env.example`) for documentation only

Violations of `.gitignore` rules are considered security defects.

### 11.2 Secrets and Credentials Handling

AI agents must:

- Never generate real secrets
- Never hardcode credentials
- Never log or echo secret values
- Use environment variables for all sensitive data
- Provide example placeholders only (e.g. `YOUR_API_KEY_HERE`)
- Treat any suspected secret as a security defect

If a secret is required for functionality, the AI must:

- Document it
- Reference `.env.example`
- Ensure it is excluded from version control

AI agents must understand that secrets include:

- API keys (OpenAI, Stripe, SendGrid, Twilio, etc.)
- Access tokens and OAuth tokens (GitHub PATs, CI/CD tokens)
- Refresh tokens
- Cloud provider credentials (AWS, GCP, Azure)
- Cryptographic private keys (SSH, TLS)
- Service account credentials
- Webhook secrets and shared secrets

**High-entropy strings and known token patterns must be treated as potential secrets until proven otherwise.**

---

### 11.3 Pre-commit Execution and Log Generation

Pre-commit is a mandatory quality gate.

AI agents must execute pre-commit using the repository helper script:

```bash
./scripts/run-precommit.sh
```

**Secret Detection**: The pre-commit hooks include `scripts/detect-secrets.sh` which
automatically scans all staged files for secrets, API keys, and credentials. If secrets
are detected, the commit will be blocked. AI agents must:

- Never attempt to bypass secret detection
- Use example placeholders (e.g., `YOUR_API_KEY_HERE`) instead of real secrets
- Ensure all secrets are stored in `.env` files (which are excluded from git)
- If a false positive is detected, add appropriate allowlist patterns to the script

---

## 12. Why Security Matters in This Framework

What this framework enforces is not just "don't commit keys," but:

- **Defense-in-depth**: Multiple layers of protection (`.gitignore`, pre-commit, CI scanning)
- **Least privilege**: Access only what is necessary
- **Auditability**: Clear trails of what was checked and when
- **AI-safe development**: Explicit instructions for AI agents to prevent accidental secret exposure

This is exactly the right level of rigor for an AI-assisted engineering framework.
