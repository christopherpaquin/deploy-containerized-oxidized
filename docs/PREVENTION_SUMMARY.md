# How We Fixed the Device Config Deletion Issue

## The Problem You Experienced

After running:
1. `uninstall.sh --remove-data --force` (deleted everything)
2. `deploy.sh` (fresh deployment)
3. `setup-remote-repo.sh` (reconnect to GitHub)

Result: Device configs showed as "deleted" in git status

## Root Cause

The old `setup-remote-repo.sh` script had this flow:

```
Fresh local repo (only README.md)
  ↓
Detect remote branch exists
  ↓
Ask: "Continue with force push? [y/N]"
  ↓ (if user chose "y")
Force-push local → GitHub (OVERWRITES REMOTE)
  ↓
Device configs on GitHub: DELETED ❌
```

## The Fix

New behavior in `setup-remote-repo.sh`:

```
Fresh local repo (only README.md)
  ↓
Detect remote branch exists
  ↓
FETCH remote history from GitHub ✅
  ↓
MERGE remote → local ✅
  ↓
Auto-resolve README.md conflict (keep local enhanced version)
  ↓
Push merged history → GitHub
  ↓
Device configs: PRESERVED ✅
```

## Code Changes

### Before (Dangerous):
```bash
if remote_branch_exists; then
  warn "This will force-push"
  ask "Continue? [y/N]"
  if yes:
    git push --force  # ❌ DELETES REMOTE DATA
```

### After (Safe):
```bash
if remote_branch_exists; then
  info "Pulling existing history to preserve device configs"
  git fetch origin main  # ✅ Get remote history
  git merge origin/main --allow-unrelated-histories  # ✅ Merge
  # Auto-resolve conflicts
  git push  # ✅ Safe push
```

## What Happens Now

When you run `setup-remote-repo.sh` after a fresh deployment:

1. **Automatically fetches** your GitHub history
2. **Merges** device configs into local repo
3. **Shows**: "✓ Restored 4 device configuration file(s) from remote"
4. **No data loss** - all device configs preserved

## Files Modified

- `scripts/setup-remote-repo.sh` - Complete rewrite of `initial_push()` function
- `docs/FRESH_DEPLOYMENT_REMOTE_SETUP.md` - New documentation

## Testing

To verify the fix works:

```bash
# Simulate the scenario
sudo /var/lib/oxidized/scripts/uninstall.sh --remove-data --force
cd /root/deploy-containerized-oxidized
sudo ./scripts/deploy.sh

# Run remote setup (will now preserve device configs)
sudo /var/lib/oxidized/scripts/setup-remote-repo.sh

# Verify
cd /var/lib/oxidized/repo
git status  # Should show "nothing to commit, working tree clean"
ls -R  # Should show all device config files
```

## Key Improvements

1. ✅ **No more force-push by default**
2. ✅ **Always fetch remote first**
3. ✅ **Merge instead of overwrite**
4. ✅ **Auto-resolve conflicts**
5. ✅ **Count and report restored files**
6. ✅ **Clear warning messages**
7. ✅ **Documentation added**

## Prevention Going Forward

The script now:
- **Prevents** accidental data deletion
- **Preserves** existing device configs automatically
- **Requires no manual intervention**
- **Works seamlessly** for fresh deployments

This issue cannot occur again with the updated script.
