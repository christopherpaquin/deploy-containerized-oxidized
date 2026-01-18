# Firewall Configuration Quick Reference

## What Was Fixed

**Problem**: Connection refused on port 8888
**Solution**: Automatic firewall configuration in deploy/uninstall scripts

## How It Works

### During Deployment
```bash
sudo ./scripts/deploy.sh
```
- Automatically adds port 8888/tcp to firewalld
- Skips if firewalld not installed/running
- Non-fatal (deployment succeeds even if firewall fails)

### During Uninstall
```bash
sudo ./scripts/uninstall.sh --force
```
- Automatically removes port 8888/tcp from firewalld
- Clean removal with no leftover rules

## Quick Commands

### Check Firewall Status
```bash
# Is firewalld running?
systemctl is-active firewalld

# What ports are allowed?
sudo firewall-cmd --list-ports

# Full firewall config
sudo firewall-cmd --list-all
```

### Manual Firewall Configuration
```bash
# Add port
sudo firewall-cmd --permanent --add-port=8888/tcp
sudo firewall-cmd --reload

# Remove port
sudo firewall-cmd --permanent --remove-port=8888/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

### Verify Service Access
```bash
# Check if port is listening
sudo ss -tlnp | grep 8888

# Test from localhost
curl http://localhost:8888/nodes.json

# Test from network
curl http://10.1.10.55:8888/nodes.json
telnet 10.1.10.55 8888
```

## Troubleshooting

### Connection Refused After Deployment

**Check 1: Is firewall configured?**
```bash
sudo firewall-cmd --list-ports
# Should show: 8888/tcp
```
If NOT shown:
```bash
sudo firewall-cmd --permanent --add-port=8888/tcp
sudo firewall-cmd --reload
```

**Check 2: Is service running?**
```bash
sudo systemctl status oxidized.service
# Should be: active (running)
```

**Check 3: Are there devices in inventory?**
```bash
sudo cat /var/lib/oxidized/config/router.db | grep -v '^#' | grep -v '^$'
```
If empty, the API won't start (this is normal Oxidized behavior).

**Solution**: Add devices to router.db:
```bash
sudo vim /var/lib/oxidized/config/router.db
# Add: name:ip:model:group::
# Example: router1:192.168.1.1:ios:core::
sudo systemctl restart oxidized.service
# Wait 10 seconds
curl http://10.1.10.55:8888/nodes.json
```

### Firewall vs Empty Inventory

| Symptom | Firewall Issue | Empty Inventory |
|---------|----------------|-----------------|
| `firewall-cmd --list-ports` | ❌ No 8888/tcp | ✅ Shows 8888/tcp |
| Container logs | ✅ Normal | "source returns no usable nodes" |
| `telnet localhost 8888` | ✅ Connects | ❌ Refused |
| `telnet 10.1.10.55 8888` | ❌ Refused | ❌ Refused |
| **Fix** | **Add firewall rule** | **Add devices to router.db** |

## Common Scenarios

### New Deployment
```bash
# 1. Deploy (firewall automatically configured)
sudo ./scripts/deploy.sh

# 2. Add devices
sudo vim /var/lib/oxidized/config/router.db

# 3. Restart
sudo systemctl restart oxidized.service

# 4. Test
curl http://10.1.10.55:8888/nodes.json
```

### Redeployment
```bash
# Idempotent - safe to run multiple times
sudo ./scripts/deploy.sh
# Won't re-add firewall rule if already present
```

### Clean Uninstall
```bash
# Removes service, container, and firewall rule
sudo ./scripts/uninstall.sh --force
```

### Check Deployment Health
```bash
# Comprehensive health check
sudo ./scripts/health-check.sh

# Shows:
# - Service status
# - Container status
# - API status
# - Firewall configuration
# - Network listeners
# - Access URLs
```

## Files Modified

- `scripts/deploy.sh` - Added `configure_firewall()` function
- `scripts/uninstall.sh` - Added `remove_firewall()` function
- `DEPLOYMENT-NOTES.md` - Documented changes
- `FIREWALL-IMPLEMENTATION.md` - Comprehensive guide
- `README.md` - Added firewall documentation reference

## Key Points

✅ **Automatic**: Firewall configured during deployment
✅ **Clean**: Firewall cleaned during uninstall
✅ **Idempotent**: Safe to run multiple times
✅ **Robust**: Handles systems with/without firewalld
✅ **Non-Fatal**: Deployment succeeds even if firewall fails
✅ **Documented**: Clear messages and comprehensive docs

## More Information

- Full documentation: `FIREWALL-IMPLEMENTATION.md`
- Deployment notes: `DEPLOYMENT-NOTES.md`
- Run health check: `sudo ./scripts/health-check.sh`
