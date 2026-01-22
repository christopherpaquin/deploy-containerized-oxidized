# 🔄 Upgrade and Rollback Guide

This document provides procedures for upgrading Oxidized to a new version and rolling back if issues occur.

---

## 📋 Table of Contents

- [Upgrade Strategy](#-upgrade-strategy)
- [Pre-Upgrade Checklist](#-pre-upgrade-checklist)
- [Upgrade Procedure](#-upgrade-procedure)
- [Rollback Procedure](#-rollback-procedure)
- [Testing New Versions](#-testing-new-versions)
- [Version History](#-version-history)

---

## 🎯 Upgrade Strategy

### Version Pinning Philosophy

This deployment uses **pinned container image versions** to ensure:

- ✅ **Predictable behavior** - no surprise changes
- ✅ **Controlled upgrades** - manual, deliberate updates
- ✅ **Easy rollback** - revert to previous working version
- ✅ **Testing before production** - validate in non-prod first

### Current Version

The Quadlet file pins the Oxidized version:

```ini
Image=docker.io/oxidized/oxidized:0.35.0
```

### Upgrade Frequency

**Recommended Schedule**:
- **Security patches**: Within 7 days of release
- **Minor versions**: Every 3-6 months
- **Major versions**: Annually, after thorough testing

---

## ✅ Pre-Upgrade Checklist

Before upgrading, complete the following steps:

### 1. Check Available Versions

```bash
# List available tags on Docker Hub
curl -s https://registry.hub.docker.com/v2/repositories/oxidized/oxidized/tags \
  | jq -r '.results[].name' | sort -V | tail -20

# Or visit: https://hub.docker.com/r/oxidized/oxidized/tags
```

### 2. Review Release Notes

Check the Oxidized changelog for breaking changes:

- GitHub: <https://github.com/yggdrasil-network/oxidized/releases>
- Look for:
  - Configuration changes
  - Model updates
  - Deprecated features
  - New dependencies

### 3. Backup Current State

**Critical**: Always backup before upgrading!

```bash
# Create backup directory
sudo mkdir -p /var/backups/oxidized/$(date +%Y%m%d)

# Backup Git repository (adjust path if you customized OXIDIZED_ROOT in .env)
sudo tar -czf /var/backups/oxidized/$(date +%Y%m%d)/oxidized-git.tar.gz \
    -C /var/lib/oxidized repo/

# Backup configuration files
sudo tar -czf /var/backups/oxidized/$(date +%Y%m%d)/oxidized-config.tar.gz \
    -C /var/lib/oxidized config/

# Backup Quadlet file
sudo cp /etc/containers/systemd/oxidized.container \
    /var/backups/oxidized/$(date +%Y%m%d)/oxidized.container.backup

# Verify backups
ls -lh /var/backups/oxidized/$(date +%Y%m%d)/
```

### 4. Document Current State

```bash
# Record current version
podman inspect oxidized | jq -r '.[0].ImageName' > /tmp/oxidized-version-before.txt

# Record current service status
sudo systemctl status oxidized.service > /tmp/oxidized-status-before.txt

# Take note of last backup times
curl -s http://localhost:8888/nodes.json | jq '.' > /tmp/oxidized-nodes-before.json
```

### 5. Plan Maintenance Window

- ⏰ **Estimated downtime**: 5-10 minutes
- 📅 **Schedule**: Off-peak hours
- 👥 **Notify**: Inform team of maintenance window
- 📊 **Monitor**: Have monitoring tools ready

---

## 🚀 Upgrade Procedure

### Step 1: Pull New Image

```bash
# Determine target version (example: 0.36.0)
NEW_VERSION="0.36.0"

# Pull new image
sudo podman pull docker.io/oxidized/oxidized:${NEW_VERSION}

# Verify image
podman images | grep oxidized
```

### Step 2: Update Quadlet Configuration

```bash
# Edit Quadlet file
sudo vim /etc/containers/systemd/oxidized.container

# Update the Image line:
# FROM: Image=docker.io/oxidized/oxidized:0.35.0
# TO:   Image=docker.io/oxidized/oxidized:0.36.0
```

Or use `sed` for automation:

```bash
OLD_VERSION="0.35.0"
NEW_VERSION="0.36.0"

sudo sed -i "s|oxidized:${OLD_VERSION}|oxidized:${NEW_VERSION}|g" \
    /etc/containers/systemd/oxidized.container

# Verify change
grep "Image=" /etc/containers/systemd/oxidized.container
```

### Step 3: Reload Systemd

```bash
# Reload systemd to pick up Quadlet changes
sudo systemctl daemon-reload

# Verify service file was regenerated
sudo systemctl cat oxidized.service | grep ExecStart
```

### Step 4: Restart Service

```bash
# Stop current service
sudo systemctl stop oxidized.service

# Verify it's stopped
sudo systemctl status oxidized.service

# Start with new version
sudo systemctl start oxidized.service

# Check status
sudo systemctl status oxidized.service
```

### Step 5: Verify Upgrade

```bash
# Check running container version
podman inspect oxidized | jq -r '.[0].ImageName'

# Check container logs for errors
podman logs oxidized | tail -50

# Test API
curl -s http://localhost:8888/ && echo "API OK"

# Test node list
curl -s http://localhost:8888/nodes.json | jq '.[] | .name'

# Access Web UI
# Open browser: http://<server-ip>:8888
```

### Step 6: Monitor Initial Operations

```bash
# Watch logs in real-time
podman logs -f oxidized

# Wait for first backup cycle (up to 1 hour)
# Monitor for errors in logs

# Check Git commits (adjust path if you customized OXIDIZED_ROOT in .env)
cd /var/lib/oxidized/repo
sudo git log --oneline -10

# Verify node status
curl -s http://localhost:8888/nodes.json | jq '.[] | {name, status: .last.status}'
```

### Step 7: Document Upgrade

```bash
# Record new version
podman inspect oxidized | jq -r '.[0].ImageName' > /tmp/oxidized-version-after.txt

# Compare versions
diff /tmp/oxidized-version-before.txt /tmp/oxidized-version-after.txt

# Update version tracking (adjust path if you customized OXIDIZED_ROOT in .env)
echo "$(date): Upgraded from 0.30.1 to 0.31.0" | \
    sudo tee -a /var/lib/oxidized/UPGRADE_HISTORY.log
```

---

## ⏪ Rollback Procedure

If the upgrade fails or causes issues, rollback to the previous version:

### Quick Rollback

```bash
# Set previous version
OLD_VERSION="0.35.0"

# Update Quadlet back to old version
sudo sed -i "s|oxidized:.*|oxidized:${OLD_VERSION}|g" \
    /etc/containers/systemd/oxidized.container

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart oxidized.service

# Verify rollback
podman inspect oxidized | jq -r '.[0].ImageName'
sudo systemctl status oxidized.service
```

### Full Rollback with Config Restore

If configuration was also changed:

```bash
# Stop service
sudo systemctl stop oxidized.service

# Restore Quadlet file
sudo cp /var/backups/oxidized/$(date +%Y%m%d)/oxidized.container.backup \
    /etc/containers/systemd/oxidized.container

# Restore configuration (if needed - adjust path if you customized OXIDIZED_ROOT)
sudo tar -xzf /var/backups/oxidized/$(date +%Y%m%d)/oxidized-config.tar.gz \
    -C /var/lib/oxidized

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl start oxidized.service

# Verify
sudo systemctl status oxidized.service
podman logs oxidized
```

### Restore from Git Backup

If Git repository is corrupted:

```bash
# Stop service
sudo systemctl stop oxidized.service

# Restore Git repository (adjust paths if you customized OXIDIZED_ROOT in .env)
sudo rm -rf /var/lib/oxidized/repo
sudo tar -xzf /var/backups/oxidized/$(date +%Y%m%d)/oxidized-git.tar.gz \
    -C /var/lib/oxidized

# Restart service
sudo systemctl start oxidized.service
```

---

## 🧪 Testing New Versions

### Test in Non-Production

Before upgrading production, test in a separate environment:

```bash
# Create test directory (adjust path based on your OXIDIZED_ROOT from .env)
sudo mkdir -p /var/lib/oxidized-test

# Copy configuration
sudo cp -r /var/lib/oxidized/config /var/lib/oxidized-test/
sudo cp -r /var/lib/oxidized/ssh /var/lib/oxidized-test/

# Create test Quadlet
sudo cp /etc/containers/systemd/oxidized.container \
    /etc/containers/systemd/oxidized-test.container

# Modify test Quadlet:
# - Change container name to "oxidized-test"
# - Change port to 8889
# - Change volumes to /var/lib/oxidized-test/*
# - Use new version

# Start test instance
sudo systemctl daemon-reload
sudo systemctl start oxidized-test.service

# Test new version
curl http://localhost:8889/

# Clean up when done
sudo systemctl stop oxidized-test.service
sudo rm /etc/containers/systemd/oxidized-test.container
```

### Testing Checklist

- [ ] Service starts successfully
- [ ] API responds correctly
- [ ] Web UI loads
- [ ] Device backups work
- [ ] Git commits are created
- [ ] Logs are written
- [ ] No SELinux denials
- [ ] Resource usage is acceptable

---

## 📚 Version History

### Version 0.35.0 (Current)

- **Release Date**: 2025-12-04
- **Status**: Stable
- **Known Issues**: None
- **Deployed**: 2026-01-22

### Version 0.30.1 (Previous)

- **Release Date**: 2024-xx-xx
- **Status**: Superseded
- **Replaced by**: 0.35.0

### Version 0.36.0 (Example Future Version)

- **Release Date**: TBD
- **Status**: Not deployed
- **Breaking Changes**: TBD
- **Migration Notes**: TBD

### Upgrade Log

Keep a log of upgrades (adjust path if you customized OXIDIZED_ROOT in `.env`):

```bash
# Create upgrade log
sudo tee -a /var/lib/oxidized/UPGRADE_HISTORY.log <<EOF
$(date): Initial deployment - version 0.35.0
EOF

# After each upgrade, append:
# $(date): Upgraded from X.Y.Z to A.B.C - Reason: ...
```

---

## 🔍 Verifying Image Integrity

### Check Image Digest

```bash
# Get image digest
podman images --digests | grep oxidized

# Compare with Docker Hub
# Visit: https://hub.docker.com/r/oxidized/oxidized/tags
```

### Inspect Image Details

```bash
# View image metadata
podman inspect docker.io/oxidized/oxidized:0.35.0 | jq '.[0]'

# Check image layers
podman history docker.io/oxidized/oxidized:0.35.0

# Verify image architecture
podman inspect docker.io/oxidized/oxidized:0.35.0 | \
    jq -r '.[0].Architecture'
```

---

## 🚨 Common Upgrade Issues

### Issue: Service Won't Start After Upgrade

**Symptoms**: Service fails to start with new version

**Diagnosis**:

```bash
sudo journalctl -u oxidized.service -n 100
podman logs oxidized
```

**Solution**: Check for configuration incompatibilities, rollback if needed

### Issue: Configuration Format Changed

**Symptoms**: Errors about invalid configuration

**Solution**: Review release notes for configuration changes, update config file

### Issue: New Version Breaks Device Models

**Symptoms**: Devices that worked before now fail

**Solution**: Check Oxidized model updates, may need to specify different model in CSV

### Issue: Container Image Corrupted

**Symptoms**: Image pull fails or container crashes immediately

**Solution**:

```bash
# Remove corrupted image
podman rmi docker.io/oxidized/oxidized:0.36.0

# Re-pull image
podman pull docker.io/oxidized/oxidized:0.36.0

# Restart service
sudo systemctl restart oxidized.service
```

---

## 📝 Upgrade Automation (Optional)

### Automated Upgrade Script

**Note**: Use with caution! Always test thoroughly first.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Variables
OLD_VERSION="${1:-0.35.0}"
NEW_VERSION="${2:-0.36.0}"
BACKUP_DIR="/var/backups/oxidized/$(date +%Y%m%d_%H%M%S)"

echo "🔄 Upgrading Oxidized from ${OLD_VERSION} to ${NEW_VERSION}"

# Backup (adjust paths if you customized OXIDIZED_ROOT in .env)
echo "📦 Creating backup..."
mkdir -p "${BACKUP_DIR}"
tar -czf "${BACKUP_DIR}/oxidized-git.tar.gz" -C /var/lib/oxidized repo/
tar -czf "${BACKUP_DIR}/oxidized-config.tar.gz" -C /var/lib/oxidized config/
cp /etc/containers/systemd/oxidized.container "${BACKUP_DIR}/oxidized.container.backup"

# Pull new image
echo "⬇️  Pulling new image..."
podman pull docker.io/oxidized/oxidized:${NEW_VERSION}

# Update Quadlet
echo "📝 Updating Quadlet..."
sed -i "s|oxidized:${OLD_VERSION}|oxidized:${NEW_VERSION}|g" \
    /etc/containers/systemd/oxidized.container

# Restart service
echo "🔄 Restarting service..."
systemctl daemon-reload
systemctl restart oxidized.service

# Verify
echo "✅ Verifying upgrade..."
sleep 5
systemctl status oxidized.service
podman logs oxidized | tail -20

echo "🎉 Upgrade complete!"
echo "📚 Backup location: ${BACKUP_DIR}"
```

---

## 📚 Next Steps

- ✅ Upgrade complete!
- 📖 Monitor service for 24-48 hours
- 🔍 Review [monitoring/ZABBIX.md](monitoring/ZABBIX.md) for alerting
- 📋 Update documentation if configuration changed

---

## 🆘 Need Help?

- Oxidized Documentation: <https://github.com/yggdrasil-network/oxidized>
- Docker Hub: <https://hub.docker.com/r/oxidized/oxidized>
- GitHub Issues: <https://github.com/yggdrasil-network/oxidized/issues>

---

**Remember**: Always backup before upgrading! 💾
