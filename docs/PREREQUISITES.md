# 📋 Prerequisites

This document lists all software prerequisites required to deploy containerized Oxidized on RHEL 10.

---

## 🎯 Target Environment

- **Operating System**: RHEL 10 (primary), RHEL 9 (secondary)
- **Container Runtime**: Podman (rootful mode)
- **Init System**: systemd with Quadlet support
- **SELinux**: Enforcing mode
- **Architecture**: x86_64
- **Network**: Internal LAN with access to network devices

---

## ✅ Required Packages

### Core Requirements

The following packages **must** be installed on the host system:

| Package | Purpose | Verification Command |
|---------|---------|---------------------|
| **podman** | Container runtime | `podman --version` |
| **policycoreutils-python-utils** | SELinux management tools | `semanage --help` |
| **git** | Git repository for config backups | `git --version` |
| **logrotate** | Log rotation management | `logrotate --version` |
| **curl** | API health checks and monitoring | `curl --version` |
| **jq** | JSON parsing for API responses | `jq --version` |

### Installation Command

Install all required packages with a single command:

```bash
sudo dnf install -y \
  podman \
  policycoreutils-python-utils \
  git \
  logrotate \
  curl \
  jq
```

---

## 🔧 Optional Packages

These packages are **recommended** but not strictly required:

| Package | Purpose | Notes |
|---------|---------|-------|
| **firewalld** | Firewall management | Required if restricting access to port 8888 |
| **rsync** | Backup synchronization | Useful for off-site backup copies |
| **vim** | Text editor | For editing configuration files |
| **tmux** | Terminal multiplexer | For managing long-running sessions |
| **net-tools** | Network utilities | For troubleshooting (`netstat`, `ifconfig`) |
| **bind-utils** | DNS utilities | For network troubleshooting (`dig`, `nslookup`) |

### Installation Command (Optional)

```bash
sudo dnf install -y \
  firewalld \
  rsync \
  vim \
  tmux \
  net-tools \
  bind-utils
```

---

## 🔍 System Requirements Verification

### Minimum System Specifications

For **~100 devices** with **hourly polling**:

- **CPU**: 2 cores
- **RAM**: 2 GB (4 GB recommended)
- **Disk**: 10 GB free space in `/var/lib/oxidized` (configurable via `.env`)
- **Network**: Stable connectivity to network devices

### Pre-Installation Checklist

Run these commands to verify your system meets the requirements:

```bash
# Check OS version
cat /etc/redhat-release

# Verify Podman is installed and working
podman --version
podman ps

# Check SELinux status (must be Enforcing)
getenforce

# Verify disk space
df -h /srv

# Check systemd version (Quadlet requires systemd >= 247)
systemctl --version

# Verify network connectivity
ping -c 3 8.8.8.8
```

---

## 🛡️ SELinux Configuration

### SELinux Status

SELinux **must** be in **Enforcing** mode. This deployment is designed to work with SELinux enforcing.

```bash
# Check current SELinux status
getenforce
# Expected output: Enforcing

# If SELinux is permissive or disabled, enable it
sudo setenforce 1
```

### Persistent SELinux Enforcement

Ensure SELinux remains enforcing after reboot:

```bash
# Edit SELinux config
sudo vim /etc/selinux/config

# Set SELINUX=enforcing
SELINUX=enforcing
```

### SELinux Context

The Quadlet configuration applies SELinux context automatically using `:Z` volume flags.
No manual `chcon` or `semanage` commands are required.

---

## 🔥 Firewall Configuration

### Port Requirements

Oxidized requires the following port to be accessible:

| Port | Protocol | Purpose | Access Level |
|------|----------|---------|--------------|
| **8888** | TCP | Web UI / REST API | Internal network only |

### Firewalld Configuration

If using `firewalld`, open the required port:

```bash
# Open port 8888 for internal zone
sudo firewall-cmd --zone=internal --add-port=8888/tcp --permanent

# Reload firewall rules
sudo firewall-cmd --reload

# Verify port is open
sudo firewall-cmd --zone=internal --list-ports
```

**Security Note**: Do **not** expose port 8888 to the public internet. Restrict access to your internal management network.

---

## 📦 Container Image Requirements

### Image Source

- **Registry**: docker.io
- **Repository**: oxidized/oxidized
- **Version**: Pinned to stable release (e.g., `0.30.1`)
- **Tag Format**: `docker.io/oxidized/oxidized:0.30.1`

### Image Pull

The container image will be automatically pulled by Podman when the service starts. To pre-pull the image:

```bash
podman pull docker.io/oxidized/oxidized:0.30.1
```

---

## 🔐 User and Permissions

### Root vs Rootless

This deployment uses **rootful Podman** to:
- Bind to privileged port 8888
- Ensure reliable systemd integration
- Simplify SELinux context management

### File System Permissions

The host directories (`/srv/oxidized/*`) should be owned by `root:root` with appropriate permissions.
The container runs as UID 30000 inside, but SELinux context (`:Z`) ensures proper access.

---

## ✅ Verification Commands

After installing prerequisites, verify everything is ready:

```bash
# System checks
cat /etc/redhat-release          # Verify RHEL 10
getenforce                        # Should show: Enforcing
systemctl --version               # Should be >= 247

# Package checks
podman --version                  # Should show Podman 4.x+
git --version                     # Should show Git 2.x+
curl --version                    # Should be available
jq --version                      # Should be available
logrotate --version               # Should be available

# Directory checks
sudo mkdir -p /srv/oxidized
df -h /srv                        # Verify disk space

# Network checks
ping -c 3 docker.io               # Verify internet connectivity
```

---

## 🚨 Common Issues

### Issue: Podman not found

**Solution**: Install Podman from RHEL repositories

```bash
sudo dnf install -y podman
```

### Issue: SELinux is disabled or permissive

**Solution**: Enable SELinux enforcing mode

```bash
sudo setenforce 1
sudo vim /etc/selinux/config  # Set SELINUX=enforcing
```

### Issue: Insufficient disk space

**Solution**: Clean up disk space or use a different mount point

```bash
# Clean Podman cache
podman system prune -a

# Or mount /srv/oxidized on a separate volume
```

### Issue: Systemd doesn't support Quadlets

**Solution**: Upgrade systemd to version 247 or later

```bash
sudo dnf update systemd
```

---

## 📚 Next Steps

Once all prerequisites are installed and verified:

1. ✅ Proceed to **[INSTALL.md](INSTALL.md)** for deployment steps
2. 📖 Review **[docs/requirements.md](requirements.md)** for design specifications
3. 🔍 Check **[docs/monitoring/ZABBIX.md](monitoring/ZABBIX.md)** for monitoring setup

---

## 📝 Summary Checklist

- [ ] RHEL 10 (or RHEL 9) installed
- [ ] Podman installed and working
- [ ] SELinux in Enforcing mode
- [ ] Git, curl, jq, logrotate installed
- [ ] Firewalld configured (if used)
- [ ] At least 10 GB free space in `/srv`
- [ ] Network connectivity to devices verified
- [ ] Systemd version >= 247

**Ready?** → Continue to [INSTALL.md](INSTALL.md) 🚀
