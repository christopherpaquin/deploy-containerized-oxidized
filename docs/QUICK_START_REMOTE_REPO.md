# Quick Start: Remote Repository Setup

## TL;DR - Fast Setup

```bash
# 1. Create private repository on GitHub/GitLab
# 2. Run the setup script
cd /root/deploy-containerized-oxidized/scripts
sudo ./setup-remote-repo.sh

# Follow the prompts to configure remote URL and auto-push
```

## Step-by-Step: GitHub Private Repository

### 1. Create Private GitHub Repository

**Option A: Using GitHub CLI**
```bash
gh repo create oxidized-backups --private --description "Network device configuration backups"
```

**Option B: Using Web Interface**
1. Go to https://github.com/new
2. Repository name: `oxidized-backups`
3. ✅ **Check "Private"** (CRITICAL for security!)
4. Click "Create repository"

### 2. Setup SSH Authentication

```bash
# Generate SSH key for oxidized user
sudo mkdir -p /var/lib/oxidized/.ssh
sudo -u "#30000" ssh-keygen -t ed25519 -C "oxidized@$(hostname)" -f /var/lib/oxidized/.ssh/id_ed25519 -N ""

# Display public key
echo -e "\n📋 Copy this public key:\n"
sudo cat /var/lib/oxidized/.ssh/id_ed25519.pub
echo ""
```

**Add key to GitHub:**
1. Go to https://github.com/settings/keys
2. Click "New SSH key"
3. Title: `Oxidized Server - $(hostname)`
4. Paste the public key
5. Click "Add SSH key"

### 3. Run Setup Script

```bash
cd /root/deploy-containerized-oxidized/scripts
sudo ./setup-remote-repo.sh
```

**Example responses:**
```
Enter remote repository URL: git@github.com:yourusername/oxidized-backups.git
Remote name: origin
Branch name: main
Enable auto-push? [y/N]: y
```

### 4. Verify Setup

```bash
# Check remote is configured
cd /var/lib/oxidized/repo
git remote -v

# Should show:
# origin  git@github.com:yourusername/oxidized-backups.git (fetch)
# origin  git@github.com:yourusername/oxidized-backups.git (push)

# Check timer is running (if auto-push enabled)
systemctl status oxidized-git-push.timer

# View recent pushes
tail /var/lib/oxidized/data/git-push.log
```

### 5. Verify Repository is Private

**GitHub:**
```bash
gh repo view yourusername/oxidized-backups --json visibility
# Should show: "visibility": "PRIVATE"
```

**Or check manually:**
1. Go to https://github.com/yourusername/oxidized-backups/settings
2. Under "Danger Zone" → check visibility shows "Private"

## What Happens Now?

### With Auto-Push Enabled
- Every 5 minutes, new commits are pushed to remote
- Logs written to `/var/lib/oxidized/data/git-push.log`
- View timer: `systemctl status oxidized-git-push.timer`

### Without Auto-Push
- Manual push required: `cd /var/lib/oxidized/repo && git push`
- Or enable later: Re-run `setup-remote-repo.sh`

## Monitoring Commands

```bash
# View push log
tail -f /var/lib/oxidized/data/git-push.log

# Check timer status
systemctl status oxidized-git-push.timer

# Manually trigger push
systemctl start oxidized-git-push.service

# View remote commits
cd /var/lib/oxidized/repo
git log origin/main --oneline -10

# Check unpushed commits
git log origin/main..HEAD --oneline
```

## Troubleshooting

### "Permission denied (publickey)"

```bash
# Test SSH connection
sudo -u "#30000" ssh -T git@github.com

# If fails, check key permissions
ls -la /var/lib/oxidized/.ssh/
sudo chown -R 30000:30000 /var/lib/oxidized/.ssh/
sudo chmod 700 /var/lib/oxidized/.ssh/
sudo chmod 600 /var/lib/oxidized/.ssh/id_ed25519
sudo chmod 644 /var/lib/oxidized/.ssh/id_ed25519.pub
```

### Timer Not Running

```bash
# Enable and start timer
sudo systemctl enable --now oxidized-git-push.timer

# Check status
systemctl status oxidized-git-push.timer
```

### Repository Not Found

- Verify repository exists: https://github.com/yourusername/oxidized-backups
- Check you have write access
- Verify remote URL: `git remote get-url origin`

## Alternative: HTTPS with Token

If SSH is blocked by firewall:

1. Create Personal Access Token at https://github.com/settings/tokens
   - Scope: `repo` (Full control of private repositories)

2. Use HTTPS URL in setup script:
   ```
   Enter remote repository URL: https://github.com/yourusername/oxidized-backups.git
   ```

3. First push will prompt for credentials:
   - Username: `yourusername`
   - Password: `<paste-token-here>`

**Note**: Token is stored in plaintext. SSH keys are more secure.

## Multi-Remote Setup

For redundancy, add multiple remotes:

```bash
cd /var/lib/oxidized/repo

# Add GitLab as secondary remote
git remote add gitlab git@gitlab.com:yourusername/oxidized-backups.git

# Configure to push to both on 'git push'
git remote set-url --add --push origin git@github.com:yourusername/oxidized-backups.git
git remote set-url --add --push origin git@gitlab.com:yourusername/oxidized-backups.git

# Test push to both
git push origin main
```

## Full Documentation

See `docs/REMOTE_REPOSITORY.md` for comprehensive documentation including:
- Authentication methods
- Multiple remotes
- CI/CD integration
- Security best practices
