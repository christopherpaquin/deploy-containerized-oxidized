# 🚀 Installation Guide

This guide provides **step-by-step instructions** to deploy containerized Oxidized on RHEL 10 using Podman Quadlets and systemd.

---

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Installation Steps](#-installation-steps)
  - [1. Install System Prerequisites](#1-install-system-prerequisites)
  - [2. Create Directory Structure](#2-create-directory-structure)
  - [3. Deploy Configuration Files](#3-deploy-configuration-files)
  - [4. Initialize Git Repository](#4-initialize-git-repository)
  - [5. Install Quadlet File](#5-install-quadlet-file)
  - [6. Enable and Start Service](#6-enable-and-start-service)
  - [7. Verify Deployment](#7-verify-deployment)
- [Post-Installation](#-post-installation)
- [Troubleshooting](#-troubleshooting)

---

## ✅ Prerequisites

Before proceeding, ensure you have completed **[PREREQUISITES.md](PREREQUISITES.md)**:

- [ ] RHEL 10 (or RHEL 9)
- [ ] Podman installed
- [ ] SELinux enforcing
- [ ] Required packages installed
- [ ] Firewall configured
- [ ] 10 GB free space in `/var/lib`
- [ ] **Created `.env` file from `env.example`**

### Create Configuration File

```bash
# Copy template
cp env.example .env

# Edit configuration
vim .env

# Secure the file
chmod 600 .env
```

**⚠️ Important**: Update at least these values in `.env`:
- `OXIDIZED_PASSWORD` - Change from default!
- `OXIDIZED_USERNAME` - Your device login username
- Review all other settings for your environment

---

## 🔧 Installation Steps

### 1. Install System Prerequisites

Install all required packages:

```bash
sudo dnf install -y \
  podman \
  policycoreutils-python-utils \
  git \
  logrotate \
  curl \
  jq
```

Verify installation:

```bash
podman --version
git --version
getenforce  # Should show: Enforcing
```

---

### 2. Create Directory Structure

Create the persistent storage directory structure on the host:

```bash
# Create main directory
sudo mkdir -p /srv/oxidized

# Create subdirectories
sudo mkdir -p /srv/oxidized/config
sudo mkdir -p /srv/oxidized/inventory
sudo mkdir -p /srv/oxidized/data
sudo mkdir -p /srv/oxidized/git
sudo mkdir -p /srv/oxidized/logs

# Set ownership (root owns host directories)
sudo chown -R root:root /srv/oxidized

# Set permissions
sudo chmod 755 /srv/oxidized
sudo chmod 755 /srv/oxidized/config
sudo chmod 755 /srv/oxidized/inventory
sudo chmod 755 /srv/oxidized/data
sudo chmod 755 /srv/oxidized/git
sudo chmod 755 /srv/oxidized/logs
```

Verify directory structure:

```bash
tree /srv/oxidized
# Expected output:
# /srv/oxidized/
# ├── config/
# ├── inventory/
# ├── data/
# ├── git/
# └── logs/
```

---

### 3. Deploy Configuration Files

#### 3.1 Deploy Oxidized Configuration

Copy the Oxidized configuration file:

```bash
# From this repository
sudo cp config/oxidized/config /srv/oxidized/config/config

# Verify
ls -la /srv/oxidized/config/config
```

#### 3.2 Create Device Inventory

Create your device inventory CSV file:

```bash
# Copy example template
sudo cp config/oxidized/inventory/devices.csv.example \
        /srv/oxidized/inventory/devices.csv

# Edit with your actual devices
sudo vim /srv/oxidized/inventory/devices.csv
```

**CSV Format**:

```csv
name,ip,model,group
switch-01,192.168.1.1,ios,core
router-01,192.168.2.1,ios,wan
firewall-01,192.168.3.1,asa,security
```

**Supported Models**: `ios`, `iosxr`, `nxos`, `asa`, `junos`, `eos`, and [many more](https://github.com/yggdrasil-network/oxidized/tree/master/lib/oxidized/model).

#### 3.3 Configure Device Credentials

**IMPORTANT**: Update the credentials in `/srv/oxidized/config/config`:

```bash
sudo vim /srv/oxidized/config/config
```

Modify these lines:

```yaml
username: your_device_username
password: your_device_password
```

**Security Note**: For production, consider using environment variables or a secrets manager instead of plaintext passwords.

#### 3.4 Deploy Logrotate Configuration

Install the logrotate configuration:

```bash
sudo cp config/logrotate/oxidized /etc/logrotate.d/oxidized

# Verify
ls -la /etc/logrotate.d/oxidized

# Test logrotate configuration
sudo logrotate -d /etc/logrotate.d/oxidized
```

---

### 4. Initialize Git Repository

Initialize the Git repository where Oxidized will store device configurations:

**Option A: Regular Git Repository** (Recommended)

```bash
# Initialize regular Git repository
sudo git init /srv/oxidized/git/configs.git

# Configure Git
cd /srv/oxidized/git/configs.git
sudo git config user.name "Oxidized"
sudo git config user.email "oxidized@example.com"

# Create initial commit
sudo touch README.md
echo "# Network Device Configurations" | sudo tee README.md
sudo git add README.md
sudo git commit -m "Initial commit"
```

**Option B: Bare Git Repository** (Alternative)

```bash
# Initialize bare repository (if you prefer)
sudo git init --bare /srv/oxidized/git/configs.git

# Configure repository
cd /srv/oxidized/git/configs.git
sudo git config user.name "Oxidized"
sudo git config user.email "oxidized@example.com"
```

**Why Regular vs Bare?**

- **Regular repository**: Easier to inspect, view files directly, better for single-server setups
- **Bare repository**: More traditional for Git output, required if pushing to remotes

This deployment uses **regular repository** by default for simplicity.

Verify Git initialization:

```bash
ls -la /srv/oxidized/git/configs.git
# Should show .git directory (regular) or Git objects (bare)
```

---

### 5. Install Quadlet File

Install the Quadlet configuration file for systemd:

```bash
# Copy Quadlet file to systemd directory
sudo cp containers/quadlet/oxidized.container \
        /etc/containers/systemd/oxidized.container

# Verify
ls -la /etc/containers/systemd/oxidized.container

# Display contents
cat /etc/containers/systemd/oxidized.container
```

The Quadlet file defines:
- Container image and version
- Port bindings (8888)
- Volume mounts with SELinux context
- Restart policies
- Resource limits

---

### 6. Enable and Start Service

Reload systemd to detect the new Quadlet configuration:

```bash
# Reload systemd daemon
sudo systemctl daemon-reload
```

The Quadlet will automatically generate a systemd service file. Verify it was created:

```bash
# Check generated service file
sudo systemctl cat oxidized.service
```

Enable the service to start on boot:

```bash
# Enable service
sudo systemctl enable oxidized.service
```

Start the service:

```bash
# Start Oxidized
sudo systemctl start oxidized.service
```

Check service status:

```bash
# View status
sudo systemctl status oxidized.service

# Expected output:
# ● oxidized.service - Oxidized Network Configuration Backup Service
#      Loaded: loaded (/etc/containers/systemd/oxidized.container; enabled)
#      Active: active (running) since ...
```

---

### 7. Verify Deployment

#### 7.1 Check Container Status

```bash
# List running containers
podman ps

# Expected output should show oxidized container running
# CONTAINER ID  IMAGE                              COMMAND  CREATED
# abc123def456  docker.io/oxidized/oxidized:0.30.1          2 minutes ago
# STATUS        PORTS                   NAMES
# Up 2 minutes  0.0.0.0:8888->8888/tcp  oxidized
```

#### 7.2 Check Container Logs

```bash
# View container logs
podman logs oxidized

# Follow logs in real-time
podman logs -f oxidized

# Check for initialization messages
podman logs oxidized | grep -i "oxidized"
```

#### 7.3 Test REST API

```bash
# Check API health
curl -s http://localhost:8888/

# List all nodes
curl -s http://localhost:8888/nodes.json | jq '.'

# Expected output: JSON array of devices
```

#### 7.4 Access Web UI

Open a web browser and navigate to:

```text
http://<your-server-ip>:8888
```

You should see the Oxidized web interface with your device list.

#### 7.5 Verify Initial Backup

Wait for the first polling interval (up to 1 hour for hourly polling), or trigger a manual backup:

```bash
# Trigger manual backup via API
curl -X POST http://localhost:8888/reload

# Check node status
curl -s http://localhost:8888/nodes.json | jq '.[] | {name, last: .last}'
```

#### 7.6 Check Git Commits

```bash
# List Git commits
cd /srv/oxidized/git/configs.git
sudo git log --oneline

# Expected output: commits for each device backup
```

#### 7.7 Verify Log Files

```bash
# Check log file exists
ls -la /srv/oxidized/logs/oxidized.log

# View log contents
sudo tail -f /srv/oxidized/logs/oxidized.log
```

---

## ✅ Post-Installation

### Enable Firewall (if using firewalld)

```bash
# Allow port 8888 for internal zone
sudo firewall-cmd --zone=internal --add-port=8888/tcp --permanent
sudo firewall-cmd --reload
```

### Schedule Logrotate Test

```bash
# Manually test log rotation
sudo logrotate -f /etc/logrotate.d/oxidized

# Verify rotated logs
ls -la /srv/oxidized/logs/
```

### Configure Monitoring

Set up monitoring using the Oxidized API. See **[docs/monitoring/ZABBIX.md](monitoring/ZABBIX.md)** for details.

### Backup Configuration

Create periodic backups of the configuration and Git repository:

```bash
# Create backup script (example)
sudo tee /usr/local/bin/backup-oxidized.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/oxidized"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "${BACKUP_DIR}"

# Backup Git repository
tar -czf "${BACKUP_DIR}/oxidized-git-${TIMESTAMP}.tar.gz" \
    -C /srv/oxidized git/

# Backup configuration
tar -czf "${BACKUP_DIR}/oxidized-config-${TIMESTAMP}.tar.gz" \
    -C /srv/oxidized config/ inventory/

# Keep only last 7 days
find "${BACKUP_DIR}" -type f -mtime +7 -delete

echo "Backup completed: ${TIMESTAMP}"
EOF

sudo chmod +x /usr/local/bin/backup-oxidized.sh

# Test backup
sudo /usr/local/bin/backup-oxidized.sh
```

---

## 🚨 Troubleshooting

### Service Won't Start

```bash
# Check systemd status
sudo systemctl status oxidized.service

# Check journal logs
sudo journalctl -u oxidized.service -n 50

# Check Podman logs
podman logs oxidized
```

### Port Already in Use

```bash
# Check what's using port 8888
sudo netstat -tulpn | grep 8888

# Or with ss
sudo ss -tulpn | grep 8888

# Stop conflicting service or change port in Quadlet
```

### SELinux Denials

```bash
# Check for SELinux denials
sudo ausearch -m avc -ts recent

# If denials exist, verify :Z flag is set in Quadlet mounts
grep "Volume=" /etc/containers/systemd/oxidized.container
```

### Container Can't Write to Volumes

```bash
# Check directory permissions
ls -laZ /srv/oxidized/

# Verify SELinux context
ls -ldZ /srv/oxidized/*

# Restart container to reapply context
sudo systemctl restart oxidized.service
```

### Devices Not Backing Up

```bash
# Check device inventory
cat /srv/oxidized/inventory/devices.csv

# Verify credentials in config
sudo cat /srv/oxidized/config/config | grep -A2 username

# Test device connectivity
ping <device-ip>
ssh <username>@<device-ip>

# Check Oxidized logs
sudo tail -f /srv/oxidized/logs/oxidized.log
```

### Git Repository Issues

```bash
# Verify Git repo initialization
ls -la /srv/oxidized/git/configs.git/.git

# Check Git configuration
cd /srv/oxidized/git/configs.git
sudo git config --list

# Check Git logs
sudo git log
```

---

## 📚 Next Steps

- ✅ Installation complete!
- 📖 Read **[UPGRADE.md](UPGRADE.md)** for upgrade procedures
- 🔍 Set up **[monitoring/ZABBIX.md](monitoring/ZABBIX.md)** for alerting
- 📋 Review **[requirements.md](requirements.md)** for design details

---

## 🎯 Quick Reference

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

### API Commands

```bash
# List all nodes
curl -s http://localhost:8888/nodes.json | jq '.'

# Get specific node
curl -s http://localhost:8888/node/show/switch-01

# Reload inventory
curl -X POST http://localhost:8888/reload

# Trigger backup for specific node
curl -X GET http://localhost:8888/node/fetch/switch-01
```

### File Locations

| Purpose | Host Path | Container Path |
|---------|-----------|----------------|
| Config | `/srv/oxidized/config` | `/etc/oxidized` |
| Inventory | `/srv/oxidized/inventory` | `/etc/oxidized/inventory` |
| Data | `/srv/oxidized/data` | `/var/lib/oxidized` |
| Git Repo | `/srv/oxidized/git` | `/var/lib/oxidized/configs.git` |
| Logs | `/srv/oxidized/logs` | `/var/lib/oxidized/logs` |
| Quadlet | `/etc/containers/systemd/oxidized.container` | N/A |
| Logrotate | `/etc/logrotate.d/oxidized` | N/A |

---

**Installation Complete!** 🎉

Your Oxidized deployment is now running and will automatically start on boot.
