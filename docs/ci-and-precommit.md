# pre-commit and CI: How This Repository Enforces Quality

This document explains how this repository uses:

- `.pre-commit-config.yaml` (local quality checks)
- `.github/workflows/ci.yaml` (code quality and testing)
- `.github/workflows/security-ci.yml` (security scanning)

to enforce consistent quality checks locally and in GitHub.

The goal is to catch issues early, prevent regressions, and make
AI-generated code safe and auditable.

---

## 1. High-level mental model (start here)

Think of this as **three complementary layers**:

| Layer        | Where it runs | When it runs                    | Purpose |
|-------------|---------------|----------------------------------|---------|
| pre-commit  | Your machine  | Before `git commit`              | Fast feedback, auto-fix issues |
| CI (GitHub) | GitHub        | On pull requests and pushes      | Enforced gate before merge |
| Security CI | GitHub        | On pull requests and pushes      | Comprehensive security scanning |

**Key idea:**
- **Pre-commit and CI**: The *same quality checks* run in both places. CI exists so checks **cannot be skipped**.
- **Security CI**: Runs **in parallel** with main CI, providing specialized
  security scanning that complements pre-commit secret detection.

---

## 2. What `.pre-commit-config.yaml` does

### Purpose

`.pre-commit-config.yaml` defines a set of automated checks that run
*before a commit is created*.

These checks include:
- Formatting code
- Linting Python
- Linting Bash
- Validating Markdown
- Catching common mistakes (merge conflicts, private keys, etc.)

### How it works (step by step)

#### One-time setup (per developer machine)

```bash
pip install pre-commit
pre-commit install
```

---

## 3. What `.github/workflows/security-ci.yml` does

### Overview

The Security CI workflow provides **comprehensive security scanning** that runs
automatically on every pull request and push to `main`. It complements the
pre-commit secret detection with additional layers of security analysis.

### When It Runs

The Security CI workflow is **automatically triggered**:

- ✅ **On every pull request** (all branches)
- ✅ **On every push to `main` branch**
- ✅ **Manually** via GitHub Actions UI (`workflow_dispatch`)

The workflow runs **in parallel** with the main CI workflow, so it doesn't slow
down the overall CI process.

### What It Scans

The Security CI workflow consists of three specialized security scanning jobs:

#### Job 1: Gitleaks Secret Scanning

**What It Scans**:
- Full git history (all commits, not just current changes)
- All file types in the repository
- Known secret patterns:
  - API keys (GitHub, AWS, Stripe, etc.)
  - Access tokens (OAuth, JWT, etc.)
  - Private keys (RSA, SSH, etc.)
  - Credentials and passwords
  - High-entropy strings that may indicate secrets

**How It Notifies**:
- ❌ **Fails the workflow** if secrets are detected
- 📋 **Detailed output** in workflow logs showing:
  - File path and line number where secret was found
  - Secret type (e.g., "GitHub Token", "AWS Access Key")
  - Commit hash where secret was introduced
- 🔴 **Blocks PR merge** until secrets are removed

**Why It's Needed**:
- Complements pre-commit `detect-secrets.sh` (defense in depth)
- Scans full git history (pre-commit only scans staged files)
- Catches secrets that may have slipped through pre-commit
- Provides comprehensive coverage of all repository content

#### Job 2: Semgrep SAST (Static Application Security Testing)

**What It Scans**:
- **Security Audit Rules** (`p/security-audit`): Common security vulnerabilities
- **OWASP Top 10** (`p/owasp-top-ten`): Top 10 most critical web application
  security risks
- Code patterns that indicate security issues:
  - SQL injection vulnerabilities
  - Cross-site scripting (XSS) risks
  - Insecure cryptographic usage
  - Authentication and authorization flaws
  - Insecure data handling
  - Command injection risks
  - Path traversal vulnerabilities
  - And many more security anti-patterns

**How It Notifies**:
- 📊 **GitHub Security Tab**: Results uploaded as SARIF format
  - Navigate to: Repository → Security → Code scanning alerts
  - View detailed findings with code locations
  - See severity levels (Critical, High, Medium, Low)
  - Access remediation guidance for each finding
- 📋 **Workflow Logs**: Detailed output in GitHub Actions logs
- ⚠️ **Workflow Status**: May fail if critical issues are found (configurable)
- 🔔 **GitHub Notifications**: Security alerts appear in repository security
  dashboard
- 📧 **Email Alerts**: Configurable email notifications for security findings

**Why It's Needed**:
- Detects security vulnerabilities in code patterns
- Identifies OWASP Top 10 risks before deployment
- Provides actionable remediation guidance
- Integrates with GitHub's native security features
- Helps maintain security best practices across the codebase

#### Job 3: OSV-Scanner Dependency Vulnerability Scanning

**What It Scans**:
- **Dependency files**: Automatically detects and scans:
  - `requirements.txt`, `requirements-dev.txt` (Python)
  - `package.json`, `package-lock.json` (Node.js)
  - `poetry.lock`, `Pipfile.lock` (Python package managers)
  - `go.mod`, `go.sum` (Go)
  - `Cargo.lock` (Rust)
  - `Gemfile.lock` (Ruby)
  - `pom.xml` (Maven/Java)
  - And many other dependency lock files
- **Open Source Vulnerabilities (OSV) Database**: Checks against known
  vulnerabilities in open source packages
- **Transitive dependencies**: Scans entire dependency tree, not just direct
  dependencies

**How It Notifies**:
- 📦 **Workflow Artifact**: JSON report uploaded as `osv-scan-results`
  - Download from workflow run page
  - Contains detailed vulnerability information:
    - Affected packages and versions
    - Vulnerability severity (Critical, High, Medium, Low)
    - CVE identifiers and descriptions
    - Remediation steps (version updates)
- 📋 **Workflow Logs**: Summary output in GitHub Actions logs
- ⚠️ **Workflow Status**: Fails if critical vulnerabilities are found
- 🔔 **GitHub Dependabot Integration**: Results complement Dependabot alerts

**Why It's Needed**:
- Identifies known vulnerabilities in dependencies
- Prevents vulnerable packages from being deployed
- Provides early warning of security issues in third-party code
- Complements GitHub's native dependency scanning
- Helps maintain up-to-date and secure dependencies

### Workflow Status and PR Requirements

- Both `CI` and `Security CI` workflows must pass for PRs to be mergeable
- Security failures block PR merge until issues are resolved
- Workflow status appears in PR checks section
- Detailed logs available in GitHub Actions tab

### Viewing Security CI Results

1. **Workflow Logs**: GitHub Actions → Workflows → Security CI → View run
2. **Security Tab**: Repository → Security → Code scanning alerts (Semgrep)
3. **Artifacts**: Workflow run page → Artifacts (OSV-Scanner results)
4. **PR Checks**: PR page shows workflow status and links to details

### Relationship to Pre-commit

The Security CI workflow **complements** pre-commit hooks:

| Feature | Pre-commit | Security CI |
|---------|-----------|-------------|
| **Secret Detection** | `detect-secrets.sh` (staged files) | Gitleaks (full history) |
| **When It Runs** | Before commit (local) | On PR/push (CI) |
| **Speed** | Fast (staged files only) | Comprehensive (full repo) |
| **Purpose** | Prevent secrets from being committed | Catch secrets that slipped through |

This **defense-in-depth** approach ensures multiple layers of security protection.
