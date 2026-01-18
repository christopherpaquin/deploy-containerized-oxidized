# Oxidized Directory Structure

Complete guide to the Oxidized directory layout and file locations.

## Table of Contents

- [Overview](#overview)
- [Understanding File Ownership](#understanding-file-ownership)
- [Directory Tree](#directory-tree)
- [Active Directories](#active-directories)
- [Empty/Unused Directories](#emptyunused-directories)
- [File Locations](#file-locations)
- [Helper Scripts](#helper-scripts)
- [Understanding the Structure](#understanding-the-structure)

---

## Overview

Oxidized data is stored under `/var/lib/oxidized/` with the following structure:

```
/var/lib/oxidized/
├── config/          # Configuration files
├── data/            # Active: Logs and runtime data
├── docs/            # Active: User documentation
├── nginx/           # nginx authentication data
├── output/          # Output files (if configured)
├── repo/            # Active: Git repository for backups
├── scripts/         # Active: Helper scripts
└── ssh/             # SSH keys and known_hosts
```

**Note:** There are some empty subdirectories under `config/` that are created by the container but not used. See [Empty/Unused Directories](#emptyunused-directories) for details.

---

## Understanding File Ownership

**CRITICAL:** Oxidized uses a containerized deployment with specific ownership requirements.

### Why UID 30000?

The Oxidized container uses **baseimage-docker**, which runs an internal init system. Inside the container, the oxidized user has **UID 30000**, which is different from the host's oxidized user (UID 2000).

When files are stored on bind-mounted volumes:

- Files **must** be owned by **UID 30000** on the host
- The container sees them as owned by its internal oxidized user
- This allows the container process to read and write them

### Ownership Rules

| Directory | Owner | Reason |
|-----------|-------|--------|
| **Container-accessed** | `30000:30000` | Container needs read/write access |
| config/, data/, repo/, ssh/, output/ | `30000:30000` | ← Must be 30000 |
| **Host-only** | `oxidized:oxidized` (2000:2000) | Only accessed from host |
| docs/, scripts/ | `oxidized:oxidized` | ← Can be 2000 |
| **System service** | `root:root` or `root:nginx` | nginx reverse proxy |
| nginx/ | `root:root` | ← System config dir |
| nginx/.htpasswd | `root:nginx` (640) | ← nginx group read |

### Automatic Fixes

The `deploy.sh` script includes a `fix_ownership()` function that:

1. Sets correct ownership (30000:30000 for container dirs)
2. Removes SELinux MCS categories that block access
3. Preserves special ownership for nginx and host-only dirs

**You should not manually change ownership** - the deploy script handles this automatically.

### Common Mistakes

❌ **WRONG:** `chown -R oxidized:oxidized /var/lib/oxidized`
✅ **CORRECT:** Let deploy.sh handle ownership (uses 30000:30000 for container dirs)

❌ **WRONG:** `chown 2000:2000 /var/lib/oxidized/config/router.db`
✅ **CORRECT:** `chown 30000:30000 /var/lib/oxidized/config/router.db`

---

## Directory Tree

Full directory tree with descriptions:

```
/var/lib/oxidized/
│
├── config/                         # Configuration directory
│   ├── config                      # ✅ ACTIVE: Main Oxidized config
│   ├── config.backup.*             # ✅ ACTIVE: Config backups
│   ├── router.db                   # ✅ ACTIVE: Device inventory
│   ├── router.db.backup.*          # ✅ ACTIVE: Device inventory backups
│   ├── crash/                      # ⚠️  EMPTY: Crash dumps (created by container, unused)
│   ├── data/                       # ⚠️  EMPTY: Not used (see /var/lib/oxidized/data/)
│   ├── logs/                       # ⚠️  EMPTY: Not used (see /var/lib/oxidized/data/)
│   ├── output/                     # ⚠️  EMPTY: Not used (see /var/lib/oxidized/output/)
│   └── repo/                       # ⚠️  EMPTY: Not used (see /var/lib/oxidized/repo/)
│
├── data/                           # ✅ ACTIVE: Runtime data
│   ├── oxidized.log                # ✅ ACTIVE: Main log file
│   └── oxidized.pid                # ✅ ACTIVE: PID file
│
├── docs/                           # ✅ ACTIVE: User documentation
│   ├── QUICK-START.md              # ✅ ACTIVE: Quick reference guide
│   ├── DEVICE-MANAGEMENT.md        # ✅ ACTIVE: Device management guide
│   ├── CREDENTIALS-GUIDE.md        # ✅ ACTIVE: Credentials guide
│   ├── DIRECTORY-STRUCTURE.md      # ✅ ACTIVE: This file
│   └── GIT-REPOSITORY-STRUCTURE.md # ✅ ACTIVE: Git repo structure guide
│
├── nginx/                          # ✅ ACTIVE: nginx auth data
│   └── .htpasswd                   # ✅ ACTIVE: HTTP Basic Auth credentials
│
├── output/                         # ✅ ACTIVE: Output directory (if configured)
│
├── repo/                           # ✅ ACTIVE: Git repository
│   ├── .git/                       # ✅ ACTIVE: Git metadata
│   ├── README.md                   # ✅ ACTIVE: Repo readme
│   └── <device-configs>            # ✅ ACTIVE: Backed-up device configs
│
├── scripts/                        # ✅ ACTIVE: Helper scripts
│   ├── health-check.sh             # ✅ ACTIVE: System health check
│   ├── validate-router-db.sh       # ✅ ACTIVE: Validate device inventory
│   └── test-device.sh              # ✅ ACTIVE: Test device connectivity
│
└── ssh/                            # ✅ ACTIVE: SSH configuration
    └── known_hosts                 # ✅ ACTIVE: SSH known hosts
```

---

## Active Directories

These directories are actively used by Oxidized:

### `/var/lib/oxidized/config/`

**Purpose:** Configuration files

**Contents:**

- `config` - Main Oxidized configuration
- `config.backup.YYYYMMDD_HHMMSS` - Automatic config backups (created on deploy)
- `router.db` - Device inventory (colon-delimited CSV)
- `router.db.backup.YYYYMMDD_HHMMSS` - Automatic router.db backups (created on deploy)

**Owner:** `30000:30000` (container's internal UID)
**Permissions:** `755` (directory), `644` (files)

**Note:** Files must be owned by UID 30000 (the container's internal oxidized user) for the container to access them.

### `/var/lib/oxidized/data/`

**Purpose:** Runtime data and logs

**Contents:**

- `oxidized.log` - **Main log file** (rotated daily, 14 days retention)
- `oxidized.pid` - Process ID file

**Owner:** `30000:30000` (container's internal UID)
**Permissions:** `755` (directory), `644` (files)

**Log Rotation:**

- Config: `/etc/logrotate.d/oxidized`
- Rotated logs: `oxidized.log.1`, `oxidized.log.2.gz`, etc.

### `/var/lib/oxidized/nginx/`

**Purpose:** nginx authentication data

**Contents:**

- `.htpasswd` - HTTP Basic Authentication credentials (bcrypt hashed)

**Owner:**

- Directory: `root:root` (755) - System service configuration directory
- `.htpasswd`: `root:nginx` (640) - nginx group can read, others cannot

**Why root:nginx?**

- nginx is a **system service** running on the host (not in container)
- System configuration directories should be owned by root (security best practice)
- nginx worker processes run as 'nginx' user
- Group ownership allows nginx to read .htpasswd
- 640 permissions prevent unprivileged users from reading password hashes

**Configuration:**

- Managed by `deploy.sh`
- Credentials from `.env`: `NGINX_USERNAME`, `NGINX_PASSWORD`
- Regenerated on every deploy

**DO NOT** change ownership to oxidized:oxidized - this will break authentication!

### `/var/lib/oxidized/docs/`

**Purpose:** User documentation and reference guides

**Contents:**

- `QUICK-START.md` - Quick reference for common tasks
- `DEVICE-MANAGEMENT.md` - Complete device management guide
- `CREDENTIALS-GUIDE.md` - Credential configuration guide
- `DIRECTORY-STRUCTURE.md` - This file
- `GIT-REPOSITORY-STRUCTURE.md` - Git repo structure and usage

**Owner:** `oxidized:oxidized` (2000:2000) - Host access only
**Permissions:** `755` (directory), `644` (files)

**Installed:** Automatically during deployment
**Removed:** Automatically during uninstall

**Purpose:** Provides administrators with on-system documentation without needing to access the deployment repository.

**Note:** Owned by host's oxidized user since it's only accessed from the host, not by the container.

### `/var/lib/oxidized/repo/`

**Purpose:** Git repository for device configurations

**Contents:**

- `.git/` - Git metadata
- `README.md` - Repository readme
- `<device-name>` - Individual device config files

**Owner:** `30000:30000` (container's internal UID)
**Permissions:** `755` (directory), `644` (files)

**Git Configuration:**

- User: `Oxidized`
- Email: `oxidized@example.com`
- Every config change creates a commit

### `/var/lib/oxidized/scripts/`

**Purpose:** Helper scripts for management

**Contents:**

- `health-check.sh` - System and service health check
- `validate-router-db.sh` - Validate router.db syntax and entries
- `test-device.sh` - Test device connectivity and trigger backup

**Owner:** `oxidized:oxidized` (2000:2000) - Host access only
**Permissions:** `755` (directory and files)

**Installed:** Automatically during deployment
**Removed:** Automatically during uninstall

**Note:** Owned by host's oxidized user since scripts are run from the host, not by the container.

### `/var/lib/oxidized/ssh/`

**Purpose:** SSH configuration and keys

**Contents:**

- `known_hosts` - SSH known hosts file

**Owner:** `30000:30000` (container's internal UID)
**Permissions:** `700` (directory), `600` (keys), `644` (known_hosts)

**Note:** If using SSH key authentication, place keys here and ensure they're owned by 30000:30000

### `/var/lib/oxidized/output/`

**Purpose:** Output files (if configured)

**Contents:** (varies based on configuration)

**Owner:** `30000:30000` (container's internal UID)
**Permissions:** `755`

---

## Empty/Unused Directories

These directories exist but are **NOT actively used**. They are created by the container image but Oxidized uses the top-level equivalents instead.

### ⚠️ `/var/lib/oxidized/config/data/` - EMPTY

**Status:** Not used
**Actual location:** `/var/lib/oxidized/data/`

This directory is empty. Oxidized writes logs to `/var/lib/oxidized/data/oxidized.log` instead.

### ⚠️ `/var/lib/oxidized/config/logs/` - EMPTY

**Status:** Not used
**Actual location:** `/var/lib/oxidized/data/oxidized.log`

This directory is empty. Logs are written to `/var/lib/oxidized/data/` not here.

### ⚠️ `/var/lib/oxidized/config/repo/` - EMPTY

**Status:** Not used
**Actual location:** `/var/lib/oxidized/repo/`

This directory is empty. The Git repository is at `/var/lib/oxidized/repo/` instead.

### ⚠️ `/var/lib/oxidized/config/output/` - EMPTY

**Status:** Not used
**Actual location:** `/var/lib/oxidized/output/`

This directory is empty. Output files go to `/var/lib/oxidized/output/` instead.

### ⚠️ `/var/lib/oxidized/config/crash/` - EMPTY

**Status:** Not used
**Purpose:** Intended for crash dumps (if Oxidized crashes)

This directory is typically empty unless Oxidized encounters a fatal error.

---

## File Locations

Quick reference for important files:

| File/Purpose | Location |
|--------------|----------|
| **Main Config** | `/var/lib/oxidized/config/config` |
| **Device Inventory** | `/var/lib/oxidized/config/router.db` |
| **Active Log** | `/var/lib/oxidized/data/oxidized.log` ✅ |
| **Rotated Logs** | `/var/lib/oxidized/data/oxidized.log.{1,2.gz,...}` |
| **Log Rotation Config** | `/etc/logrotate.d/oxidized` |
| **PID File** | `/var/lib/oxidized/data/oxidized.pid` |
| **Git Repository** | `/var/lib/oxidized/repo/` |
| **Device Configs** | `/var/lib/oxidized/repo/<device-name>` |
| **SSH Known Hosts** | `/var/lib/oxidized/ssh/known_hosts` |
| **nginx Auth** | `/var/lib/oxidized/nginx/.htpasswd` |
| **Helper Scripts** | `/var/lib/oxidized/scripts/` |

**❌ NOT Used:**

- ~~`/var/lib/oxidized/config/data/`~~ - Empty, not used
- ~~`/var/lib/oxidized/config/logs/`~~ - Empty, not used
- ~~`/var/lib/oxidized/config/repo/`~~ - Empty, not used
- ~~`/var/lib/oxidized/config/output/`~~ - Empty, not used

---

## Helper Scripts

Scripts installed in `/var/lib/oxidized/scripts/`:

### `health-check.sh`

**Purpose:** Check Oxidized service and container health

**Usage:**
```bash
/var/lib/oxidized/scripts/health-check.sh
```

**Checks:**

- Service status and uptime
- Container running and health
- API accessibility (frontend and backend)
- Container resource usage
- Bind mounts and network configuration

### `validate-router-db.sh`

**Purpose:** Validate router.db syntax and entries

**Usage:**
```bash

# Validate default location

/var/lib/oxidized/scripts/validate-router-db.sh

# Validate specific file

/var/lib/oxidized/scripts/validate-router-db.sh /path/to/router.db
```

**Checks:**

- File format (6 fields per line)
- Device name format
- IP address/hostname format
- Duplicate device names
- Duplicate IP addresses (warning)
- Known device models (warning if unknown)
- Credential consistency

### `test-device.sh`

**Purpose:** Test device connectivity and trigger backup

**Usage:**
```bash
/var/lib/oxidized/scripts/test-device.sh <device-name>
```

**Checks:**

- Device exists in router.db
- Container is running
- Device is registered in Oxidized
- Network connectivity (ping)
- SSH port accessibility (port 22)
- Triggers manual backup
- Shows recent logs

---

## Understanding the Structure

### Why Are There Empty Subdirectories?

The empty subdirectories under `/var/lib/oxidized/config/` (data, logs, output, repo) are created by the Oxidized container image but are not used in this deployment.

**Reason:** This deployment uses bind mounts to map host directories to specific container paths:

```yaml

# Container internal paths → Host paths

/home/oxidized/.config/oxidized/      → /var/lib/oxidized/config/
/home/oxidized/.config/oxidized/data/ → /var/lib/oxidized/data/
/home/oxidized/.config/oxidized/repo/ → /var/lib/oxidized/repo/
```

The container creates subdirectories under its config path, but they remain empty because we're using separate bind mounts for data and repo.

### Why Not Use the Subdirectories?

**Better organization:**

- Clear separation: config vs. data vs. repo
- Easier to find logs: `/var/lib/oxidized/data/oxidized.log`
- Easier to backup: Git repo at `/var/lib/oxidized/repo/`
- Simpler paths: No nested subdirectories

**Standard Linux practice:**

- `/var/lib/<service>/` typically contains multiple directories
- Logs, data, and repos are separate entities
- Matches systemd service structure

### Can I Delete the Empty Directories?

**No - leave them alone.** They are created by the container and may be referenced by internal scripts. Deleting them won't save meaningful space (they're empty) and could cause issues.

---

## Quick Commands

### View Directory Structure

```bash

# Full tree

tree -L 2 /var/lib/oxidized

# Sizes

du -sh /var/lib/oxidized/*

# File counts

find /var/lib/oxidized -type f | wc -l
```

### Check Active Files

```bash

# Current log size

du -h /var/lib/oxidized/data/oxidized.log

# Git repo size

du -sh /var/lib/oxidized/repo

# Device count

grep -v "^#" /var/lib/oxidized/config/router.db | grep -v "^$" | wc -l

# Backup count

ls -1 /var/lib/oxidized/config/*.backup.* | wc -l
```

### Verify Empty Directories

```bash

# Should be empty

ls -la /var/lib/oxidized/config/data/
ls -la /var/lib/oxidized/config/logs/
ls -la /var/lib/oxidized/config/repo/
ls -la /var/lib/oxidized/config/output/
```

---

## Related Documentation

- [DEVICE-MANAGEMENT.md](DEVICE-MANAGEMENT.md) - Device and log management
- [DEPLOYMENT-NOTES.md](DEPLOYMENT-NOTES.md) - Deployment details
- [QUICK-START.md](QUICK-START.md) - Quick reference
- [README.md](README.md) - Main documentation

---

**Last Updated:** 2026-01-18
**Oxidized Version:** 0.30.1
