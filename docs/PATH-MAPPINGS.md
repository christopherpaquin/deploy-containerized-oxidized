# Oxidized Path Mappings Reference

Quick reference for understanding how files are mapped between the host system and the Oxidized container.

## Visual Path Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                         HOST SYSTEM                                     │
│                     (Red Hat Enterprise Linux)                          │
│                                                                          │
│  /var/lib/oxidized/                                                     │
│  ├── config/                                                            │
│  │   ├── config          ←─────┐ Main configuration (YAML)             │
│  │   └── router.db       ←─────┤ Device inventory (colon-delimited)    │
│  │                              │                                       │
│  ├── repo/                      │                                       │
│  │   └── lab-switches/   ←─────┤ Git repository (backed-up configs)    │
│  │       ├── s3560g-1           │                                       │
│  │       └── s3560g-2           │                                       │
│  │                              │                                       │
│  ├── data/                      │                                       │
│  │   └── oxidized.log    ←─────┤ Application logs                      │
│  │                              │                                       │
│  ├── ssh/                       │                                       │
│  │   ├── .gitconfig      ←─────┤ Git user configuration                │
│  │   └── known_hosts     ←─────┤ SSH known hosts                       │
│  │                              │                                       │
│  └── scripts/                   │                                       │
│      ├── health-check.sh        │                                       │
│      ├── validate-router-db.sh  │                                       │
│      └── test-device.sh         │                                       │
│                                  │                                       │
└─────────────────────────────────┼───────────────────────────────────────┘
                                   │
                     PODMAN VOLUME MOUNTS (with SELinux :Z)
                                   │
┌─────────────────────────────────┼───────────────────────────────────────┐
│                                  │                                       │
│                          CONTAINER                                       │
│                    (oxidized/oxidized:0.30.1)                           │
│                                  │                                       │
│  /home/oxidized/                 │                                       │
│  └── .config/oxidized/           │                                       │
│      ├── config          ←───────┘ Oxidized expects config here         │
│      ├── router.db                 (XDG Base Directory convention)      │
│      │                                                                   │
│      ├── repo/                     Git repository mounted here          │
│      │   └── lab-switches/        Organized by group                    │
│      │       ├── s3560g-1         Files owned by UID 30000 (container)  │
│      │       └── s3560g-2                                               │
│      │                                                                   │
│      └── data/                                                          │
│          └── oxidized.log          Application logs                     │
│                                                                          │
│  /home/oxidized/.ssh/                                                   │
│      ├── .gitconfig                Git config (read-only mount)         │
│      └── known_hosts               SSH known hosts                      │
│                                                                          │
│  Environment:                                                           │
│    HOME=/home/oxidized                                                  │
│    GIT_CONFIG_GLOBAL=/home/oxidized/.ssh/.gitconfig                     │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Mount Configuration Table

| Host Path | Container Path | Mode | Purpose |
|-----------|----------------|------|---------|
| `/var/lib/oxidized/config/` | `/home/oxidized/.config/oxidized/` | Read/Write (`:Z`) | Configuration and device inventory |
| `/var/lib/oxidized/repo/` | `/home/oxidized/.config/oxidized/repo/` | Read/Write (`:Z`) | Git repository for backed-up configs |
| `/var/lib/oxidized/data/` | `/home/oxidized/.config/oxidized/data/` | Read/Write (`:Z`) | Logs and runtime data |
| `/var/lib/oxidized/ssh/` | `/home/oxidized/.ssh/` | Read-Only (`:Z,ro`) | SSH keys and Git configuration |
| `/var/lib/oxidized/output/` | `/home/oxidized/.config/oxidized/output/` | Read/Write (`:Z`) | Legacy output directory |

## File-Level Mappings

### Configuration Files

| Description | Host | Container |
|-------------|------|-----------|
| Main config (YAML) | `/var/lib/oxidized/config/config` | `/home/oxidized/.config/oxidized/config` |
| Device inventory | `/var/lib/oxidized/config/router.db` | `/home/oxidized/.config/oxidized/router.db` |

### Git Repository

| Description | Host | Container |
|-------------|------|-----------|
| Git repo root | `/var/lib/oxidized/repo/` | `/home/oxidized/.config/oxidized/repo/` |
| Git metadata | `/var/lib/oxidized/repo/.git/` | `/home/oxidized/.config/oxidized/repo/.git/` |
| Config by group | `/var/lib/oxidized/repo/<group>/<device>` | `/home/oxidized/.config/oxidized/repo/<group>/<device>` |

**Example:**

- Device: `s3560g-1` in group `lab-switches`
- Host: `/var/lib/oxidized/repo/lab-switches/s3560g-1`
- Container: `/home/oxidized/.config/oxidized/repo/lab-switches/s3560g-1`

### Runtime Files

| Description | Host | Container |
|-------------|------|-----------|
| Application log | `/var/lib/oxidized/data/oxidized.log` | `/home/oxidized/.config/oxidized/data/oxidized.log` |
| PID file | `/var/lib/oxidized/data/oxidized.pid` | `/home/oxidized/.config/oxidized/data/oxidized.pid` |
| Crash dumps | `/var/lib/oxidized/data/crashes/` | `/home/oxidized/.config/oxidized/data/crashes/` |

### SSH and Git Configuration

| Description | Host | Container |
|-------------|------|-----------|
| Git config | `/var/lib/oxidized/ssh/.gitconfig` | `/home/oxidized/.ssh/.gitconfig` |
| SSH known hosts | `/var/lib/oxidized/ssh/known_hosts` | `/home/oxidized/.ssh/known_hosts` |

## User ID Mappings

| Context | UID | GID | Username | Notes |
|---------|-----|-----|----------|-------|
| **Host** | 2000 | 2000 | `oxidized` | Created by deploy.sh |
| **Container** | 30000 | 30000 | `oxidized` | Container's internal UID |
| **Files on Host** | 30000 | 30000 | (numeric) | Files created by container |

**Important:** Files in `/var/lib/oxidized/` are owned by UID 30000 (container's internal user), **not** the host's oxidized user (UID 2000). This is intentional for proper namespace isolation.

To interact with these files from the host:
```bash

# Use sudo with numeric UID

sudo -u "#30000" git -C /var/lib/oxidized/repo log

# Or read files directly (they're world-readable)

cat /var/lib/oxidized/repo/lab-switches/s3560g-1
```

## Quadlet Configuration Excerpt

From `/etc/containers/systemd/oxidized.container`:

```ini
[Container]

# Configuration and device inventory (read/write)

Volume=/var/lib/oxidized/config:/home/oxidized/.config/oxidized:Z

# Git repository for backed-up configs (read/write)

Volume=/var/lib/oxidized/repo:/home/oxidized/.config/oxidized/repo:Z

# Logs and runtime data (read/write)

Volume=/var/lib/oxidized/data:/home/oxidized/.config/oxidized/data:Z

# SSH keys and Git config (read-only)

Volume=/var/lib/oxidized/ssh:/home/oxidized/.ssh:Z,ro

# Legacy output directory (read/write)

Volume=/var/lib/oxidized/output:/home/oxidized/.config/oxidized/output:Z

# Environment variables

Environment=TZ=EST
Environment=HOME=/home/oxidized
Environment=GIT_CONFIG_GLOBAL=/home/oxidized/.ssh/.gitconfig
```

## SELinux Context

All volumes are mounted with `:Z` flag for automatic SELinux relabeling:

- `:Z` - Private unshared label (container-specific)
- Context type: `container_file_t`

Verify contexts:
```bash
ls -laZ /var/lib/oxidized/config/
ls -laZ /var/lib/oxidized/repo/
```

## Common Access Patterns

### Viewing Configuration

```bash

# Main config (host)

cat /var/lib/oxidized/config/config

# Main config (container)

podman exec oxidized cat /home/oxidized/.config/oxidized/config

# Device inventory (host)

cat /var/lib/oxidized/config/router.db

# Device inventory (container)

podman exec oxidized cat /home/oxidized/.config/oxidized/router.db
```

### Accessing Backed-Up Configs

```bash

# List all groups (host)

ls /var/lib/oxidized/repo/

# List devices in a group (host)

ls /var/lib/oxidized/repo/lab-switches/

# View device config (host)

cat /var/lib/oxidized/repo/lab-switches/s3560g-1

# View device config (container)

podman exec oxidized cat /home/oxidized/.config/oxidized/repo/lab-switches/s3560g-1
```

### Git Operations

```bash

# View Git log (host)

sudo -u "#30000" git -C /var/lib/oxidized/repo log --oneline

# View Git log (container)

podman exec -u oxidized oxidized git -C /home/oxidized/.config/oxidized/repo log --oneline

# View specific commit (host)

sudo -u "#30000" git -C /var/lib/oxidized/repo show COMMIT_HASH

# Compare versions (host)

sudo -u "#30000" git -C /var/lib/oxidized/repo diff HEAD~1 HEAD
```

### Log Access

```bash

# Tail logs (host)

tail -f /var/lib/oxidized/data/oxidized.log

# Tail logs (container)

podman exec oxidized tail -f /home/oxidized/.config/oxidized/data/oxidized.log

# View container logs (Podman)

podman logs -f oxidized

# View systemd logs

journalctl -u oxidized.service -f
```

## Troubleshooting Path Issues

### "File not found" errors

1. **Check if mount exists:**

   ```bash
   podman inspect oxidized | jq '.[].Mounts'
   ```

2. **Verify file exists on host:**

   ```bash
   ls -la /var/lib/oxidized/config/config
   ls -la /var/lib/oxidized/config/router.db
   ```

3. **Check inside container:**

   ```bash
   podman exec oxidized ls -la /home/oxidized/.config/oxidized/
   ```

### Permission denied

1. **Check file ownership:**

   ```bash
   ls -ln /var/lib/oxidized/config/
   ```

2. **Check SELinux context:**

   ```bash
   ls -laZ /var/lib/oxidized/config/
   ```

3. **Fix ownership (if needed):**

   ```bash
   chown -R 30000:30000 /var/lib/oxidized/config/
   chown -R 30000:30000 /var/lib/oxidized/repo/
   ```

4. **Fix SELinux context (if needed):**

   ```bash
   chcon -R -t container_file_t /var/lib/oxidized/
   ```

### Git "dubious ownership" errors

This is resolved by setting `safe.directory` in `.gitconfig`:

```bash

# Check if .gitconfig exists

ls -la /var/lib/oxidized/ssh/.gitconfig

# Verify content

cat /var/lib/oxidized/ssh/.gitconfig

# Should contain:

# [safe]

#   directory = /home/oxidized/.config/oxidized/repo

```

## See Also

- [Configuration Guide](CONFIGURATION.md) - Detailed configuration documentation
- [Installation Guide](INSTALL.md) - Deployment procedures
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues and solutions
