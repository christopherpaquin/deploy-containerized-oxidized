# Credentials Documentation Overview

## Two Separate Credential Sets

Your Oxidized deployment uses **TWO completely separate credential sets**:

### 1. Web UI Login Credentials (nginx)

**Purpose**: Access the Oxidized web interface
**Documentation**: [AUTHENTICATION-SETUP.md](AUTHENTICATION-SETUP.md)
**Configured in**: `.env` file (`NGINX_USERNAME` and `NGINX_PASSWORD`)
**Used for**: Logging into http://your-server:8888

### 2. Network Device Credentials

**Purpose**: SSH/Telnet access to network devices for backing up configs
**Documentation**: ⭐ **[CREDENTIALS-GUIDE.md](CREDENTIALS-GUIDE.md)** (COMPLETE GUIDE)
**Configured in**: `.env` file **AND** `router.db`
**Used for**: Oxidized connecting to routers, switches, firewalls

## 🔴 Critical Information About Device Credentials

**The CREDENTIALS-GUIDE.md explains a critical CSV parsing behavior:**

- **Empty credential fields (`::`) do NOT trigger global credential fallback**
- Empty fields are parsed as empty strings, causing authentication failures
- You **MUST provide explicit credentials** for each device in `router.db`
- Even when using "global" credentials, repeat them for each device

### Quick Example

❌ **WRONG** - Will fail with authentication errors:
```
router1:10.1.1.1:ios:core::
router2:10.1.1.2:ios:core::
```

✅ **CORRECT** - Explicit credentials work:
```
router1:10.1.1.1:ios:core:admin:password123
router2:10.1.1.2:ios:core:admin:password123
```

## Documentation Files by Topic

### Primary References

| Document | Topic | When to Use |
|----------|-------|-------------|
| **[CREDENTIALS-GUIDE.md](CREDENTIALS-GUIDE.md)** | ⭐ Device credentials (complete guide) | Adding devices, authentication issues |
| **[AUTHENTICATION-SETUP.md](AUTHENTICATION-SETUP.md)** | Web UI login credentials | Setting up nginx authentication |
| **[DEVICE-MANAGEMENT.md](DEVICE-MANAGEMENT.md)** | Managing devices in router.db | Adding/updating/removing devices |
| **[ADD-DEVICE.md](ADD-DEVICE.md)** | Interactive device addition script | Using add-device.sh |

### Where Credential Info Appears

| Location | Content | Purpose |
|----------|---------|---------|
| `/var/lib/oxidized/config/router.db` | Inline docs with CSV parsing warnings | Device inventory file |
| `docs/CREDENTIALS-GUIDE.md` | Complete credential guide (476 lines) | Authoritative reference |
| `docs/DEVICE-MANAGEMENT.md` | Quick summary + link to CREDENTIALS-GUIDE | Device management workflow |
| `docs/ADD-DEVICE.md` | Brief mention during device addition | Script documentation |
| `docs/AUTHENTICATION-SETUP.md` | Web UI credentials only | nginx configuration |

## What Was Fixed

### Before (Misleading)

The documentation incorrectly stated:

> "Leave username/password columns blank in this file"
> "Use :: to trigger global credential fallback"

This caused authentication failures because:
- CSV parser interprets `::` as empty strings `"" ""`
- Oxidized uses these empty strings as actual credentials
- Login fails with empty username/password

### After (Accurate)

The documentation now correctly explains:

> "You MUST provide explicit credentials in router.db"
> "Empty fields (`::`) are parsed as empty strings, not 'use globals'"
> "Repeat credentials for each device (matching your .env values)"

## Quick Start

1. **Read**: [CREDENTIALS-GUIDE.md](CREDENTIALS-GUIDE.md) for complete credential documentation
2. **Edit**: `/var/lib/oxidized/config/router.db` with explicit credentials
3. **Test**: `/var/lib/oxidized/scripts/test-device.sh <device-name>`

## Related Documentation

- [README-OXIDIZED.md](README-OXIDIZED.md) - Oxidized usage guide
- [DEVICE-MANAGEMENT.md](DEVICE-MANAGEMENT.md) - Managing devices
- [QUICK-START.md](../QUICK-START.md) - Getting started
- [SERVICE-MANAGEMENT.md](SERVICE-MANAGEMENT.md) - Service control

---

**Last Updated**: 2026-02-05
**Consolidated By**: Documentation review to eliminate credential confusion
