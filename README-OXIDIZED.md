# 📘 Oxidized Usage and Configuration Guide

This guide covers how to use, configure, and troubleshoot Oxidized once deployed using this repository's deployment scripts.

**For deployment instructions**, see [README.md](README.md).

---

## 📋 Table of Contents

- [What is Oxidized?](#-what-is-oxidized)
- [Service Management](#-service-management)
- [Configuration](#-configuration)
- [Device Inventory](#-device-inventory)
- [Web UI](#-web-ui)
- [REST API](#-rest-api)
- [Git Repository](#-git-repository)
- [Logs](#-logs)
- [Monitoring](#-monitoring)
- [Upgrade & Rollback](#-upgrade--rollback)
- [Troubleshooting](#-troubleshooting)
- [Security Considerations](#-security-considerations)
- [External Documentation](#-external-documentation)

---

## 🤖 What is Oxidized?

Oxidized is a network device configuration backup tool that:

- **Automatically backs up** network device configurations on a schedule
- **Tracks changes** using Git version control with full history
- **Supports 130+ device models** including:
  - Cisco (IOS, IOS-XR, NX-OS, ASA)
  - Juniper (JunOS)
  - Arista (EOS)
  - HP (ProCurve, Comware)
  - Fortinet (FortiOS)
  - Palo Alto (PAN-OS)
  - Aruba (AOS-CX)
  - And many more...
- **Provides a Web UI** for viewing configurations and diffs
- **Exposes a REST API** for automation and monitoring integration
- **Runs in a container** with persistent storage for configs and Git history

---

## 🎮 Service Management

Oxidized runs as a systemd service managed by Podman Quadlets.

### Start Service

```bash
sudo systemctl start oxidized.service
```

### Stop Service

```bash
sudo systemctl stop oxidized.service
```

### Restart Service

```bash
sudo systemctl restart oxidized.service
```

### Check Status

```bash
sudo systemctl status oxidized.service
```

### Enable Auto-Start on Boot

```bash
sudo systemctl enable oxidized.service
```

### Disable Auto-Start

```bash
sudo systemctl disable oxidized.service
```

### View Logs

```bash
# Follow logs in real-time
sudo journalctl -u oxidized.service -f

# View last 50 lines
sudo journalctl -u oxidized.service -n 50

# View logs since yesterday
sudo journalctl -u oxidized.service --since yesterday
```

---

## ⚙️ Configuration

### Configuration File

**Host Location**: `/var/lib/oxidized/config/config`
**Container Location**: `/home/oxidized/.config/oxidized/config`
**Format**: YAML

The configuration file is automatically generated during deployment from `.env` variables and the `config/oxidized/config.template` file.

### Key Configuration Settings

```yaml
# Global device credentials (can be overridden per-device in router.db)
username: admin
password: your_secure_password

# Polling interval (seconds)
interval: 3600  # 1 hour

# REST API and Web UI (oxidized-web extension)
extensions:
  oxidized-web:
    host: 0.0.0.0
    port: 8888

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

### Modifying Configuration

**Do not edit the generated config file directly**. Instead:

1. Update variables in `.env` file
2. For advanced settings, edit `config/oxidized/config.template` in the repository
3. Re-run deployment: `sudo ./scripts/deploy.sh`
4. Restart service: `sudo systemctl restart oxidized.service`

### Common Configuration Changes

**Change polling interval**:

```bash
# Edit .env
POLL_INTERVAL=7200  # 2 hours

# Re-deploy and restart
sudo ./scripts/deploy.sh
sudo systemctl restart oxidized.service
```

**Enable/disable Web UI**:

```bash
# Edit .env
OXIDIZED_WEB_UI="true"   # or "false"

# Re-deploy and restart
sudo ./scripts/deploy.sh
sudo systemctl restart oxidized.service
```

**Change credentials**:

```bash
# Edit .env
OXIDIZED_USERNAME="newuser"
OXIDIZED_PASSWORD="newpassword"

# Re-deploy and restart
sudo ./scripts/deploy.sh
sudo systemctl restart oxidized.service
```

---

## 📊 Device Inventory (router.db)

Oxidized uses a CSV-based inventory file (`router.db`) to define which network devices to back up.

### File Locations

- **Template**: `inventory/router.db.template` (in this repository)
- **Live file (host)**: `/var/lib/oxidized/config/router.db`
- **Inside container**: `/home/oxidized/.config/oxidized/router.db`

**Important**: The live file is mounted into the container via the `/var/lib/oxidized/config` bind mount. Always place your `router.db` file in `/var/lib/oxidized/config/` on the host.

### Creating the Inventory File

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
# CRITICAL for security - file may contain credentials
sudo chown 30000:30000 /var/lib/oxidized/config/router.db
sudo chmod 644 /var/lib/oxidized/config/router.db
```

**Step 4**: Restart service to load changes

```bash
sudo systemctl restart oxidized.service
```

### File Format

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

### Credential Modes

Oxidized supports three credential authentication modes:

#### Mode 1: Global Credentials (Recommended)

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

#### Mode 2: Per-Device Credentials

Specify credentials for each device individually:

```text
core-router01:10.1.1.1:ios:core:netadmin:CorePass123
edge-switch01:10.1.2.1:procurve:distribution:switchuser:SwitchPass456
firewall01:10.1.3.1:fortios:firewalls:fwadmin:FirewallPass789
```

**Best for**: Heterogeneous environments with different credentials per device

**⚠️ SECURITY WARNING**: Per-device credentials are stored in **plaintext** in `router.db`

- **MUST** set permissions: `chmod 644 /var/lib/oxidized/config/router.db`
- **MUST** set ownership: `chown 30000:30000 /var/lib/oxidized/config/router.db` (container's UID)
- **NEVER** commit `router.db` with real credentials to Git

#### Mode 3: Mixed (Global with Exceptions)

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

### SSH Key Authentication (Recommended)

**SSH key authentication is the preferred method** for securing device access. It eliminates plaintext passwords and provides better security and auditability.

#### Why Use SSH Keys?

✅ **More secure** - No plaintext passwords in configuration files
✅ **Centralized management** - One key pair for all devices
✅ **Better auditing** - Device logs show key-based authentication
✅ **Easy rotation** - Revoke old key, deploy new one
✅ **Prevents password spray attacks** - Keys are cryptographically strong

#### How SSH Keys Work with Oxidized

1. **Key pair generated** on Oxidized host (private + public key)
2. **Public key deployed** to all network devices
3. **Private key stays** on Oxidized server (read-only mount to container)
4. **Oxidized authenticates** using private key (no password needed)

#### SSH Key File Locations

**On Host:**
```
/var/lib/oxidized/ssh/
├── id_ed25519          # Private key (keep secret!)
├── id_ed25519.pub      # Public key (deploy to devices)
└── known_hosts         # SSH fingerprints (auto-created)
```

**In Container** (bind-mounted read-only):
```
/home/oxidized/.ssh/    → /var/lib/oxidized/ssh (host)
```

---

#### Step-by-Step Setup

##### Step 1: Generate SSH Key Pair

###### Option A: Ed25519 (Recommended - Modern, Secure, Fast)

```bash
# Generate key as the oxidized user
sudo -u oxidized ssh-keygen -t ed25519 \
  -f /var/lib/oxidized/ssh/id_ed25519 \
  -C "oxidized@$(hostname)" \
  -N ""

# Set correct permissions (critical!)
sudo chmod 600 /var/lib/oxidized/ssh/id_ed25519
sudo chmod 644 /var/lib/oxidized/ssh/id_ed25519.pub
sudo chown 30000:30000 /var/lib/oxidized/ssh/id_ed25519*
```

###### Option B: RSA 4096 (Traditional, Widely Supported)

```bash
# Generate RSA key
sudo -u oxidized ssh-keygen -t rsa -b 4096 \
  -f /var/lib/oxidized/ssh/id_rsa \
  -C "oxidized@$(hostname)" \
  -N ""

# Set permissions
sudo chmod 600 /var/lib/oxidized/ssh/id_rsa
sudo chmod 644 /var/lib/oxidized/ssh/id_rsa.pub
sudo chown 30000:30000 /var/lib/oxidized/ssh/id_rsa*
```

**Key Generation Options Explained:**
- `-t ed25519` or `-t rsa -b 4096` - Key type and size
- `-f /path/to/key` - Output file path
- `-C "comment"` - Key comment (helpful for identification)
- `-N ""` - No passphrase (required for automated backups)

##### Step 2: Deploy Public Key to Network Devices

You have two deployment methods:

###### Method A: Automated (ssh-copy-id)

```bash
# Copy public key to each device
sudo -u oxidized ssh-copy-id -i /var/lib/oxidized/ssh/id_ed25519.pub admin@10.1.1.1
sudo -u oxidized ssh-copy-id -i /var/lib/oxidized/ssh/id_ed25519.pub admin@10.1.2.1
sudo -u oxidized ssh-copy-id -i /var/lib/oxidized/ssh/id_ed25519.pub admin@10.1.3.1

# You'll be prompted for the password once per device
```

###### Method B: Manual (for devices without ssh-copy-id support)

1. **Display the public key:**

   ```bash
   sudo cat /var/lib/oxidized/ssh/id_ed25519.pub
   ```

2. **Copy the output** (entire line, looks like):

   ```
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx... oxidized@hostname
   ```

3. **Add to device authorized_keys** (varies by vendor):

   **Cisco IOS/IOS-XE:**
   ```
   conf t
   ip ssh pubkey-chain
     username admin
       key-string
         <paste public key here>
       exit
     exit
   exit
   write memory
   ```

   **Juniper JunOS:**
   ```
   set system login user admin authentication ssh-rsa "<paste public key>"
   commit
   ```

   **Arista EOS:**
   ```
   configure
   username admin sshkey ssh-ed25519 <paste public key>
   write memory
   ```

   **Linux/Unix devices:**
   ```bash
   # SSH to device and run:
   echo "ssh-ed25519 AAAAC3Nz..." >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

##### Step 3: Configure Oxidized to Use SSH Keys

**Update `.env` file:**

```bash
# SSH key configuration
SSH_PRIVATE_KEY="id_ed25519"     # or "id_rsa" for RSA keys
SSH_KNOWN_HOSTS="known_hosts"

# Optional: Set username (if using SSH keys, password not needed)
OXIDIZED_USERNAME="admin"
OXIDIZED_PASSWORD=""             # Can be blank or dummy value
```

**Update `router.db`** (leave password columns blank):

```text
# SSH key auth - no passwords needed
core-router01:10.1.1.1:ios:core:admin:
edge-switch01:10.1.2.1:procurve:distribution:admin:
firewall01:10.1.3.1:fortios:firewalls:admin:
```

Or use global credentials (username only):

```text
# Global username from .env, SSH key for auth
core-router01:10.1.1.1:ios:core::
edge-switch01:10.1.2.1:procurve:distribution::
```

##### Step 4: Restart and Verify

```bash
# Restart service to load SSH key
sudo systemctl restart oxidized.service

# Check for errors
sudo systemctl status oxidized.service

# Watch logs for SSH authentication
sudo journalctl -u oxidized.service -f
```

**Successful SSH key authentication logs look like:**

```
Successfully connected to device 10.1.1.1 using SSH key authentication
Fetching configuration from core-router01 (10.1.1.1)
```

---

#### Troubleshooting SSH Key Authentication

##### Problem: "Permission denied (publickey)"

```bash
# Check key permissions
ls -la /var/lib/oxidized/ssh/
# Should show:
# -rw------- 1 oxidized oxidized ... id_ed25519 (600)
# -rw-r--r-- 1 oxidized oxidized ... id_ed25519.pub (644)

# Fix permissions
sudo chmod 600 /var/lib/oxidized/ssh/id_ed25519
sudo chown 30000:30000 /var/lib/oxidized/ssh/id_ed25519

# Verify public key is on device
ssh admin@10.1.1.1 "show run | include ssh"  # Cisco IOS
```

##### Problem: "Host key verification failed"

```bash
# Clear known_hosts and retry (first connection)
sudo rm /var/lib/oxidized/ssh/known_hosts
sudo systemctl restart oxidized.service

# Or manually accept host key
sudo -u oxidized ssh -o StrictHostKeyChecking=no admin@10.1.1.1
```

##### Problem: "Private key not found"

```bash
# Verify file exists
ls -l /var/lib/oxidized/ssh/id_ed25519

# Check .env configuration
grep SSH_PRIVATE_KEY /root/deploy-containerized-oxidized/.env

# Verify bind mount in container
sudo podman exec oxidized ls -la /home/oxidized/.ssh/
```

##### Problem: Device still prompts for password

- **Cause 1**: Public key not deployed correctly to device
- **Cause 2**: Device username doesn't match (check `router.db` column 4)
- **Cause 3**: Device SSH key authentication disabled
- **Cause 4**: Wrong key format for device (try RSA instead of Ed25519)

```bash
# Test SSH key authentication manually
sudo -u oxidized ssh -i /var/lib/oxidized/ssh/id_ed25519 admin@10.1.1.1

# If successful, check Oxidized config
sudo cat /var/lib/oxidized/config/config | grep -A5 "ssh:"
```

---

#### Security Best Practices for SSH Keys

1. **Never share the private key** (`id_ed25519` or `id_rsa`)
   - Keep it on the Oxidized server only
   - Never email, copy to workstations, or commit to Git

2. **Restrict private key permissions**:
   ```bash
   sudo chmod 600 /var/lib/oxidized/ssh/id_ed25519
   sudo chown 30000:30000 /var/lib/oxidized/ssh/id_ed25519
   ```

3. **Audit device logs** for SSH key usage:
   - Monitor for unauthorized key-based logins
   - Verify Oxidized server IP is the only source

4. **Rotate keys periodically** (annually recommended):
   ```bash
   # Generate new key
   sudo -u oxidized ssh-keygen -t ed25519 -f /var/lib/oxidized/ssh/id_ed25519_new

   # Deploy to all devices
   # Remove old key from devices
   # Rename new key to replace old
   sudo mv /var/lib/oxidized/ssh/id_ed25519_new /var/lib/oxidized/ssh/id_ed25519

   # Restart Oxidized
   sudo systemctl restart oxidized.service
   ```

5. **Backup private key securely**:
   ```bash
   # Encrypted backup
   sudo tar -czf - /var/lib/oxidized/ssh/id_ed25519 | \
     gpg --symmetric --cipher-algo AES256 > oxidized-sshkey-backup.tar.gz.gpg

   # Store in secure location (vault, encrypted storage)
   ```

6. **Use device ACLs** to restrict SSH access:
   ```
   # Cisco IOS example - only allow Oxidized server
   access-list 10 permit host 10.0.0.50
   line vty 0 15
     access-class 10 in
   ```

---

#### Mixed Authentication (SSH Keys + Passwords)

You can use **both SSH keys and passwords** in the same deployment:

**Scenario**: Most devices use SSH keys, but legacy devices require passwords

**Configuration**:

1. **Set global SSH key** in `.env`:
   ```bash
   SSH_PRIVATE_KEY="id_ed25519"
   OXIDIZED_USERNAME="admin"
   ```

2. **Specify passwords only for exceptions** in `router.db`:
   ```text
   # Modern devices - use SSH key (blank password)
   core-router01:10.1.1.1:ios:core:admin:
   edge-switch01:10.1.2.1:procurve:distribution:admin:

   # Legacy device - requires password (SSH keys not supported)
   old-switch01:10.1.99.1:ios:legacy:admin:LegacyPassword123
   ```

**Oxidized behavior**:
- Tries SSH key authentication first
- Falls back to password if key auth fails
- Logs indicate which method succeeded

### Supported Models (Common Examples)

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

### Example Inventory File

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

### Validation

After creating or modifying `router.db`:

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

### Adding/Removing Devices

To modify the device list:

1. Edit the file:
   ```bash
   sudo vim /var/lib/oxidized/config/router.db
   ```

2. Add or remove device lines (one per line)

3. Save and restart:
   ```bash
   sudo systemctl restart oxidized.service
   ```

Oxidized will automatically pick up the changes on restart.

---

## 🌐 Web UI

Oxidized provides a web interface for viewing device configurations and changes.

### Accessing the Web UI

**Default URL**: `http://<your-server-ip>:8888`

Example:
```bash
http://10.1.1.100:8888
```

### Enabling/Disabling Web UI

The Web UI is controlled by the `OXIDIZED_WEB_UI` variable:

```bash
# Edit .env
OXIDIZED_WEB_UI="true"   # Enable
OXIDIZED_WEB_UI="false"  # Disable

# Re-deploy and restart
sudo ./scripts/deploy.sh
sudo systemctl restart oxidized.service
```

### Web UI Features

- **Device List**: View all configured devices and their backup status
- **Configuration Viewer**: View current and historical configurations
- **Diff Viewer**: Compare configuration versions
- **Search**: Search across all device configurations
- **Groups**: Filter devices by group
- **Status Indicators**: See last backup time and success/failure status

### Firewall Configuration

If accessing the Web UI remotely, ensure port 8888 is open:

```bash
# For firewalld (RHEL default)
sudo firewall-cmd --permanent --add-port=8888/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

---

## 🔌 REST API

Oxidized exposes a REST API for programmatic access and automation.

### API Endpoint

**Base URL**: `http://<your-server-ip>:8888`

### Common API Operations

#### Get All Devices

```bash
curl -s http://localhost:8888/nodes | jq
```

#### Get Device Configuration

```bash
# Get latest config
curl -s http://localhost:8888/node/show/<device-name> | jq

# Example
curl -s http://localhost:8888/node/show/core-router01 | jq
```

#### Trigger Backup for Specific Device

```bash
curl -X GET http://localhost:8888/node/fetch/<device-name>

# Example
curl -X GET http://localhost:8888/node/fetch/core-router01
```

#### Get Device Status

```bash
curl -s http://localhost:8888/node/show/<device-name>.json | jq
```

#### Reload Configuration

```bash
curl -X GET http://localhost:8888/reload
```

### API Response Format

All API responses are in JSON format. Use `jq` for pretty-printing:

```bash
curl -s http://localhost:8888/nodes | jq '.'
```

---

## 📁 Git Repository

Oxidized stores all device configurations in a Git repository with full version history.

### Repository Location

- **Host**: `/var/lib/oxidized/repo/`
- **Container**: `/home/oxidized/.config/oxidized/repo/`

### Viewing Configuration History

```bash
# Navigate to repo
cd /var/lib/oxidized/repo

# View commit history
sudo git log --oneline

# View specific device history
sudo git log -- core-router01

# View diff between commits
sudo git diff <commit1> <commit2>

# View changes in last commit
sudo git show HEAD
```

### Searching Configurations

```bash
# Search all configs for a string
cd /var/lib/oxidized/repo
sudo git grep "ip address 10.1.1.1"

# Search with context
sudo git grep -C 3 "hostname core-router01"
```

### Viewing Specific Device Configuration

```bash
# View current config
sudo cat /var/lib/oxidized/repo/core-router01

# View config at specific commit
sudo git show <commit-hash>:core-router01
```

### Remote Repository Backup

To push backups to a remote Git repository:

1. Configure remote in the Git repo:
   ```bash
   cd /var/lib/oxidized/repo
   sudo git remote add origin https://github.com/yourorg/network-configs.git
   ```

2. Set up authentication (SSH keys or tokens)

3. Create a cron job or systemd timer to push regularly:
   ```bash
   # Example cron (runs daily at 2 AM)
   0 2 * * * cd /var/lib/oxidized/repo && git push origin main
   ```

---

## 📋 Logs

Oxidized generates logs for monitoring backup operations and troubleshooting.

### Log Locations

- **Oxidized Application Log**: `/var/lib/oxidized/data/oxidized.log`
- **Systemd Journal**: `journalctl -u oxidized.service`

### Viewing Logs

```bash
# View Oxidized application log
sudo tail -f /var/lib/oxidized/data/oxidized.log

# View systemd journal (real-time)
sudo journalctl -u oxidized.service -f

# View last 100 lines
sudo journalctl -u oxidized.service -n 100

# View logs since yesterday
sudo journalctl -u oxidized.service --since yesterday

# View logs for specific time range
sudo journalctl -u oxidized.service --since "2026-01-15 10:00:00" --until "2026-01-15 11:00:00"
```

### Log Rotation

Logs are automatically rotated by logrotate:

- **Configuration**: `/etc/logrotate.d/oxidized`
- **Rotation**: Daily
- **Retention**: 14 days
- **Compression**: Yes (gzip)

Rotated logs are stored at:
```bash
/var/lib/oxidized/data/oxidized.log.1.gz
/var/lib/oxidized/data/oxidized.log.2.gz
...
```

### Common Log Messages

**Successful backup**:
```
I, [2026-01-17T10:00:00.123456 #1]  INFO -- : node core-router01 completed in 2.5s
```

**Failed backup**:
```
E, [2026-01-17T10:00:00.123456 #1] ERROR -- : node core-router01 failed: Connection timeout
```

**Configuration change detected**:
```
I, [2026-01-17T10:00:00.123456 #1]  INFO -- : Configuration updated for core-router01
```

---

## 📊 Monitoring

### Quick Health Check

Use the included health check script:

```bash
sudo ./scripts/health-check.sh
```

This checks:
- Service status
- Container health
- Recent backups
- Disk space
- File permissions

### Monitoring with Zabbix

See [docs/monitoring/ZABBIX.md](docs/monitoring/ZABBIX.md) for:
- Zabbix template installation
- Pre-configured monitoring items
- Alert triggers
- Dashboard examples

### Key Metrics to Monitor

#### 1. Service Status

```bash
systemctl is-active oxidized.service
```

#### 2. Last Backup Time

```bash
sudo ls -lt /var/lib/oxidized/repo/ | head -n 5
```

#### 3. Failed Backups

```bash
sudo journalctl -u oxidized.service | grep -i error
```

#### 4. Disk Space

```bash
df -h /var/lib/oxidized
```

#### 5. Container Status

```bash
podman ps --filter "name=oxidized"
```

---

## 🔄 Upgrade & Rollback

### Upgrading Oxidized

To upgrade to a new Oxidized version:

1. **Check release notes**:
   - Visit: https://github.com/yggdrasil-network/oxidized/releases
   - Review breaking changes and new features

2. **Backup current data**:
   ```bash
   sudo tar -czf oxidized-backup-$(date +%Y%m%d).tar.gz /var/lib/oxidized
   ```

3. **Update image version in `.env`**:
   ```bash
   # Edit .env
   OXIDIZED_IMAGE="docker.io/oxidized/oxidized:0.30.2"  # New version
   ```

4. **Re-deploy**:
   ```bash
   sudo ./scripts/deploy.sh
   ```

5. **Verify**:
   ```bash
   sudo systemctl status oxidized.service
   sudo ./scripts/health-check.sh
   ```

### Rollback

If an upgrade causes issues:

1. **Stop service**:
   ```bash
   sudo systemctl stop oxidized.service
   ```

2. **Update `.env` to previous version**:
   ```bash
   OXIDIZED_IMAGE="docker.io/oxidized/oxidized:0.35.0"  # Previous version
   ```

3. **Re-deploy**:
   ```bash
   sudo ./scripts/deploy.sh
   ```

4. **Start service**:
   ```bash
   sudo systemctl start oxidized.service
   ```

5. **Verify**:
   ```bash
   sudo systemctl status oxidized.service
   ```

### Version History

Track deployed versions in `.env` and Git:

```bash
# View deployment history
git log --oneline -- .env

# View specific version that was deployed
git show <commit-hash>:.env | grep OXIDIZED_IMAGE
```

---

## 🚨 Troubleshooting

### Common Issues

#### Service Won't Start

**Check service status**:
```bash
sudo systemctl status oxidized.service
sudo journalctl -u oxidized.service -n 50
```

**Common causes**:
- Port 8888 already in use
- Invalid configuration syntax
- Missing/incorrect file permissions
- Container image pull failure

**Solution**:
```bash
# Check port usage
sudo ss -tulpn | grep 8888

# Validate configuration
sudo cat /var/lib/oxidized/config/config

# Check permissions
ls -la /var/lib/oxidized/

# Pull image manually
sudo podman pull docker.io/oxidized/oxidized:0.35.0
```

#### Devices Not Backing Up

**Check router.db file**:
```bash
# Verify file exists and has correct permissions
ls -la /var/lib/oxidized/config/router.db

# Check format
sudo head -10 /var/lib/oxidized/config/router.db
```

**Common causes**:
- Incorrect file format (must be colon-delimited)
- Wrong credentials
- Network connectivity issues
- Unsupported device model
- SSH/Telnet connection issues

**Solution**:
```bash
# Test device connectivity
ping 10.1.1.1

# Test SSH access
ssh admin@10.1.1.1

# Check logs for specific error
sudo journalctl -u oxidized.service | grep "core-router01"

# Verify device model is supported
# See: https://github.com/yggdrasil-network/oxidized/tree/master/lib/oxidized/model
```

#### Permission Denied Errors

**Solution**: Fix ownership and permissions

```bash
sudo chown 30000:30000 /var/lib/oxidized/config/router.db
sudo chmod 644 /var/lib/oxidized/config/router.db
sudo systemctl restart oxidized.service
```

#### Container Keeps Restarting

**Check container logs**:
```bash
sudo podman logs oxidized
```

**Common causes**:
- Configuration syntax errors
- Missing required files
- SELinux issues

**Solution**:
```bash
# Check SELinux denials
sudo ausearch -m AVC -ts recent | grep oxidized

# Validate Quadlet file
sudo cat /etc/containers/systemd/oxidized.container

# Restart from scratch
sudo systemctl stop oxidized.service
sudo ./scripts/deploy.sh
sudo systemctl start oxidized.service
```

#### Git Repository Issues

**Problem**: Git commits failing

**Solution**:
```bash
# Check Git configuration
cd /var/lib/oxidized/repo
sudo git config --list

# Fix Git identity if needed
sudo git config user.name "Oxidized"
sudo git config user.email "oxidized@example.com"

# Check for repository corruption
sudo git fsck
```

#### High CPU/Memory Usage

**Check resource usage**:
```bash
# Container stats
podman stats oxidized --no-stream

# Top processes
top -p $(pgrep -f oxidized)
```

**Solutions**:
- Reduce polling frequency (increase `POLL_INTERVAL`)
- Reduce thread count (decrease `THREADS`)
- Check for problematic devices causing timeouts

**Adjust in `.env`**:
```bash
POLL_INTERVAL=7200  # Increase from 3600
THREADS=15          # Decrease from 30
```

#### Web UI Not Accessible

**Check Web UI is enabled**:
```bash
grep "web:" /var/lib/oxidized/config/config
```

**Check firewall**:
```bash
sudo firewall-cmd --list-ports | grep 8888

# Add port if missing
sudo firewall-cmd --permanent --add-port=8888/tcp
sudo firewall-cmd --reload
```

**Check service is listening**:
```bash
sudo ss -tulpn | grep 8888
```

### Inventory Troubleshooting

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
sudo chown 30000:30000 /var/lib/oxidized/config/router.db
sudo chmod 644 /var/lib/oxidized/config/router.db
sudo systemctl restart oxidized.service
```

### Getting Help

1. **Check logs first**:
   ```bash
   sudo journalctl -u oxidized.service -n 100
   sudo tail -100 /var/lib/oxidized/data/oxidized.log
   ```

2. **Run health check**:
   ```bash
   sudo ./scripts/health-check.sh
   ```

3. **Check Oxidized documentation**:
   - GitHub: https://github.com/yggdrasil-network/oxidized
   - Wiki: https://github.com/yggdrasil-network/oxidized/wiki

4. **Review repository documentation**:
   - [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
   - [docs/monitoring/ZABBIX.md](docs/monitoring/ZABBIX.md)

---

## 🔒 Security Considerations

### Credential Security

**Best Practices**:

1. **Use SSH keys instead of passwords** (preferred):
   ```bash
   # Generate key
   sudo -u oxidized ssh-keygen -t ed25519 -f /var/lib/oxidized/ssh/id_ed25519

   # Copy to devices
   sudo -u oxidized ssh-copy-id -i /var/lib/oxidized/ssh/id_ed25519.pub admin@10.1.1.1
   ```

2. **Rotate passwords regularly** (quarterly recommended)

3. **Use least-privilege accounts** on devices (read-only access)

4. **Secure router.db file**:
   ```bash
   sudo chmod 644 /var/lib/oxidized/config/router.db
   sudo chown 30000:30000 /var/lib/oxidized/config/router.db
   ```

5. **Never commit credentials to Git**:
   - The template includes `.gitignore` rules
   - Verify: `git status` should not show `router.db`

### Network Security

1. **Restrict API access**:
   - Use firewall rules to limit access to port 8888
   - Consider placing behind reverse proxy with authentication

2. **Device access control**:
   - Configure ACLs on network devices to only allow Oxidized server IP
   - Log all Oxidized connections on devices

3. **Encrypt backups at rest**:
   ```bash
   # Consider encrypting /var/lib/oxidized with LUKS
   # Or use encrypted storage backend
   ```

### Container Security

This deployment includes several security hardening measures:

- Non-root container user (UID 30000)
- Read-only root filesystem
- No elevated capabilities
- SELinux enforcing
- Resource limits
- Network isolation

See [docs/SECURITY-HARDENING.md](docs/SECURITY-HARDENING.md) for complete security documentation.

---

## 📚 External Documentation

### Official Oxidized Resources

- **GitHub Repository**: https://github.com/yggdrasil-network/oxidized
- **Documentation Wiki**: https://github.com/yggdrasil-network/oxidized/wiki
- **Supported Models**: https://github.com/yggdrasil-network/oxidized/tree/master/lib/oxidized/model
- **Configuration Reference**: https://github.com/yggdrasil-network/oxidized/blob/master/docs/Configuration.md
- **Hooks Documentation**: https://github.com/yggdrasil-network/oxidized/blob/master/docs/Hooks.md

### Deployment Documentation

- [README.md](README.md) - Deployment instructions for this repository
- [docs/INSTALL.md](docs/INSTALL.md) - Detailed installation guide
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md) - Configuration deep-dive
- [docs/SECURITY-HARDENING.md](docs/SECURITY-HARDENING.md) - Security best practices
- [docs/UPGRADE.md](docs/UPGRADE.md) - Upgrade procedures
- [docs/monitoring/ZABBIX.md](docs/monitoring/ZABBIX.md) - Zabbix monitoring setup

### Community Resources

- **Oxidized Gitter Chat**: https://gitter.im/oxidized/Lobby
- **Reddit r/networking**: Discussions about network automation
- **Network to Code**: Automation tutorials and examples

---

## 💡 Tips and Best Practices

### Backup Strategy

1. **Regular backups of /var/lib/oxidized**:
   ```bash
   # Daily backup script
   #!/bin/bash
   tar -czf /backup/oxidized-$(date +%Y%m%d).tar.gz /var/lib/oxidized
   find /backup -name "oxidized-*.tar.gz" -mtime +30 -delete
   ```

2. **Push Git repo to remote regularly**:
   - Provides off-site backup
   - Enables disaster recovery

### Performance Tuning

1. **Adjust polling interval based on change frequency**:
   - High-change environments: 1-2 hours
   - Stable networks: 4-8 hours
   - Development/lab: 15-30 minutes

2. **Optimize thread count**:
   - Default: 30 threads
   - Reduce if causing high CPU usage
   - Increase for faster backups of many devices

3. **Group devices logically**:
   - Easier filtering and management
   - Can apply group-specific settings
   - Better organization in Web UI

### Maintenance Schedule

- **Daily**: Review logs for errors
- **Weekly**: Check disk space usage
- **Monthly**: Verify all devices backing up successfully
- **Quarterly**: Rotate credentials, review access logs
- **Annually**: Review and update Oxidized version

---

**For deployment questions**, see [README.md](README.md)

**For issues or contributions**, see [CONTRIBUTING.md](CONTRIBUTING.md)
