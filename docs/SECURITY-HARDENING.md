# 🛡️ Security Hardening Guide

This document describes the security-hardened deployment model for Oxidized.

---

## 🎯 Overview

This deployment implements defense-in-depth security practices:

1. **Dedicated System User**: Runs as `oxidized:oxidized` (UID/GID 2000)
2. **Non-Root Container**: Container process runs as UID 2000 (not root)
3. **Read-Only Root Filesystem**: Container rootfs is immutable
4. **Dropped Capabilities**: All Linux capabilities removed
5. **No New Privileges**: Prevents privilege escalation
6. **Isolated Network**: Dedicated Podman bridge network
7. **Minimal Permissions**: Strict file/directory permissions (750/640)
8. **SELinux Enforcing**: Full SELinux support with `:Z` labeling

---

## 🔒 Security Model

### System User

**User**: `oxidized`
**Group**: `oxidized`
**UID**: `2000`
**GID**: `2000`
**Home**: `/home/oxidized`
**Shell**: `/usr/sbin/nologin` (no interactive login)

This dedicated user owns all Oxidized data and runs the container process.

### Container Security

```ini
# From Quadlet configuration
User=2000:2000                    # Run as oxidized user
ReadOnly=true                     # Immutable root filesystem
DropCapability=ALL                # Remove all capabilities
NoNewPrivileges=true              # Prevent privilege escalation
Network=oxidized-net              # Isolated bridge network
```

### Filesystem Security

| Location | Purpose | Permissions | Owner |
|----------|---------|-------------|-------|
| `/var/lib/oxidized` | Root data directory | 750 (rwxr-x---) | 2000:2000 |
| `/var/lib/oxidized/config` | Configuration files | 750 | 2000:2000 |
| `/var/lib/oxidized/ssh` | SSH keys | 700 (rwx------) | 2000:2000 |
| `/var/lib/oxidized/data` | Runtime data | 750 | 2000:2000 |
| `/var/lib/oxidized/output` | Backup output | 750 | 2000:2000 |
| `/var/lib/oxidized/repo` | Git repository | 750 | 2000:2000 |

**File Permissions**:
- Regular files: 640 (rw-r-----)
- SSH private keys: 600 (rw-------)
- SSH public keys/known_hosts: 644 (rw-r--r--)

---

## 📂 Directory Structure

```text
/var/lib/oxidized/              # Root (owned by oxidized:oxidized)
├── config/                     # Configuration
│   ├── config                  # Main config file
│   └── router.db               # Device database (CSV)
├── ssh/                        # SSH keys (mode 700)
│   ├── id_rsa                  # Private key (mode 600)
│   ├── id_rsa.pub              # Public key (mode 644)
│   └── known_hosts             # Known hosts (mode 644)
├── data/                       # Runtime data
│   ├── oxidized.log            # Log file
│   ├── oxidized.pid            # PID file
│   └── crashes/                # Crash dumps
├── output/                     # Backup output (if used)
└── repo/                       # Git repository
    ├── .git/                   # Git metadata
    └── (device configs)        # Backed up configurations
```

---

## 🔌 Container Mounts

| Host Path | Container Path | Mode | SELinux |
|-----------|----------------|------|---------|
| `/var/lib/oxidized/config` | `/home/oxidized/.config/oxidized` | rw | :Z |
| `/var/lib/oxidized/ssh` | `/home/oxidized/.ssh` | ro | :Z |
| `/var/lib/oxidized/data` | `/home/oxidized/.config/oxidized/data` | rw | :Z |
| `/var/lib/oxidized/output` | `/home/oxidized/.config/oxidized/output` | rw | :Z |
| `/var/lib/oxidized/repo` | `/home/oxidized/.config/oxidized/repo` | rw | :Z |

**SELinux `:Z` Flag**: Exclusive container access, automatically relabels files

---

## 🔐 Oxidized Security Configuration

The deployment includes built-in security features in the Oxidized configuration:

### Secret Removal

**Configuration**: `vars.remove_secret: true`

Automatically strips sensitive data from backed-up configurations before storing them in Git:

- SNMP community strings
- Device passwords
- Pre-shared keys
- Authentication credentials
- API tokens
- Other sensitive data defined in device models

**Benefits**:
- Prevents accidental exposure of secrets in Git repository
- Safer to share configurations for troubleshooting
- Reduces risk if backup repository is compromised
- Compliant with security policies requiring secret rotation

**Trade-off**: Stored configurations are not complete and cannot be used directly for device restoration without manually re-adding secrets.

**Reference**: [Oxidized Configuration Documentation - Removing Secrets](https://github.com/ytti/oxidized/blob/master/docs/Configuration.md#removing-secrets)

### DNS Resolution Disabled

**Configuration**: `resolve_dns: false`

Disables DNS lookups for device IP addresses:

**Benefits**:
- Avoids DNS-based attacks and poisoning
- Prevents delays from DNS timeouts
- More predictable behavior with IP addresses
- Works in environments without DNS
- Reduces external dependencies

**Best Practice**: Use IP addresses in `router.db` instead of hostnames for maximum reliability and security.

---

## 🌐 Network Security

### Podman Network

- **Name**: `oxidized-net`
- **Type**: bridge
- **Isolation**: Container-only network
- **Host Networking**: Not used (unnecessary)

### Port Exposure

Oxidized initiates outbound connections to network devices:
- **Outbound**: SSH (22), Telnet (23) to devices
- **Inbound**: None required for basic operation
- **Optional**: Port 8888 for REST API/Web UI (disabled by default)

**Note**: With non-root container and read-only rootfs, binding to ports <1024
requires additional configuration. Port 8888 works without privileges.

---

## 🔐 Privilege Model

### What Oxidized CANNOT Do

- ❌ Run as root inside container
- ❌ Modify container rootfs
- ❌ Escalate privileges
- ❌ Use any Linux capabilities
- ❌ Access other containers
- ❌ Modify host system
- ❌ Bind to privileged ports (<1024)

### What Oxidized CAN Do

- ✅ Read/write to mounted volumes (owned by UID 2000)
- ✅ Make outbound SSH/Telnet connections
- ✅ Write to tmpfs (/tmp, /run)
- ✅ Create files in data directories
- ✅ Run Git operations in repo
- ✅ Listen on port 8888 (if enabled)

---

## 🚫 Attack Surface Reduction

### Defense Layers

#### 1. User Isolation

- Dedicated system user with no shell access
- Cannot sudo or authenticate interactively
- Limited to UID 2000 permissions

#### 2. Container Isolation

- Non-root container process
- Read-only root filesystem prevents tampering
- Dropped capabilities prevent kernel exploits

#### 3. Filesystem Isolation

- Strict permissions (750/640/600)
- SELinux mandatory access control
- Only necessary paths mounted

#### 4. Network Isolation

- Dedicated bridge network
- No host networking
- No privileged ports

#### 5. Process Isolation

- `NoNewPrivileges` prevents setuid escalation
- Container cannot affect other containers
- systemd provides additional isolation

---

## 🔍 Security Verification

### Check User Configuration

```bash
# Verify user exists with correct UID/GID
id oxidized
# Expected: uid=2000(oxidized) gid=2000(oxidized) groups=2000(oxidized)

# Verify no shell access
grep oxidized /etc/passwd
# Expected: oxidized:x:2000:2000:...:/usr/sbin/nologin
```

### Check File Permissions

```bash
# Check directory ownership
ls -ld /var/lib/oxidized
# Expected: drwxr-x--- ... oxidized oxidized ... /var/lib/oxidized

# Check SSH directory permissions
ls -ld /var/lib/oxidized/ssh
# Expected: drwx------ ... oxidized oxidized ... /var/lib/oxidized/ssh

# Check file permissions
ls -l /var/lib/oxidized/config/
# Expected: -rw-r----- ... oxidized oxidized ... config
```

### Check Container Security

```bash
# Check container user
podman inspect oxidized | jq '.[0].Config.User'
# Expected: "2000:2000"

# Check read-only rootfs
podman inspect oxidized | jq '.[0].HostConfig.ReadonlyRootfs'
# Expected: true

# Check capabilities
podman inspect oxidized | jq '.[0].HostConfig.CapDrop'
# Expected: ["ALL"]

# Check no-new-privileges
podman inspect oxidized | jq '.[0].HostConfig.SecurityOpt'
# Expected: includes "no-new-privileges"
```

### Check SELinux

```bash
# Check SELinux mode
getenforce
# Expected: Enforcing

# Check file contexts
ls -laZ /var/lib/oxidized
# Expected: container_file_t contexts

# Check for denials
ausearch -m avc -ts recent | grep oxidized
# Expected: No denials
```

---

## ⚠️ Security Considerations

### SSH Key Management

- Store SSH private keys in `/var/lib/oxidized/ssh/` with mode 600
- Mounted read-only (`:ro`) into container for safety
- Never commit private keys to Git
- Rotate keys periodically
- Use separate key per Oxidized instance

### Credential Management

- Default: Plaintext in `config` file (protected by file permissions)
- Better: Use environment variables in Quadlet
- Best: Use external secrets manager

**Environment Variable Example**:

```ini
# In Quadlet file
Environment=OXIDIZED_USERNAME=admin
Environment=OXIDIZED_PASSWORD=secret
```

### Environment Configuration (.env)

**⚠️ CRITICAL**: The `.env` file contains sensitive credentials

**Security Requirements**:

- File permissions: `600` (owner read/write only)
- Never commit `.env` to Git (already in `.gitignore`)
- Store securely: consider encrypted backups
- Change default passwords immediately
- Use strong, unique passwords

**Validation**:

```bash
# Check permissions
ls -la .env
# Should show: -rw-------

# Validate configuration
./scripts/validate-env.sh
```

**Best Practices**:
- Use a secrets manager (Vault, AWS Secrets Manager) for production
- Rotate credentials regularly
- Use SSH keys instead of passwords when possible
- Limit who has access to `.env` file

### Network Device Access

- Oxidized needs SSH/Telnet access to devices
- Use least-privilege accounts on devices
- Configure credentials in `.env` file
- Consider using SSH keys instead of passwords
- Implement device-side access controls (ACLs)
- Log Oxidized's connections on devices

### Git Repository Security

- Contains device configurations (sensitive)
- Owned by oxidized:oxidized
- Mode 750 prevents unauthorized read
- Consider encrypting at rest
- Audit access to `/var/lib/oxidized/repo`

---

## 🔧 Changing UID/GID

If UID/GID 2000 conflicts with existing users:

### 1. Choose new UID/GID

Choose a new UID/GID (e.g., 3000)

### 2. Update `.env` file

```bash
# Edit .env
OXIDIZED_UID=3000
OXIDIZED_GID=3000
```

### 3. Validate configuration

```bash
./scripts/validate-env.sh
```

### 4. Re-run deployment

Generates Quadlet with new UID/GID:

```bash
# Stop service
sudo systemctl stop oxidized.service

# Change ownership
sudo chown -R 3000:3000 /var/lib/oxidized

# Update user/group
sudo usermod -u 3000 oxidized
sudo groupmod -g 3000 oxidized

# Restart service
sudo systemctl start oxidized.service
```

---

## 📊 Security vs. Functionality Trade-offs

| Security Feature | Impact | Mitigation |
|------------------|--------|------------|
| Read-only rootfs | Some tools may fail | Use tmpfs for /tmp, /run |
| Dropped capabilities | Cannot bind to ports <1024 | Use port 8888 (>1024) |
| Non-root user | Cannot write to root-owned paths | Mount only owned directories |
| No new privileges | Cannot use setuid binaries | Not needed for Oxidized |
| Network isolation | Cannot access host services | Use bridge network |

---

## 🆘 Troubleshooting Permission Errors

### Container won't start

```bash
# Check logs
podman logs oxidized

# Common issues:
# - File ownership: chown -R 2000:2000 /var/lib/oxidized
# - Directory permissions: chmod 750 /var/lib/oxidized
# - SELinux: restorecon -R /var/lib/oxidized
```

### Cannot write to mounted volumes

```bash
# Verify ownership
ls -ln /var/lib/oxidized
# Should show UID/GID 2000

# Fix if needed
sudo chown -R 2000:2000 /var/lib/oxidized
```

### SSH keys not working

```bash
# Check SSH directory permissions
ls -ld /var/lib/oxidized/ssh
# Should be: drwx------ ... oxidized oxidized

# Check private key permissions
ls -l /var/lib/oxidized/ssh/id_rsa
# Should be: -rw------- ... oxidized oxidized

# Fix if needed
sudo chmod 700 /var/lib/oxidized/ssh
sudo chmod 600 /var/lib/oxidized/ssh/id_rsa
```

### SELinux denials

```bash
# Check for denials
sudo ausearch -m avc -ts recent

# Temporarily set permissive (testing only!)
sudo setenforce 0

# If it works, re-label files
sudo restorecon -Rv /var/lib/oxidized

# Re-enable enforcing
sudo setenforce 1
```

---

## 📚 References

- [Podman Security](https://docs.podman.io/en/latest/markdown/podman-run.1.html#security-opt)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [SELinux for Containers](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html/container_security_guide/linux_capabilities_and_seccomp)
- [Oxidized Documentation](https://github.com/yggdrasil-network/oxidized)

---

**Security is a process, not a product. Regularly review and audit your deployment.**
