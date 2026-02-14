# Remote Repository Setup for Oxidized

This guide explains how to configure a remote git repository (GitHub, GitLab, Gitea, etc.) for Oxidized configuration backups.

## Overview

By default, Oxidized stores device configurations in a local git repository at `/var/lib/oxidized/repo`. To add redundancy and enable remote access, you can configure a remote repository to automatically receive backup commits.

## Prerequisites

1. **Oxidized Deployed**: Run `deploy.sh` first
2. **Remote Repository**: Create a private repository on your git hosting platform
3. **Authentication**: Configure SSH key or personal access token

## Quick Start

```bash
cd /root/deploy-containerized-oxidized/scripts
sudo ./setup-remote-repo.sh
```

The script will guide you through:
- Entering remote repository URL
- Configuring remote name and branch
- Testing connectivity
- Enabling automatic push (optional)

## Manual Setup

### 1. Create Remote Repository

**GitHub Example:**
```bash
# Using GitHub CLI
gh repo create oxidized-backups --private

# Or create manually at https://github.com/new
# ✓ Set repository to PRIVATE
```

**GitLab Example:**
```bash
# Create at https://gitlab.com/projects/new
# Set visibility to PRIVATE
```

### 2. Configure SSH Authentication (Recommended)

```bash
# Generate SSH key for oxidized user (UID 30000)
sudo -u "#30000" ssh-keygen -t ed25519 -C "oxidized@$(hostname)" -f /var/lib/oxidized/.ssh/id_ed25519

# Display public key to add to GitHub/GitLab
sudo cat /var/lib/oxidized/.ssh/id_ed25519.pub
```

Add the public key to your git hosting platform:
- **GitHub**: Settings → SSH and GPG keys → New SSH key
- **GitLab**: Preferences → SSH Keys → Add new key

### 3. Add Remote Repository

```bash
cd /var/lib/oxidized/repo

# Add remote (SSH - recommended)
git remote add origin git@github.com:username/oxidized-backups.git

# OR add remote (HTTPS - requires token)
git remote add origin https://github.com/username/oxidized-backups.git

# Verify remote
git remote -v
```

### 4. Initial Push

```bash
cd /var/lib/oxidized/repo

# Rename branch to main (if needed)
git branch -M main

# Push to remote
git push -u origin main
```

## Automatic Push Configuration

### Option A: Using Systemd Timer (Recommended)

The `setup-remote-repo.sh` script creates a systemd timer that pushes every 5 minutes:

```bash
# View timer status
systemctl status oxidized-git-push.timer

# View push logs
tail -f /var/lib/oxidized/data/git-push.log

# Manually trigger push
systemctl start oxidized-git-push.service
```

**Timer Configuration:**
- **Location**: `/etc/systemd/system/oxidized-git-push.timer`
- **Frequency**: Every 5 minutes
- **Script**: `/var/lib/oxidized/scripts/git-push.sh`

### Option B: Using Git Post-Commit Hook

```bash
# Create post-commit hook
cat > /var/lib/oxidized/repo/.git/hooks/post-commit << 'EOF'
#!/bin/bash
git push origin main 2>&1 | logger -t oxidized-git-push
EOF

chmod +x /var/lib/oxidized/repo/.git/hooks/post-commit
chown 30000:30000 /var/lib/oxidized/repo/.git/hooks/post-commit
```

**Note**: Hooks push immediately after each commit, which may be excessive for high-frequency backups.

## Authentication Methods

### SSH Key Authentication (Recommended)

**Advantages:**
- More secure
- No token expiration
- Simpler setup

**Setup:**
```bash
# Generate key
sudo -u "#30000" ssh-keygen -t ed25519 -f /var/lib/oxidized/.ssh/id_ed25519

# Add public key to git hosting platform
sudo cat /var/lib/oxidized/.ssh/id_ed25519.pub

# Use SSH URL
git remote add origin git@github.com:username/oxidized-backups.git
```

### Personal Access Token (HTTPS)

**Advantages:**
- Works behind restrictive firewalls
- Can be scoped/limited

**Setup:**
```bash
# Create token at git hosting platform
# GitHub: Settings → Developer settings → Personal access tokens → Tokens (classic)
# Scope: repo (Full control of private repositories)

# Configure git credential helper
cd /var/lib/oxidized/repo
git config credential.helper store

# First push will prompt for credentials
# Username: your-username
# Password: <paste-token>
git push -u origin main
```

**Security Note**: Tokens are stored in plaintext in `~/.git-credentials`. Use SSH keys for better security.

## Repository Privacy

**CRITICAL**: Always set your remote repository to **PRIVATE**

Device configurations may contain:
- IP addresses and network topology
- Device models and versions
- Interface configurations
- Potentially sensitive comments

### Verify Repository Privacy

**GitHub:**
```bash
gh repo view username/oxidized-backups --json visibility
# Should show: "visibility": "PRIVATE"
```

**GitLab:**
- Navigate to: Settings → General → Visibility
- Should be: Private

## Troubleshooting

### Push Authentication Fails

```bash
# Test SSH connection
sudo -u "#30000" ssh -T git@github.com

# Should see: "Hi username! You've successfully authenticated"
```

If fails:
```bash
# Check SSH key permissions
ls -la /var/lib/oxidized/.ssh/
# Should be: drwx------ (700) for directory, -rw------- (600) for private key

# Fix permissions if needed
chown -R 30000:30000 /var/lib/oxidized/.ssh/
chmod 700 /var/lib/oxidized/.ssh/
chmod 600 /var/lib/oxidized/.ssh/id_ed25519
chmod 644 /var/lib/oxidized/.ssh/id_ed25519.pub
```

### Push Fails: "Repository Not Found"

- Verify repository exists: Visit URL in browser
- Check remote URL: `git remote get-url origin`
- Ensure you have write access to repository

### Timer Not Running

```bash
# Check timer status
systemctl status oxidized-git-push.timer

# If inactive, enable and start
systemctl enable --now oxidized-git-push.timer

# View recent timer executions
journalctl -u oxidized-git-push.service -n 50
```

### Merge Conflicts

If remote has changes not in local:
```bash
cd /var/lib/oxidized/repo

# Fetch remote changes
git fetch origin

# Merge or rebase
git pull origin main --rebase

# Push local commits
git push origin main
```

## Monitoring

### Check Last Push Time

```bash
cd /var/lib/oxidized/repo
git log origin/main -1 --format="%ar: %s"
```

### Monitor Push Activity

```bash
# Watch push log
tail -f /var/lib/oxidized/data/git-push.log

# View systemd journal
journalctl -u oxidized-git-push.service -f
```

### List Unpushed Commits

```bash
cd /var/lib/oxidized/repo
git log origin/main..HEAD --oneline
```

## Backup Strategy

### Recommended Configuration

1. **Local Repository**: `/var/lib/oxidized/repo` (primary)
2. **Remote Repository**: GitHub/GitLab (redundancy)
3. **Push Frequency**: Every 5 minutes (systemd timer)
4. **Backup Retention**: Unlimited (full git history)

### Multiple Remotes

You can configure multiple remote repositories for additional redundancy:

```bash
cd /var/lib/oxidized/repo

# Add secondary remote
git remote add gitlab git@gitlab.com:username/oxidized-backups.git

# Push to both remotes
git push origin main
git push gitlab main

# Configure push to all remotes
git remote set-url --add --push origin git@github.com:username/oxidized-backups.git
git remote set-url --add --push origin git@gitlab.com:username/oxidized-backups.git

# Now 'git push origin' pushes to both
```

## Security Best Practices

1. **Always use private repositories**
2. **Use SSH keys instead of tokens when possible**
3. **Limit token scope to minimum required permissions**
4. **Rotate credentials periodically**
5. **Enable 2FA on git hosting account**
6. **Use dedicated git account for automation**
7. **Review `.gitignore` to exclude sensitive files**

## Integration with CI/CD

You can use the remote repository for:
- **Compliance auditing**: Track configuration changes over time
- **Automated testing**: Run linters/validators on configs
- **Change notifications**: Alert on specific changes
- **Documentation**: Auto-generate network documentation

**Example GitHub Action** (`.github/workflows/audit.yml`):
```yaml
name: Config Audit
on: [push]
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check for sensitive data
        run: |
          # Check for potential secrets
          grep -r "password\|secret\|key" . || echo "No secrets found"
```

## References

- [Git Remote Documentation](https://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes)
- [GitHub SSH Keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [GitLab SSH Keys](https://docs.gitlab.com/ee/user/ssh.html)
- [Oxidized Documentation](https://github.com/ytti/oxidized)
