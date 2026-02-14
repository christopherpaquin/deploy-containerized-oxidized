# UID Migration to 30000 - Complete Guide

## Why This Change Was Made

### The Problem

The Oxidized container uses a built-in `oxidized` user with **UID 30000** internally. Previously, the deployment created a host `oxidized` user with **UID 2000**. This mismatch caused several issues:

1. **File Ownership Complexity**
   - Container wrote files as UID 30000
   - Host needed to access files as UID 2000
   - Required complex permission workarounds

2. **Script Execution Issues**
   - `sudo -u oxidized` on the host ran as UID 2000
   - Container expected UID 30000
   - Needed `setpriv` or `sudo -u "#30000"` workarounds

3. **Permission Confusion**
   - `ls -l` showed `30000:30000` (container ownership)
   - Scripts needed to handle both UIDs
   - Error messages unclear about which UID was failing

### The Solution

**Align the host `oxidized` user UID with the container's UID (30000).**

### Benefits

✅ **Simplified File Ownership** - All files consistently owned by 30000:30000
✅ **Direct Script Execution** - `sudo -u oxidized` works directly
✅ **Clear Permissions** - Single UID throughout the system
✅ **Reduced Complexity** - No UID mapping workarounds needed
✅ **Better Errors** - Clear ownership in error messages

## Migration Process

### Automatic Migration

The `deploy.sh` script **automatically detects and migrates** existing installations:

1. **Detection**
   - Checks if `oxidized` user exists with UID 2000
   - Compares with target UID 30000 from `.env`

2. **Pre-Migration Safety**
   - Stops `oxidized.service` gracefully
   - Stops `oxidized-logger.service`
   - Waits for clean shutdown

3. **UID/GID Change**
   - Uses `usermod -u 30000 oxidized`
   - Uses `groupmod -g 30000 oxidized`
   - Updates system user database

4. **File Ownership Update**
   - Finds all files owned by old UID (2000)
   - Recursively updates under `/var/lib/oxidized/`
   - Preserves all permissions and timestamps

5. **Verification**
   - Confirms new UID/GID
   - Restarts services
   - Validates API connectivity

### Manual Migration (Not Recommended)

If you need to migrate manually:

```bash
# 1. Stop services
sudo systemctl stop oxidized.service oxidized-logger.service

# 2. Change user/group ID
sudo usermod -u 30000 oxidized
sudo groupmod -g 30000 oxidized

# 3. Update file ownership
sudo find /var/lib/oxidized/ -user 2000 -exec chown 30000:30000 {} +
sudo find /var/lib/oxidized/ -group 2000 -exec chown 30000:30000 {} +

# 4. Restart services
sudo systemctl start oxidized.service oxidized-logger.service
```

**Note**: The automated migration in `deploy.sh` is safer and more thorough.

## Verification

### Check User UID

```bash
id oxidized
# Expected output: uid=30000(oxidized) gid=30000(oxidized) groups=30000(oxidized)
```

### Check Directory Ownership

```bash
ls -ldn /var/lib/oxidized/
# Expected: 30000 30000 ... /var/lib/oxidized/

ls -ldn /var/lib/oxidized/repo
# Expected: 30000 30000 ... /var/lib/oxidized/repo

ls -ldn /var/lib/oxidized/config
# Expected: 30000 30000 ... /var/lib/oxidized/config
```

### Check File Ownership

```bash
# Check repository files
ls -ln /var/lib/oxidized/repo/

# Check config files
ls -ln /var/lib/oxidized/config/

# All should show 30000:30000
```

### Check Service Status

```bash
sudo systemctl status oxidized.service
# Should show: active (running)

sudo systemctl status oxidized-logger.service
# Should show: active (running)
```

### Check API Connectivity

```bash
curl -s http://127.0.0.1:8888/nodes | jq
# Should return JSON list of devices
```

### Check Logs

```bash
sudo journalctl -u oxidized.service -n 50
# Should show successful startup, no UID errors
```

## Troubleshooting

### Issue: "sudo: unknown user #30000"

**Cause**: Host user still has old UID

**Solution**: Re-run migration
```bash
sudo ./scripts/deploy.sh
```

### Issue: "Permission denied" on files

**Cause**: Some files still owned by UID 2000

**Solution**: Update ownership manually
```bash
sudo chown -R 30000:30000 /var/lib/oxidized/
```

### Issue: Service won't start after migration

**Cause**: Stale PID file

**Solution**: Clean PID and restart
```bash
sudo rm -f /var/lib/oxidized/data/oxidized.pid
sudo systemctl restart oxidized.service
```

### Issue: Git operations fail

**Cause**: Repository ownership incorrect

**Solution**: Fix repo ownership
```bash
sudo chown -R 30000:30000 /var/lib/oxidized/repo/
sudo -u oxidized git -C /var/lib/oxidized/repo status
```

## Impact on Existing Systems

### Fresh Installations

- ✅ No impact
- UID 30000 used from the start
- `.env` already defaults to 30000

### Existing Installations

- ✅ Automatic migration during next `deploy.sh` run
- ⏱️ Migration takes ~10-30 seconds depending on file count
- 🔄 Services briefly stopped during migration
- ✅ All data preserved
- ✅ No configuration changes needed

### Scripts and Automation

**Before Migration:**
```bash
# Complex workaround needed
sudo setpriv --reuid=30000 --regid=30000 git -C /var/lib/oxidized/repo status
```

**After Migration:**
```bash
# Simple, direct execution
sudo -u oxidized git -C /var/lib/oxidized/repo status
```

## Configuration Changes

### .env File

**Before (old default):**
```bash
OXIDIZED_UID=2000
OXIDIZED_GID=2000
```

**After (new default):**
```bash
OXIDIZED_UID=30000  # Matches container's internal oxidized user
OXIDIZED_GID=30000
```

**Note**: Existing `.env` files are **not modified automatically**. The migration works regardless of the `.env` value, but it's recommended to update for clarity.

### No Other Changes Required

- ✅ Container configuration unchanged
- ✅ Quadlet file unchanged
- ✅ Volume mounts unchanged
- ✅ File permissions unchanged (still 644/755)
- ✅ Directory structure unchanged

## Benefits in Practice

### Example: Remote Repository Setup

**Before Migration** (complex):
```bash
# Had to detect UID from file ownership
OXIDIZED_UID=$(stat -c '%u' /var/lib/oxidized/repo)
# Then use setpriv
sudo setpriv --reuid=$OXIDIZED_UID git push
```

**After Migration** (simple):
```bash
# Direct user reference
sudo -u oxidized git push
```

### Example: SSH Key Generation

**Before Migration** (error-prone):
```bash
# Wrong UID used
sudo -u oxidized ssh-keygen  # Creates as UID 2000, container can't use!
```

**After Migration** (works correctly):
```bash
# Correct UID automatically
sudo -u oxidized ssh-keygen  # Creates as UID 30000, container uses it!
```

### Example: File Permissions

**Before Migration** (confusing):
```bash
ls -l /var/lib/oxidized/repo
# Shows: 30000 30000 (container ownership)
id oxidized
# Shows: uid=2000 (host ownership)
# Confusion: Which is correct?
```

**After Migration** (clear):
```bash
ls -l /var/lib/oxidized/repo
# Shows: 30000 30000
id oxidized
# Shows: uid=30000
# Clear: Both match!
```

## Timeline

- **2026-02-13**: UID migration implemented
- **Automatic**: Runs during next `deploy.sh` execution
- **Backwards Compatible**: No breaking changes

## Related Documentation

- [REMOTE_REPOSITORY.md](REMOTE_REPOSITORY.md) - Uses simplified UID approach
- [SERVICE-MANAGEMENT.md](SERVICE-MANAGEMENT.md) - Updated for UID 30000
- [DEPLOYMENT-NOTES.md](DEPLOYMENT-NOTES.md) - Migration details

## Summary

The UID migration from 2000 to 30000 is:

✅ **Automatic** - No manual intervention required
✅ **Safe** - Preserves all data and settings
✅ **Simple** - Runs during next deployment
✅ **Beneficial** - Eliminates complexity and confusion
✅ **Backwards Compatible** - Works with existing installations

The migration is automatic, safe, and provides immediate benefits.
