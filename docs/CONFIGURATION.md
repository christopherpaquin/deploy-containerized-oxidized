# Oxidized Configuration Guide

## Table of Contents

- [Configuration File Locations](#configuration-file-locations)
- [Path Mappings (Host ↔ Container)](#path-mappings-host--container)
- [Device Inventory Format](#device-inventory-format)
- [Understanding "CSV Source"](#understanding-csv-source)
- [Credential Modes](#credential-modes)
- [Configuration File Structure](#configuration-file-structure)

---

## Configuration File Locations

### Main Configuration File

**File:** `config` (yes, just "config" with no extension)
**Host Path:** `/var/lib/oxidized/config/config`
**Container Path:** `/home/oxidized/.config/oxidized/config`

**Why "config/config"?**
This follows Oxidized's default convention where it expects the config file at `~/.config/oxidized/config`. Inside the container, the oxidized user's home is `/home/oxidized`, so the full path becomes `/home/oxidized/.config/oxidized/config`.

On the host, we mount this from `/var/lib/oxidized/config/config` to keep everything organized under `/var/lib/oxidized/`.

### Device Inventory File

**File:** `router.db`
**Host Path:** `/var/lib/oxidized/config/router.db`
**Container Path:** `/home/oxidized/.config/oxidized/router.db`
**Permissions:** `600` (read/write by oxidized user only)
**Owner:** `oxidized:oxidized` (UID 2000:GID 2000 on host, UID 30000:30000 in container)

**Format:** Colon-delimited with 6 fields (see below)

---

## Path Mappings (Host ↔ Container)

All paths are mounted via Podman Quadlet `Volume` directives with SELinux relabeling (`:Z`).

| Purpose | Host Path | Container Path | Mount Options |
|---------|-----------|----------------|---------------|
| Configuration | `/var/lib/oxidized/config/` | `/home/oxidized/.config/oxidized/` | `:Z` (read/write) |
| Git Repository | `/var/lib/oxidized/repo/` | `/home/oxidized/.config/oxidized/repo/` | `:Z` (read/write) |
| Log Files | `/var/lib/oxidized/data/` | `/home/oxidized/.config/oxidized/data/` | `:Z` (read/write) |
| SSH Keys & Git Config | `/var/lib/oxidized/ssh/` | `/home/oxidized/.ssh/` | `:Z,ro` (read-only) |
| Output (legacy) | `/var/lib/oxidized/output/` | `/home/oxidized/.config/oxidized/output/` | `:Z` (read/write) |

**Key Files:**

- **Main Config:** `/var/lib/oxidized/config/config` → `/home/oxidized/.config/oxidized/config`
- **Device Inventory:** `/var/lib/oxidized/config/router.db` → `/home/oxidized/.config/oxidized/router.db`
- **Git Configs:** `/var/lib/oxidized/repo/` → `/home/oxidized/.config/oxidized/repo/`
- **Logs:** `/var/lib/oxidized/data/oxidized.log` → `/home/oxidized/.config/oxidized/data/oxidized.log`
- **Git Config:** `/var/lib/oxidized/ssh/.gitconfig` → `/home/oxidized/.ssh/.gitconfig`

---

## Device Inventory Format

### File: `router.db`

**Format:** Colon-delimited with 6 fields (NOT comma-separated!)

### Syntax

```
name:ip:model:group:username:password
```

### Field Descriptions

| Position | Field | Description | Required | Example |
|----------|-------|-------------|----------|---------|
| 0 | `name` | Unique device identifier (hostname) | Yes | `core-rtr01` |
| 1 | `ip` | IP address or FQDN | Yes | `10.1.1.1` or `router.example.com` |
| 2 | `model` | Device type/model | Yes | `ios`, `nxos`, `eos`, `junos`, `procurve` |
| 3 | `group` | Logical grouping (for organization) | Yes | `datacenter`, `branch`, `core` |
| 4 | `username` | Device-specific username | Optional | `admin` or leave blank |
| 5 | `password` | Device-specific password | Optional | `secret123` or leave blank |

### Examples

**Example 1: Using Per-Device Credentials**
```
core-rtr01:10.1.1.1:ios:core:netadmin:Password123
dist-sw01:10.1.2.1:nxos:distribution:netops:Secret456
branch-sw01:10.2.1.1:procurve:branch:admin:Branch789
firewall01:10.1.3.1:fortios:security:fwadmin:FW_Pass123
```

**Example 2: Using Global Credentials (Recommended)**
```

# Leave username and password fields empty (trailing ::)

core-rtr01:10.1.1.1:ios:core::
core-rtr02:10.1.1.2:ios:core::
dist-sw01:10.1.2.1:nxos:distribution::
dist-sw02:10.1.2.2:nxos:distribution::
```

**Example 3: Mixed Mode (Some Per-Device, Some Global)**
```

# Most devices use global credentials

core-rtr01:10.1.1.1:ios:core::
core-rtr02:10.1.1.2:ios:core::

# This device has unique credentials

legacy-sw01:10.3.1.1:ios:legacy:oldadmin:OldPassword123

# Back to global credentials

dist-sw01:10.1.2.1:nxos:distribution::
```

**Example 4: Using FQDNs Instead of IPs**
```
core-rtr01:router1.datacenter.example.com:ios:core::
core-rtr02:router2.datacenter.example.com:ios:core::
```

### Supported Models (Common Examples)

| Model | Description | Vendor |
|-------|-------------|--------|
| `ios` | Cisco IOS | Cisco |
| `iosxr` | Cisco IOS XR | Cisco |
| `nxos` | Cisco Nexus (NX-OS) | Cisco |
| `asa` | Cisco ASA Firewall | Cisco |
| `eos` | Arista EOS | Arista |
| `junos` | Juniper JunOS | Juniper |
| `procurve` | HP ProCurve | HP/Aruba |
| `comware` | HP Comware | HP |
| `aoscx` | Aruba AOS-CX | Aruba |
| `fortios` | FortiGate | Fortinet |
| `panos` | PAN-OS | Palo Alto |

**Full list:** https://github.com/yggdrasil-network/oxidized/tree/master/lib/oxidized/model

---

## Understanding "CSV Source"

### Why is it called "CSV" but uses colons?

In Oxidized, "CSV" means **"Character-Separated Values"** with a **configurable delimiter**, NOT necessarily comma-separated.

The configuration uses:
```yaml
source:
  default: csv
  csv:
    delimiter: !ruby/regexp /:/  # ← Colon delimiter (NOT comma!)
```

This is **intentional** and allows compatibility with traditional router.db format while supporting extended fields.

### Traditional router.db vs. Our Format

**Traditional router.db (2 fields):**
```
router1:ios
router2:ios
switch1:procurve
```

**Our Extended Format (6 fields):**
```
router1:10.1.1.1:ios:core::
router2:10.1.1.2:ios:core::
switch1:10.1.2.1:procurve:access::
```

The extended format adds:

- **IP address** (field 1) - Required for connection
- **Group** (field 3) - For organization (configs stored in `repo/<group>/<name>`)
- **Username/Password** (fields 4-5) - For per-device credentials

---

## Credential Modes

Oxidized supports two credential modes:

### Mode A: Global Credentials (Recommended)

**Configuration:**

1. Set credentials in `.env`:

   ```bash
   OXIDIZED_USERNAME=admin
   OXIDIZED_PASSWORD=YourGlobalPassword
   ```

2. Leave username/password blank in `router.db`:

   ```
   switch01:10.1.1.1:ios:datacenter::
   switch02:10.1.1.2:ios:datacenter::
   ```

**Advantages:**

- Single place to update credentials
- Easier to rotate passwords
- Less sensitive data in router.db

**Use When:**

- All devices share the same credentials
- You use centralized authentication (TACACS+/RADIUS)
- Security policy requires minimal plaintext password storage

### Mode B: Per-Device Credentials

**Configuration:**

- Specify credentials in each line of `router.db`:

  ```
  switch01:10.1.1.1:ios:datacenter:admin:Password123
  legacy-sw:10.1.1.5:ios:legacy:oldadmin:OldPass456
  ```

**Advantages:**

- Supports heterogeneous environments
- Each device can have unique credentials
- Useful for migration scenarios

**Use When:**

- Devices have different local credentials
- You're migrating between authentication systems
- Some devices don't support centralized auth

**Security Warning:**

- ⚠️ Plaintext passwords in `router.db`
- ⚠️ Ensure `chmod 600` and proper ownership
- ⚠️ Never commit this file to Git with real passwords

### Mode C: Mixed (Global + Per-Device)

You can mix both modes:
```

# These use global credentials

modern-sw01:10.1.1.1:ios:datacenter::
modern-sw02:10.1.1.2:ios:datacenter::

# This legacy device has unique credentials

legacy-sw01:10.2.1.1:ios:legacy:oldadmin:OldPassword

# Back to global credentials

modern-sw03:10.1.1.3:ios:datacenter::
```

---

## Configuration File Structure

### Main Config: `/var/lib/oxidized/config/config`

This is a YAML file generated from `config/oxidized/config.template` during deployment.

**Key Sections:**

```yaml
---

# Global device credentials (used when router.db has empty username/password)

username: admin
password: changeme

# How often to poll devices (in seconds)

interval: 3600  # 1 hour

# Logging

log: /home/oxidized/.config/oxidized/data/oxidized.log
debug: false

# REST API (backend, exposed via Nginx)

rest: 0.0.0.0:8888

# Web UI (disabled, use REST API + custom frontend instead)

web: false

# Input methods (how to connect to devices)

input:
  default: ssh, telnet
  ssh:
    secure: false  # Allows legacy SSH ciphers

# Output (where to store configs)

output:
  default: git
  git:
    user: Oxidized
    email: oxidized@example.com
    repo: /home/oxidized/.config/oxidized/repo
    single_repo: true

# Source (where to get device list)

source:
  default: csv
  csv:
    file: /home/oxidized/.config/oxidized/router.db
    delimiter: !ruby/regexp /:/  # Colon delimiter
    map:
      name: 0      # Field 0: device name
      ip: 1        # Field 1: IP address
      model: 2     # Field 2: device model
      group: 3     # Field 3: group (for organization)
      username: 4  # Field 4: username (optional)
      password: 5  # Field 5: password (optional)
```

---

## Validation

### Automatic Validation During Deployment

The deployment script now includes automatic validation:

1. **File Existence Check:**
   - Fails if `router.db` doesn't exist
   - Provides clear error message

2. **Device Count Check:**
   - Warns if no devices are configured
   - Shows count of active device entries

3. **Format Validation:**
   - Runs `validate-router-db.sh` automatically
   - Checks field counts, syntax, and formats
   - Validates credential modes

### Manual Validation

**Validate router.db syntax:**
```bash
/var/lib/oxidized/scripts/validate-router-db.sh
```

**Test device connectivity:**
```bash
/var/lib/oxidized/scripts/test-device.sh DEVICE_NAME
```

**Check deployment health:**
```bash
/var/lib/oxidized/scripts/health-check.sh
```

---

## Troubleshooting

### "No devices found"

- Check if `router.db` exists at `/var/lib/oxidized/config/router.db`
- Verify file has non-empty, non-comment lines
- Run validation: `/var/lib/oxidized/scripts/validate-router-db.sh`

### "Permission denied" reading router.db

```bash

# Fix ownership

chown 2000:2000 /var/lib/oxidized/config/router.db
chmod 600 /var/lib/oxidized/config/router.db

# Fix SELinux context

chcon -t container_file_t /var/lib/oxidized/config/router.db
```

### "Invalid field count" errors

- Ensure all lines have exactly 6 fields (including empty ones)
- Format: `name:ip:model:group:username:password`
- For global credentials, use trailing `::` for empty username/password
- Example: `switch01:10.1.1.1:ios:datacenter::`

### Configs stored in unexpected location

- Configs are organized by **group** in subdirectories
- Path: `/var/lib/oxidized/repo/<group>/<name>`
- Example: `router.db` line `sw01:10.1.1.1:ios:datacenter::` → `/var/lib/oxidized/repo/datacenter/sw01`

---

## Quick Reference

### File Locations Summary

| File | Host Path | Container Path |
|------|-----------|----------------|
| Main Config | `/var/lib/oxidized/config/config` | `/home/oxidized/.config/oxidized/config` |
| Device Inventory | `/var/lib/oxidized/config/router.db` | `/home/oxidized/.config/oxidized/router.db` |
| Backed-up Configs | `/var/lib/oxidized/repo/<group>/` | `/home/oxidized/.config/oxidized/repo/<group>/` |
| Logs | `/var/lib/oxidized/data/oxidized.log` | `/home/oxidized/.config/oxidized/data/oxidized.log` |
| Git Config | `/var/lib/oxidized/ssh/.gitconfig` | `/home/oxidized/.ssh/.gitconfig` |

### Common Commands

```bash

# Validate router.db

/var/lib/oxidized/scripts/validate-router-db.sh

# Test device connectivity

/var/lib/oxidized/scripts/test-device.sh DEVICE_NAME

# View logs

tail -f /var/lib/oxidized/data/oxidized.log

# Trigger manual backup

curl -u admin:password "http://localhost:8888/node/fetch/DEVICE_NAME"

# View Git history

sudo -u "#30000" git -C /var/lib/oxidized/repo log --oneline

# View backed-up config

cat /var/lib/oxidized/repo/<group>/<device-name>
```

---

## See Also

- [Installation Guide](INSTALL.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [API Reference](API.md)
- [Oxidized Official Docs](https://github.com/yggdrasil-network/oxidized/blob/master/docs/Configuration.md)
