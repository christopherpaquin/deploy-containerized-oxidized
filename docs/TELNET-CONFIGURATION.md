# Per-Device Protocol Configuration (SSH vs Telnet)

Guide for configuring SSH and Telnet on a per-device or per-group basis.

## Table of Contents

- [Overview](#overview)
- [Current Default Behavior](#current-default-behavior)
- [Why Configure Per-Device Protocols](#why-configure-per-device-protocols)
- [Option 1: Group-Based Protocol Override (Recommended)](#option-1-group-based-protocol-override-recommended)
- [Option 2: Per-Device Variables (Advanced)](#option-2-per-device-variables-advanced)
- [Testing Protocol Configuration](#testing-protocol-configuration)
- [Troubleshooting](#troubleshooting)

---

## Overview

By default, Oxidized tries SSH first for all devices, then falls back to Telnet if SSH fails. For legacy devices that you **know** only support Telnet, you can configure Oxidized to skip the SSH timeout and use Telnet directly, saving time and reducing errors.

---

## Current Default Behavior

**Global Configuration:**
```yaml
input:
  default: ssh, telnet
  ssh:
    secure: false
```

**What Happens:**

1. Oxidized tries SSH (with legacy cipher support)
2. If SSH fails → waits for timeout (20 seconds × 3 retries = 60 seconds)
3. Falls back to Telnet
4. Uses same credentials from router.db

**router.db Format (Current):**
```
name:ip:model:group:username:password
```

Example:
```
router1:192.168.1.1:ios:core:admin:password
switch1:192.168.1.2:ios:access:admin:password
```

**Problem:**

- If you have 10 legacy Telnet-only devices
- Each takes ~60 seconds to fail SSH and succeed on Telnet
- Total wasted time: **10 minutes** per backup cycle

---

## Why Configure Per-Device Protocols

### Use Cases

1. **Legacy Devices Without SSH**
   - Old switches/routers that only support Telnet
   - Skip SSH timeout entirely
   - Faster backup cycles

2. **Mixed Environment**
   - Modern devices: SSH (secure)
   - Legacy devices: Telnet (direct, no timeout)
   - Optimize for both security and performance

3. **Troubleshooting**
   - Force specific protocol for testing
   - Isolate SSH cipher issues
   - Verify Telnet connectivity

### Benefits

✅ **Faster Backups**: No SSH timeout for Telnet-only devices
✅ **Less Log Noise**: Fewer failed SSH attempts in logs
✅ **Clear Intent**: Explicitly define protocol per device/group
✅ **Better Performance**: Reduce overall backup cycle time

---

## Option 1: Group-Based Protocol Override (Recommended)

Use Oxidized groups to override input method for specific device types.

### Step 1: Identify Legacy Devices

List devices that **only** support Telnet (no SSH):

```bash

# Check which devices fail SSH

tail -f /var/lib/oxidized/data/oxidized.log | grep -i "ssh.*fail\|telnet"
```

### Step 2: Assign Group in router.db

Use the `group` field (4th column) to categorize devices:

```
name:ip:model:group:username:password
```

**Example:**
```

# Modern devices (SSH works)

router1:192.168.1.1:ios:core-routers::
router2:192.168.1.2:ios:core-routers::

# Legacy devices (Telnet only)

old-switch1:192.168.1.10:ios:legacy-telnet::
old-switch2:192.168.1.11:ios:legacy-telnet::
old-switch3:192.168.1.12:ios:legacy-telnet::
```

### Step 3: Configure Group Override

Edit `/var/lib/oxidized/config/config`:

```yaml

# Group-specific configurations

groups:
  legacy-telnet:
    input:
      default: telnet
    vars: {}
```

### Step 4: Restart Oxidized

```bash
sudo systemctl restart oxidized.service
```

### Result

**Modern Devices (group: core-routers)**

- Uses global `input: default: ssh, telnet`
- Tries SSH first, Telnet fallback
- Secure when possible

**Legacy Devices (group: legacy-telnet)**

- Uses group `input: default: telnet`
- Skips SSH entirely
- Connects via Telnet immediately
- **No 60-second timeout per device!**

### Full Configuration Example

**`/var/lib/oxidized/config/config`:**
```yaml

# Global settings

input:
  default: ssh, telnet
  debug: false
  ssh:
    secure: false
  telnet: {}

# Group overrides

groups:
  # Legacy devices - Telnet only
  legacy-telnet:
    input:
      default: telnet
    vars: {}

  # Devices with broken SSH but working Telnet
  ssh-broken:
    input:
      default: telnet
    vars: {}

  # High-security devices - SSH only (no Telnet fallback)
  critical-core:
    input:
      default: ssh
    vars: {}
```

**`/var/lib/oxidized/config/router.db`:**
```

# Format: name:ip:model:group:username:password

# Modern devices - SSH preferred, Telnet fallback

router1:192.168.1.1:ios:core::
router2:192.168.1.2:ios:core::
switch1:192.168.1.3:ios:access::

# Legacy devices - Telnet only (no SSH timeout)

old-cisco-2950:192.168.1.10:ios:legacy-telnet::
old-hp-2524:192.168.1.11:procurve:legacy-telnet::
ancient-switch:192.168.1.12:ios:legacy-telnet::

# Critical devices - SSH only (security requirement)

firewall1:192.168.1.100:asa:critical-core::
core-router:192.168.1.101:ios:critical-core::
```

---

## Option 2: Per-Device Variables (Advanced)

For maximum flexibility, use `vars_map` to specify protocol per device.

### Configuration

**Edit `/var/lib/oxidized/config/config`:**

```yaml
source:
  default: csv
  csv:
    file: /home/oxidized/.config/oxidized/router.db
    delimiter: !ruby/regexp /:/
    map:
      name: 0
      ip: 1
      model: 2
      group: 3
      username: 4
      password: 5
    vars_map:
      input: 6  # New 7th field for protocol
    gpg: false
```

### router.db Format (7 fields)

```
name:ip:model:group:username:password:input
```

**Examples:**
```

# SSH first, Telnet fallback (default)

router1:192.168.1.1:ios:core:::ssh,telnet

# Telnet only

old-switch:192.168.1.10:ios:legacy:::telnet

# SSH only (no fallback)

secure-device:192.168.1.100:asa:critical:::ssh
```

**Notes:**

- Empty `input` field uses global default
- Format: `ssh`, `telnet`, or `ssh,telnet`
- Must update **all** entries if using vars_map

**⚠️ Complexity Warning:**

- Requires 7th field on every device
- More error-prone
- Harder to maintain
- **Recommendation:** Use Option 1 (groups) unless you need per-device control

---

## Testing Protocol Configuration

### Test Individual Device

```bash

# Test device with enhanced diagnostics

/var/lib/oxidized/scripts/test-device.sh device-name
```

The script will show:

- Which protocol was attempted (SSH, Telnet)
- Connection errors
- Success/failure for each protocol

### Monitor Live Logs

```bash

# Watch connection attempts

tail -f /var/lib/oxidized/data/oxidized.log
```

**Look for:**
```

# SSH attempt

I, [timestamp] INFO -- : Connecting to device-name via SSH

# Telnet fallback

W, [timestamp] WARN -- : SSH failed, trying Telnet for device-name

# Telnet-only (group override)

I, [timestamp] INFO -- : Connecting to device-name via Telnet
```

### Verify Group Configuration

```bash

# Check if groups are loaded

grep -A10 "^groups:" /var/lib/oxidized/config/config
```

### Time Comparison

**Before (SSH + Telnet fallback):**
```bash

# Time a backup cycle for legacy device

time systemctl restart oxidized

# Watch logs for device backup completion

# Typical: 60-90 seconds per device (SSH timeout + Telnet)

```

**After (Telnet-only via group):**
```bash

# Same test with group override

time systemctl restart oxidized

# Watch logs for device backup completion

# Typical: 10-20 seconds per device (direct Telnet)

```

**Result:** 3-5x faster for Telnet-only devices!

---

## Troubleshooting

### Group Override Not Working

**Check 1: Verify group name matches**
```bash

# In router.db

grep "device-name" /var/lib/oxidized/config/router.db

# Output: device-name:...:...:legacy-telnet:...

# In config

grep -A3 "legacy-telnet:" /var/lib/oxidized/config/config
```

**Check 2: Restart service**
```bash
sudo systemctl restart oxidized.service
```

**Check 3: Watch logs**
```bash
tail -f /var/lib/oxidized/data/oxidized.log | grep device-name
```

### Still Trying SSH When Telnet Expected

**Possible causes:**

1. Group name mismatch (case-sensitive)
2. YAML indentation error in config
3. Service not restarted after config change
4. Device not yet processed (wait for backup cycle)

**Fix:**
```bash

# Validate YAML syntax

ruby -ryaml -e "YAML.load_file('/var/lib/oxidized/config/config')"

# Check for group

grep -A5 "groups:" /var/lib/oxidized/config/config

# Force restart

sudo systemctl restart oxidized.service

# Watch for device

podman logs -f oxidized | grep device-name
```

### Device Appears in Wrong Group

**Check router.db:**
```bash

# Show device entry

grep "^device-name:" /var/lib/oxidized/config/router.db

# Output format: name:ip:model:GROUP:username:password

#                                  ^^^^^ This must match group config

```

**Fix:**
```bash

# Edit router.db

sudo vi /var/lib/oxidized/config/router.db

# Validate syntax

/var/lib/oxidized/scripts/validate-router-db.sh

# Restart

sudo systemctl restart oxidized.service
```

---

## Summary

### Recommended Approach

**Use groups for protocol override:**

1. ✅ **Simple**: Just use the existing `group` field
2. ✅ **Maintainable**: Easy to see which devices use which protocol
3. ✅ **Fast**: No SSH timeout for Telnet-only devices
4. ✅ **Flexible**: Easy to add/move devices between groups

### Quick Setup Guide

1. **Identify legacy devices** (Telnet-only)

   ```bash
   tail -f /var/lib/oxidized/data/oxidized.log | grep -i telnet
   ```

2. **Edit router.db** - Set group field

   ```bash
   sudo vi /var/lib/oxidized/config/router.db
   # Change group to: legacy-telnet
   ```

3. **Edit config** - Add group override

   ```bash
   sudo vi /var/lib/oxidized/config/config
   ```

   Add:
   ```yaml
   groups:
     legacy-telnet:
       input:
         default: telnet
   ```

4. **Restart and test**

   ```bash
   sudo systemctl restart oxidized.service
   /var/lib/oxidized/scripts/test-device.sh device-name
   ```

5. **Verify performance**
   - Check logs: No more SSH failures
   - Faster backups: 3-5x improvement for Telnet devices

---

## Related Documentation

- **DEVICE-MANAGEMENT.md**: Complete device management guide
- **GIT-REPOSITORY-STRUCTURE.md**: Understanding groups and repository layout
- **CREDENTIALS-GUIDE.md**: Managing device credentials

---

## Example: Real-World Scenario

**Environment:**

- 20 modern switches (SSH works)
- 5 legacy switches (Telnet only)

**Before Optimization:**
```
Modern switches:  20 × 10s =  200s (SSH succeeds quickly)
Legacy switches:   5 × 70s =  350s (SSH timeout + Telnet)
Total backup time:            550s (9 minutes)
```

**After Group Configuration:**
```
Modern switches:  20 × 10s =  200s (SSH succeeds quickly)
Legacy switches:   5 × 15s =   75s (Telnet direct, no SSH timeout)
Total backup time:            275s (4.5 minutes)
```

**Result:** 50% faster backup cycles! ⚡
