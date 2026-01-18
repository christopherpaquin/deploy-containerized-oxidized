# Firewall Configuration Implementation

## Overview

Automatic firewall configuration has been added to both deployment and uninstallation scripts to ensure port 8888 is properly accessible for the Oxidized API and Web UI.

## Problem Statement

### Issue Encountered

- **Symptom**: Connection refused on port 8888 even when service was running
- **Command**: `telnet 10.1.10.55 8888` returned "Connection refused"
- **Root Cause**: firewalld on RHEL 10 was blocking port 8888
- **Verification**: `firewall-cmd --list-ports` showed no ports allowed

### Why This Matters

On RHEL 10 (and similar distributions), firewalld is enabled by default and blocks all ports except explicitly allowed services. Without firewall configuration:

- Service runs normally (systemd shows active)
- Container is healthy (podman shows running)
- Port is listening (`ss -tlnp` shows 0.0.0.0:8888)
- **BUT** firewall drops all incoming packets to port 8888
- Result: Connection refused for external clients

## Implementation Details

### 1. Deploy Script (`scripts/deploy.sh`)

#### New Function: `configure_firewall()`

**Location**: Added before `start_service()` function
**Execution**: Called after `pull_image` and before `start_service` in main()

**Function Code**:
```bash
configure_firewall() {
  log_step "Configuring Firewall"

  # Check if firewalld is installed and running
  if ! command -v firewall-cmd &> /dev/null; then
    log_info "firewalld not installed, skipping firewall configuration"
    return
  fi

  if ! systemctl is-active --quiet firewalld 2> /dev/null; then
    log_info "firewalld not running, skipping firewall configuration"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would add firewall rule for port ${OXIDIZED_API_PORT}/tcp"
    return
  fi

  # Check if port is already allowed
  if firewall-cmd --list-ports 2>/dev/null | grep -q "${OXIDIZED_API_PORT}/tcp"; then
    log_info "Port ${OXIDIZED_API_PORT}/tcp already allowed in firewall"
    return
  fi

  # Add port to firewall
  log_info "Adding port ${OXIDIZED_API_PORT}/tcp to firewall..."
  if firewall-cmd --permanent --add-port="${OXIDIZED_API_PORT}/tcp" &> /dev/null; then
    if firewall-cmd --reload &> /dev/null; then
      log_success "Added port ${OXIDIZED_API_PORT}/tcp to firewall (permanent)"
    else
      log_warn "Failed to reload firewall (non-fatal)"
    fi
  else
    log_warn "Failed to add port to firewall (non-fatal, may need manual configuration)"
  fi
}
```

#### Key Features:

1. **Smart Detection**:
   - Checks if `firewall-cmd` command exists
   - Verifies firewalld service is active
   - Skips gracefully if firewalld not present

2. **Idempotent**:
   - Checks if port already allowed before adding
   - Safe to run multiple times

3. **Non-Fatal**:
   - Warnings instead of errors if firewall config fails
   - Deployment continues even if firewall setup fails
   - Allows manual firewall configuration

4. **Dry-Run Support**:
   - Shows what would be done without making changes

5. **Port Configurable**:
   - Uses `${OXIDIZED_API_PORT}` from .env (default: 8888)

### 2. Uninstall Script (`scripts/uninstall.sh`)

#### New Function: `remove_firewall()`

**Location**: Added after `remove_logrotate()` function
**Execution**: Called after `remove_logrotate` and before `remove_data` in main()

**Function Code**:
```bash
remove_firewall() {
  log_step "Removing firewall configuration"

  # Check if firewalld is installed and running
  if ! command -v firewall-cmd &> /dev/null; then
    log_info "firewalld not installed, skipping firewall cleanup"
    return
  fi

  if ! systemctl is-active --quiet firewalld 2> /dev/null; then
    log_info "firewalld not running, skipping firewall cleanup"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove firewall rule for port ${OXIDIZED_API_PORT:-8888}/tcp"
    return
  fi

  local port="${OXIDIZED_API_PORT:-8888}"

  # Check if port is in firewall
  if firewall-cmd --list-ports 2>/dev/null | grep -q "${port}/tcp"; then
    log_info "Removing port ${port}/tcp from firewall..."
    if firewall-cmd --permanent --remove-port="${port}/tcp" &> /dev/null; then
      if firewall-cmd --reload &> /dev/null; then
        log_success "Removed port ${port}/tcp from firewall"
      else
        log_warn "Failed to reload firewall (non-fatal)"
      fi
    else
      log_warn "Failed to remove port from firewall (non-fatal)"
    fi
  else
    log_info "Port ${port}/tcp not found in firewall"
  fi
}
```

#### Key Features:

1. **Clean Uninstallation**:
   - Removes firewall rule during uninstall
   - No leftover firewall configurations

2. **Non-Fatal Cleanup**:
   - Won't stop uninstall if firewall removal fails
   - Appropriate for systems where firewall was manually configured

3. **Graceful Handling**:
   - Checks if port exists before attempting removal
   - Doesn't error if port not found

## Testing and Verification

### Test Cycle Performed

1. **Initial State**: Firewall blocking port 8888
2. **Deploy**: Added port 8888/tcp to firewall
3. **Verification**: Confirmed port allowed
4. **Uninstall**: Removed port 8888/tcp from firewall
5. **Verification**: Confirmed port removed
6. **Redeploy**: Successfully added port again

### Verification Commands

```bash

# Check firewall status

firewall-cmd --list-ports

# Check service status

systemctl is-active firewalld

# Check port listening

ss -tlnp | grep 8888

# Test connection (with devices in inventory)

curl http://10.1.10.55:8888/nodes.json
telnet 10.1.10.55 8888
```

### Expected Behavior

#### With firewalld active and port configured:

✅ `firewall-cmd --list-ports` shows `8888/tcp`
✅ `ss -tlnp` shows port listening
✅ `telnet 10.1.10.55 8888` connects successfully (if API running)

#### With firewalld not installed/not running:

✅ Scripts skip firewall configuration
✅ Deployment succeeds normally
✅ Port accessible (no firewall blocking)

## Important Notes

### Empty Inventory Behavior

Even with the firewall properly configured, you may still see "Connection refused" if the device inventory is empty. This is **normal Oxidized behavior**:

**Why**: Oxidized's Puma web server (API/Web UI) only starts when there are valid devices in `router.db`. Without devices:

- Service runs normally (systemd active)
- Container is healthy (podman running)
- Port appears to be listening (conmon process)
- **BUT Puma hasn't started**, so connections are refused
- Container logs show: "source returns no usable nodes"

**Solution**: Add devices to `/var/lib/oxidized/config/router.db` and restart the service:
```bash
sudo vim /var/lib/oxidized/config/router.db
sudo systemctl restart oxidized.service

# Wait ~10 seconds for Puma to start

curl http://10.1.10.55:8888/nodes.json
```

### Firewall vs API Issues

| Symptom | Firewall Issue | Empty Inventory |
|---------|---------------|-----------------|
| `firewall-cmd --list-ports` | ❌ No 8888/tcp | ✅ Shows 8888/tcp |
| Container logs | ✅ Normal | "source returns no usable nodes" |
| `ss -tlnp` shows 8888 | ✅ Yes | ✅ Yes |
| `telnet localhost 8888` | ✅ Connects | ❌ Refused |
| `telnet 10.1.10.55 8888` | ❌ Refused | ❌ Refused |
| Fix | Add firewall rule | Add devices to router.db |

## Design Decisions

### Why Non-Fatal?

Firewall configuration is non-fatal because:

1. **Manual Configuration**: Users may want to configure firewall manually
2. **Different Tools**: Some systems use `ufw`, `iptables`, or other firewall tools
3. **Security Policies**: Corporate environments may have strict firewall policies
4. **Deployment Success**: Service can still work on localhost or with firewall disabled

### Why Permanent Rules?

Using `--permanent` ensures:

- Rules persist across firewalld restarts
- Rules persist across system reboots
- Consistent behavior after maintenance

### Why Check for firewalld?

The scripts check for firewalld because:

- Not all Linux distributions use firewalld
- firewalld may be disabled in favor of other tools
- Docker/container hosts often disable firewalls
- Avoids errors on minimal installations

## Files Modified

### `/root/deploy-containerized-oxidized/scripts/deploy.sh`

- Added `configure_firewall()` function (42 lines)
- Added function call in `main()` execution flow
- Modified `verify_deployment()` to be non-fatal for API check

### `/root/deploy-containerized-oxidized/scripts/uninstall.sh`

- Added `remove_firewall()` function (33 lines)
- Added function call in `main()` execution flow

## Manual Firewall Configuration

If you prefer to configure the firewall manually:

### Add Rule

```bash
sudo firewall-cmd --permanent --add-port=8888/tcp
sudo firewall-cmd --reload
```

### Remove Rule

```bash
sudo firewall-cmd --permanent --remove-port=8888/tcp
sudo firewall-cmd --reload
```

### Verify

```bash
sudo firewall-cmd --list-ports
sudo firewall-cmd --list-all
```

## Troubleshooting

### Issue: Firewall configuration fails during deployment

**Symptoms**:

- Warning: "Failed to add port to firewall"
- Deployment continues but port not accessible

**Diagnosis**:
```bash

# Check firewalld status

systemctl status firewalld

# Check current zone

firewall-cmd --get-active-zones

# Check default zone

firewall-cmd --get-default-zone

# List all ports in current zone

firewall-cmd --list-all
```

**Solutions**:

1. Ensure firewalld is running: `sudo systemctl start firewalld`
2. Try manual configuration (see above)
3. Check SELinux: `sudo ausearch -m avc -ts recent`
4. Check permissions: Ensure running as root

### Issue: Port removed during uninstall but still accessible

**Explanation**: firewalld may be disabled or another firewall tool is in use

**Verification**:
```bash

# Check firewalld status

systemctl is-active firewalld

# Check iptables rules (if using iptables)

sudo iptables -L -n | grep 8888

# Check nftables (if using nftables)

sudo nft list ruleset | grep 8888
```

## Summary

✅ **Implemented**: Automatic firewall configuration
✅ **Tested**: Deploy/undeploy cycles with verification
✅ **Idempotent**: Safe to run multiple times
✅ **Robust**: Handles systems with/without firewalld
✅ **Non-Fatal**: Deployment succeeds even if firewall config fails
✅ **Documented**: Clear user messaging and documentation
✅ **Clean**: Uninstall removes firewall rules

The implementation provides a seamless experience for users on systems with firewalld while gracefully handling other configurations.
