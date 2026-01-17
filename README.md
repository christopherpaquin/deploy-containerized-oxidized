# 🤖 GitHub AI Engineering Framework

<div style="display: flex; align-items: flex-start; gap: 20px; margin-bottom: 20px;">
  <div style="flex: 0 0 25%;">
    <img src="https://chrispaquin.com/wp-content/uploads/2026/01/Nobby-the-robot.png"
         alt="Nobby the Robot" width="20%" align="left">
  </div>
  <div style="flex: 1;">
    <blockquote>
      <p>A <strong>governance-first</strong> GitHub-centric framework for
      AI-assisted software engineering framework with enforced standards, pre-commit, CI,
      and explicit operational contracts.</p>
      <p>This framework enforces security, documentation consistency, and
      quality through automated checks and explicit AI agent instructions.</p>
    </blockquote>
    <p>
      <img src="https://img.shields.io/badge/license-Apache%202.0-blue.svg" alt="License">
      <img src="https://img.shields.io/badge/python-3.11%2B-blue.svg" alt="Python">
      <img src="https://img.shields.io/badge/tested%20on-RHEL%209%2F10%20%7C%20Ubuntu%2022.04-green.svg" alt="Tested on">
      <img src="https://img.shields.io/badge/security-hardened-red.svg" alt="Security">
      <img src="https://img.shields.io/badge/governance-documentation%20driven-purple.svg" alt="Governance">
      <img src="https://img.shields.io/badge/AI-Governed-critical" alt="AI-Governed">
    </p>
  </div>
</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [How This Repository Works](#-how-this-repository-works)
- [Governance: Security and Documentation](#-governance-security-and-documentation)
- [Requirements / Dependencies](#-requirements--dependencies)
- [High-Level Architecture](#-high-level-architecture-overview)
- [Installation](#-installation)
- [Usage Examples](#-usage-examples)
- [Configuration](#-configuration)
- [Troubleshooting](#-troubleshooting)
- [Security Notes](#-security-notes)

---

## 🎯 Overview

This repository provides a structured foundation for AI-assisted development
projects. Unlike traditional templates, this framework treats
**documentation as executable instructions** for AI agents. All AI tools
(Cursor, ChatGPT, Copilot, etc.) are required to follow the standards
defined in `docs/ai/CONTEXT.md`, making documentation the authoritative
governance mechanism.

### Core Philosophy

**Governance through Documentation**: In this framework, documentation serves
dual purposes:

- ✅ **Human-readable guidance** for developers and operators
- ✅ **Machine-readable instructions** for AI agents

The documentation files (`docs/ai/CONTEXT.md`, `docs/requirements.md`) are not
suggestions—they are **mandatory behavioral contracts** that AI agents must
follow. This approach ensures consistency, security, and maintainability
across all AI-assisted development work.

---

## ⚙️ How This Repository Works

### Understanding the Framework Structure

This repository serves as both:
1. **A GitHub Template**: Use it to create new repositories with the framework
2. **A Working Framework**: Once created, it provides governance and quality enforcement

### 1. Template Structure

When you use this template, you get a complete framework with:

| Component | Status | Description |
|-----------|--------|-------------|
| ✅ Governance Documentation | Included | Standards and requirements that AI agents must follow |
| ✅ Security Enforcement | Included | Strict `.gitignore` policies and pre-commit hooks |
| ✅ Quality Gates | Included | Automated formatting, linting, and safety checks |
| ✅ Consistent Standards | Included | Bash, Python, YAML, and JSON formatting rules |
| ✅ CI/CD Pipeline | Included | Automated testing and quality checks on every PR |
| ✅ Issue & PR Templates | Included | Structured templates for bug reports and features |
| ✅ Helper Scripts | Included | Pre-commit wrapper and secret detection |

### File Relationships and Workflow

**Core Governance Files**:

```text
docs/ai/CONTEXT.md (Authoritative)
    ↓
    ├─→ Defines AI agent behavior standards
    ├─→ Referenced by: README.md, scripts, CI
    └─→ Must be followed by all AI tools

docs/requirements.md (Project Contract)
    ↓
    ├─→ Defines project-specific requirements
    ├─→ Maps to acceptance criteria
    └─→ Updated before implementation

README.md (User Documentation)
    ↓
    ├─→ Human-readable project overview
    ├─→ References CONTEXT.md standards
    └─→ Provides usage examples
```

**Quality Enforcement Chain**:

```text
Developer/AI Agent
    ↓
    Makes changes
    ↓
    Runs: ./scripts/run-precommit.sh
    ↓
    Pre-commit hooks execute:
    ├─→ Formatting (Ruff, shfmt)
    ├─→ Linting (ShellCheck, PyMarkdown)
    ├─→ Secret detection (detect-secrets.sh)
    └─→ Safety checks (private keys, merge conflicts)
    ↓
    If passes → Commit succeeds
    If fails → Commit blocked, review artifacts/pre-commit.log
    ↓
    Push to GitHub
    ↓
    CI runs same checks (cannot be bypassed)
    ↓
    If CI passes → PR can be merged
```

### 2. AI Agent Workflow

AI agents working in this repository follow a strict workflow:

- [x] **Read Governance Documents First**: `docs/ai/CONTEXT.md` and `docs/requirements.md` are authoritative
- [x] **Respect Security Boundaries**: `.gitignore` is strictly enforced—violations are security defects
- [x] **Execute Quality Checks**: Pre-commit must pass using `./scripts/run-precommit.sh`
- [x] **Update Documentation**: Changes must be reflected in documentation

### 3. Governance Enforcement

Governance is enforced through multiple layers:

| Layer | Mechanism | Purpose | Status |
|-------|-----------|---------|--------|
| 📚 **Documentation** | `docs/ai/CONTEXT.md`, `docs/requirements.md` | Defines mandatory AI behavior | ✅ Active |
| 🔍 **Pre-commit** | `.pre-commit-config.yaml` | Catches issues before commit (formatting, linting, secrets) | ✅ Active |
| 🚀 **CI/CD** | `.github/workflows/ci.yaml` | Enforces checks cannot be skipped, runs on all PRs | ✅ Active |
| 🔒 **Security** | `.gitignore` | Prevents secrets and artifacts from being committed | ✅ Active |

---

## 🛡️ Governance: Security and Documentation

### 🔐 Security Governance

Security is the **highest priority** in this framework. All contributors and AI agents must adhere to strict security standards.

#### Credentials and Secrets Management

> ⚠️ **Critical Rule**: Credentials, secrets, and sensitive configuration **must never** be committed to the repository.

**How Secrets Are Handled**:

1. **Environment Files**: All secrets must be stored in `.env` files (or equivalent)
   - ❌ `.env` files are **never** committed (enforced by `.gitignore`)
   - ✅ `.env.example` files **must** be committed to document required variables
   - ✅ Example files contain placeholder values, never real secrets

2. **What Is Protected**: The `.gitignore` file protects:

   | Category | Protected Items | Status |
   |----------|----------------|--------|
   | 🔑 Environment Files | `.env`, `.env.*`, `vars.env` | ✅ Protected |
   | 🔐 Credential Files | `.pem`, `.key`, `.crt`, `.pfx`, `.p12`, SSH keys | ✅ Protected |
   | ☁️ Cloud Credentials | `.aws/`, `.gcp/`, `.azure/`, `terraform.tfvars` | ✅ Protected |
   | 🚫 Generic Secrets | `secrets.*`, `*.secret`, `*.secrets` | ✅ Protected |

3. **AI Agent Requirements**: AI agents must:

   - [x] Read `.gitignore` before creating or modifying files
   - [x] Never create, move, or commit ignored files
   - [x] Never log, echo, or persist secret values
   - [x] Use example files (e.g., `.env.example`) for documentation only
   - [x] Treat violations of `.gitignore` rules as security defects

4. **Security Standards from CONTEXT.md**:

   - ❌ Never log secrets
   - ❌ Credentials and IP addresses must never be hardcoded—use `.env` files
   - ✅ Treat all inputs as untrusted
   - ✅ Use least privilege
   - ✅ Sanitize file paths and user input
   - ✅ Document required permissions

#### Security Enforcement

| Enforcement Method | Status | Description |
|-------------------|--------|-------------|
| 🔍 Pre-commit hooks | ✅ Active | Detect private keys and other secrets before commit |
| 🚀 CI workflows | ✅ Active | Run the same checks to prevent bypassing local checks |
| 📋 `.gitignore` is authoritative | ✅ Active | AI agents must respect it without exception |

### 📚 Documentation Governance

Documentation in this repository serves as **executable instructions** for AI agents. This creates a governance model where:

1. ✅ **Documentation Defines Behavior**: `docs/ai/CONTEXT.md` contains mandatory standards that AI agents must follow
2. ✅ **Requirements Are Contracts**: `docs/requirements.md` defines the behavioral contract for the project
3. ✅ **Consistency Is Enforced**: All projects using this framework follow the same documentation structure
4. ✅ **AI Agents Are Accountable**: AI agents cannot deviate from documented standards without explicit clarification

#### Documentation Structure

| File | Purpose | Audience | Status |
|------|---------|----------|--------|
| `docs/ai/CONTEXT.md` | Mandatory AI behavior standards | AI agents (authoritative) | ✅ Required |
| `docs/requirements.md` | Project requirements and acceptance criteria | AI agents, developers | ✅ Required |
| `docs/ci-and-precommit.md` | Quality enforcement mechanisms | Developers, operators | ✅ Required |
| `docs/governance/` | Project-specific governance documents | All stakeholders | ⚠️ Optional |
| `README.md` | Project overview and usage | All stakeholders | ✅ Required |

**Documentation Hierarchy**:

1. **`docs/ai/CONTEXT.md`** is **authoritative** for AI agents
   - Defines mandatory behavior standards
   - Referenced by all other documentation
   - Must be followed without exception

2. **`docs/requirements.md`** defines the project contract
   - Maps requirements to acceptance criteria
   - Must be updated before implementation
   - Guides AI agent development work

3. **`README.md`** provides human-readable guidance
   - Explains how to use the framework
   - Documents configuration and usage
   - References CONTEXT.md for AI agent instructions

4. **`docs/governance/`** is for project-specific governance
   - Empty by default
   - Add custom governance documents as needed
   - Examples: coding standards, review processes, etc.

#### Documentation Requirements

Per `docs/ai/CONTEXT.md`, all projects must include:

- ✅ **README.md** with: overview, tested-on shields, requirements/dependencies,
  architecture overview, installation, uninstall steps, usage examples,
  configuration, troubleshooting, security notes, license
- ✅ **docs/runbook.md** for operational tools
- ✅ **Consistent formatting** enforced by pre-commit (Markdown linting)

---

## 📦 Requirements / Dependencies

### System Requirements

| Requirement | Version | Status |
|-------------|---------|--------|
| 🐧 **Primary OS** | RHEL 9 / RHEL 10 | ✅ Required |
| 🐧 **Secondary OS** | Ubuntu 22.04 | ⚠️ Best-effort |
| 🐚 **Shell** | bash | ✅ Required |
| 🐍 **Python** | 3.11+ | ✅ Required |

### Development Dependencies

- ✅ `pre-commit` (for quality checks)
- ✅ Python packages as defined in `requirements.txt` or `requirements-dev.txt` (if present)

### Tools Used

| Tool | Purpose | Status |
|------|---------|--------|
| 🐍 **Ruff** | Python linting and formatting | ✅ Active |
| 🐚 **ShellCheck** | Bash script linting | ✅ Active |
| 📝 **shfmt** | Bash script formatting | ✅ Active |
| 📄 **PyMarkdown** | Markdown validation | ✅ Active |

---

## 🏗️ High-Level Architecture Overview

<div style="display: flex; align-items: flex-start; gap: 20px; margin-bottom: 20px;">
  <div style="flex: 0 0 25%;">
    <img src="https://chrispaquin.com/wp-content/uploads/2026/01/framework-flow.png"
         alt="Nobby the Robot" width="60%" align="center">
  </div>

**Key Components**:

1. 📚 **Governance Layer**: Documentation files that define mandatory behavior
2. 🔒 **Security Layer**: `.gitignore` and pre-commit hooks that prevent secret leakage
3. 🤖 **AI Agent Layer**: AI tools that follow governance documentation
4. ✅ **Quality Gate Layer**: Automated checks that enforce standards

---

## 🚀 Installation

### How This Template Works

This is a **GitHub Template Repository**. When you use it, GitHub creates a new
repository with all the files from this template, giving you a complete
framework for AI-assisted development with governance, security, and quality
enforcement built-in.

**Template Workflow**:

1. **Create Repository**: Use GitHub's "Use this template" button
2. **Clone & Setup**: Clone your new repo and set up pre-commit
3. **Customize**: Populate project-specific files and documentation
4. **Start Developing**: Begin using the framework with AI agents

### Step 1: Use This Template

- [ ] Click **"Use this template"** on GitHub
- [ ] Choose a repository name and description
- [ ] Select public or private visibility
- [ ] Click **"Create repository from template"**

This creates a new repository with all framework files:
- ✅ Directory structure (`docs/`, `.github/`, `scripts/`)
- ✅ Configuration files (`.pre-commit-config.yaml`, `.gitignore`, etc.)
- ✅ Documentation templates (`CONTEXT.md`, `requirements.md`)
- ✅ CI/CD workflows (`.github/workflows/ci.yaml`)
- ✅ Helper scripts (`run-precommit.sh`, `detect-secrets.sh`)
- ✅ Issue and PR templates

### Step 2: Clone Your New Repository

```bash
git clone <your-new-repo-url>
cd <your-repo-name>
```

### Step 3: Set Up Pre-commit

```bash
pip install pre-commit
pre-commit install
```

**Verification Checklist**:

- [ ] Pre-commit is installed
- [ ] Pre-commit hooks are installed
- [ ] Run `./scripts/run-precommit.sh` to verify setup

### Step 4: Populate Project-Specific Files

**Required Customization**:

- [ ] **`docs/requirements.md`**: Define your project's requirements and acceptance criteria
  - Use the template structure provided
  - Document functional and non-functional requirements
  - Define acceptance criteria for each requirement
- [ ] **`.env.example`**: Create an example environment file documenting required variables
  - List all environment variables your project needs
  - Use placeholder values (e.g., `YOUR_API_KEY_HERE`)
  - Document what each variable is for
- [ ] **`README.md`**: Update with your project-specific information
  - Replace framework description with your project description
  - Update architecture diagram (if using image)
  - Customize installation and usage sections

**Optional Customization**:

- [ ] **`docs/governance/`**: Add project-specific governance documents
- [ ] **`docs/runbook.md`**: Create operational runbook (if applicable)
- [ ] **Issue Templates**: Customize `.github/ISSUE_TEMPLATE/` files if needed
- [ ] **PR Template**: Customize `.github/pull_request_template.md` if needed

### Step 5: Bootstrap Structure (Optional)

The `bootstrap-template-structure.sh` script recreates the template's directory
structure and empty placeholder files. Use it if:

- You accidentally deleted framework files
- You want to add the structure to an existing repository
- You need to restore the template structure

**What It Creates**:

**Directories**:
- `docs/`, `docs/ai/`, `docs/governance/`
- `.github/`, `.github/workflows/`, `.github/ISSUE_TEMPLATE/`
- `scripts/`

**Files** (empty placeholders):
- `README.md`, `LICENSE`, `.gitignore`
- `.pre-commit-config.yaml`, `.pymarkdown.json`
- `docs/ai/CONTEXT.md`, `docs/requirements.md`, `docs/ci-and-precommit.md`
- `.github/workflows/ci.yaml`
- `.github/pull_request_template.md`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `scripts/run-precommit.sh`, `scripts/detect-secrets.sh`

**Usage**:

```bash
./bootstrap-template-structure.sh
```

**Note**: The script will **not overwrite** existing files—it only creates missing
files and directories.

---

## 🗑️ Uninstall Steps

To remove this framework's infrastructure from a project:

### Step 1: Remove Pre-commit Hooks

```bash
pre-commit uninstall
```

### Step 2: Remove Template-Specific Files (Optional)

- [ ] `.pre-commit-config.yaml`
- [ ] `.github/workflows/ci.yaml`
- [ ] `docs/ai/CONTEXT.md`
- [ ] `scripts/run-precommit.sh`

### Step 3: Remove Pre-commit Package (Optional)

```bash
pip uninstall pre-commit
```

> 💡 **Note**: Consider keeping the governance documentation and quality checks even if removing other template components.

---

## 💡 Usage Examples

### Working with AI Agents

When instructing AI agents to work on this repository, always include:

```markdown
Please follow the standards in docs/ai/CONTEXT.md and implement
the requirements in docs/requirements.md. Ensure pre-commit passes
before completing the work.
```

### Understanding the Artifacts Directory

The `artifacts/` directory is automatically created and ignored by git. It
contains:

- **`pre-commit.log`**: Detailed output from pre-commit runs
  - Created by `scripts/run-precommit.sh`
  - Contains full hook output for debugging
  - Useful for AI agents to review failures
  - Uploaded as CI artifact on failure

**Note**: The `artifacts/` directory is in `.gitignore` and should never be
committed.

### Using Issue Templates

The framework includes structured issue templates:

**Bug Reports** (`.github/ISSUE_TEMPLATE/bug_report.yml`):
- Requires: Summary, reproduction steps, expected/actual behavior, environment
- Automatically labels issues as "bug"

**Feature Requests** (`.github/ISSUE_TEMPLATE/feature_request.yml`):
- Requires: Problem statement, desired outcome, acceptance criteria
- Automatically labels issues as "enhancement"
- Encourages requirement documentation before implementation

### Using the Pull Request Template

The PR template (`.github/pull_request_template.md`) ensures:

- ✅ Requirements coverage is documented
- ✅ Acceptance criteria are verified
- ✅ Security and safety checks are confirmed
- ✅ Testing evidence is provided
- ✅ Documentation is updated

This template enforces the discipline required by `docs/ai/CONTEXT.md` Section 10.

### Running Pre-commit Checks

**✅ Recommended method** (for AI-assisted workflows):

```bash
./scripts/run-precommit.sh
```

**What this script does**:

- ✅ Runs all pre-commit hooks
- ✅ Captures output to `artifacts/pre-commit.log` for AI review
- ✅ Preserves correct exit codes

**Alternative method** (automatic on commit):

```bash
git commit -m "Your message"
# Pre-commit runs automatically if installed
```

### Creating Environment Files

**Step-by-step checklist**:

1. [ ] Copy the example file:

   ```bash
   cp .env.example .env
   ```

2. [ ] Edit `.env` with your actual values (never commit this file)
3. [ ] Verify `.env` is in `.gitignore` (it should be automatically ignored)

---

## ⚙️ Configuration

### Pre-commit Configuration

Pre-commit hooks are configured in `.pre-commit-config.yaml`. The default configuration includes:

| Category | Tools | Status |
|----------|-------|--------|
| 🔍 Basic checks | merge conflicts, YAML/JSON validation, trailing whitespace | ✅ Active |
| 🐍 Python | Ruff linting and formatting | ✅ Active |
| 🐚 Bash | ShellCheck and shfmt formatting | ✅ Active |
| 📄 Markdown | PyMarkdown validation | ✅ Active |
| 🔒 Security | Private key detection, API key detection, token scanning | ✅ Active |

#### Secret Detection

The framework includes comprehensive secret detection via `scripts/detect-secrets.sh`:

**What It Detects**:

- ✅ API keys (Stripe, OpenAI, Google, AWS, etc.)
- ✅ GitHub tokens (PATs, OAuth tokens)
- ✅ Cloud provider credentials (AWS, GCP, Azure)
- ✅ Private keys (SSH, TLS, signing keys)
- ✅ OAuth tokens and refresh tokens
- ✅ JWT tokens
- ✅ High-entropy strings (potential secrets)

**False Positive Filtering**:

- ✅ Ignores variable names (e.g., `api_key =`)
- ✅ Ignores example/placeholder values
- ✅ Ignores URLs and API endpoints
- ✅ Ignores comments and documentation
- ✅ Excludes test files and example files

If secrets are detected, the commit will be blocked. Use example placeholders like
`YOUR_API_KEY_HERE` instead of real secrets.

### CI/CD Configuration

This framework includes **two complementary CI workflows** that run in parallel:

1. **`ci.yaml`**: Code quality and testing (pre-commit checks, unit tests)
2. **`security-ci.yml`**: Security scanning (secret detection, SAST, dependency scanning)

#### Main CI Workflow (`ci.yaml`)

The main CI workflow consists of two jobs that run sequentially:

**Job 1: Pre-commit Checks** (runs first):

- ✅ Runs on all pull requests and pushes to `main`
- ✅ Executes all pre-commit hooks (formatting, linting, secret detection)
- ✅ Uses Python 3.11 on Ubuntu latest
- ✅ If checks fail, generates detailed log via `scripts/run-precommit.sh`
- ✅ Uploads pre-commit log as artifact for review (only on failure)

**Job 2: Unit Tests** (runs after pre-commit passes):

- ✅ Only runs if pre-commit job succeeds
- ✅ Conditionally installs dependencies:
  - Installs from `requirements.txt` if present
  - Installs from `requirements-dev.txt` if present
  - Installs `pytest` only if `tests/` directory exists
- ✅ Runs `pytest` if tests exist, otherwise skips gracefully
- ✅ Ensures code quality before running tests

**Key Features**:

- 🔒 **Cannot be bypassed**: All checks run in CI, preventing skipped local checks
- 📋 **Artifact logging**: Failed pre-commit runs generate downloadable logs
- ⚡ **Efficient**: Tests only run if pre-commit passes
- 🔄 **Consistent**: Same checks run locally and in CI

#### Security CI Workflow (`security-ci.yml`)

The security CI workflow runs **in parallel** with the main CI workflow and
provides comprehensive security scanning. This workflow is **automatically
triggered** on every pull request and push to `main`, and can also be run
manually via `workflow_dispatch`.

**When It Runs**:

- ✅ **Automatically** on every pull request (all branches)
- ✅ **Automatically** on every push to `main` branch
- ✅ **Manually** via GitHub Actions UI (`workflow_dispatch`)

**Job 1: Gitleaks Secret Scanning**:

**What It Scans**:
- Full git history (including all commits, not just current changes)
- All file types in the repository
- Known secret patterns (API keys, tokens, credentials, private keys)
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
- Catches secrets that may have slipped through pre-commit
- Scans full git history (pre-commit only scans staged files)
- Provides comprehensive coverage of all repository content

**Job 2: Semgrep SAST (Static Application Security Testing)**:

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
  - And many more security anti-patterns

**How It Notifies**:
- 📊 **GitHub Security Tab**: Results uploaded as SARIF format
  - Navigate to: Repository → Security → Code scanning alerts
  - View detailed findings with code locations
  - See severity levels and remediation guidance
- 📋 **Workflow Logs**: Detailed output in GitHub Actions logs
- ⚠️ **Workflow Status**: May fail if critical issues are found (configurable)
- 🔔 **GitHub Notifications**: Security alerts appear in repository security
  dashboard

**Why It's Needed**:
- Detects security vulnerabilities in code patterns
- Identifies OWASP Top 10 risks before deployment
- Provides actionable remediation guidance
- Integrates with GitHub's security features

**Job 3: OSV-Scanner Dependency Vulnerability Scanning**:

**What It Scans**:
- **Dependency files**: Automatically detects and scans:
  - `requirements.txt`, `requirements-dev.txt` (Python)
  - `package.json`, `package-lock.json` (Node.js)
  - `poetry.lock`, `Pipfile.lock` (Python package managers)
  - `go.mod`, `go.sum` (Go)
  - `Cargo.lock` (Rust)
  - `Gemfile.lock` (Ruby)
  - And many other dependency lock files
- **Open Source Vulnerabilities (OSV) Database**: Checks against known
  vulnerabilities in open source packages
- **Transitive dependencies**: Scans entire dependency tree, not just direct
  dependencies

**How It Notifies**:
- 📦 **Workflow Artifact**: JSON report uploaded as `osv-scan-results`
  - Download from workflow run page
  - Contains detailed vulnerability information
  - Includes affected packages, severity, and remediation steps
- 📋 **Workflow Logs**: Summary output in GitHub Actions logs
- ⚠️ **Workflow Status**: Fails if critical vulnerabilities are found
- 🔔 **GitHub Dependabot Integration**: Results complement Dependabot alerts

**Why It's Needed**:
- Identifies known vulnerabilities in dependencies
- Prevents vulnerable packages from being deployed
- Provides early warning of security issues in third-party code
- Complements GitHub's native dependency scanning

**Key Features**:

- 🔒 **Defense in Depth**: Multiple layers of security scanning
- 📊 **GitHub Integration**: SARIF results appear in Security tab
- ⚡ **Parallel Execution**: Runs simultaneously with main CI (faster)
- 🔍 **Comprehensive**: Covers secrets, code vulnerabilities, and dependencies
- 🚫 **Non-Bypassable**: Runs automatically on all PRs and pushes
- 📈 **Actionable Results**: Detailed findings with remediation guidance

**Workflow Status and PR Requirements**:

- Both `CI` and `Security CI` workflows must pass for PRs to be mergeable
- Security failures block PR merge until issues are resolved
- Workflow status appears in PR checks section
- Detailed logs available in GitHub Actions tab

**Viewing Results**:

1. **Workflow Logs**: GitHub Actions → Workflows → Security CI → View run
2. **Security Tab**: Repository → Security → Code scanning alerts (Semgrep)
3. **Artifacts**: Workflow run page → Artifacts (OSV-Scanner results)
4. **PR Checks**: PR page shows workflow status and links to details

**Note**: See `docs/security-ci-review.md` for detailed integration guidance and
best practices.

### Markdown Configuration

Markdown linting rules are configured in `.pymarkdown.json`:

| Rule | Setting | Status |
|------|---------|--------|
| Line length | 120 characters | ✅ Active |
| Headers | First line doesn't need to be a header (md041 disabled) | ✅ Active |
| Blank lines | Required around lists and headers | ✅ Active |
| Inline HTML | Allowed (for image sizing) | ✅ Active |

---

## 🔧 Troubleshooting

### Pre-commit Fails

**Troubleshooting checklist**:

1. [ ] **Review the log**: Check `artifacts/pre-commit.log` for detailed error messages
2. [ ] **Auto-fix issues**: Many hooks auto-fix issues—run pre-commit again
3. [ ] **Manual fixes**: Address remaining issues manually
4. [ ] **CI failures**: Same checks run in CI—fix locally first

### Secrets Detected in Pre-commit

**If pre-commit detects secrets**:

1. [ ] **Verify it's a false positive**: Some patterns may match non-secrets
2. [ ] **If real secret**: Remove it immediately, rotate the credential
3. [ ] **Check git history**: Use `git log` to see if it was ever committed
4. [ ] **Clean history if needed**: Consider using `git filter-branch` or BFG Repo-Cleaner

### AI Agent Not Following Standards

**If an AI agent violates standards**:

1. [ ] **Explicitly reference CONTEXT.md**: "Please follow docs/ai/CONTEXT.md section X"
2. [ ] **Point to specific rules**: Quote the exact standard being violated
3. [ ] **Re-run pre-commit**: Quality gates will catch many violations

---

## 🔒 Security Notes

### Security-First Design

This framework is designed with security as the highest priority:

| Security Feature | Status | Description |
|-----------------|--------|-------------|
| 🔐 Secrets Protection | ✅ Active | Comprehensive `.gitignore` prevents accidental secret commits |
| 🔍 Pre-commit Detection | ✅ Active | Pre-commit hooks detect secrets via `detect-secrets.sh` |
| 🔒 CI Secret Scanning | ✅ Active | Gitleaks scans full git history in CI (defense in depth) |
| 🛡️ SAST Scanning | ✅ Active | Semgrep performs static security analysis (OWASP, security audit) |
| 📦 Dependency Scanning | ✅ Active | OSV-Scanner checks dependencies for known vulnerabilities |
| 🛡️ Least Privilege | ✅ Active | All scripts should use least privilege principles |
| ✅ Input Validation | ✅ Active | All inputs should be treated as untrusted |
| 📋 Audit Trail | ✅ Active | Pre-commit logs and CI artifacts provide audit trails |

### Security Best Practices

**Do's** ✅:

- ✅ Always use `.env` files or secure secret management
- ✅ Rotate credentials if a secret is ever exposed
- ✅ Review `.gitignore` to ensure all sensitive files are covered
- ✅ Use example files to document required variables in `.env.example`

**Don'ts** ❌:

- ❌ Never hardcode credentials
- ❌ Never log secrets
- ❌ Never commit `.env` files or secrets

### Reporting Security Issues

If you discover a security vulnerability in this framework:

1. ❌ **Do not** open a public issue
2. ✅ Contact the repository maintainers privately
3. ✅ Include details about the vulnerability and potential impact

---

## 📄 License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for full text.

---

## 📚 Key Files Reference

| File | Purpose | Status |
|------|---------|--------|
| `docs/ai/CONTEXT.md` | **Authoritative** AI behavior standards (mandatory for AI agents) | ✅ Required |
| `docs/requirements.md` | Project requirements and acceptance criteria | ✅ Required |
| `.gitignore` | **Authoritative** security rules (secrets, artifacts) | ✅ Required |
| `.pre-commit-config.yaml` | Quality check configuration | ✅ Required |
| `.github/workflows/ci.yaml` | CI/CD pipeline definition | ✅ Required |
| `scripts/run-precommit.sh` | Pre-commit execution wrapper (use this, not `pre-commit` directly) | ✅ Required |
| `scripts/detect-secrets.sh` | Secret detection script (runs automatically via pre-commit) | ✅ Required |
| `bootstrap-template-structure.sh` | Recreate template structure | ✅ Optional |

---

## 🤝 Contributing

When contributing to this framework:

- [x] Follow all standards in `docs/ai/CONTEXT.md`
- [x] Ensure pre-commit passes: `./scripts/run-precommit.sh`
- [x] Update documentation if adding new features
- [x] Maintain backward compatibility where possible
- [x] Test on both RHEL 9/10 and Ubuntu 22.04

---

## 🔗 Additional Resources

- 📖 [Pre-commit Documentation](https://pre-commit.com/)
- 🐍 [Ruff Documentation](https://docs.astral.sh/ruff/)
- 🐚 [ShellCheck Documentation](https://www.shellcheck.net/)
- 📜 [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)
