# Device Input Configuration Guide

This guide explains how to configure SSH and Telnet for network devices in Oxidized, including per-device settings and troubleshooting SSH compatibility issues.

## Table of Contents

- [Overview](#overview)
- [Input Methods](#input-methods)
- [Global Configuration](#global-configuration)
- [Per-Device Configuration](#per-device-configuration)
- [Per-Model Configuration](#per-model-configuration)
- [SSH Compatibility Issues](#ssh-compatibility-issues)
- [Telnet Configuration](#telnet-configuration)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

---

## Overview

Oxidized supports multiple input methods to connect to network devices:

1. **SSH** (default, preferred for security)
2. **Telnet** (fallback for legacy devices or SSH compatibility issues)

The connection method can be configured:
- **Globally** - applies to all devices
- **Per-model** - applies to all devices of a specific type (ios, tplink, etc.)
- **Per-device** - applies to individual devices in router.db

---

## Input Methods

### SSH (Secure Shell)

**Pros**:
- Encrypted communication
- Industry standard for management
- Supported by most modern devices

**Cons**:
- Older devices may only support weak/deprecated algorithms
- Modern SSH clients reject weak algorithms for security
- May require special configuration for legacy devices

### Telnet

**Pros**:
- Works with very old devices
- Simple protocol, fewer compatibility issues
- Good for isolated lab/management networks

**Cons**:
- Unencrypted (credentials sent in plaintext)
- Not recommended for production/untrusted networks
- Should be restricted to management VLANs

---

## Global Configuration

### Default: Try SSH, Fallback to Telnet

**File**: `/var/lib/oxidized/config/config`

```yaml
input:
  default: ssh, telnet
  debug: false
```

This tries SSH first, then falls back to Telnet if SSH fails.

### Prefer Telnet Globally (Not Recommended)

```yaml
input:
  default: telnet, ssh
```

Only use this if most of your devices require Telnet.

### SSH Options (Global)

```yaml
input:
  default: ssh, telnet
  ssh:
    secure: false
    # Enable legacy algorithms globally (use with caution)
    kex: diffie-hellman-group1-sha1
    encryption: aes128-cbc
    hmac: hmac-sha1
```

⚠️ **Warning**: Enabling weak algorithms globally reduces security for all devices.

---

## Per-Device Configuration

### Method 1: Extended router.db Format

Oxidized supports an extended CSV format with additional columns for per-device variables.

**Standard format** (6 columns):
```
name:ip:model:group:username:password
```

**Extended format** (with vars):
```
name:ip:model:group:username:password:vars
```

Where `vars` is a JSON object or key-value pairs.

### Method 2: vars_map in config

**File**: `/var/lib/oxidized/config/config`

Add a `vars_map` section to map device-specific variables:

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
        input: 6
        enable: 7
```

Then in `router.db`:
```
# name:ip:model:group:user:pass:input:enable
s3560g-1:10.1.10.49:ios:lab-switches:::telnet:
s3560g-2:10.1.10.45:ios:lab-switches:::telnet:my_enable_pass
SX3008F:10.1.10.48:tplink:lab-switches:::ssh:
```

### Method 3: Source with Device-Specific Vars (Recommended)

Create a more detailed source file with per-device variables.

**Example using SQLite source** (for complex setups):
See: https://github.com/ytti/oxidized/blob/master/docs/Configuration.md#source

---

## Per-Model Configuration

Configure all devices of a specific model type.

**File**: `/var/lib/oxidized/config/config`

### Example 1: Force Telnet for Cisco IOS

```yaml
models:
  ios:
    vars:
      input: telnet
```

### Example 2: SSH Options for TP-Link Switches

```yaml
models:
  tplink:
    vars:
      # Disable public key authentication (like PubkeyAuthentication no)
      ssh_no_keys: true
      # Don't try publickey method (like PreferredAuthentications password)
      ssh_auth_methods: password,keyboard-interactive
```

This is equivalent to your SSH config:
```
PubkeyAuthentication no
PreferredAuthentications password
IdentitiesOnly yes
```

### Example 3: Legacy SSH for Old IOS Devices

```yaml
models:
  ios:
    vars:
      # SSH options for devices with weak ciphers
      ssh_kex: diffie-hellman-group1-sha1
      ssh_encryption: aes128-cbc
      ssh_hmac: hmac-sha1
```

---

## SSH Compatibility Issues

### Problem: SSH Key Exchange Failure

**Error**:
```
Unable to negotiate with X.X.X.X port 22: no matching key exchange method found.
Their offer: diffie-hellman-group1-sha1
```

**Cause**: Device only supports weak algorithms rejected by modern SSH.

**Solution Options**:

#### Option A: Use Telnet Instead

Best for isolated lab environments.

```yaml
models:
  ios:
    vars:
      input: telnet
```

#### Option B: Enable Legacy SSH Algorithms

**Per-model** (recommended):
```yaml
models:
  ios:
    vars:
      ssh_kex: diffie-hellman-group1-sha1
      ssh_encryption: aes128-cbc
      ssh_hmac: hmac-sha1
```

**Global** (not recommended):
```yaml
input:
  ssh:
    secure: false
    kex: diffie-hellman-group1-sha1
    encryption: aes128-cbc
    hmac: hmac-sha1
```

### Problem: Public Key Authentication Interfering

**Error**:
```
Net::SSH::AuthenticationFailed
```

**Your SSH Config**:
```
PubkeyAuthentication no
PreferredAuthentications password
IdentitiesOnly yes
```

**Oxidized Equivalent**:

```yaml
models:
  tplink:
    vars:
      ssh_no_keys: true
      ssh_auth_methods: password,keyboard-interactive
```

Or per-device in router.db using vars_map (see Per-Device Configuration).

---

## Telnet Configuration

### Enable Telnet Globally

```yaml
input:
  default: ssh, telnet
  telnet:
    timeout: 30
```

### Force Telnet for Specific Devices

**Method 1: Per-model**
```yaml
models:
  ios:
    vars:
      input: telnet
```

**Method 2: Per-device** (using vars_map)

router.db:
```
s3560g-1:10.1.10.49:ios:lab-switches:::telnet:
```

With config:
```yaml
source:
  csv:
    vars_map:
      input: 6
```

---

## Examples

### Example 1: Mixed Environment

You have:
- Modern switches (SSH works fine)
- Old Cisco 3560 switches (need Telnet)
- TP-Link switches (SSH works but needs special config)

**router.db**:
```
# Modern switches - SSH works normally
core-sw01:10.1.1.1:ios:core::

# Old Cisco 3560 - use Telnet
s3560g-1:10.1.10.49:ios:lab-switches::
s3560g-2:10.1.10.45:ios:lab-switches::

# TP-Link - SSH with special auth
SX3008F:10.1.10.48:tplink:lab-switches::
```

**config**:
```yaml
input:
  default: ssh, telnet
  ssh:
    secure: false

models:
  ios:
    # No vars - uses default (SSH, fallback to Telnet)
  tplink:
    vars:
      ssh_no_keys: true
      ssh_auth_methods: password,keyboard-interactive
```

Result:
- Core switch: SSH (works normally)
- 3560 switches: SSH fails, falls back to Telnet ✓
- TP-Link: SSH with password-only auth ✓

### Example 2: Force Telnet for Old IOS Devices

**config**:
```yaml
models:
  ios:
    vars:
      input: telnet
```

All IOS devices will use Telnet.

### Example 3: Legacy SSH Algorithms

For devices that support SSH but only weak algorithms:

**config**:
```yaml
models:
  ios:
    vars:
      ssh_kex: diffie-hellman-group1-sha1
      ssh_encryption: aes128-cbc
      ssh_hmac: hmac-sha1
```

### Example 4: Per-Device Input Method

Using extended router.db with vars_map:

**config**:
```yaml
source:
  csv:
    map:
      name: 0
      ip: 1
      model: 2
      group: 3
      username: 4
      password: 5
      vars_map:
        input: 6
```

**router.db**:
```
# name:ip:model:group:user:pass:input
modern-sw:10.1.1.1:ios:core:::ssh
old-3560:10.1.10.49:ios:lab:::telnet
tplink:10.1.10.48:tplink:lab:::ssh
```

---

## Troubleshooting

### Test Manual Connection

Before configuring Oxidized, test the connection manually:

#### SSH Test
```bash
# Basic SSH
ssh admin@10.1.10.48

# SSH with legacy algorithms
ssh -o KexAlgorithms=+diffie-hellman-group1-sha1 \
    -o HostKeyAlgorithms=+ssh-rsa \
    -o Ciphers=+aes128-cbc \
    admin@10.1.10.45

# SSH without public key (like your TP-Link config)
ssh -o PubkeyAuthentication=no \
    -o PreferredAuthentications=password \
    admin@10.1.10.48
```

#### Telnet Test
```bash
telnet 10.1.10.45
# Enter: admin
# Enter: password
# Check prompt format
```

### Enable Debug Logging

```yaml
input:
  debug: true
```

Then check logs:
```bash
podman logs oxidized
tail -f /var/lib/oxidized/data/oxidized.log
```

### Check What Input Method Was Used

```bash
# Check logs for connection attempts
podman logs oxidized 2>&1 | grep -E "(ssh|telnet|input)"
```

### Verify Device Configuration

```bash
# Check what's configured for a device
podman exec oxidized oxidized -d device_name
```

### Force Immediate Backup

```bash
# Using API (requires nginx auth)
curl -u admin:password http://localhost:8888/node/fetch/device_name

# Using script (see next section)
/var/lib/oxidized/scripts/force-backup.sh device_name
```

---

## Testing Changes

After modifying configuration:

1. **Restart Oxidized**:
   ```bash
   sudo /var/lib/oxidized/scripts/oxidized-restart.sh
   ```

2. **Watch logs**:
   ```bash
   podman logs -f oxidized
   ```

3. **Trigger manual backup** (see script in next section)

4. **Check results**:
   ```bash
   cd /var/lib/oxidized/repo
   git log --oneline --since="5 minutes ago"
   ```

---

## Related Documentation

- [SSH Configuration for Oxidized](https://github.com/ytti/oxidized/blob/master/docs/Configuration.md#input)
- [Telnet Configuration](docs/TELNET-CONFIGURATION.md)
- [Per-Device Variables](https://github.com/ytti/oxidized/blob/master/docs/Configuration.md#source)
- [Model-Specific Configuration](https://github.com/ytti/oxidized/blob/master/docs/Model-Notes.md)

---

## Summary: Your Specific Case

For your TP-Link switch at 10.1.10.48 that needs:
```
PubkeyAuthentication no
PreferredAuthentications password
IdentitiesOnly yes
```

**Add to config**:
```yaml
models:
  tplink:
    vars:
      ssh_no_keys: true
      ssh_auth_methods: password,keyboard-interactive
```

For your Cisco 3560 switches that don't support modern SSH:
- Let them fall back to Telnet automatically (current config)
- OR force Telnet in models section
- OR add legacy SSH support (less secure)

**Current recommended config** is already set:
```yaml
input:
  default: ssh, telnet  # Try SSH first, fallback to Telnet
```

This gives you the best of both worlds:
- Modern devices use SSH
- Old devices automatically fall back to Telnet
- Per-model SSH tweaks for special cases like TP-Link
