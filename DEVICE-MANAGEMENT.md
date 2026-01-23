# Oxidized Device Management Guide

Complete guide for managing network devices in Oxidized.

## Table of Contents

- [Device Inventory](#device-inventory)
- [Groups](#groups)
- [Adding Devices](#adding-devices)
- [Updating Devices](#updating-devices)
- [Removing Devices](#removing-devices)
- [Connection Methods: SSH and Telnet](#connection-methods-ssh-and-telnet)
- [Testing Devices](#testing-devices)
- [Backup Schedule](#backup-schedule)
- [Logging and Troubleshooting](#logging-and-troubleshooting)
- [Validation Tools](#validation-tools)
- [Backup Management](#backup-management)

---

## Device Inventory

### router.db File

**Location:**

- Active: `/var/lib/oxidized/config/router.db`
- Template: `inventory/router.db.template`

**Format:** Colon-delimited CSV

```
name:ip_address:model:group:username:password
```

**Fields:**

1. **name** - Device hostname/identifier (must be unique)
2. **ip_address** - IP address or FQDN
3. **model** - Device type (ios, junos, eos, etc.)
4. **group** - Logical grouping (**optional** but recommended - see [Groups](#groups) below)
5. **username** - SSH username (optional if using global credentials)
6. **password** - SSH password (optional if using global credentials)

**Example:**
```
core-router01:10.1.1.1:ios:core::
edge-switch01:10.2.1.1:procurve:access::
firewall01:10.3.1.1:fortios:security::
```

---

## Groups

### What Are Groups?

Groups are **optional** labels for organizing devices logically. The group field in `router.db` allows you to categorize devices and apply group-specific settings.

**Common use cases:**

- Organizational structure (core, edge, datacenter, branch)
- Network tiers (access, distribution, core)
- Security zones (dmz, internal, external)
- Physical locations (building-a, datacenter-1, remote-site)
- Device roles (routers, switches, firewalls)

### How Groups Work

**In router.db:**
```
name:ip:model:group:username:password
router1:10.1.1.1:ios:core::
router2:10.1.1.2:ios:edge::
switch1:10.2.1.1:ios:access::
```

**Groups are used for:**

1. **Organization** - Filter and view devices by group in Web UI
2. **Group-specific credentials** - Different groups can use different credentials
3. **Group-specific outputs** - Save different groups to different Git repos
4. **Reporting** - Generate reports by group
5. **Selective backups** - Trigger backups only for specific groups

### Groups Are Optional

**You can leave the group field empty:**
```
router1:10.1.1.1:ios:::
switch1:10.2.1.1:ios:::
```

This works fine! Groups are purely for organization. Oxidized will still back up devices without groups.

### Group-Specific Configuration

To apply different settings per group, edit `/var/lib/oxidized/config/config`:

```yaml
groups:
  core:
    username: core-admin
    password: core-password
  edge:
    username: edge-admin
    password: edge-password
  dmz:
    output:
      git:
        repo: /home/oxidized/.config/oxidized/repo-dmz
```

**Without group config**, all devices use the global settings.

### Group Examples

**By Network Tier:**
```
core-router01:10.1.1.1:ios:core::
core-router02:10.1.1.2:ios:core::
dist-switch01:10.2.1.1:ios:distribution::
dist-switch02:10.2.1.2:ios:distribution::
access-switch01:10.3.1.1:ios:access::
access-switch02:10.3.1.2:ios:access::
```

**By Location:**
```
hq-router01:10.1.1.1:ios:headquarters::
dc1-switch01:10.10.1.1:ios:datacenter-1::
branch1-router01:10.20.1.1:ios:branch-office::
```

**By Security Zone:**
```
fw-external01:10.1.1.1:fortios:external::
fw-dmz01:10.2.1.1:fortios:dmz::
core-internal01:10.3.1.1:ios:internal::
```

**By Device Type:**
```
router-core01:10.1.1.1:ios:routers::
switch-dist01:10.2.1.1:ios:switches::
firewall-edge01:10.3.1.1:fortios:firewalls::
```

### Best Practices for Groups

1. **Use consistent naming** - Decide on a scheme and stick to it
2. **Keep it simple** - Start with broad categories (core, edge, access)
3. **Document your scheme** - Add comments in router.db
4. **Use group config sparingly** - Only when you need different settings
5. **Empty is OK** - Don't force groups if you don't need them

### Viewing Devices by Group

**Web UI:**

- Navigate to `http://your-server:8888`
- Devices are sortable by group
- Filter by group in the interface

**API:**
```bash

# Get all devices

curl http://127.0.0.1:8889/nodes.json | jq '.'

# Filter by group

curl http://127.0.0.1:8889/nodes.json | jq '.[] | select(.group == "core")'

# Count devices per group

curl http://127.0.0.1:8889/nodes.json | jq 'group_by(.group) | map({group: .[0].group, count: length})'
```

**Command line:**
```bash

# List devices by group

grep -v "^#" /var/lib/oxidized/config/router.db | awk -F: '{print $4}' | sort | uniq -c

# Show all devices in "core" group

grep ":core:" /var/lib/oxidized/config/router.db
```

---

## Adding Devices

### Automatic Backups

**Every time you run `deploy.sh`, router.db is automatically backed up!**

```bash

# When deploy.sh runs, it creates:

/var/lib/oxidized/config/router.db.backup.YYYYMMDD_HHMMSS

# Example:

/var/lib/oxidized/config/router.db.backup.20260118_143022

# This ensures you can always restore previous versions

```

**Backup Features:**

- ✅ Timestamped backup created on every deployment
- ✅ Backups are never overwritten (unique timestamps)
- ✅ Original file is preserved during deployment
- ✅ Easy to restore if needed

**Restore a Backup:**
```bash

# List available backups

ls -lh /var/lib/oxidized/config/router.db.backup.*

# View backup content

cat /var/lib/oxidized/config/router.db.backup.20260118_143022

# Restore from backup

sudo cp /var/lib/oxidized/config/router.db.backup.20260118_143022 \
        /var/lib/oxidized/config/router.db

# Restart Oxidized to use restored config

sudo systemctl restart oxidized.service
```

### Method 1: Interactive Device Addition (Recommended)

**Use the interactive add-device script** for a user-friendly, guided experience:

```bash

# Run the interactive script

sudo /var/lib/oxidized/scripts/add-device.sh
```

**What it does:**

1. ✅ **Prompts for device hostname** with validation
2. ✅ **Prompts for IP address/FQDN** with validation
3. ✅ **Shows available OS types** from a comprehensive list
4. ✅ **Displays existing groups** or lets you create a new one
5. ✅ **Shows default credentials** from config (username only)
6. ✅ **Optionally prompts for device-specific credentials**
7. ✅ **Validates entry format** before adding
8. ✅ **Creates timestamped backup** in `/var/lib/oxidized/config/backup/`
9. ✅ **Appends to router.db** (never overwrites)
10. ✅ **Runs full syntax validation** on all entries

**Example session:**
```
╔══════════════════════════════════════════════════════════════════════════╗
║              Oxidized Device Management Tool                         ║
║                  Add Device to router.db                             ║
╚══════════════════════════════════════════════════════════════════════════╝

[?] Enter device hostname (e.g., switch01, core-router-01):
core-router01
[✓] Hostname: core-router01

[?] Enter IP address or FQDN (e.g., 10.1.1.1 or router.example.com):
10.1.1.1
[✓] IP/Hostname: 10.1.1.1

Available Device Models:
  1   aoscx           - Aruba AOS-CX
  2   arubaos         - Aruba ArubaOS
  3   asa             - Cisco ASA
  ...

[?] Enter device model (e.g., ios, nxos, junos, fortios):
ios
[✓] Device model: ios (Cisco IOS)

Existing groups in router.db:
  - core
  - datacenter
  - branch

[?] Enter group name (e.g., datacenter, branch, core, firewalls):
core
[✓] Using existing group: core

[INFO] Default credentials from config:
  Username: netadmin
  Password: ********** (hidden)

Do you want to override the default credentials for this device? (y/N): n
[✓] Using default credentials from config

Entry Details:
  Hostname: core-router01
  IP/FQDN:  10.1.1.1
  Model:    ios
  Group:    core
  Credentials: Using global defaults

Add this device to router.db? (y/N): y

[INFO] Creating backup...
[✓] Backup created: /var/lib/oxidized/config/backup/router.db.20260122_143022

[INFO] Adding entry to router.db...
[✓] Entry added to router.db

[INFO] Running full router.db validation...
[✓] Validation PASSED

╔══════════════════════════════════════════════════════════════════════════╗
║                    Device Added Successfully!                        ║
╚══════════════════════════════════════════════════════════════════════════╝

[✓] Device 'core-router01' has been added to router.db
[INFO] Oxidized will pick up this device on the next poll cycle

Next steps:
  1. Test the device: test-device.sh core-router01
  2. Check Oxidized logs: tail -f /var/lib/oxidized/data/oxidized.log
  3. Restart Oxidized (if needed): systemctl restart oxidized.service
```

**Features:**

- 🎯 **Validation at every step** - catches errors before they're added
- 🔒 **Never overwrites** - only appends to router.db
- 💾 **Automatic backups** - timestamped backup before any changes
- 📋 **Shows available options** - OS types, existing groups
- 🔐 **Secure credential handling** - passwords never displayed
- ✅ **Full validation** - runs syntax check on all entries after addition
- 📝 **Clear feedback** - shows exactly what will be added

### Method 2: Edit router.db Directly

```bash

# 1. Edit the file

sudo vi /var/lib/oxidized/config/router.db

# 2. Add your device

my-router:10.1.1.1:ios:production::

# 3. Validate syntax (optional but recommended)

./scripts/validate-router-db.sh

# 4. Restart Oxidized to pick up changes

sudo systemctl restart oxidized.service

# 5. Test the new device

./scripts/test-device.sh my-router
```

### Method 3: Quick Reload (No Restart)

```bash

# Edit router.db

sudo vi /var/lib/oxidized/config/router.db

# Send HUP signal to reload config

podman exec oxidized pkill -HUP ruby

# Note: This is faster but full restart is more reliable

```

### Credential Modes

**Global Credentials (Recommended):**
```bash

# Set in .env file

OXIDIZED_USERNAME="netadmin"
OXIDIZED_PASSWORD="YourPassword"

# In router.db, leave username/password blank

router1:10.1.1.1:ios:core::
router2:10.1.1.2:ios:core::
```

**Per-Device Credentials:**
```bash

# Specify in router.db

router1:10.1.1.1:ios:core:admin1:Pass123
router2:10.1.1.2:junos:core:admin2:Pass456
```

⚠️ **Security:** Per-device credentials are stored in plaintext. Use `chmod 600 router.db`.

---

## Updating Devices

### Change IP Address

```bash

# 1. Edit router.db

sudo vi /var/lib/oxidized/config/router.db

# 2. Change the IP

# OLD: router1:10.1.1.1:ios:core::

# NEW: router1:10.1.1.100:ios:core::

# 3. Restart Oxidized

sudo systemctl restart oxidized.service
```

### Change Credentials

**For Global Credentials:**
```bash

# 1. Edit .env

vi .env

OXIDIZED_USERNAME="newuser"
OXIDIZED_PASSWORD="newpass"

# 2. Redeploy (applies new credentials)

./scripts/deploy.sh
```

**For Per-Device Credentials:**
```bash

# 1. Edit router.db

sudo vi /var/lib/oxidized/config/router.db

# 2. Update credentials

router1:10.1.1.1:ios:core:newuser:newpass

# 3. Restart Oxidized

sudo systemctl restart oxidized.service
```

### Change Device Model

```bash

# 1. Edit router.db

sudo vi /var/lib/oxidized/config/router.db

# 2. Change model

# OLD: router1:10.1.1.1:ios:core::

# NEW: router1:10.1.1.1:iosxe:core::

# 3. Restart Oxidized

sudo systemctl restart oxidized.service

# 4. Test the device

./scripts/test-device.sh router1
```

---

## Removing Devices

### Remove from Inventory

```bash

# 1. Edit router.db

sudo vi /var/lib/oxidized/config/router.db

# 2. Delete or comment out the line

# router1:10.1.1.1:ios:core::

# 3. Restart Oxidized

sudo systemctl restart oxidized.service
```

**Note:** Removing a device from `router.db` does NOT delete its backup history from the Git repository.

### Remove Backup History (Optional)

```bash

# WARNING: This deletes all backup history for the device!

# 1. Remove device from router.db

# 2. Restart Oxidized

sudo systemctl restart oxidized.service

# 3. Remove from Git repo

cd /var/lib/oxidized/repo
sudo -u oxidized git rm <device-name>
sudo -u oxidized git commit -m "Removed decommissioned device: <device-name>"
```

---

## Connection Methods: SSH and Telnet

### Overview

Oxidized supports both SSH and Telnet for connecting to network devices. **SSH is tried first**, and Telnet is used as an automatic fallback if SSH fails.

### Current Configuration

```yaml
input:
  default: ssh, telnet
```

This means:

1. **SSH attempted first** (secure, recommended)
2. **Telnet as fallback** (if SSH fails)
3. **Same credentials** used for both protocols

### Connection Priority

```
Device Connection Attempt:
  ├── 1. Try SSH (port 22)
  │   ├── Success → Use SSH
  │   └── Failure → Continue to step 2
  ├── 2. Try Telnet (port 23)
  │   ├── Success → Use Telnet
  │   └── Failure → Mark device as failed
  └── Result: Device accessible or failed
```

### When Telnet is Used

Telnet fallback activates automatically when SSH fails due to:

- ❌ SSH port closed/unreachable (port 22)
- ❌ SSH not enabled on device
- ❌ SSH connection timeout
- ❌ SSH authentication failure
- ❌ SSH key exchange issues (old algorithms)

**No configuration changes needed** - Oxidized handles the fallback automatically.

### Security Considerations

⚠️ **WARNING: Telnet is Insecure**

Telnet transmits:

- Credentials in **plaintext**
- Configuration data **unencrypted**
- Vulnerable to network sniffing and man-in-the-middle attacks

**Best Practices:**

- ✅ Use SSH whenever possible
- ✅ Enable SSH on all modern devices
- ✅ Restrict Telnet to isolated management VLANs
- ✅ Use Telnet only for legacy devices without SSH support
- ❌ Never use Telnet over untrusted networks
- ❌ Avoid Telnet in production if SSH is available

### Device Configuration

**No special configuration needed in `router.db`:**

```csv

# Works for both SSH and Telnet

device-name:192.168.1.1:ios:group:username:password
```

Oxidized will:

1. Try SSH with these credentials first
2. If SSH fails, try Telnet with the same credentials
3. Use whichever protocol succeeds

### Retry Logic

**Per Connection Attempt:**

- **Timeout**: 20 seconds
- **Retries**: 3 attempts per protocol
- **Total possible attempts**: 6 (3 SSH + 3 Telnet)

**Example Timeline:**
```
00:00 - SSH attempt 1 (timeout 20s)
00:20 - SSH attempt 2 (timeout 20s)
00:40 - SSH attempt 3 (timeout 20s)
01:00 - Telnet attempt 1 (timeout 20s)
01:20 - Telnet attempt 2 (timeout 20s)
01:40 - Telnet attempt 3 (timeout 20s)
02:00 - Device marked as failed
```

### Checking Which Protocol Was Used

**View logs:**
```bash

# Check specific device

podman logs oxidized | grep "device-name"

# Live monitoring

podman logs -f oxidized
```

**Log Output Examples:**

**SSH Success:**
```
update device-name
```

**SSH Failed, Telnet Success:**
```
SSH connection failed to device-name
Trying Telnet for device-name
update device-name
```

**Both Failed:**
```
unable to get configuration from device-name
```

### Forcing Telnet Only (Advanced)

If a device has broken SSH and you want to skip SSH attempts entirely:

**Edit Configuration:**
```bash
sudo vi /var/lib/oxidized/config/config
```

**Change:**
```yaml
input:
  default: telnet  # Remove ssh from the list
```

**Restart:**
```bash
sudo systemctl restart oxidized.service
```

⚠️ **Not recommended** unless SSH is definitively broken. Keep automatic fallback for flexibility.

### Supported Device Models

Most Oxidized models support both SSH and Telnet:

- ✅ Cisco IOS, IOS-XE, IOS-XR
- ✅ Cisco NX-OS
- ✅ Cisco ASA
- ✅ Juniper JunOS
- ✅ Arista EOS
- ✅ HP ProCurve/Comware
- ✅ Fortinet FortiGate
- ✅ And many more...

Check model support: https://github.com/ytti/oxidized/tree/master/lib/oxidized/model

### Common Scenarios

**Scenario 1: Modern Network (All SSH)**
```
✅ SSH connects immediately
✅ Telnet never attempted
✅ Secure and fast
Result: Best case
```

**Scenario 2: Legacy Device (No SSH)**
```
❌ SSH fails (port closed)
✅ Telnet connects
⚠️  Insecure but functional
Result: Works for legacy devices
```

**Scenario 3: SSH Misconfigured**
```
❌ SSH fails (authentication error)
✅ Telnet connects with same credentials
💡 Indicates SSH needs troubleshooting
Result: Device backed up, but SSH should be fixed
```

**Scenario 4: Device Offline**
```
❌ SSH fails (unreachable)
❌ Telnet fails (unreachable)
❌ Device marked as failed
Result: Network connectivity issue
```

### Configuration Reference

**Location:** `/var/lib/oxidized/config/config`

```yaml
input:
  default: ssh, telnet    # ✅ Fallback enabled
  debug: false
  ssh:
    secure: false         # Allows older SSH algorithms (compatibility)

timeout: 20               # 20 seconds per attempt
retries: 3                # 3 attempts per protocol
```

**To modify:**

1. Option A: Edit `.env` and redeploy

   ```bash
   vi /root/deploy-containerized-oxidized/.env
   ./scripts/deploy.sh
   ```

2. Option B: Edit config directly

   ```bash
   sudo vi /var/lib/oxidized/config/config
   sudo systemctl restart oxidized.service
   ```

### Per-Device Protocol Configuration

If you have specific devices that **only** support Telnet and you want to skip the SSH timeout entirely, you can configure Telnet-only access using groups:

**Quick Example:**

1. Edit `router.db` - set group to `legacy-telnet`:

   ```
   old-switch:192.168.1.10:ios:legacy-telnet::
   ```

2. Edit `/var/lib/oxidized/config/config` - add group override:

   ```yaml
   groups:
     legacy-telnet:
       input:
         default: telnet
   ```

3. Restart service:

   ```bash
   sudo systemctl restart oxidized.service
   ```

**Result:** Device will use Telnet directly, skipping SSH timeout (3-5x faster!)

**📘 Complete Guide:** See `/var/lib/oxidized/docs/TELNET-CONFIGURATION.md` for:

- Detailed group-based configuration
- Per-device protocol variables
- Performance optimization
- Real-world examples

---

## Testing Devices

### Test Device Connectivity

Use the provided test script:

```bash

# Test a specific device

./scripts/test-device.sh router1
```

**What it checks:**

- ✅ Container is running
- ✅ Device exists in router.db
- ✅ Device is registered in Oxidized
- ✅ Network connectivity (ping)
- ✅ SSH port is reachable
- ✅ Triggers a backup
- ✅ Shows recent logs

**Example output:**
```
==> Checking Oxidized container status
[SUCCESS] Container is running

==> Checking if device exists in router.db
[SUCCESS] Device found in router.db

[INFO] Device details:
  Name:  router1
  IP:    10.1.1.1
  Model: ios
  Group: core

==> Testing network connectivity to 10.1.1.1
[SUCCESS] Device is reachable via ping

==> Testing SSH connectivity on port 22
[SUCCESS] SSH port (22) is open

==> Triggering backup for router1
[SUCCESS] Backup completed successfully!
```

### Manual Testing

**Test SSH connectivity:**
```bash

# From host (as oxidized user)

sudo -u oxidized ssh netadmin@10.1.1.1

# From container

podman exec -it oxidized ssh netadmin@10.1.1.1
```

**Trigger backup via API:**
```bash

# Trigger specific device backup

curl -X GET http://127.0.0.1:8889/node/next/router1.json

# Check all devices status

curl http://127.0.0.1:8889/nodes.json | jq '.'
```

---

## Backup Schedule

### How Oxidized Schedules Backups

Oxidized uses an **internal scheduler** (not cron). It runs continuously and backs up devices on a configurable interval.

**Default Schedule:**

- Interval: 3600 seconds (1 hour)
- All devices are backed up every hour
- Devices are queued and processed sequentially

### Configuration File

**Location:** `/var/lib/oxidized/config/config`

**Relevant sections:**
```yaml
---
interval: 3600  # Seconds between backup cycles (default: 1 hour)

# Other timing settings

timeout: 20     # Seconds to wait for device response
retries: 3      # Number of retry attempts on failure
```

### Change Backup Frequency

```bash

# 1. Edit config

sudo vi /var/lib/oxidized/config/config

# 2. Change interval (in seconds)

# Examples:

#   1800  = 30 minutes

#   3600  = 1 hour (default)

#   7200  = 2 hours

#   14400 = 4 hours

#   86400 = 24 hours

interval: 1800  # Change to 30 minutes

# 3. Restart Oxidized

sudo systemctl restart oxidized.service
```

### Common Intervals

| Interval | Seconds | Use Case |
|----------|---------|----------|
| 15 minutes | 900 | High-change environment |
| 30 minutes | 1800 | Active development |
| 1 hour | 3600 | **Default** - Production |
| 4 hours | 14400 | Stable environment |
| 12 hours | 43200 | Low-change network |
| 24 hours | 86400 | Archival purposes |

### Verify Schedule

```bash

# Check current config

grep "^interval:" /var/lib/oxidized/config/config

# Monitor backup activity

podman logs -f oxidized | grep -i "configuration updated\|starting new"
```

---

## Logging and Troubleshooting

### Log Locations

**Primary Log File:**
```bash

# Main Oxidized log (on host)

/var/lib/oxidized/data/oxidized.log

# Inside container

/home/oxidized/.config/oxidized/data/oxidized.log
```

**Container Logs (Recommended):**
```bash

# Follow live logs

podman logs -f oxidized

# View recent logs

podman logs --since 1h oxidized

# Search logs

podman logs oxidized | grep -i error
```

**Systemd Journal:**
```bash

# Follow live logs

journalctl -u oxidized.service -f

# View recent logs

journalctl -u oxidized.service --since "1 hour ago"

# Show errors only

journalctl -u oxidized.service -p err
```

**Oxidized Log File:**
```bash

# On host (main log file)

tail -f /var/lib/oxidized/data/oxidized.log

# Inside container

podman exec oxidized tail -f /home/oxidized/.config/oxidized/data/oxidized.log
```

**Note about `/var/lib/oxidized/config/logs/`:**

This directory exists but is **empty** and **not used**. Oxidized writes logs to `/var/lib/oxidized/data/oxidized.log` instead. The empty `logs/` directory may be a remnant from the container image or a placeholder for future use.

### Log Rotation

Oxidized logs are **automatically rotated** using system `logrotate`.

**Configuration:**

- Location: `/etc/logrotate.d/oxidized`
- Rotates: `/var/lib/oxidized/data/*.log`
- Frequency: Daily
- Retention: 14 days
- Compression: Enabled (delayed until next rotation)
- Method: `copytruncate` (safe for containers with open file handles)

**View Rotation Config:**
```bash
cat /etc/logrotate.d/oxidized
```

**Test Log Rotation:**
```bash

# Dry run (shows what would happen)

sudo logrotate -d /etc/logrotate.d/oxidized

# Force rotation (for testing)

sudo logrotate -f /etc/logrotate.d/oxidized

# Verify rotated logs

ls -lh /var/lib/oxidized/data/*.log*
```

**Rotated Log Files:**
```bash

# Current log

/var/lib/oxidized/data/oxidized.log

# Rotated logs (compressed after 2 days)

/var/lib/oxidized/data/oxidized.log.1
/var/lib/oxidized/data/oxidized.log.2.gz
/var/lib/oxidized/data/oxidized.log.3.gz
```

**Change Retention Period:**

Edit `/etc/logrotate.d/oxidized`:
```bash
sudo vi /etc/logrotate.d/oxidized

# Change this line:

rotate 14    # Keep 14 days

# To (for example):

rotate 30    # Keep 30 days
rotate 7     # Keep 7 days
rotate 90    # Keep 90 days
```

**Manual Log Cleanup:**
```bash

# Delete old compressed logs

sudo rm /var/lib/oxidized/data/*.log.*.gz

# Keep only last 5 rotations

cd /var/lib/oxidized/data
ls -t oxidized.log.* | tail -n +6 | xargs -r sudo rm
```

**Log Size Monitoring:**
```bash

# Check current log size

du -h /var/lib/oxidized/data/oxidized.log

# Check all logs (including rotated)

du -sh /var/lib/oxidized/data/*.log*

# Monitor log growth

watch -n 5 'du -h /var/lib/oxidized/data/oxidized.log'
```

### Common Log Messages

**Successful Backup:**
```
Configuration updated for <device-name>
```

**Connection Errors:**
```

# Device unreachable

connect failed: <device-ip> port 22: Connection refused
connect failed: <device-ip> port 22: No route to host

# Authentication failed

Authentication failed for <device-name>
Bad password: <device-name>

# Timeout

Timeout on <device-name>
```

**Configuration Errors:**
```

# Device not in router.db

unknown model: <model-name>

# Invalid credentials

Login failed: <device-name>
```

### Troubleshooting Device Issues

**Device Not Appearing in Web UI:**

1. Check if device is in router.db
2. Verify Oxidized has restarted: `systemctl restart oxidized.service`
3. Check logs: `podman logs oxidized | grep <device-name>`
4. Wait for initial backup cycle (up to `interval` seconds)

**Authentication Failures:**

1. Verify credentials in `.env` or `router.db`
2. Test SSH manually: `ssh user@device-ip`
3. Check device logs for login attempts
4. Verify SSH keys if using key-based auth

**SSH Cipher/Algorithm Errors (Legacy Devices):**

Many older network devices only support legacy SSH ciphers and algorithms that modern SSH clients reject by default. You'll see errors like:

- `no matching cipher found`
- `no matching key exchange method found`
- `no matching MAC found`
- `unable to negotiate`

**Solution 1: Enable Legacy Algorithms (Already Configured)**

Your deployment already has `ssh: secure: false` in the config, which enables legacy algorithm support. If you still have issues:

**Solution 2: Let Telnet Fallback Handle It**

The easiest solution: Do nothing! Oxidized will:

1. Try SSH with legacy algorithms
2. If SSH still fails → automatically try Telnet
3. Connect via Telnet if available

**Solution 3: Manual SSH Testing**

Test SSH connectivity with legacy algorithms:
```bash

# Test modern SSH

ssh admin@device-ip

# Test with legacy algorithms (if Telnet isn't available)

ssh -oKexAlgorithms=+diffie-hellman-group1-sha1 \
    -oHostKeyAlgorithms=+ssh-rsa \
    -oCiphers=+aes128-cbc,aes256-cbc \
    admin@device-ip
```

**Solution 4: Enable SSH on Legacy Device**

If device only has Telnet enabled:
```

# On Cisco IOS devices

configure terminal
crypto key generate rsa modulus 2048
ip ssh version 2
line vty 0 15
  transport input ssh telnet  # Allow both
end
write memory
```

**Check Logs for Cipher Errors:**
```bash

# View detailed connection errors

tail -f /var/lib/oxidized/data/oxidized.log | grep -i "cipher\|algorithm\|ssh"

# Or use the test script

/var/lib/oxidized/scripts/test-device.sh device-name
```

**Connection Timeouts:**

1. Verify device is reachable: `ping <device-ip>`
2. Check SSH port: `nc -zv <device-ip> 22`
3. Check firewall rules
4. Increase timeout in config: `timeout: 30`

**Model Not Supported:**

1. Check supported models: https://github.com/yggdrasil-network/oxidized/tree/master/lib/oxidized/model
2. Try similar model (e.g., `ios` for many Cisco devices)
3. Check Oxidized documentation for custom models

**Model Name Errors (Device Not Showing in Web UI):**

If a device is in `router.db` but not appearing in the web UI, check for model name errors:

1. **Check logs for ModelNotFound errors:**
   ```bash
   sudo tail -50 /var/lib/oxidized/data/oxidized.log | grep -i "modelnotfound\|unknown model"
   ```

2. **Common mistakes:**
   - ❌ `tp-link` (with hyphen) → ✅ `tplink` (no hyphen)
   - ❌ `Cisco-IOS` → ✅ `ios` (lowercase, no hyphen)
   - ❌ `Juniper` → ✅ `junos` (specific model name)

3. **Verify model name:**
   - Model names are case-sensitive and must match exactly
   - Check official model list: https://github.com/ytti/oxidized/tree/master/lib/oxidized/model
   - Model file name = model name (e.g., `tplink.rb` → use `tplink`)

4. **Fix:**
   ```bash
   # Edit router.db
   sudo vim /var/lib/oxidized/config/router.db
   # Correct the model name (e.g., change tp-link to tplink)
   # Restart service
   sudo systemctl restart oxidized.service
   ```

---

## Validation Tools

### Validate router.db Syntax

Use the provided validation script:

```bash
./scripts/validate-router-db.sh [path-to-router.db]

# Examples:

./scripts/validate-router-db.sh
./scripts/validate-router-db.sh /var/lib/oxidized/config/router.db
./scripts/validate-router-db.sh inventory/router.db.template
```

**What it checks:**

- ✅ File exists
- ✅ Field count (must be 6 fields)
- ✅ Device name format (alphanumeric, hyphens, underscores, dots)
- ✅ Duplicate device names
- ✅ IP address/hostname format
- ✅ Duplicate IP addresses (warning)
- ✅ Empty required fields
- ✅ Known device models (warning if unknown)
- ✅ Credential consistency

**Example output:**
```
╔══════════════════════════════════════════════════════════════════════════╗
║           Oxidized Router Database Syntax Validator                  ║
╚══════════════════════════════════════════════════════════════════════════╝

[INFO] Validating: /var/lib/oxidized/config/router.db

[OK] Line 5: router1 (10.1.1.1, ios)
[OK] Line 6: router2 (10.1.1.2, ios)
[OK] Line 7: switch1 (10.2.1.1, procurve)
[WARN] Line 8: Unknown device model: custom-model
[OK] Line 8: firewall1 (10.3.1.1, custom-model)

╔══════════════════════════════════════════════════════════════════════════╗
║                         Validation Summary                           ║
╚══════════════════════════════════════════════════════════════════════════╝

Total Lines: 10
Valid Devices: 4
Warnings: 1
Errors: 0

✓ Validation PASSED
  (with 1 warnings)
```

### Pre-Deployment Validation

**Recommended workflow:**
```bash

# 1. Edit router.db

sudo vi /var/lib/oxidized/config/router.db

# 2. Validate syntax

./scripts/validate-router-db.sh

# 3. If validation passes, restart Oxidized

sudo systemctl restart oxidized.service

# 4. Test each new device

./scripts/test-device.sh new-device-name
```

---

## Quick Reference

### Common Commands

```bash

# Add devices (interactive)

/var/lib/oxidized/scripts/add-device.sh

# Add devices (manual)

vi /var/lib/oxidized/config/router.db
systemctl restart oxidized.service

# Validate syntax

/var/lib/oxidized/scripts/validate-router-db.sh

# Test device

/var/lib/oxidized/scripts/test-device.sh <device-name>

# Health check

/var/lib/oxidized/scripts/health-check.sh

# View logs

podman logs -f oxidized
journalctl -u oxidized.service -f
tail -f /var/lib/oxidized/data/oxidized.log

# Test log rotation

sudo logrotate -d /etc/logrotate.d/oxidized

# Trigger backup

curl -X GET http://127.0.0.1:8889/node/next/<device-name>.json

# List devices

curl http://127.0.0.1:8889/nodes.json | jq '.[].name'

# List groups

curl http://127.0.0.1:8889/nodes.json | jq '.[].group' | sort -u

# Filter by group

curl http://127.0.0.1:8889/nodes.json | jq '.[] | select(.group == "core")'

# View backups

ls -la /var/lib/oxidized/repo/
git -C /var/lib/oxidized/repo log --oneline
```

### File Locations

| Purpose | Location |
|---------|----------|
| Device inventory | `/var/lib/oxidized/config/router.db` |
| Configuration | `/var/lib/oxidized/config/config` |
| Backups (Git repo) | `/var/lib/oxidized/repo/` |
| **Logs (ACTIVE)** | **`/var/lib/oxidized/data/oxidized.log`** |
| Rotated logs | `/var/lib/oxidized/data/oxidized.log.1`, `.log.2.gz`, etc. |
| Log rotation config | `/etc/logrotate.d/oxidized` |
| SSH keys | `/var/lib/oxidized/ssh/` |
| ~~Logs directory~~ | ~~`/var/lib/oxidized/config/logs/`~~ (empty, not used) |

### Scripts

**Helper Scripts (Installed):**

These scripts are automatically installed to `/var/lib/oxidized/scripts/` during deployment:

| Script | Location | Purpose |
|--------|----------|---------|
| `add-device.sh` | `/var/lib/oxidized/scripts/` | Interactive device addition with validation |
| `validate-router-db.sh` | `/var/lib/oxidized/scripts/` | Validate router.db syntax |
| `test-device.sh` | `/var/lib/oxidized/scripts/` | Test device connectivity and trigger backup |
| `health-check.sh` | `/var/lib/oxidized/scripts/` | Check overall system health |

**Deployment Scripts (Repository):**

These remain in the repository for deployment management:

| Script | Location | Purpose |
|--------|----------|---------|
| `deploy.sh` | `<repo>/scripts/` | Deploy/update Oxidized |
| `uninstall.sh` | `<repo>/scripts/` | Remove Oxidized |
| `validate-env.sh` | `<repo>/scripts/` | Validate .env file |

---

## Backup Management

### Automatic router.db Backups

Every deployment automatically backs up `router.db` with a timestamp:

```bash

# Run deploy

./scripts/deploy.sh

# Creates backup:

/var/lib/oxidized/config/router.db.backup.20260118_143022
```

### Manual Backups

Create manual backups before major changes:

```bash

# Create timestamped backup

sudo cp /var/lib/oxidized/config/router.db \
        /var/lib/oxidized/config/router.db.backup.$(date +%Y%m%d_%H%M%S)

# Create named backup

sudo cp /var/lib/oxidized/config/router.db \
        /var/lib/oxidized/config/router.db.before-production-change
```

### List All Backups

```bash

# Show all backups with timestamps

ls -lht /var/lib/oxidized/config/router.db.backup.* | head -10

# Count total backups

ls -1 /var/lib/oxidized/config/router.db.backup.* | wc -l

# Show disk space used by backups

du -h /var/lib/oxidized/config/router.db.backup.*
```

### Restore from Backup

```bash

# 1. List backups

ls -lh /var/lib/oxidized/config/router.db.backup.*

# 2. Preview backup content

cat /var/lib/oxidized/config/router.db.backup.20260118_143022

# 3. Compare with current

diff /var/lib/oxidized/config/router.db \
     /var/lib/oxidized/config/router.db.backup.20260118_143022

# 4. Restore (backup current first!)

sudo cp /var/lib/oxidized/config/router.db \
        /var/lib/oxidized/config/router.db.pre-restore
sudo cp /var/lib/oxidized/config/router.db.backup.20260118_143022 \
        /var/lib/oxidized/config/router.db

# 5. Restart Oxidized

sudo systemctl restart oxidized.service
```

### Cleanup Old Backups

```bash

# Keep only last 10 backups

cd /var/lib/oxidized/config
ls -t router.db.backup.* | tail -n +11 | xargs -r sudo rm

# Delete backups older than 30 days

sudo find /var/lib/oxidized/config -name "router.db.backup.*" -mtime +30 -delete

# Delete all backups (not recommended)

sudo rm /var/lib/oxidized/config/router.db.backup.*
```

### Backup Locations Summary

| Backup Type | Location | Purpose |
|-------------|----------|---------|
| **Automatic deployment backup** | `/var/lib/oxidized/config/router.db.backup.YYYYMMDD_HHMMSS` | Created every deploy |
| **Config backups** | `/var/lib/oxidized/config/config.backup.YYYYMMDD_HHMMSS` | Created when config changes |
| **Quadlet backups** | `/etc/containers/systemd/oxidized.container.backup.YYYYMMDD_HHMMSS` | Created when Quadlet changes |
| **nginx config backups** | `/etc/nginx/conf.d/oxidized.conf.backup` | Created when nginx config changes |
| **Device config backups** | `/var/lib/oxidized/repo/` | Git repository (version controlled) |

---

## Best Practices

1. **Always validate** router.db before restarting: `./scripts/validate-router-db.sh`
2. **Test new devices** immediately: `./scripts/test-device.sh <device-name>`
3. **Use global credentials** when possible (easier to manage)
4. **Document changes** in router.db with comments
5. **Monitor logs** after adding devices: `podman logs -f oxidized`
6. **Start with longer intervals** (4 hours) and decrease as needed
7. **Use groups for organization** (optional but helpful for large deployments)
8. **Keep backup history** in Git (don't delete commits unless necessary)
9. **Test SSH manually** before adding to Oxidized
10. **Set permissions** correctly: `chmod 600 router.db` if using passwords
11. **Review automatic backups** periodically and cleanup old ones
12. **Backup before major changes** (adding many devices, credential changes)
13. **Check log rotation** is working: `sudo logrotate -d /etc/logrotate.d/oxidized`
14. **Monitor log size** to ensure rotation is functioning

---

## Related Documentation

- [DIRECTORY-STRUCTURE.md](DIRECTORY-STRUCTURE.md) - Complete directory layout and file locations
- [CREDENTIALS-GUIDE.md](CREDENTIALS-GUIDE.md) - Understanding credentials
- [QUICK-START.md](QUICK-START.md) - Getting started quickly
- [DEPLOYMENT-NOTES.md](DEPLOYMENT-NOTES.md) - Deployment details
- [README.md](README.md) - Main documentation

---

**Last Updated:** 2026-01-18
**Oxidized Version:** 0.35.0
