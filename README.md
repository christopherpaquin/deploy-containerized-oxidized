# 🤖 Containerized Oxidized for Network Configuration Backup

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![RHEL 10](https://img.shields.io/badge/RHEL-10-red.svg)](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux)
[![RHEL 9](https://img.shields.io/badge/RHEL-9-red.svg)](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux)
[![Podman](https://img.shields.io/badge/Podman-4.x+-purple.svg)](https://podman.io/)
[![SELinux](https://img.shields.io/badge/SELinux-Enforcing-green.svg)](https://github.com/SELinuxProject)

Production-grade, containerized deployment of [Oxidized](https://github.com/yggdrasil-network/oxidized)
for automated network device configuration backup and versioning using **Podman Quadlets** and **systemd** on RHEL.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Requirements](#-requirements)
- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Monitoring](#-monitoring)
- [Upgrade & Rollback](#-upgrade--rollback)
- [Uninstallation](#-uninstallation)
- [Troubleshooting](#-troubleshooting)
- [Security](#-security)
- [Documentation](#-documentation)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

This repository provides a **complete deployment framework** for running Oxidized as a containerized service
on RHEL 10/9 using modern container orchestration practices.

### What is Oxidized?

Oxidized is a network device configuration backup tool that:
- **Automatically backs up** network device configurations
- **Tracks changes** using Git version control
- **Supports 130+ device models** (Cisco, Juniper, Arista, etc.)
- **Provides a Web UI** for viewing configs and diffs
- **Exposes a REST API** for automation and monitoring

### Why This Repository?

- ✅ **Production-ready**: Designed for enterprise environments
- ✅ **Systemd integrated**: Auto-starts on boot via Podman Quadlets
- ✅ **SELinux compatible**: Works with enforcing mode
- ✅ **Version pinned**: Stable, predictable releases
- ✅ **Fully documented**: Step-by-step guides and runbooks
- ✅ **Monitoring ready**: Zabbix integration examples
- ✅ **Idempotent**: Safe to re-run and upgrade

---

## ✨ Features

### 🚀 Deployment

- **Podman Quadlets**: Declarative systemd-managed containers
- **Automatic startup**: Starts on boot, restarts on failure
- **Persistent storage**: All data survives container recreation
- **SELinux enforcing**: No custom policies required
- **Version pinned**: Explicit image versions, no `latest` tag

### 📦 Data Management

- **Git versioning**: Every config change tracked in Git
- **CSV inventory**: Simple, human-editable device list
- **Log rotation**: Automated via logrotate
- **Backup procedures**: Scripts and documentation provided

### 🔍 Monitoring

- **REST API**: JSON endpoints for status and metrics
- **Web UI**: View configs and diffs in browser
- **Zabbix ready**: Pre-built monitoring queries and alerts
- **Health checks**: Built-in container health monitoring

### 🛡️ Security

- **Non-root container**: Runs as UID 30000 inside container
- **SELinux enforcing**: Proper context labeling
- **Isolated storage**: Dedicated paths under `/srv/oxidized`
- **No secrets in repo**: Credentials managed separately

---

## 🏗️ Architecture

### High-Level Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                      RHEL 10 Host                           │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              systemd (Quadlets)                     │   │
│  │                                                     │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │    Podman Container (oxidized:0.30.1)       │  │   │
│  │  │                                              │  │   │
│  │  │  🤖 Oxidized Service                         │  │   │
│  │  │     ├─ REST API (port 8888)                 │  │   │
│  │  │     ├─ Web UI                               │  │   │
│  │  │     ├─ Polling Engine (hourly)              │  │   │
│  │  │     └─ Git Output                           │  │   │
│  │  │                                              │  │   │
│  │  │  Volumes (bind mounts with :Z)              │  │   │
│  │  │     /etc/oxidized         ← config          │  │   │
│  │  │     /etc/oxidized/inventory ← devices.csv   │  │   │
│  │  │     /var/lib/oxidized     ← data            │  │   │
│  │  │     /var/lib/oxidized/configs.git ← Git     │  │   │
│  │  │     /var/lib/oxidized/logs ← logs           │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  📁 Host Persistent Storage: /srv/oxidized/                │
│     ├── config/         (Oxidized configuration)           │
│     ├── inventory/      (devices.csv)                      │
│     ├── data/           (runtime data)                     │
│     ├── git/            (Git repository with configs)      │
│     └── logs/           (application logs)                 │
│                                                             │
│  🔄 logrotate: /etc/logrotate.d/oxidized                   │
│  🎯 Quadlet: /etc/containers/systemd/oxidized.container    │
└─────────────────────────────────────────────────────────────┘
              │                              │
              │ SSH/Telnet                   │ HTTP
              ▼                              ▼
    ┌──────────────────┐          ┌──────────────────┐
    │  Network Devices │          │  Zabbix Server   │
    │  (routers,       │          │  (monitoring)    │
    │   switches,      │          │                  │
    │   firewalls)     │          │  🔍 API Polling  │
    └──────────────────┘          └──────────────────┘
```

### Data Flow

1. **Oxidized polls** network devices via SSH/Telnet (hourly by default)
2. **Configurations extracted** and compared to previous version
3. **Changes committed** to local Git repository
4. **Logs written** to persistent storage
5. **API exposes** status for monitoring systems
6. **Web UI** provides human interface for viewing configs

### Component Relationships

```text
┌────────────┐    reads    ┌──────────────┐    polls    ┌──────────┐
│ inventory  │────────────▶│   Oxidized   │────────────▶│ Devices  │
│ (CSV file) │             │   Service    │             └──────────┘
└────────────┘             └──────────────┘
                                  │
                     writes       │       exposes
                                  │
                     ┌────────────┼────────────┐
                     │            │            │
                     ▼            ▼            ▼
              ┌──────────┐  ┌─────────┐  ┌─────────┐
              │   Git    │  │  Logs   │  │   API   │
              │   Repo   │  │         │  │ (8888)  │
              └──────────┘  └─────────┘  └─────────┘
                                               │
                                               │ monitors
                                               ▼
                                          ┌─────────┐
                                          │ Zabbix  │
                                          └─────────┘
```

---

## 📋 Requirements

### Operating System

| Platform | Status | Notes |
|----------|--------|-------|
| **RHEL 10** | ✅ Primary | Fully tested |
| **RHEL 9** | ✅ Secondary | Supported |
| Ubuntu 22.04 | ⚠️ Best-effort | May require adjustments |

### Software Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| **podman** | 4.x+ | Container runtime |
| **systemd** | 247+ | Quadlet support |
| **git** | 2.x+ | Version control |
| **logrotate** | Any | Log rotation |
| **curl** | Any | API testing |
| **jq** | Any | JSON parsing |

### System Requirements

For **~100 devices** with **hourly polling**:

- **CPU**: 2 cores
- **RAM**: 2 GB (4 GB recommended)
- **Disk**: 10 GB free in `/srv/oxidized`
- **SELinux**: Enforcing mode
- **Network**: Access to network devices

### Network Requirements

- **Outbound**: SSH (22), Telnet (23) to network devices
- **Inbound**: HTTP (8888) for Web UI and API (optional, can be firewalled)

---

## 🚀 Quick Start

### Automated Deployment (Recommended)

```bash
# 1. Clone repository
git clone https://github.com/yourusername/deploy-containerized-oxidized.git
cd deploy-containerized-oxidized

# 2. Create configuration file from template
cp env.example .env
chmod 600 .env

# 3. Edit configuration (IMPORTANT: Update credentials!)
vim .env

# 4. Validate configuration
./scripts/validate-env.sh

# 5. Run deployment script
sudo ./scripts/deploy.sh

# 6. Verify deployment
sudo ./scripts/health-check.sh
```

**Important**: The `.env` file contains sensitive information including device credentials.
Never commit this file to Git (it's already in `.gitignore`).

### Manual Deployment

<details>
<summary>Click to expand manual installation steps</summary>

### 1. Install Prerequisites

```bash
sudo dnf install -y podman git logrotate curl jq policycoreutils-python-utils
```

### 2. Clone Repository

```bash
git clone https://github.com/yourusername/deploy-containerized-oxidized.git
cd deploy-containerized-oxidized
```

### 3. Create Directory Structure

```bash
sudo mkdir -p /srv/oxidized/{config,inventory,data,git,logs}
```

### 4. Deploy Configuration

```bash
# Copy config files
sudo cp config/oxidized/config /srv/oxidized/config/
sudo cp config/oxidized/inventory/devices.csv.example /srv/oxidized/inventory/devices.csv

# Edit with your devices
sudo vim /srv/oxidized/inventory/devices.csv

# Update credentials
sudo vim /srv/oxidized/config/config
```

### 5. Initialize Git Repository

```bash
sudo git init /srv/oxidized/git/configs.git
cd /srv/oxidized/git/configs.git
sudo git config user.name "Oxidized"
sudo git config user.email "oxidized@example.com"
```

### 6. Install Quadlet

```bash
sudo cp containers/quadlet/oxidized.container /etc/containers/systemd/
sudo systemctl daemon-reload
```

### 7. Start Service

```bash
sudo systemctl enable --now oxidized.service
sudo systemctl status oxidized.service
```

### 8. Verify

```bash
# Check API
curl http://localhost:8888/nodes.json | jq '.'

# Access Web UI
# Open browser: http://<your-server>:8888
```

</details>

**For detailed instructions**, see [docs/INSTALL.md](docs/INSTALL.md)

---

## 🔧 Installation

### Detailed Installation

For complete, step-by-step installation instructions, see:

📖 **[docs/INSTALL.md](docs/INSTALL.md)**

Includes:
- ✅ Prerequisites installation
- ✅ Directory structure setup
- ✅ Configuration deployment
- ✅ Git repository initialization
- ✅ Quadlet installation
- ✅ Service enablement
- ✅ Verification procedures
- ✅ Troubleshooting steps

---

## ⚙️ Configuration

### Environment Configuration (.env)

**Location**: `.env` (in repository root)

**⚠️ SECURITY**: This file contains sensitive information (credentials, IP addresses).
- Copy from `env.example`: `cp env.example .env`
- Restrict permissions: `chmod 600 .env`
- Never commit to Git (already in `.gitignore`)

**Key Configuration Variables**:

```bash
# System user
OXIDIZED_UID=2000
OXIDIZED_GID=2000

# Data directory
OXIDIZED_ROOT="/var/lib/oxidized"

# Container image (pinned version)
OXIDIZED_IMAGE="docker.io/oxidized/oxidized:0.30.1"

# Device credentials
OXIDIZED_USERNAME="admin"
OXIDIZED_PASSWORD="changeme"  # CHANGE THIS!

# Operational settings
POLL_INTERVAL=3600  # Hourly
THREADS=30
TIMEOUT=20
```

See `env.example` for all available options.

### Oxidized Configuration

**Location**: `/var/lib/oxidized/config/config` (auto-generated from `.env` and `config/oxidized/config.template`)

The configuration file is automatically generated during deployment. Key settings:

```yaml
# Global device credentials (can be overridden per-device in router.db)
username: admin
password: your_secure_password

# Polling interval (seconds)
interval: 3600  # 1 hour

# REST API and Web UI
rest: 0.0.0.0:8888
web: true

# CSV inventory source (router.db)
source:
  default: csv
  csv:
    file: /home/oxidized/.config/oxidized/router.db  # Inside container
    delimiter: !ruby/regexp /:/  # Colon delimiter
    map:
      name: 0
      ip: 1
      model: 2
      group: 3
      username: 4  # Per-device username (optional)
      password: 5  # Per-device password (optional)

# Git output (version control for configs)
output:
  default: git
  git:
    user: Oxidized
    email: oxidized@example.com
    repo: /home/oxidized/.config/oxidized/repo  # Inside container
```

**Note**: Do not edit the generated config file directly. Instead:
1. Update variables in `.env`
2. For advanced settings, edit `config/oxidized/config.template`
3. Re-run deployment: `sudo ./scripts/deploy.sh`

### Device Inventory (router.db)

Oxidized uses a CSV-based inventory file (`router.db`) to define which network devices to back up.

#### File Locations

- **Template**: `inventory/router.db.template` (in this repository)
- **Live file (host)**: `/var/lib/oxidized/config/router.db`
- **Inside container**: `/home/oxidized/.config/oxidized/router.db`

The live file is automatically mounted into the container via the `/var/lib/oxidized/config` directory mount.

#### Creating the Inventory File

**Step 1**: Copy the template

```bash
sudo cp inventory/router.db.template /var/lib/oxidized/config/router.db
```

**Step 2**: Edit with your devices

```bash
sudo vim /var/lib/oxidized/config/router.db
```

**Step 3**: Set correct permissions

```bash
# CRITICAL for security - file contains credentials
sudo chown 2000:2000 /var/lib/oxidized/config/router.db
sudo chmod 600 /var/lib/oxidized/config/router.db
```

#### File Format

**Format**: Colon-delimited CSV (`:`) with 6 columns

```text
name:ip:model:group:username:password
```

**Column Definitions**:

| Column | Index | Description | Example |
|--------|-------|-------------|---------|
| `name` | 0 | Unique device identifier/hostname | `core-router01` |
| `ip` | 1 | IP address or FQDN | `10.1.1.1` or `router.example.com` |
| `model` | 2 | Device type/model | `ios`, `nxos`, `eos`, `junos` |
| `group` | 3 | Logical grouping | `core`, `distribution`, `branch` |
| `username` | 4 | Device login username (or blank for global) | `netadmin` |
| `password` | 5 | Device login password (or blank for global) | `SecretPass123` |

#### Credential Modes

Oxidized supports three credential authentication modes:

##### Mode 1: Global Credentials (Recommended)

Use the same username/password for all devices:

1. Set credentials in `.env`:

   ```bash
   OXIDIZED_USERNAME="admin"
   OXIDIZED_PASSWORD="your_secure_password"
   ```

2. Leave username/password columns **blank** in `router.db`:

   ```text
   core-router01:10.1.1.1:ios:core::
   edge-switch01:10.1.2.1:procurve:distribution::
   firewall01:10.1.3.1:fortios:firewalls::
   ```

**Best for**: Homogeneous environments with shared credentials

##### Mode 2: Per-Device Credentials

Specify credentials for each device individually:

```text
core-router01:10.1.1.1:ios:core:netadmin:CorePass123
edge-switch01:10.1.2.1:procurve:distribution:switchuser:SwitchPass456
firewall01:10.1.3.1:fortios:firewalls:fwadmin:FirewallPass789
```

**Best for**: Heterogeneous environments with different credentials per device

**⚠️ SECURITY WARNING**: Per-device credentials are stored in **plaintext** in `router.db`
- **MUST** set permissions: `chmod 600 /var/lib/oxidized/config/router.db`
- **MUST** set ownership: `chown 2000:2000 /var/lib/oxidized/config/router.db`
- **NEVER** commit `router.db` with real credentials to Git

##### Mode 3: Mixed (Global with Exceptions)

Use global credentials as default, override for specific devices:

1. Set global credentials in `.env`
2. Specify credentials only for exceptions in `router.db`:

   ```text
   # Most devices use global credentials (blank columns)
   core-router01:10.1.1.1:ios:core::
   edge-switch01:10.1.2.1:procurve:distribution::

   # Special device with different credentials
   firewall01:10.1.3.1:fortios:firewalls:fwadmin:SpecialPass123
   ```

#### Supported Models (Common Examples)

| Vendor | Model Code | Description |
|--------|------------|-------------|
| Cisco | `ios` | Cisco IOS |
| Cisco | `iosxr` | Cisco IOS XR |
| Cisco | `nxos` | Cisco Nexus |
| Cisco | `asa` | Cisco ASA Firewall |
| Arista | `eos` | Arista EOS |
| Juniper | `junos` | Juniper JunOS |
| HP | `procurve` | HP ProCurve Switches |
| HP | `comware` | HP Comware |
| Aruba | `aoscx` | Aruba AOS-CX |
| Fortinet | `fortios` | FortiGate Firewalls |
| Palo Alto | `panos` | PAN-OS |

**Full list**: [Oxidized Supported Models](https://github.com/yggdrasil-network/oxidized/tree/master/lib/oxidized/model)

#### Example Inventory File

```text
# Oxidized Router Database
# Format: name:ip:model:group:username:password

# Core infrastructure (using global credentials)
core-router01:10.1.1.1:ios:core::
core-router02:10.1.1.2:ios:core::
core-switch01:10.1.1.10:junos:core::

# Distribution layer (per-device credentials)
edge-switch01:10.1.2.1:procurve:distribution:switchadmin:Pass123
edge-switch02:10.1.2.2:procurve:distribution:switchadmin:Pass123

# Security devices (different credentials)
firewall01:10.1.3.1:fortios:firewalls:fwadmin:FwPass456
firewall02:10.1.3.2:fortios:firewalls:fwadmin:FwPass456

# Data center (using FQDN)
datacenter-sw01:dc-sw01.example.com:nxos:datacenter::
datacenter-sw02:dc-sw02.example.com:nxos:datacenter::

# Branch sites
branch-router01:10.2.1.1:ios:branch::
branch-router02:10.2.2.1:ios:branch::
```

#### Validation

After creating `router.db`, validate it loads correctly:

```bash
# Check file exists and has correct permissions
ls -la /var/lib/oxidized/config/router.db
# Should show: -rw------- 1 oxidized oxidized ... router.db

# Restart service to load new inventory
sudo systemctl restart oxidized.service

# Check for errors
sudo systemctl status oxidized.service
sudo journalctl -u oxidized.service -n 50

# View Oxidized logs
sudo tail -f /var/lib/oxidized/data/oxidized.log
```

#### Inventory Troubleshooting

**Problem**: Devices not being backed up

**Solutions**:
1. Check file permissions: `ls -la /var/lib/oxidized/config/router.db`
2. Verify file format (colon delimiters, no spaces)
3. Check credentials are correct
4. Verify device model is supported
5. Ensure devices are network-reachable from container

**Problem**: "Permission denied" errors

**Solution**: Fix ownership and permissions

```bash
sudo chown 2000:2000 /var/lib/oxidized/config/router.db
sudo chmod 600 /var/lib/oxidized/config/router.db
sudo systemctl restart oxidized.service
```

### Environment Variables

Optional environment variables can be set in the Quadlet file:

```ini
Environment=OXIDIZED_USERNAME=admin
Environment=OXIDIZED_PASSWORD=secret
Environment=TZ=UTC
```

---

## 🛠️ Management Scripts

This repository includes automated scripts for common operations:

### Deployment Script

**Location**: `scripts/deploy.sh`

Automates the complete installation process:

```bash
# Standard deployment
sudo ./scripts/deploy.sh

# Dry-run to see what would happen
sudo ./scripts/deploy.sh --dry-run

# Skip credential prompts (configure manually later)
sudo ./scripts/deploy.sh --skip-credentials

# Show help
./scripts/deploy.sh --help
```

**Features**:
- ✅ Checks prerequisites
- ✅ Creates directory structure
- ✅ Deploys configuration files
- ✅ Initializes Git repository
- ✅ Installs Quadlet and logrotate
- ✅ Pulls container image
- ✅ Starts and enables service
- ✅ Verifies deployment
- ✅ Idempotent (safe to re-run)

### Health Check Script

**Location**: `scripts/health-check.sh`

Performs comprehensive health checks:

```bash
# Standard health check
sudo ./scripts/health-check.sh

# Verbose output
sudo ./scripts/health-check.sh --verbose

# JSON output (for monitoring integration)
sudo ./scripts/health-check.sh --json

# Nagios plugin mode
sudo ./scripts/health-check.sh --nagios
```

**Checks**:
- ✅ Systemd service status
- ✅ Container health
- ✅ API reachability
- ✅ Backup success rate
- ✅ Persistent storage
- ✅ Git repository
- ✅ Disk space
- ✅ Resource usage

**Exit Codes**:
- `0` - All checks passed
- `1` - Critical failures detected

### Uninstall Script

**Location**: `scripts/uninstall.sh`

Safely removes Oxidized deployment:

```bash
# Uninstall but preserve data (default)
sudo ./scripts/uninstall.sh

# Uninstall and remove all data (DESTRUCTIVE!)
sudo ./scripts/uninstall.sh --remove-data --force

# Dry-run to see what would be removed
sudo ./scripts/uninstall.sh --dry-run --remove-data
```

**Features**:
- ✅ Stops and disables service
- ✅ Removes container
- ✅ Removes Quadlet and logrotate configs
- ✅ Optionally removes data
- ✅ Safety confirmations
- ✅ Preserves data by default

---

## 🎮 Usage

### Service Management

```bash
# Start service
sudo systemctl start oxidized.service

# Stop service
sudo systemctl stop oxidized.service

# Restart service
sudo systemctl restart oxidized.service

# Check status
sudo systemctl status oxidized.service

# View logs
podman logs -f oxidized
```

### API Usage

```bash
# List all nodes
curl http://localhost:8888/nodes.json | jq '.'

# Get specific node
curl http://localhost:8888/node/show/switch-01 | jq '.'

# Reload inventory
curl -X POST http://localhost:8888/reload

# Trigger backup for specific node
curl -X GET http://localhost:8888/node/fetch/switch-01
```

### Web UI

Access the Web UI at: `http://<server-ip>:8888`

Features:
- View all device configurations
- Compare versions (diffs)
- Search configurations
- View backup status

### Git Repository

```bash
# View commit history
cd /srv/oxidized/git/configs.git
sudo git log --oneline

# View specific config version
sudo git show <commit-hash>:<device-name>

# Compare versions
sudo git diff <old-commit> <new-commit> -- <device-name>
```

### Logs

```bash
# View logs
sudo tail -f /srv/oxidized/logs/oxidized.log

# Search for errors
sudo grep -i error /srv/oxidized/logs/oxidized.log

# Check specific device
sudo grep "switch-01" /srv/oxidized/logs/oxidized.log
```

---

## 📊 Monitoring

### Monitoring with Zabbix

Complete Zabbix monitoring setup, including:
- Service health checks
- Per-device backup status
- Stale backup detection
- API query examples
- Alert definitions

📖 **See**: [docs/monitoring/ZABBIX.md](docs/monitoring/ZABBIX.md)

### Quick Health Check

```bash
# Service status
systemctl is-active oxidized.service

# API reachability
curl -f http://localhost:8888/ && echo "OK" || echo "FAIL"

# Success rate
curl -s http://localhost:8888/nodes.json | jq '
  (([.[] | select(.status == "success")] | length) / length * 100)
'
```

---

## 🔄 Upgrade & Rollback

### Upgrading Oxidized

1. Backup current state
2. Pull new image
3. Update Quadlet file with new version
4. Reload systemd and restart service
5. Verify upgrade

### Rollback

If issues occur:

1. Restore Quadlet file to previous version
2. Restart service
3. Restore backups if needed

📖 **Full details**: [docs/UPGRADE.md](docs/UPGRADE.md)

---

## 🗑️ Uninstallation

### Complete Removal

```bash
# Stop and disable service
sudo systemctl stop oxidized.service
sudo systemctl disable oxidized.service

# Remove container
podman stop oxidized
podman rm oxidized

# Remove Quadlet file
sudo rm /etc/containers/systemd/oxidized.container
sudo systemctl daemon-reload

# Remove logrotate config
sudo rm /etc/logrotate.d/oxidized

# Optionally remove data (THIS DELETES ALL CONFIGS AND HISTORY!)
# sudo rm -rf /srv/oxidized
```

### Preserve Data

To keep backups and Git history:
- **DO NOT** delete `/srv/oxidized/git` (config backups)
- **DO NOT** delete `/srv/oxidized/logs` (historical logs)
- Consider archiving before removal:

```bash
sudo tar -czf oxidized-backup-$(date +%Y%m%d).tar.gz /srv/oxidized
```

---

## 🚨 Troubleshooting

### Common Issues

#### Service Won't Start

```bash
# Check service status
sudo systemctl status oxidized.service

# Check journal logs
sudo journalctl -u oxidized.service -n 100

# Check container logs
podman logs oxidized
```

#### Devices Not Backing Up

```bash
# Check device connectivity
ping <device-ip>
ssh <username>@<device-ip>

# Check Oxidized logs
sudo tail -50 /srv/oxidized/logs/oxidized.log

# Verify inventory
cat /srv/oxidized/inventory/devices.csv

# Test credentials
curl http://localhost:8888/node/fetch/<device-name>
```

#### API Not Accessible

```bash
# Check port binding
sudo netstat -tulpn | grep 8888

# Check firewall
sudo firewall-cmd --list-ports

# Test locally
curl http://localhost:8888/
```

#### SELinux Denials

```bash
# Check for denials
sudo ausearch -m avc -ts recent

# Verify SELinux context
ls -laZ /srv/oxidized

# Restart service to reapply context
sudo systemctl restart oxidized.service
```

### Getting Help

- 📖 **[Installation Guide](docs/INSTALL.md)**
- 📖 **[Upgrade Guide](docs/UPGRADE.md)**
- 📖 **[Monitoring Guide](docs/monitoring/ZABBIX.md)**
- 📖 **[Decisions Log](docs/DECISIONS.md)**
- 🐛 **[GitHub Issues](https://github.com/yourusername/deploy-containerized-oxidized/issues)**

---

## 🔒 Security

### Security Features

- ✅ **Non-root container**: Runs as UID 30000
- ✅ **SELinux enforcing**: Proper context isolation
- ✅ **No privileged mode**: Standard container capabilities
- ✅ **Isolated storage**: Dedicated paths with proper permissions
- ✅ **Version pinned**: No unexpected changes

### Security Best Practices

1. Credentials Management
   - Store credentials securely
   - Use environment variables for sensitive data
   - Consider a secrets manager for production

2. Network Security
   - Restrict port 8888 to internal network only
   - Use firewall rules
   - Consider VPN for remote access

3. Access Control
   - Limit SSH access to Oxidized host
   - Use key-based authentication
   - Regular security updates

4. Monitoring
   - Monitor for failed backups (may indicate credential issues)
   - Track API access patterns
   - Alert on service downtime

### Security Considerations

- **Plaintext credentials**: By default, device credentials are in `/srv/oxidized/config/config`
  - File is root-owned and readable by container
  - Consider environment variables or secrets manager for high-security environments
- **API authentication**: Not enabled by default
  - Restrict access via firewall
  - Consider reverse proxy with authentication
- **Git repository**: Contains device configurations
  - May include sensitive information
  - Protect access to `/srv/oxidized/git`

---

## 📚 Documentation

### Repository Documentation

| Document | Description |
|----------|-------------|
| **[PREREQUISITES.md](docs/PREREQUISITES.md)** | System requirements and package installation |
| **[INSTALL.md](docs/INSTALL.md)** | Step-by-step installation guide |
| **[CONFIGURATION.md](docs/CONFIGURATION.md)** | Detailed `.env` configuration guide |
| **[ENV-ARCHITECTURE.md](docs/ENV-ARCHITECTURE.md)** | Environment-based configuration architecture |
| **[UPGRADE.md](docs/UPGRADE.md)** | Version upgrade and rollback procedures |
| **[SECURITY-HARDENING.md](docs/SECURITY-HARDENING.md)** | Advanced security configurations |
| **[DECISIONS.md](docs/DECISIONS.md)** | Implementation decisions and rationale |
| **[requirements.md](docs/requirements.md)** | Project requirements and specifications |
| **[monitoring/ZABBIX.md](docs/monitoring/ZABBIX.md)** | Zabbix monitoring setup and queries |

### Management Scripts

| Script | Description |
|--------|-------------|
| **[deploy.sh](scripts/deploy.sh)** | Automated deployment with prerequisites checks |
| **[validate-env.sh](scripts/validate-env.sh)** | Validate `.env` configuration before deployment |
| **[health-check.sh](scripts/health-check.sh)** | Comprehensive health checks (JSON/Nagios compatible) |
| **[uninstall.sh](scripts/uninstall.sh)** | Safe uninstallation with data preservation option |
| **[run-precommit.sh](scripts/run-precommit.sh)** | Pre-commit hooks for code quality |

### External Documentation

- **[Oxidized GitHub](https://github.com/yggdrasil-network/oxidized)** - Official Oxidized documentation
- **[Podman Documentation](https://docs.podman.io/)** - Podman and Quadlet guides
- **[RHEL Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10)** - RHEL 10 guides

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run pre-commit checks: `./scripts/run-precommit.sh`
5. Submit a pull request

### Development Standards

This repository follows strict coding standards defined in [docs/ai/CONTEXT.md](docs/ai/CONTEXT.md), including:

- Bash standards (`set -euo pipefail`, proper quoting)
- Idempotency and safety
- Security best practices
- Documentation requirements

---

## 📄 License

This project is licensed under the **Apache License 2.0**.

See [LICENSE](LICENSE) file for details.

```text
Copyright 2026

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

---

## 🙏 Acknowledgments

- **[Oxidized Project](https://github.com/yggdrasil-network/oxidized)** - The excellent network config backup tool
- **[Podman](https://podman.io/)** - Daemonless container engine
- **[Red Hat](https://www.redhat.com/)** - RHEL platform

---

## 📞 Support

- 📧 Email: support@example.com
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/deploy-containerized-oxidized/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/deploy-containerized-oxidized/discussions)

---

Made with ❤️ for Network Engineers

*Automated configuration backups shouldn't be complicated.*
