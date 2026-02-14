# Fresh Deployment Remote Repository Setup

## Problem

After running `uninstall.sh --remove-data --force` and then redeploying, if you run `setup-remote-repo.sh` to reconnect to your existing GitHub repository, device configuration files might show as "deleted" in git status.

## Root Cause

This happened in older versions of the script because:

1. **Uninstall** deleted `/var/lib/oxidized/` including the git repository
2. **Fresh Deploy** created a new empty repository with only `README.md`
3. **Remote Setup** (old behavior) would either:
   - Force-push the empty local repo, **overwriting GitHub** (deleting device configs)
   - Or fail to push due to divergent histories

## Solution (Automatic)

**As of version 2.0**, `setup-remote-repo.sh` automatically handles this:

1. **Detects** if remote branch already exists
2. **Fetches** remote history from GitHub
3. **Merges** remote history into local (preserves all device configs)
4. **Auto-resolves** README.md conflicts (keeps enhanced local version)
5. **Pushes** merged history back to GitHub

### What You'll See

```bash
$ sudo ./setup-remote-repo.sh

# ... SSH key setup ...

⚠ Remote branch 'main' already exists
ℹ Pulling existing history from remote to preserve device configs...
ℹ Merging remote history into local repository...
✓ Successfully merged remote history
✓ Restored 4 device configuration file(s) from remote
ℹ Pushing merged history to remote...
✓ Pushed to remote repository
```

### Restored Files

After the merge, your device configs will be automatically restored:

```bash
$ cd /var/lib/oxidized/repo
$ ls -R
.:
README.md  lab-switches/  vpn_servers/

./lab-switches:
s3560g-1  s3560g-2  SX3008F

./vpn_servers:
asav
```

## Manual Resolution (If Needed)

If auto-merge fails (rare), you'll see instructions to resolve manually:

```bash
cd /var/lib/oxidized/repo
git status  # See conflicted files
# Edit conflicts in affected files
git add .
git commit -m 'Resolved merge conflicts'
git push -u origin main
```

## Prevention

The updated script **prevents data loss** by:

- ✅ Never force-pushing by default
- ✅ Always fetching remote history first
- ✅ Merging remote into local (not overwriting)
- ✅ Auto-resolving README.md conflicts
- ✅ Counting and reporting restored device files

## Verification

After setup, verify everything is correct:

```bash
# Check files exist
cd /var/lib/oxidized/repo
ls -laR

# Check git status
git status
# Should show: "nothing to commit, working tree clean"

# Check GitHub
# Visit your repo URL - device configs should be there

# Trigger a backup
/var/lib/oxidized/scripts/force-backup.sh

# Watch for updates
sudo podman logs -f oxidized
```

## Upgrade Path

If you have an older version of the script:

```bash
# Pull latest changes
cd /root/deploy-containerized-oxidized
git pull

# Copy updated script
sudo cp scripts/setup-remote-repo.sh /var/lib/oxidized/scripts/

# Re-run if needed
sudo /var/lib/oxidized/scripts/setup-remote-repo.sh
```

## Key Takeaways

1. **New deployments are safe** - script automatically preserves existing device configs
2. **No manual intervention needed** - merge happens automatically
3. **Device history preserved** - all commits retained
4. **README enhanced** - local enhanced version kept, remote device configs restored

---

**Last Updated:** February 2026
**Script Version:** 2.0+
