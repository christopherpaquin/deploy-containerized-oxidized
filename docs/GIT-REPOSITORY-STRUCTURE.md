# Git Repository Structure

This document explains how Oxidized organizes device configurations in the Git repository and how the `group` field in `router.db` affects storage.

## Repository Location

```
/var/lib/oxidized/repo/
```

This is a standard Git repository that stores all backed-up device configurations.

## Current Configuration: Single Repository (Flat Structure)

Your Oxidized deployment uses a **single repository** for all devices. This is the default and recommended configuration for most deployments.

### Directory Structure

```
/var/lib/oxidized/repo/
├── .git/                    # Git metadata
├── README.md                # Repository information
├── device-name-1            # Device config (flat file)
├── device-name-2            # Device config (flat file)
├── device-name-3            # Device config (flat file)
└── ...
```

### How It Works

1. **One file per device**: Each device gets a single file named after the device
2. **Flat structure**: All devices are in the root directory (no subdirectories)
3. **Git commits**: Every config change triggers a new Git commit
4. **Full history**: `git log` shows all changes across all devices

### Example

If you have these devices in `router.db`:
```
router1:192.168.1.1:ios:core::
switch1:192.168.1.2:ios:access::
firewall1:192.168.1.3:asa:security::
```

Your repo will contain:
```
/var/lib/oxidized/repo/
├── router1      # Running config from router1
├── switch1      # Running config from switch1
└── firewall1    # Running config from firewall1
```

## The `group` Field in router.db

### What Is It?

The `group` field (4th column) in `router.db` is used for **logical organization** and **filtering**, not for directory structure.

```
# Format: name:ip:model:group:username:password
router1:192.168.1.1:ios:core::
switch1:192.168.1.2:ios:access::
firewall1:192.168.1.3:asa:security::
```

### What Groups Are Used For

1. **Web UI Filtering**: Filter devices by group in the web interface
2. **API Queries**: Query devices by group via REST API
3. **Logical Organization**: Organize devices by function, location, or type
4. **Reporting**: Generate reports for specific groups

### What Groups Are NOT Used For (In Default Config)

❌ **Not used for directory structure** (all devices are in repo root)
❌ **Not used for separate Git repositories** (single repo for all)
❌ **Not used for access control** (all devices in same repo)

### Common Group Naming Schemes

**By Function:**
```
core-routers
access-switches
distribution-switches
firewalls
wan-routers
```

**By Location:**
```
datacenter-1
datacenter-2
branch-office-nyc
branch-office-la
```

**By Environment:**
```
production
staging
development
lab
```

**By Vendor/Model:**
```
cisco-ios
cisco-nxos
arista-eos
juniper-junos
```

## Git Operations

### View All Commits

```bash
cd /var/lib/oxidized/repo
sudo -u oxidized git log --all --oneline
```

### View Changes for a Specific Device

```bash
cd /var/lib/oxidized/repo
sudo -u oxidized git log --all --oneline -- router1
```

### View Changes in a Time Range

```bash
cd /var/lib/oxidized/repo
sudo -u oxidized git log --all --since="1 week ago"
```

### View Diff for Last Change

```bash
cd /var/lib/oxidized/repo
sudo -u oxidized git diff HEAD~1 HEAD -- router1
```

### Restore Previous Version

```bash
cd /var/lib/oxidized/repo
# View history
sudo -u oxidized git log --all --oneline -- router1

# Restore from specific commit (replace COMMIT_HASH)
sudo -u oxidized git show COMMIT_HASH:router1 > /tmp/router1-restored.cfg
```

## Advanced Configuration: Group-Based Repositories

If you need **separate Git repositories per group**, you can modify the configuration. This is useful for:

- Very large deployments (thousands of devices)
- Separate access control per group
- Different Git workflows per device type

### Configuration Example

Edit `/var/lib/oxidized/config/config`:

```yaml
output:
  default: git
  git:
    user: Oxidized
    email: oxidized@example.com
    repo: /home/oxidized/.config/oxidized/repos/default.git
```

Then create group-specific repositories:

```yaml
groups:
  core-routers:
    git:
      repo: /home/oxidized/.config/oxidized/repos/core.git
  access-switches:
    git:
      repo: /home/oxidized/.config/oxidized/repos/access.git
```

**Result:**
```
/var/lib/oxidized/repos/
├── default.git/      # Devices without specific group config
├── core.git/         # Core router configs
└── access.git/       # Access switch configs
```

### When to Use Group-Based Repos

✅ **Use when:**
- You have 1000+ devices
- You need separate Git workflows per group
- You want isolated repositories for compliance
- You have different retention policies per group

❌ **Don't use when:**
- You have < 500 devices (single repo is simpler)
- You want unified search/reporting across all devices
- You prefer simple Git operations

## File Naming and Content

### File Names

- **Naming**: Uses device name from `router.db` (first column)
- **No extension**: Files have no `.txt` or `.cfg` extension
- **Case-sensitive**: Device names are case-sensitive in filesystem

### File Content

Each file contains the device's **running configuration** as retrieved by Oxidized:

```
! Cisco IOS Configuration
version 15.2
service timestamps debug datetime msec
service timestamps log datetime msec
...
```

The exact content depends on:
- Device model (`ios`, `nxos`, `asa`, etc.)
- Commands defined in the Oxidized model
- Device's running configuration

## Git Commit Messages

Oxidized generates automatic commit messages:

```
new node: device-name                    # First backup
update device-name                       # Config changed
delete device-name                       # Device removed from router.db
```

### Example Git Log

```
$ sudo -u oxidized git log --all --oneline
a1b2c3d update router1
e4f5g6h new node: switch2
i7j8k9l update firewall1
m0n1o2p update router1
```

## Repository Maintenance

### Repository Size

- **Growth**: Repo size grows with number of devices and change frequency
- **Compression**: Git automatically compresses old commits
- **Typical size**: 10-50 MB for 100 devices with 1 year history

### Cleanup Old History (Optional)

If your repository grows too large, you can prune old history:

```bash
cd /var/lib/oxidized/repo
sudo -u oxidized git reflog expire --expire=now --all
sudo -u oxidized git gc --prune=now --aggressive
```

**⚠️ Warning**: This permanently deletes old history. Only do this if disk space is critical.

### Backup Recommendations

1. **Automated backups**: Include `/var/lib/oxidized/repo/` in system backups
2. **Remote Git mirrors**: Push to remote Git server periodically
3. **Retention**: Keep at least 90 days of history

## Troubleshooting

### Problem: Device file not appearing in repo

**Causes:**
- Device not reachable via network
- Credentials incorrect
- Model not supported
- SSH key issues

**Check:**
```bash
/var/lib/oxidized/scripts/test-device.sh device-name
podman logs oxidized | grep device-name
```

### Problem: Repository is locked

**Cause:** Git lock file exists (rare)

**Fix:**
```bash
cd /var/lib/oxidized/repo
sudo -u oxidized rm -f .git/index.lock
sudo systemctl restart oxidized
```

### Problem: Commit author is wrong

**Fix:**
```bash
# Edit config
sudo vi /var/lib/oxidized/config/config

# Update git settings
output:
  git:
    user: New Name
    email: new@example.com

# Restart
sudo systemctl restart oxidized
```

## Summary

### Default Configuration (Current)

✅ **Single Git repository**: All devices in `/var/lib/oxidized/repo/`
✅ **Flat structure**: One file per device in repo root
✅ **Groups for organization**: Used in Web UI, not for directories
✅ **Full Git history**: All changes tracked in commits
✅ **Simple operations**: Standard Git commands work

### Key Takeaways

1. Device files are stored in repo root (no subdirectories by default)
2. The `group` field organizes devices logically, not physically
3. Each config change triggers a Git commit
4. Use `git log` and `git diff` to view history
5. Backup the entire repo directory regularly

## Related Documentation

- **DEVICE-MANAGEMENT.md**: Adding, editing, and managing devices
- **DIRECTORY-STRUCTURE.md**: Complete file system layout
- **QUICK-START.md**: Common operational commands

## References

- Oxidized Git Output: https://github.com/ytti/oxidized/blob/master/docs/Outputs.md#git
- Git Documentation: https://git-scm.com/doc
