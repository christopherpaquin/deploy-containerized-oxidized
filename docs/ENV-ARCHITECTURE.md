# 🔧 Environment-Based Configuration Architecture

This document describes the environment-based configuration system implemented in the Oxidized deployment.

---

## 📋 Overview

All deployment configuration has been externalized to a `.env` file to:

- ✅ Keep secrets out of Git
- ✅ Eliminate hardcoded values from scripts
- ✅ Provide single source of truth for configuration
- ✅ Enable easy customization per environment
- ✅ Simplify deployment across multiple instances

---

## 🏗️ Architecture

### Configuration Flow

```text
env.example (template)
    ↓ (user copies & customizes)
.env (user's configuration)
    ↓ (loaded by deploy.sh)
deploy.sh (validates & uses variables)
    ↓ (generates from templates)
oxidized.container (Quadlet file)
config (Oxidized config)
```

### File Structure

```text
repo-root/
├── env.example          # Template (committed to Git)
├── .env                  # User config (NOT in Git)
├── .gitignore            # Excludes .env
├── scripts/
│   ├── deploy.sh         # Loads .env, generates configs
│   └── validate-env.sh   # Validates .env file
├── containers/quadlet/
│   └── oxidized.container.template  # Template with {{VARS}}
└── config/oxidized/
    └── config.template   # Template with {{VARS}}
```

---

## 🔐 Security Features

### 1. Git Exclusion

`.gitignore` automatically excludes:

```gitignore
.env
.env.*
!env.example
```

### 2. Permission Enforcement

Deployment script checks and enforces:

```bash
chmod 600 .env  # Owner read/write only
```

### 3. Validation

`validate-env.sh` checks for:
- Missing required variables
- Default/weak passwords
- Insecure permissions
- Common configuration mistakes

### 4. No Secrets in Code

All sensitive data moved from code to `.env`:
- ❌ Before: `OXIDIZED_PASSWORD="changeme"` in script
- ✅ After: `OXIDIZED_PASSWORD="${OXIDIZED_PASSWORD}"` from `.env`

---

## 📁 Generated Files

The deployment script generates files from templates:

### 1. Podman Quadlet

**Template**: `containers/quadlet/oxidized.container.template`
**Output**: `/etc/containers/systemd/oxidized.container`

Variables substituted:
- `{{OXIDIZED_IMAGE}}` → Container image
- `{{OXIDIZED_UID}}` → User ID
- `{{OXIDIZED_GID}}` → Group ID
- `{{OXIDIZED_ROOT}}` → Data directory
- `{{PODMAN_NETWORK}}` → Network name
- And more...

### 2. Oxidized Config

**Template**: `config/oxidized/config.template`
**Output**: `/var/lib/oxidized/config/config`

Variables substituted:
- `{{OXIDIZED_USERNAME}}` → Device username
- `{{OXIDIZED_PASSWORD}}` → Device password
- `{{POLL_INTERVAL}}` → Polling frequency
- `{{GIT_USER_NAME}}` → Git committer name
- And more...

---

## 🛠️ Implementation Details

### Variable Loading

```bash
# In deploy.sh

load_env() {
  # Check .env exists
  if [[ ! -f "${ENV_FILE}" ]]; then
    log_error ".env file not found"
    exit 1
  fi

  # Check permissions
  if [[ "${perms: -1}" -gt 0 ]]; then
    chmod 600 "${ENV_FILE}"
  fi

  # Source variables
  source "${ENV_FILE}"
}
```

### Variable Validation

```bash
validate_env() {
  local required_vars=(
    "OXIDIZED_USER"
    "OXIDIZED_UID"
    "OXIDIZED_ROOT"
    # ... more
  )

  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      log_error "Missing: ${var}"
    fi
  done
}
```

### Template Generation

```bash
sed \
  -e "s|{{OXIDIZED_IMAGE}}|${OXIDIZED_IMAGE}|g" \
  -e "s|{{OXIDIZED_UID}}|${OXIDIZED_UID}|g" \
  -e "s|{{OXIDIZED_ROOT}}|${OXIDIZED_ROOT}|g" \
  "${template_file}" > "${output_file}"
```

---

## 🔄 Deployment Workflow

### Initial Deployment

```bash
# 1. Copy template
cp env.example .env

# 2. Edit configuration
vim .env

# 3. Validate
./scripts/validate-env.sh

# 4. Deploy
sudo ./scripts/deploy.sh
```

### Configuration Updates

```bash
# 1. Modify .env
vim .env

# 2. Validate changes
./scripts/validate-env.sh

# 3. Redeploy (regenerates configs)
sudo ./scripts/deploy.sh

# 4. Verify
sudo systemctl status oxidized
```

---

## 📊 Variable Categories

### System User (Required)

```bash
OXIDIZED_USER="oxidized"
OXIDIZED_UID=2000
OXIDIZED_GID=2000
```

### Directories (Required)

```bash
OXIDIZED_ROOT="/var/lib/oxidized"
```

### Container (Required)

```bash
OXIDIZED_IMAGE="docker.io/oxidized/oxidized:0.35.0"
CONTAINER_NAME="oxidized"
PODMAN_NETWORK="oxidized-net"
```

### Credentials (Required, SENSITIVE)

```bash
OXIDIZED_USERNAME="admin"
OXIDIZED_PASSWORD="changeme"  # MUST CHANGE!
```

### Optional Settings

```bash
POLL_INTERVAL=3600
THREADS=30
DEBUG="false"
MEMORY_LIMIT="1G"
TZ="UTC"
```

---

## 🧪 Validation Script

### Features

`scripts/validate-env.sh` performs:

#### 1. File checks

- Existence
- Permissions (600)
- Ownership

#### 2. Variable checks

- Required variables present
- Correct data types (numeric UID/GID)
- Format validation (memory, CPU)

#### 3. Security checks

- Default password detection
- Password strength
- Image pinning
- API exposure

#### 4. Path validation

- Absolute paths
- Directory ownership

### Usage

```bash
# Basic validation
./scripts/validate-env.sh

# Example output
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  .env File Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ .env file exists: /path/to/.env
✓ File permissions: 600
✓ OXIDIZED_USER is set
✗ ERROR: Default password detected
⚠ WARNING: API listening on all interfaces

Validation Summary
✗ 1 error(s) found
⚠ 1 warning(s) found
```

---

## 🔍 Troubleshooting

### ".env file not found"

```bash
# Create from template
cp env.example .env
vim .env
chmod 600 .env
```

### "Missing required environment variables"

```bash
# Compare with template
diff env.example .env

# Or re-create
mv .env .env.old
cp env.example .env
# Copy values from .env.old
```

### "Configuration not taking effect"

```bash
# 1. Verify .env is correct
./scripts/validate-env.sh

# 2. Check generated files
cat /etc/containers/systemd/oxidized.container
cat /var/lib/oxidized/config/config

# 3. Redeploy if needed
sudo ./scripts/deploy.sh
```

### "Permission denied"

```bash
# Fix .env permissions
chmod 600 .env
chown $(whoami):$(whoami) .env

# Or if deploying as root
sudo chmod 600 .env
```

---

## 📝 Best Practices

### 1. Version Control

```bash
# Commit
git add env.example              # ✅ Template
git add scripts/deploy.sh         # ✅ Scripts
git add containers/quadlet/*.template  # ✅ Templates

# DON'T commit
git add .env                      # ❌ User config
```

### 2. Multiple Environments

```bash
# Development
cp env.example .env.dev
vim .env.dev

# Production
cp env.example .env.prod
vim .env.prod

# Deploy specific env
cp .env.prod .env
sudo ./scripts/deploy.sh
```

### 3. Secrets Management

For production, consider:

- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Sealed Secrets (Kubernetes)

Integration example:

```bash
# Load from vault before deployment
vault kv get -field=password secret/oxidized > /tmp/oxidized_pass
OXIDIZED_PASSWORD=$(cat /tmp/oxidized_pass)
export OXIDIZED_PASSWORD
sudo -E ./scripts/deploy.sh
```

### 4. Backup Strategy

```bash
# Backup .env (encrypted)
tar czf oxidized-config.tar.gz .env
gpg -c oxidized-config.tar.gz
rm oxidized-config.tar.gz

# Store encrypted backup securely
mv oxidized-config.tar.gz.gpg /secure/backup/
```

---

## 🔗 Related Files

- `env.example` - Configuration template
- `scripts/deploy.sh` - Deployment script
- `scripts/validate-env.sh` - Validation script
- `containers/quadlet/oxidized.container.template` - Quadlet template
- `config/oxidized/config.template` - Oxidized config template
- `docs/CONFIGURATION.md` - Configuration guide
- `docs/SECURITY-HARDENING.md` - Security practices

---

## 📚 Migration from Hardcoded Values

### Before (Old Approach)

```bash
# In deploy.sh - BAD!
readonly OXIDIZED_ROOT="/var/lib/oxidized"
readonly OXIDIZED_PASSWORD="changeme"
readonly OXIDIZED_IMAGE="docker.io/oxidized/oxidized:latest"

# Direct file copies
cp config/oxidized/config /var/lib/oxidized/config/config
```

### After (Current Approach)

```bash
# In .env - GOOD!
OXIDIZED_ROOT="/var/lib/oxidized"
OXIDIZED_PASSWORD="secure-password-here"
OXIDIZED_IMAGE="docker.io/oxidized/oxidized:0.35.0"

# In deploy.sh
source .env
sed "s|{{OXIDIZED_ROOT}}|${OXIDIZED_ROOT}|g" template > output
```

---

## 🎯 Benefits

### 1. Security

- Secrets never in Git
- Configurable permissions
- Validation before deployment

### 2. Flexibility

- Easy multi-environment support
- No code changes needed
- Template-based generation

### 3. Maintainability

- Single source of truth
- Clear documentation
- Validation tooling

### 4. Compliance

- Audit-friendly
- Meets security standards
- Trackable changes

---

**Last Updated**: 2026-01-17
**Version**: 1.0
