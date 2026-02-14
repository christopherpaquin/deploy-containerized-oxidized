# 🤖 Containerized Oxidized Deployment for RHEL

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![RHEL 10](https://img.shields.io/badge/RHEL-10-red.svg)](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux)
[![RHEL 9](https://img.shields.io/badge/RHEL-9-red.svg)](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux)
[![Podman](https://img.shields.io/badge/Podman-4.x+-purple.svg)](https://podman.io/)
[![SELinux](https://img.shields.io/badge/SELinux-Enforcing-green.svg)](https://github.com/SELinuxProject)

Production-grade deployment framework for running [Oxidized](https://github.com/yggdrasil-network/oxidized)
as a containerized service on RHEL 10/9 using **Podman Quadlets** and **systemd**.

**For Oxidized usage and configuration**, see [docs/README-OXIDIZED.md](docs/README-OXIDIZED.md).

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Requirements](#-requirements)
- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Management Scripts](#-management-scripts)
- [Uninstallation](#-uninstallation)
- [Security](#-security)
- [Documentation](#-documentation)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

This repository provides automated deployment scripts and configuration templates for running Oxidized (network device configuration backup tool) as a containerized service on RHEL.

### What is Oxidized?

Oxidized is a network device configuration backup tool that automatically backs up network device
configurations, tracks changes using Git, and supports 130+ device models.

**Full Oxidized documentation**: [docs/README-OXIDIZED.md](docs/README-OXIDIZED.md)

### Why This Repository?

- ✅ **Production-ready**: Designed for enterprise RHEL environments
- ✅ **Systemd integrated**: Auto-starts on boot via Podman Quadlets
- ✅ **SELinux compatible**: Works with enforcing mode out of the box
- ✅ **Version pinned**: Stable, predictable releases
- ✅ **Automated deployment**: Single script deployment with validation
- ✅ **Fully documented**: Step-by-step guides and runbooks
- ✅ **Idempotent**: Safe to re-run and upgrade

---

## ✨ Features

### 🚀 Deployment

- **Podman Quadlets**: Declarative systemd-managed containers
- **Automatic startup**: Starts on boot, restarts on failure
- **Persistent storage**: All data survives container recreation
- **SELinux enforcing**: No custom policies required
- **Version pinned**: Explicit image versions, no `latest` tag
- **Idempotent scripts**: Safe to re-run deployment

### 📦 Data Management

- **Git versioning**: Every config change tracked automatically
- **CSV inventory**: Simple, colon-delimited device list (`router.db`)
- **Log rotation**: Automated via logrotate
- **Backup procedures**: Local git + optional remote repository (GitHub/GitLab)

### 🔍 Monitoring & Management

- **Health check script**: Automated validation
- **REST API**: JSON endpoints for status and metrics
- **Web UI**: View configs and diffs in browser
- **Zabbix ready**: Pre-built monitoring templates

### 🛡️ Security

- **Container isolation**: Strong namespace and cgroup isolation
- **SELinux enforcing**: Proper context labeling (`:Z` mounts)
- **Isolated storage**: Dedicated paths under `/var/lib/oxidized`
- **No secrets in repo**: Credentials managed via `.env` file
- **Secret removal**: Automatically strips passwords, SNMP strings, and keys from backups ([docs](https://github.com/ytti/oxidized/blob/master/docs/Configuration.md#removing-secrets))
- **DNS disabled**: Prevents DNS-based attacks, uses IP addresses only
- **Minimal capabilities**: Only SETUID/SETGID for init system
- **NoNewPrivileges**: Prevents privilege escalation

**Note**: See [SECURITY-HARDENING.md](docs/SECURITY-HARDENING.md) for complete security documentation.

---

## 🏗️ Architecture

### High-Level Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                      RHEL 10/9 Host                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              systemd (Quadlets)                     │   │
│  │                                                     │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │    Podman Container (oxidized:0.35.0)       │  │   │
│  │  │                                              │  │   │
│  │  │  🤖 Oxidized Service                         │  │   │
│  │  │     ├─ REST API (port 8888)                 │  │   │
│  │  │     ├─ Web UI                               │  │   │
│  │  │     ├─ Polling Engine (hourly)              │  │   │
│  │  │     └─ Git Output                           │  │   │
│  │  │                                              │  │   │
│  │  │  Volumes (bind mounts with :Z)              │  │   │
│  │  │     /var/lib/oxidized/config  ← config      │  │   │
│  │  │     /var/lib/oxidized/ssh     ← keys        │  │   │
│  │  │     /var/lib/oxidized/data    ← logs        │  │   │
│  │  │     /var/lib/oxidized/output  ← backups     │  │   │
│  │  │     /var/lib/oxidized/repo    ← git         │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  📁 Host Persistent Storage: /var/lib/oxidized/            │
│     ├── config/         (Oxidized configuration)           │
│     │   ├── config      (main config file)                 │
│     │   └── router.db   (device inventory)                 │
│     ├── ssh/            (SSH keys)                         │
│     ├── data/           (runtime data & logs)              │
│     ├── output/         (backup output)                    │
│     └── repo/           (Git repository)                   │
│                                                             │
│  🔄 logrotate: /etc/logrotate.d/oxidized                   │
│  🎯 Quadlet: /etc/containers/systemd/oxidized.container    │
└─────────────────────────────────────────────────────────────┘
              │                              │
              │ SSH/Telnet                   │ HTTP
              ▼                              ▼
    ┌──────────────────┐          ┌──────────────────┐
    │  Network Devices │          │  Monitoring      │
    │  (routers,       │          │  (Zabbix, etc.)  │
    │   switches,      │          │                  │
    │   firewalls)     │          │  🔍 API Polling  │
    └──────────────────┘          └──────────────────┘
```

### Key Components

- **Podman Quadlets**: Systemd-native container management
- **SELinux Context**: All mounts properly labeled (`:Z`)
- **Persistent Storage**: All data under `/var/lib/oxidized`
- **Device Inventory**: CSV file at `/var/lib/oxidized/config/router.db`
- **Git Repository**: Version-controlled configs at `/var/lib/oxidized/repo`

---

## 📋 Requirements

### Operating System

| Platform | Status | Notes |
|----------|--------|-------|
| **RHEL 10** | ✅ Primary | Fully tested |
| **RHEL 9** | ✅ Secondary | Supported |

### Software Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| **podman** | 4.x+ | Container runtime |
| **systemd** | 247+ | Quadlet support |
| **git** | 2.x+ | Version control |
| **logrotate** | Any | Log rotation |

### System Requirements

| Resource | Minimum | Recommended | Notes |
|----------|---------|-------------|-------|
| **CPU** | 1 core | 2+ cores | More threads = faster backups |
| **RAM** | 512 MB | 1 GB | Depends on device count |
| **Disk** | 2 GB | 10 GB | Grows with config history |
| **Network** | SSH/Telnet | Outbound only | To devices |

### Network Requirements

- **Outbound**: SSH (22) and/or Telnet (23) to network devices
- **Optional**: Port 8888 for Web UI/API (inbound, if remote access needed)

---

## 🚀 Quick Start

### Automated Deployment (Recommended)

**Complete deployment in 5 minutes:**

```bash

# 1. Clone repository

git clone https://github.com/christopherpaquin/deploy-containerized-oxidized.git
cd deploy-containerized-oxidized

# 2. Create .env file

cp env.example .env
chmod 600 .env

# 3. Edit .env (REQUIRED: change OXIDIZED_PASSWORD)

vim .env

# 4. Validate configuration

./scripts/validate-env.sh

# 5. Deploy (creates user, directories, installs service)

sudo ./scripts/deploy.sh

# 6. Verify deployment

sudo ./scripts/health-check.sh
```

**Post-deployment**:

```bash
# Add devices interactively (recommended)
sudo /var/lib/oxidized/scripts/add-device.sh

# OR manually edit device inventory
sudo cp inventory/router.db.template /var/lib/oxidized/config/router.db
sudo vim /var/lib/oxidized/config/router.db
sudo chown 30000:30000 /var/lib/oxidized/config/router.db
sudo chmod 644 /var/lib/oxidized/config/router.db

# Reload devices (no restart needed)
curl -X GET http://127.0.0.1:8889/reload

# Check status
sudo systemctl status oxidized.service
```

> **📝 IMPORTANT: Test Device Included**
>
> The `router.db.template` includes a **test device** entry:
> ```
> test-device:192.0.2.1:ios:testing::
> ```
>
> **Purpose**: This dummy device (using non-routable TEST-NET IP) allows the Oxidized Web UI and API to start successfully for verification.
>
> **Action Required**:
> 1. ✅ Leave it during initial deployment/testing
> 2. ❌ **Remove or replace it** before production use with your real devices
>
> See [docs/DEVICE-MANAGEMENT.md](docs/DEVICE-MANAGEMENT.md) for adding real devices.

**Access Web UI**: `http://<your-server-ip>:8888`

---

## 🔧 Installation

### Detailed Installation Steps

#### 1. Install Prerequisites

```bash

# Install required packages

sudo dnf install -y podman git logrotate curl jq

# Verify installations

podman --version
git --version
systemctl --version
```

#### 2. Clone Repository

```bash
git clone https://github.com/christopherpaquin/deploy-containerized-oxidized.git
cd deploy-containerized-oxidized
```

#### 3. Configure Environment

```bash

# Copy template

cp env.example .env

# Secure permissions (contains credentials)

chmod 600 .env

# Edit configuration

vim .env
```

**Required Changes**:

- `OXIDIZED_PASSWORD` - Change from default "changeme"
- `OXIDIZED_USERNAME` - Device login username
- `GIT_USER_NAME` - Git commit author
- `GIT_USER_EMAIL` - Git commit email

**Optional Changes**:

- `OXIDIZED_ROOT` - Default: `/var/lib/oxidized`
- `POLL_INTERVAL` - Default: `3600` (1 hour)
- `OXIDIZED_IMAGE` - Container image version

See `env.example` for all options with detailed comments.

#### 4. Validate Configuration

```bash
./scripts/validate-env.sh
```

This checks for:

- Missing required variables
- Default passwords
- Invalid paths
- Permission issues
- Common misconfigurations

#### 5. Run Deployment Script

```bash
sudo ./scripts/deploy.sh
```

This script:

1. Creates system user (`oxidized`, UID 30000)
2. Migrates existing users from old UID 2000 to 30000 (automatic)
3. Creates directory structure under `/var/lib/oxidized`
4. Generates Oxidized config from templates
5. Installs Podman Quadlet service
6. Sets up logrotate and log tailer
7. Installs helper scripts
8. Pulls container image
9. Starts services (oxidized + logger)

**The deployment is idempotent** - safe to re-run for upgrades.

#### 6. Create Device Inventory

```bash

# Copy template

sudo cp inventory/router.db.template /var/lib/oxidized/config/router.db

# Edit with your devices

sudo vim /var/lib/oxidized/config/router.db

# Set permissions (CRITICAL - must be owned by container's UID)

sudo chown 30000:30000 /var/lib/oxidized/config/router.db
sudo chmod 644 /var/lib/oxidized/config/router.db

# Restart service

sudo systemctl restart oxidized.service
```

**Format**: `name:ip:model:group:username:password`

See [docs/README-OXIDIZED.md - Device Inventory](docs/README-OXIDIZED.md#-device-inventory-routerdb) for complete documentation.

#### 7. Verify Deployment

```bash

# Run health check

sudo ./scripts/health-check.sh

# Check service status

sudo systemctl status oxidized.service

# View logs

sudo journalctl -u oxidized.service -f
```

---

## ⚙️ Configuration

### Environment Configuration (.env)

**Location**: `.env` (in repository root)

**⚠️ SECURITY**: This file contains sensitive information (credentials, IP addresses).

- Copy from `env.example`: `cp env.example .env`
- Restrict permissions: `chmod 600 .env`
- Never commit to Git (already in `.gitignore`)

### Key Configuration Variables

```bash

# System user (matches container UID)

OXIDIZED_USER="oxidized"
OXIDIZED_UID=30000  # Matches container's internal oxidized user
OXIDIZED_GID=30000

# Data directory (all persistent data)

OXIDIZED_ROOT="/var/lib/oxidized"

# Container image (pinned version)

OXIDIZED_IMAGE="docker.io/oxidized/oxidized:0.35.0"

# Device credentials (global defaults)

OXIDIZED_USERNAME="admin"
OXIDIZED_PASSWORD="changeme"  # CHANGE THIS!

# Operational settings

POLL_INTERVAL=3600  # Hourly backup (seconds)
THREADS=30          # Parallel device connections
TIMEOUT=20          # Device timeout (seconds)

# Git configuration

GIT_USER_NAME="Oxidized"
GIT_USER_EMAIL="oxidized@example.com"

# Network settings

OXIDIZED_API_PORT=8888
OXIDIZED_API_HOST="0.0.0.0"
OXIDIZED_WEB_UI="true"
```

See `env.example` for **all available options** with detailed documentation.

### Bind Mounts

All host directories are automatically mounted into the container:

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `/var/lib/oxidized/config` | `/home/oxidized/.config/oxidized` | Configuration files, router.db |
| `/var/lib/oxidized/ssh` | `/home/oxidized/.ssh` | SSH keys (read-only) |
| `/var/lib/oxidized/data` | `/home/oxidized/.config/oxidized/data` | Logs, runtime data |
| `/var/lib/oxidized/output` | `/home/oxidized/.config/oxidized/output` | Backup output |
| `/var/lib/oxidized/repo` | `/home/oxidized/.config/oxidized/repo` | Git repository |

**Important**: Always place your `router.db` inventory file in `/var/lib/oxidized/config/` so it's accessible to the container.

### Device Inventory (router.db)

**Location**: `/var/lib/oxidized/config/router.db` (on host)

**Format**: Colon-delimited CSV with explicit credentials required

```text
name:ip:model:group:username:password
core-router01:10.1.1.1:ios:core:admin:password123
edge-switch01:10.1.2.1:procurve:distribution:admin:password123
```

⚠️ **CRITICAL**: Empty credential fields (`::`) will cause authentication failures. Always provide explicit credentials for each device.

**Complete documentation**:
- **Credentials**: [docs/CREDENTIALS-GUIDE.md](docs/CREDENTIALS-GUIDE.md) ⭐ START HERE
- **Device Management**: [docs/DEVICE-MANAGEMENT.md](docs/DEVICE-MANAGEMENT.md)
- **Usage Guide**: [docs/README-OXIDIZED.md](docs/README-OXIDIZED.md)

---

## 🛠️ Management Scripts

This repository includes automated scripts for common operations:

### Overview

All scripts are deployed to `/var/lib/oxidized/scripts/` for easy access after deployment.

### Deployment Script

**Path**: `scripts/deploy.sh`

**Purpose**: Install and configure Oxidized service

**Usage**:
```bash
sudo ./scripts/deploy.sh
```

**What it does**:

- Creates system user and group
- Creates directory structure
- Generates configuration files
- Installs Podman Quadlet
- Sets up logrotate
- Pulls container image
- Starts service

**Options**:
```bash

# Dry-run mode (show what would be done)

sudo ./scripts/deploy.sh --dry-run

# Skip validation

sudo ./scripts/deploy.sh --skip-validation
```

**Idempotent**: Safe to re-run for upgrades or configuration changes.

### Service Management Scripts

**Purpose**: Manage Oxidized service with automatic PID file cleanup

These wrapper scripts handle a common issue where the PID file (`/home/oxidized/.config/oxidized/data/oxidized.pid`) is not removed when the container stops, causing startup failures.

#### Start Service

**Path**: `scripts/oxidized-start.sh`

**Usage**:
```bash
sudo /var/lib/oxidized/scripts/oxidized-start.sh
```

**What it does**:
- Checks for existing PID file
- Verifies if process is actually running
- Removes stale PID file if needed
- Starts the systemd service
- Verifies successful startup

#### Stop Service

**Path**: `scripts/oxidized-stop.sh`

**Usage**:
```bash
sudo /var/lib/oxidized/scripts/oxidized-stop.sh
```

**What it does**:
- Stops the systemd service gracefully
- Verifies container has stopped
- Removes PID file
- Confirms clean shutdown

#### Restart Service

**Path**: `scripts/oxidized-restart.sh`

**Usage**:
```bash
sudo /var/lib/oxidized/scripts/oxidized-restart.sh
```

**What it does**:
- Stops service gracefully
- Verifies container shutdown
- Removes stale PID file
- Starts service fresh
- Verifies successful restart

**When to use**:
- ✅ Use these scripts when `systemctl restart oxidized.service` fails with PID file errors
- ✅ Use for reliable restarts after configuration changes
- ✅ Use in automation scripts to ensure clean restarts

**Documentation**: See [docs/SERVICE-MANAGEMENT.md](docs/SERVICE-MANAGEMENT.md) for complete guide.

### Health Check Script

**Path**: `scripts/health-check.sh`

**Purpose**: Validate deployment and service health

**Usage**:
```bash
sudo ./scripts/health-check.sh
```

**Checks**:

- System user exists
- Directories exist with correct permissions
- Configuration files present and valid
- Service running
- Container healthy
- Recent backups successful
- Disk space adequate
- Network connectivity
- Log file accessible

**Exit codes**:

- `0` = All checks passed
- `1` = One or more checks failed

**Use in monitoring**:
```bash

# Cron job example (check every hour)

0 * * * * /path/to/deploy-containerized-oxidized/scripts/health-check.sh || mail -s "Oxidized Health Check Failed" admin@example.com
```

### Add Device Script

**Path**: `scripts/add-device.sh`

**Purpose**: Interactive script to add network devices to the inventory

**Usage**:
```bash
sudo /var/lib/oxidized/scripts/add-device.sh
```

**NEW**: Backups are automatically organized in `/var/lib/oxidized/config/backup-routerdb/`

**Features**:

- Interactive prompts with validation for hostname, IP, model, and group
- Shows list of 38+ supported device models
- Displays existing groups or allows creating new ones
- Shows default credentials from config (username only, password masked)
- Optional per-device credential override
- Comprehensive spell checking with 50+ typo patterns
- Intelligent suggestions for common mistakes (tp-link → tplink, arista → eos)
- Automatic timestamped backups in `/var/lib/oxidized/config/backup-routerdb/`
- Full syntax validation after addition
- Append-only operation (never overwrites router.db)

**Interactive Commands**:
```bash

# During model selection:

list   # Show all 38+ device models again
help   # Display common typo guide
```

**What it does**:

1. Prompts for device hostname with duplicate detection
2. Prompts for IP address or FQDN with validation
3. Shows available OS types (ios, nxos, junos, fortios, etc.)
4. Displays existing groups or creates new group
5. Shows default credentials, allows override
6. Validates entry format
7. Creates timestamped backup of router.db
8. Appends entry to router.db
9. Runs full validation on all devices

**Example**:
```bash
sudo /var/lib/oxidized/scripts/add-device.sh

# Follow interactive prompts:
# 1. Hostname: core-router01
# 2. IP: 10.1.1.1
# 3. Model: ios (or type 'help' to see common typos)
# 4. Group: core (or create new)
# 5. Credentials: Use defaults or override
# 6. Confirm and add
```

**Spell Checking**: Automatically detects and corrects common typos like:
- `tp-link` → `tplink`
- `cisco-ios` → `ios`
- `arista` → `eos` (vendor vs. model)
- `fortigate` → `fortios`
- And 50+ more patterns

**Safety**: Never overwrites router.db, creates backup before changes, validates all entries.

**Documentation**: See [`docs/ADD-DEVICE.md`](docs/ADD-DEVICE.md) for complete guide.

### Validate Router DB Script

**Path**: `scripts/validate-router-db.sh`

**Purpose**: Validate router.db syntax and format

**Usage**:
```bash
/var/lib/oxidized/scripts/validate-router-db.sh [path-to-router.db]
```

**Checks**:

- File format (6 fields, colon-delimited)
- Device name format
- Duplicate device names
- IP address/hostname format
- Duplicate IP addresses (warning)
- Empty required fields
- Known device models (warning if unknown)
- Credential consistency

**Automatically run by**: `add-device.sh` after adding new devices

### Test Device Script

**Path**: `scripts/test-device.sh`

**Purpose**: Test connectivity and trigger backup for a specific device

**Usage**:
```bash
/var/lib/oxidized/scripts/test-device.sh <device-name>
```

**Checks**:

- Container is running
- Device exists in router.db
- Device is registered in Oxidized
- Network connectivity (ping)
- SSH port is reachable
- Triggers backup
- Shows recent logs

**Example**:
```bash
/var/lib/oxidized/scripts/test-device.sh core-router01
```

### Remote Repository Setup Script

**Path**: `scripts/setup-remote-repo.sh`

**Purpose**: Configure remote git repository (GitHub/GitLab) for backup redundancy

**Usage**:
```bash
sudo /var/lib/oxidized/scripts/setup-remote-repo.sh
```

**Features**:

- Interactive SSH key generation
- GitHub/GitLab integration instructions
- Automatic push configuration (optional timer)
- Connection testing before setup
- Multi-remote support

**Documentation**:
- Quick Start: [docs/QUICK_START_REMOTE_REPO.md](docs/QUICK_START_REMOTE_REPO.md)
- Full Guide: [docs/REMOTE_REPOSITORY.md](docs/REMOTE_REPOSITORY.md)

### Uninstall Script

**Path**: `scripts/uninstall.sh`

**Purpose**: Remove Oxidized deployment

**Usage**:
```bash

# Remove service only (preserve data)

sudo ./scripts/uninstall.sh

# Remove everything including data (prompts to backup router.db)

sudo ./scripts/uninstall.sh --remove-data

# Remove everything without prompts (NO BACKUP!)

sudo ./scripts/uninstall.sh --remove-data --force
```

**What it removes**:

- Systemd service
- Podman Quadlet file
- Logrotate configuration
- Helper scripts
- System user (optional)

**Safety Feature:** When using `--remove-data`, the script prompts to backup `router.db` to your home directory with a timestamp before deletion.

- Data directories (only with `--purge`)

**⚠️ WARNING**: `--purge` permanently deletes all backups and Git history!

### Validation Script

**Path**: `scripts/validate-env.sh`

**Purpose**: Validate `.env` configuration before deployment

**Usage**:
```bash
./scripts/validate-env.sh
```

**Checks**:

- `.env` file exists
- Required variables present
- No default passwords
- Valid UID/GID
- Absolute paths
- Correct file permissions

---

## 🗑️ Uninstallation

### Remove Service (Preserve Data)

```bash
sudo ./scripts/uninstall.sh
```

This removes:

- Systemd service
- Podman Quadlet
- Logrotate config
- Container

**Preserves**:

- Data directories (`/var/lib/oxidized`)
- System user
- Container image

### Complete Removal (Delete Everything)

```bash
sudo ./scripts/uninstall.sh --remove-data
```

**Safety:** You'll be prompted to backup `router.db` before deletion.

**⚠️ WARNING**: This permanently deletes:

- All device configurations
- Git history
- Logs
- SSH keys
- Everything under `/var/lib/oxidized`

**Before purging**, back up data:
```bash
sudo tar -czf oxidized-backup-$(date +%Y%m%d).tar.gz /var/lib/oxidized
```

---

## 🔒 Security

### Security Features

This deployment includes multiple security hardening measures:

- **Container isolation**: Strong namespace and cgroup isolation
- **SELinux enforcing**: Proper context labeling (`:Z` mounts)
- **Network isolation**: Dedicated Podman network
- **Minimal capabilities**: Only SETUID/SETGID (required for init system)
- **NoNewPrivileges**: Prevents privilege escalation within container
- **Restricted permissions**:
  - Config files: `640`
  - Credentials: `600`
  - Directories: `750`
- **No secrets in repo**: All credentials in `.env` (Git-ignored)
- **Version pinned**: Explicit container versions
- **Resource limits**: CPU and memory constraints enforced

**Container Security Note**: The Oxidized container uses baseimage-docker with an init system that requires root privileges inside the container. However, the container remains securely isolated through:

- Namespace isolation (PID, network, mount, IPC, UTS)
- Cgroup resource limits
- SELinux mandatory access controls
- NoNewPrivileges flag
- Dedicated bridge network

For detailed security analysis and trade-offs, see [docs/DEPLOYMENT-NOTES.md](docs/DEPLOYMENT-NOTES.md).

### Security Best Practices

1. **Change default passwords immediately**:

   ```bash
   # In .env
   OXIDIZED_PASSWORD="strong_unique_password_here"
   ```

2. **Use SSH keys instead of passwords** (recommended):

   ```bash
   sudo -u oxidized ssh-keygen -t ed25519 -f /var/lib/oxidized/ssh/id_ed25519
   sudo -u oxidized ssh-copy-id -i /var/lib/oxidized/ssh/id_ed25519.pub admin@device
   ```

   📖 **For detailed SSH key setup**, see [SSH Key Authentication](docs/README-OXIDIZED.md#ssh-key-authentication-recommended) in docs/README-OXIDIZED.md

3. **Secure the `.env` file**:

   ```bash
   chmod 600 .env
   # Never commit to Git
   ```

4. **Secure `router.db`** (if using per-device credentials):

   ```bash
   sudo chmod 644 /var/lib/oxidized/config/router.db
   sudo chown 30000:30000 /var/lib/oxidized/config/router.db
   ```

5. **Restrict network access**:

   ```bash
   # Allow only from monitoring server
   sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.1.1.100" port port="8888" protocol="tcp" accept'
   ```

6. **Regular updates**:
   - Monitor [Oxidized releases](https://github.com/yggdrasil-network/oxidized/releases)
   - Test upgrades in non-production first
   - Keep `.env` variables up to date

7. **Use least-privilege device accounts**:
   - Create read-only accounts on network devices
   - Limit access to config commands only
   - Monitor Oxidized's device access in device logs

8. **Back up the Git repository**:

   ```bash
   # Push to remote Git server
   cd /var/lib/oxidized/repo
   sudo git remote add origin git@github.com:yourorg/network-configs.git
   sudo git push origin main
   ```

**Complete security documentation**: [docs/SECURITY-HARDENING.md](docs/SECURITY-HARDENING.md)

---

## 📚 Documentation

### Repository Documentation

> **📖 Not sure which doc to read?** See **[docs/DOCUMENTATION-GUIDE.md](docs/DOCUMENTATION-GUIDE.md)** for a complete guide to our documentation structure.

#### Getting Started
- **[docs/QUICK-START.md](docs/QUICK-START.md)** - ⚡ Quick reference guide for deployment and common tasks
- **[docs/INSTALL.md](docs/INSTALL.md)** - Detailed installation guide
- **[docs/PREREQUISITES.md](docs/PREREQUISITES.md)** - System requirements and dependencies
- **[docs/README-OXIDIZED.md](docs/README-OXIDIZED.md)** - Oxidized usage and configuration

#### Configuration & Management
- **[docs/CONFIGURATION.md](docs/CONFIGURATION.md)** - Configuration deep-dive
- **[docs/ENV-ARCHITECTURE.md](docs/ENV-ARCHITECTURE.md)** - Environment variable architecture
- **[docs/DEVICE-MANAGEMENT.md](docs/DEVICE-MANAGEMENT.md)** - 📱 Complete device management guide
- **[docs/ADD-DEVICE.md](docs/ADD-DEVICE.md)** - Interactive device addition guide
- **[docs/DIRECTORY-STRUCTURE.md](docs/DIRECTORY-STRUCTURE.md)** - 📁 Directory layout explained
- **[docs/SERVICE-MANAGEMENT.md](docs/SERVICE-MANAGEMENT.md)** - Service operations guide

#### Security & Authentication
- **[docs/CREDENTIALS-GUIDE.md](docs/CREDENTIALS-GUIDE.md)** - 🔑 **IMPORTANT:** Understanding credentials
- **[docs/SECURITY-HARDENING.md](docs/SECURITY-HARDENING.md)** - Security best practices
- **[docs/SECURITY-AUTHENTICATION.md](docs/SECURITY-AUTHENTICATION.md)** - Authentication options
- **[docs/AUTHENTICATION-SETUP.md](docs/AUTHENTICATION-SETUP.md)** - Web UI login setup
- **[docs/FIREWALL-IMPLEMENTATION.md](docs/FIREWALL-IMPLEMENTATION.md)** - Firewall configuration

#### Remote Backups (NEW)
- **[docs/QUICK_START_REMOTE_REPO.md](docs/QUICK_START_REMOTE_REPO.md)** - ⭐ Remote repository quick start
- **[docs/REMOTE_REPOSITORY.md](docs/REMOTE_REPOSITORY.md)** - Complete remote repo guide
- **[docs/UID_MIGRATION_30000.md](docs/UID_MIGRATION_30000.md)** - UID migration documentation

#### Operations & Troubleshooting
- **[docs/DEPLOYMENT-NOTES.md](docs/DEPLOYMENT-NOTES.md)** - Deployment improvements and notes
- **[docs/TROUBLESHOOTING-WEB-UI.md](docs/TROUBLESHOOTING-WEB-UI.md)** - Web UI troubleshooting
- **[docs/UPGRADE.md](docs/UPGRADE.md)** - Upgrade procedures
- **[docs/GIT-REPOSITORY-STRUCTURE.md](docs/GIT-REPOSITORY-STRUCTURE.md)** - Git repo structure
- **[docs/PATH-MAPPINGS.md](docs/PATH-MAPPINGS.md)** - Container path mappings

#### Advanced Topics
- **[docs/CUSTOM-MODELS.md](docs/CUSTOM-MODELS.md)** - Custom device models
- **[docs/TP-LINK-SX3008F.md](docs/TP-LINK-SX3008F.md)** - TP-Link switch support
- **[docs/TELNET-CONFIGURATION.md](docs/TELNET-CONFIGURATION.md)** - Telnet setup
- **[docs/DEVICE-INPUT-CONFIGURATION.md](docs/DEVICE-INPUT-CONFIGURATION.md)** - Input methods
- **[docs/monitoring/ZABBIX.md](docs/monitoring/ZABBIX.md)** - Zabbix monitoring setup

#### Project Documentation
- **[docs/DECISIONS.md](docs/DECISIONS.md)** - Architecture decisions
- **[docs/DOCUMENTATION-GUIDE.md](docs/DOCUMENTATION-GUIDE.md)** - Documentation structure
- **[docs/DOCUMENTATION-CONSOLIDATION.md](docs/DOCUMENTATION-CONSOLIDATION.md)** - Doc organization

### Templates

- **`env.example`** - Environment variable template with extensive documentation
- **`inventory/router.db.template`** - Device inventory template with examples
- **`config/oxidized/config.template`** - Oxidized configuration template
- **`containers/quadlet/oxidized.container.template`** - Podman Quadlet template

### External Documentation

- **Oxidized GitHub**: https://github.com/yggdrasil-network/oxidized
- **Oxidized Documentation**: https://github.com/yggdrasil-network/oxidized/wiki
- **Supported Models**: https://github.com/yggdrasil-network/oxidized/tree/master/lib/oxidized/model
- **Podman Quadlets**: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

### Reporting Issues

- Use GitHub Issues
- Include system information (RHEL version, Podman version)
- Provide relevant logs
- Describe expected vs actual behavior

### Pull Requests

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `./scripts/validate-env.sh`
5. Test deployment on clean system
6. Submit pull request with clear description

### Development Standards

- **Shell scripts**: Follow ShellCheck recommendations
- **Documentation**: Update relevant docs for any changes
- **Testing**: Test on RHEL 10 and RHEL 9
- **SELinux**: Ensure compatibility with enforcing mode
- **Idempotency**: Scripts must be safe to re-run

---

## 📄 License

```
Copyright 2026 Christopher Paquin

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

Full license text: [LICENSE](LICENSE)

---

## 🙏 Acknowledgments

- **Oxidized**: https://github.com/yggdrasil-network/oxidized
- **Podman**: https://podman.io/
- **Red Hat Enterprise Linux**: https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux
- Community contributors and testers

---

## 📞 Support

- **GitHub Issues**: https://github.com/christopherpaquin/deploy-containerized-oxidized/issues
- **Documentation**: [docs/](docs/)
- **Oxidized Community**: https://gitter.im/oxidized/Lobby

---

**Quick Links**:

- [Oxidized Usage Guide](docs/README-OXIDIZED.md)
- [Quick Start Guide](docs/QUICK-START.md)
- [Device Management](docs/DEVICE-MANAGEMENT.md)
- [Remote Repository Setup](docs/QUICK_START_REMOTE_REPO.md)
- [Troubleshooting](docs/TROUBLESHOOTING-WEB-UI.md)
- [Security Hardening](docs/SECURITY-HARDENING.md)
