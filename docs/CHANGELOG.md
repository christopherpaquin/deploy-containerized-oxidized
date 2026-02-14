# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Remote Repository Setup** - New `setup-remote-repo.sh` script for GitHub/GitLab integration
  - Interactive SSH key generation
  - Connection testing before setup
  - Optional automatic push timer (systemd)
  - Comprehensive documentation:
    - `docs/QUICK_START_REMOTE_REPO.md` - Quick start guide
    - `docs/REMOTE_REPOSITORY.md` - Complete guide
- **Log Tailer Service** - Real-time log monitoring via systemd
  - `oxidized-logger.service` - Follows Oxidized logs
  - `oxidized-log-tailer.sh` - Log tailer script
- **Backup Directory Organization** - Organized backup directories
  - `/var/lib/oxidized/config/backup-routerdb/` - router.db backups with README
  - `/var/lib/oxidized/config/backup-config-file/` - config file backups with README
  - Removed old `/var/lib/oxidized/config/backup/` directory
- **Documentation Index** - Created `docs/README.md` with comprehensive index
- **UID Migration Documentation** - `docs/UID_MIGRATION_30000.md` explains the migration

### Changed
- **UID Migration** - Changed oxidized user from UID 2000 to UID 30000
  - Matches container's internal oxidized user
  - Automatic migration during deployment
  - Simplified file ownership and permissions
  - Updated `.env` template with new defaults
  - See `docs/UID_MIGRATION_30000.md` for details
- **Documentation Organization** - Moved all docs to `/docs` directory
  - `QUICK-START.md` → `docs/QUICK-START.md`
  - `DOCUMENTATION-CONSOLIDATION.md` → `docs/DOCUMENTATION-CONSOLIDATION.md`
  - Updated all cross-references in README.md
  - Created comprehensive `docs/README.md` index
- **Deployment Script** - Enhanced `scripts/deploy.sh`
  - Added automatic UID migration logic (2000 → 30000)
  - Removed script backup behavior (no more `.backup.*` files)
  - Added log tailer service installation
  - Added `setup-remote-repo.sh` to helper scripts
  - Enhanced backup directory creation with dedicated paths
- **Add Device Script** - Updated `scripts/add-device.sh`
  - Changed backup directory to `/var/lib/oxidized/config/backup-routerdb/`
  - Standardized backup filename format to `router.db.backup.YYYYMMDD_HHMMSS`
- **Service Management Scripts** - Updated all service scripts
  - `oxidized-start.sh`, `oxidized-stop.sh`, `oxidized-restart.sh`
  - Updated for UID 30000
  - Improved PID file handling
- **README.md** - Major update to main README
  - Added remote repository setup information
  - Updated UID/GID references (2000 → 30000)
  - Reorganized documentation links by category
  - Added new scripts documentation
  - Updated quick start guide
  - Fixed all documentation cross-references

### Fixed
- **Git Repository Sync** - Fixed git status discrepancies
  - Restored missing device files from git
  - Corrected file ownership (30000:30000)
  - Committed pending changes
- **Setup Script Formatting** - Fixed ANSI color code rendering in `setup-remote-repo.sh`
  - Replaced `cat << EOF` with `echo -e` for color variables
- **Script Execution** - Fixed UID mismatch issues
  - Updated `setup-remote-repo.sh` to detect correct UID dynamically
  - Simplified execution after host UID migration
- **Service Scripts** - Fixed function name typos
  - Corrected `log_warning` → `log_warn` in deploy.sh

### Removed
- **Script Backups** - Removed automatic script backup creation
  - No more `.backup.<timestamp>` files in `/var/lib/oxidized/scripts/`
  - Cleaned up existing backup files
- **Old Backup Directory** - Removed `/var/lib/oxidized/config/backup/`
  - Migrated contents to organized backup directories
  - Updated scripts to use new locations

## Release Notes

### UID Migration (2000 → 30000)

**Background**: The container's internal `oxidized` user has always used UID 30000. Previously, the host used UID 2000, requiring permission workarounds.

**Solution**: The host `oxidized` user now uses UID 30000, matching the container. This simplifies:
- File ownership (no UID mapping needed)
- Script execution (direct `sudo -u oxidized` works)
- Permission management (consistent across host and container)

**Migration**: Fully automatic during deployment:
1. Detects existing UID 2000 user
2. Stops services
3. Changes UID/GID (usermod/groupmod)
4. Updates file ownership (find + chown)
5. Restarts services

**No manual intervention required.**

### Remote Repository Integration

New `setup-remote-repo.sh` script provides:
- **GitHub/GitLab support** - Push backups to remote repository
- **SSH key management** - Generate and configure keys
- **Auto-push** - Optional systemd timer for automatic pushes
- **Interactive setup** - Step-by-step with validation

See `docs/QUICK_START_REMOTE_REPO.md` for quick start.

### Documentation Reorganization

All documentation now resides in `/docs/` with:
- Comprehensive index (`docs/README.md`)
- Category-based organization
- Updated cross-references
- Clear getting started path

Main README.md focuses on overview and quick start, with links to detailed docs.

## Upgrade Notes

### From UID 2000 to UID 30000

**Automatic**: Run `sudo ./scripts/deploy.sh` and the migration happens automatically.

**Verification**:
```bash
# Check user UID
id oxidized  # Should show uid=30000

# Check directory ownership
ls -ldn /var/lib/oxidized/  # Should show 30000:30000

# Check service status
sudo systemctl status oxidized.service
```

### Documentation Updates

**Update bookmarks**: Documentation has moved to `/docs/` directory.

**Update scripts**: If you have custom scripts referencing docs, update paths:
- `README-OXIDIZED.md` → `docs/README-OXIDIZED.md`
- `QUICK-START.md` → `docs/QUICK-START.md`

## Breaking Changes

**None** - All changes are backward compatible with automatic migration.

## Known Issues

**None reported** - All issues from conversation have been resolved.

---

**Date**: February 13, 2026
**Contributors**: Christopher Paquin
