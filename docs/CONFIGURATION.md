# ⚙️ Configuration Guide

This document explains how to configure Oxidized using the `.env` file.

---

## 📋 Overview

All deployment configuration is managed through the `.env` file:

- No secrets in Git
- No hardcoded IP addresses
- No embedded credentials in scripts
- Single source of truth for all configuration

---

## 🚀 Quick Start

### Create Configuration

```bash
# 1. Copy template
cp env.example .env

# 2. Edit values
vim .env

# 3. Secure the file
chmod 600 .env

# 4. Deploy
sudo ./scripts/deploy.sh
```

---

## 🔐 Security Best Practices

### File Permissions

```bash
# .env should be readable only by owner
chmod 600 .env

# Verify
ls -la .env
# Should show: -rw------- ... .env
```

### Never Commit .env

The `.env` file is automatically excluded by `.gitignore`:

```gitignore
.env
.env.*
!env.example
```

**Why?**
- Contains device credentials
- Contains IP addresses
- May contain API keys
- Prevents accidental secret exposure

---

## 📝 Configuration Categories

### 1. System User Configuration

Controls the dedicated Linux user for Oxidized:

```bash
OXIDIZED_USER="oxidized"
OXIDIZED_GROUP="oxidized"
OXIDIZED_UID=2000
OXIDIZED_GID=2000
OXIDIZED_HOME="/home/oxidized"
```

**When to change:**
- UID/GID 2000 conflicts with existing users
- Company policy requires specific UID ranges
- Multi-tenant deployments

### 2. Directory Configuration

Where Oxidized stores data:

```bash
OXIDIZED_ROOT="/var/lib/oxidized"
```

**Directory structure:**

```text
/var/lib/oxidized/
├── config/     # Configuration files
├── ssh/        # SSH keys
├── data/       # Runtime data, logs
├── output/     # Backup output
└── repo/       # Git repository
```

### 3. Container Configuration

Container image and networking:

```bash
OXIDIZED_IMAGE="docker.io/oxidized/oxidized:0.30.1"
CONTAINER_NAME="oxidized"
PODMAN_NETWORK="oxidized-net"
```

**Best practices:**
- Pin to specific version (NOT `latest`)
- Update `OXIDIZED_IMAGE` when upgrading
- Keep network name consistent

### 4. Network Configuration

API and Web UI settings:

```bash
OXIDIZED_API_PORT=8888
OXIDIZED_API_HOST="0.0.0.0"
OXIDIZED_WEB_UI="false"
```

**Options:**
- `OXIDIZED_API_HOST="0.0.0.0"` - Listen on all interfaces
- `OXIDIZED_API_HOST="127.0.0.1"` - Localhost only (more secure)
- `OXIDIZED_WEB_UI="true"` - Enable Web UI (requires port exposure)

### 5. Device Credentials

#### ⚠️ CRITICAL SECURITY SECTION

```bash
OXIDIZED_USERNAME="admin"
OXIDIZED_PASSWORD="changeme"
```

**IMPORTANT:**
- Change `OXIDIZED_PASSWORD` from default
- Use least-privilege accounts on devices
- Consider using SSH keys instead
- Rotate credentials periodically

**Using SSH Keys:**

```bash
# 1. Set in .env
SSH_PRIVATE_KEY="id_rsa"

# 2. Copy key to SSH directory
sudo cp ~/.ssh/id_rsa /var/lib/oxidized/ssh/
sudo chown 2000:2000 /var/lib/oxidized/ssh/id_rsa
sudo chmod 600 /var/lib/oxidized/ssh/id_rsa

# 3. Deploy
sudo ./scripts/deploy.sh
```

### 6. Git Configuration

Version control settings:

```bash
GIT_USER_NAME="Oxidized"
GIT_USER_EMAIL="oxidized@example.com"
```

**Customize:**
- Use company email domain
- Match your Git naming conventions

### 7. Operational Configuration

Polling and performance:

```bash
POLL_INTERVAL=3600  # 1 hour
THREADS=30
TIMEOUT=20
RETRIES=3
DEBUG="false"
```

**Tuning:**
- `POLL_INTERVAL`: Lower = more frequent backups (higher load)
- `THREADS`: Increase for many devices (watch CPU)
- `TIMEOUT`: Increase for slow/remote devices
- `DEBUG="true"`: Enable only for troubleshooting

### 8. Resource Limits

Container resource constraints:

```bash
MEMORY_LIMIT="1G"
CPU_QUOTA="100%"
```

**Sizing guidelines:**

| Devices | Memory | CPU | Notes |
|---------|--------|-----|-------|
| < 50 | 512M | 50% | Small deployment |
| 50-100 | 1G | 100% | Medium deployment |
| 100-500 | 2G | 200% | Large deployment |
| 500+ | 4G+ | 400%+ | Enterprise deployment |

---

## 🔄 Updating Configuration

### Change Requires Redeployment

Some changes require redeploying:

```bash
# 1. Update .env
vim .env

# 2. Redeploy
sudo ./scripts/deploy.sh

# 3. Verify
sudo ./scripts/health-check.sh
```

**Changes requiring redeployment:**
- UID/GID changes
- Directory paths
- Container image version
- Network configuration

### Change Requires Restart Only

Some changes only need a restart:

```bash
# 1. Update .env
vim .env

# 2. Restart service
sudo systemctl restart oxidized.service

# 3. Check logs
podman logs -f oxidized
```

**Changes requiring restart only:**
- Device credentials
- Polling interval
- Thread count
- Debug mode

---

## 🧪 Testing Configuration

### Validate .env File

```bash
# Check file exists
ls -la .env

# Check permissions
stat -c "%a %n" .env
# Should show: 600 .env

# Check for secrets (should find OXIDIZED_PASSWORD)
grep -i password .env

# Validate required variables
source .env
echo "User: $OXIDIZED_USER (UID: $OXIDIZED_UID)"
echo "Root: $OXIDIZED_ROOT"
echo "Image: $OXIDIZED_IMAGE"
```

### Dry Run Deployment

```bash
# Test without making changes
sudo ./scripts/deploy.sh --dry-run
```

---

## 📚 Example Configurations

### Minimal (Default)

```bash
OXIDIZED_UID=2000
OXIDIZED_GID=2000
OXIDIZED_ROOT="/var/lib/oxidized"
OXIDIZED_IMAGE="docker.io/oxidized/oxidized:0.30.1"
OXIDIZED_USERNAME="admin"
OXIDIZED_PASSWORD="your-secure-password"
```

### Production with SSH Keys

```bash
OXIDIZED_UID=2000
OXIDIZED_GID=2000
OXIDIZED_ROOT="/var/lib/oxidized"
OXIDIZED_IMAGE="docker.io/oxidized/oxidized:0.30.1"
OXIDIZED_USERNAME="backup-user"
OXIDIZED_PASSWORD=""  # Not used with SSH keys
SSH_PRIVATE_KEY="oxidized_rsa"
POLL_INTERVAL=3600
THREADS=50
DEBUG="false"
MEMORY_LIMIT="2G"
CPU_QUOTA="200%"
```

### High-Security (Localhost Only)

```bash
OXIDIZED_UID=3000
OXIDIZED_GID=3000
OXIDIZED_ROOT="/data/oxidized"
OXIDIZED_IMAGE="docker.io/oxidized/oxidized:0.30.1"
OXIDIZED_API_HOST="127.0.0.1"
OXIDIZED_WEB_UI="false"
OXIDIZED_USERNAME="readonly"
OXIDIZED_PASSWORD="complex-password-here"
SSH_PRIVATE_KEY="id_ed25519"
```

---

## ❓ Troubleshooting

### ".env file not found"

```bash
# Check if .env exists
ls -la .env

# Create from template if missing
cp env.example .env
vim .env
chmod 600 .env
```

### "Missing required environment variables"

```bash
# Validate .env has all required variables
diff <(grep -o '^[A-Z_]*=' env.example | sort) \
     <(grep -o '^[A-Z_]*=' .env | sort)

# Re-create from template
cp env.example .env
vim .env
```

### "Permission denied" on .env

```bash
# Fix permissions
chmod 600 .env
chown $(whoami):$(whoami) .env
```

### Configuration not taking effect

```bash
# 1. Verify .env is being loaded
sudo ./scripts/deploy.sh --verbose

# 2. Check generated files
cat /etc/containers/systemd/oxidized.container
cat /var/lib/oxidized/config/config

# 3. Restart service
sudo systemctl restart oxidized.service
```

---

## 🔗 Related Documentation

- [SECURITY-HARDENING.md](SECURITY-HARDENING.md) - Security best practices
- [INSTALL.md](INSTALL.md) - Installation guide
- [UPGRADE.md](UPGRADE.md) - Upgrade procedures
- [PREREQUISITES.md](PREREQUISITES.md) - System requirements

---

**Remember**: The `.env` file is the single source of truth for your deployment configuration.
Keep it secure, keep it updated, and never commit it to Git.
