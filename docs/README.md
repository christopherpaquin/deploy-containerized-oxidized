# Documentation Index

This directory contains all documentation for the Containerized Oxidized Deployment project.

## 📖 Documentation Structure

All documentation is now organized in the `/docs` directory. The main `README.md` in the repository root provides an overview and links to detailed documentation.

## 🚀 Getting Started

**New Users - Start Here:**

1. **[QUICK-START.md](QUICK-START.md)** - Quick reference for deployment
2. **[INSTALL.md](INSTALL.md)** - Detailed installation guide
3. **[README-OXIDIZED.md](README-OXIDIZED.md)** - Oxidized usage guide

## 📋 Documentation Categories

### Configuration & Setup

- **[CONFIGURATION.md](CONFIGURATION.md)** - Configuration deep-dive
- **[ENV-ARCHITECTURE.md](ENV-ARCHITECTURE.md)** - Environment variable architecture
- **[PREREQUISITES.md](PREREQUISITES.md)** - System requirements
- **[DIRECTORY-STRUCTURE.md](DIRECTORY-STRUCTURE.md)** - Directory layout

### Device Management

- **[DEVICE-MANAGEMENT.md](DEVICE-MANAGEMENT.md)** - Complete device management guide
- **[ADD-DEVICE.md](ADD-DEVICE.md)** - Interactive device addition
- **[DEVICE-INPUT-CONFIGURATION.md](DEVICE-INPUT-CONFIGURATION.md)** - Input methods
- **[CUSTOM-MODELS.md](CUSTOM-MODELS.md)** - Custom device models
- **[TP-LINK-SX3008F.md](TP-LINK-SX3008F.md)** - TP-Link switch support
- **[TELNET-CONFIGURATION.md](TELNET-CONFIGURATION.md)** - Telnet setup

### Security

- **[CREDENTIALS-GUIDE.md](CREDENTIALS-GUIDE.md)** - Understanding credentials (⭐ IMPORTANT)
- **[CREDENTIALS-README.md](CREDENTIALS-README.md)** - Quick credentials reference
- **[SECURITY-HARDENING.md](SECURITY-HARDENING.md)** - Security best practices
- **[SECURITY-AUTHENTICATION.md](SECURITY-AUTHENTICATION.md)** - Authentication options
- **[AUTHENTICATION-SETUP.md](AUTHENTICATION-SETUP.md)** - Web UI login setup
- **[FIREWALL-IMPLEMENTATION.md](FIREWALL-IMPLEMENTATION.md)** - Firewall configuration
- **[FIREWALL-QUICKREF.md](FIREWALL-QUICKREF.md)** - Firewall quick reference

### Remote Backups (NEW)

- **[QUICK_START_REMOTE_REPO.md](QUICK_START_REMOTE_REPO.md)** - Remote repository quick start
- **[REMOTE_REPOSITORY.md](REMOTE_REPOSITORY.md)** - Complete remote repo guide
- **[UID_MIGRATION_30000.md](UID_MIGRATION_30000.md)** - UID migration documentation
- **[GIT-REPOSITORY-STRUCTURE.md](GIT-REPOSITORY-STRUCTURE.md)** - Git repo structure

### Operations

- **[SERVICE-MANAGEMENT.md](SERVICE-MANAGEMENT.md)** - Service operations
- **[DEPLOYMENT-NOTES.md](DEPLOYMENT-NOTES.md)** - Deployment improvements
- **[UPGRADE.md](UPGRADE.md)** - Upgrade procedures
- **[PATH-MAPPINGS.md](PATH-MAPPINGS.md)** - Container path mappings
- **[TROUBLESHOOTING-WEB-UI.md](TROUBLESHOOTING-WEB-UI.md)** - Web UI troubleshooting

### Project Documentation

- **[DOCUMENTATION-GUIDE.md](DOCUMENTATION-GUIDE.md)** - Documentation structure guide
- **[DOCUMENTATION-CONSOLIDATION.md](DOCUMENTATION-CONSOLIDATION.md)** - Doc organization
- **[DECISIONS.md](DECISIONS.md)** - Architecture decisions
- **[requirements.md](requirements.md)** - Project requirements
- **[ci-and-precommit.md](ci-and-precommit.md)** - CI/CD setup
- **[security-ci-review.md](security-ci-review.md)** - Security review

### Monitoring

- **[monitoring/ZABBIX.md](monitoring/ZABBIX.md)** - Zabbix integration

### AI Context

- **[ai/CONTEXT.md](ai/CONTEXT.md)** - AI assistant context

## 🆕 Recent Changes

### February 2026

**UID Migration (UID 30000)**
- Migrated from UID 2000 to 30000 to match container
- Automatic migration during deployment
- See [UID_MIGRATION_30000.md](UID_MIGRATION_30000.md)

**Remote Repository Support**
- Added GitHub/GitLab integration
- Automatic SSH key generation
- Optional auto-push timer
- See [QUICK_START_REMOTE_REPO.md](QUICK_START_REMOTE_REPO.md)

**Documentation Reorganization**
- Moved all docs to `/docs` directory
- Created comprehensive index
- Updated all cross-references

**Backup Directory Organization**
- `/var/lib/oxidized/config/backup-routerdb/` - router.db backups
- `/var/lib/oxidized/config/backup-config-file/` - config file backups
- Removed old `/var/lib/oxidized/config/backup/` directory

## 📞 Need Help?

1. **Quick answers**: Check [QUICK-START.md](QUICK-START.md)
2. **Not sure which doc to read?**: See [DOCUMENTATION-GUIDE.md](DOCUMENTATION-GUIDE.md)
3. **GitHub Issues**: https://github.com/christopherpaquin/deploy-containerized-oxidized/issues
4. **Oxidized Community**: https://gitter.im/oxidized/Lobby
