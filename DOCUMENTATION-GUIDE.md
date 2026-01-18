# Documentation Guide

This repository contains multiple documentation files, each serving a specific purpose. Here's when to use each one:

## 📚 Documentation Structure

### For New Users

**Start Here:**

1. **[QUICK-START.md](QUICK-START.md)** ⚡
   - **Purpose**: Get Oxidized running in 3 steps
   - **Use When**: You want to deploy quickly
   - **Contents**: Prerequisites, 3-step deployment, common commands
   - **Time**: 5 minutes

2. **[README.md](README.md)** 📖
   - **Purpose**: Comprehensive overview and reference
   - **Use When**: You need to understand features, architecture, or configuration
   - **Contents**: Features, architecture, security, configuration options, management scripts
   - **Time**: 15-20 minutes

### For Day-to-Day Operations

3. **[QUICK-START.md](QUICK-START.md)** 🔧
   - Quick command reference
   - Common troubleshooting
   - File locations

4. **[DEPLOYMENT-NOTES.md](DEPLOYMENT-NOTES.md)** 🔍
   - **Purpose**: Detailed testing results and improvements
   - **Use When**: Troubleshooting issues or understanding deployment decisions
   - **Contents**: Testing methodology, improvements made, security trade-offs, troubleshooting
   - **Time**: 10 minutes

### For Advanced Users

5. **[docs/INSTALL.md](docs/INSTALL.md)** ⚙️
   - **Purpose**: Manual installation steps (advanced)
   - **Use When**: You want manual control or need to understand what deploy.sh does
   - **Contents**: Step-by-step manual deployment process
   - **Note**: The automated `deploy.sh` script is recommended for most users

6. **[README-OXIDIZED.md](README-OXIDIZED.md)** 🔧
   - **Purpose**: Oxidized application usage and configuration
   - **Use When**: Configuring devices, models, SSH keys, or using Oxidized features
   - **Contents**: Device inventory format, supported models, API usage, Git operations

### For Specific Topics

7. **[docs/CONFIGURATION.md](docs/CONFIGURATION.md)**
   - Deep dive into configuration options
   - Environment variables explained
   - Advanced configuration scenarios

8. **[docs/SECURITY-HARDENING.md](docs/SECURITY-HARDENING.md)**
   - Security best practices
   - Hardening guidelines
   - Compliance considerations

9. **[docs/UPGRADE.md](docs/UPGRADE.md)**
   - Upgrade procedures
   - Version compatibility
   - Migration guides

10. **[docs/monitoring/ZABBIX.md](docs/monitoring/ZABBIX.md)**

    - Zabbix monitoring setup
    - Templates and triggers

## 🎯 Quick Decision Tree

```
Need to deploy?
├─ Yes, quickly → QUICK-START.md (use deploy.sh)
├─ Yes, manually → docs/INSTALL.md (step-by-step)
└─ Already deployed
   ├─ Need commands? → QUICK-START.md (reference section)
   ├─ Troubleshooting? → DEPLOYMENT-NOTES.md + README-OXIDIZED.md
   ├─ Understanding features? → README.md
   ├─ Configuring Oxidized? → README-OXIDIZED.md
   ├─ Security hardening? → docs/SECURITY-HARDENING.md
   └─ Upgrading? → docs/UPGRADE.md
```

## 📊 Documentation Comparison

| Document | Length | Purpose | Audience |
|----------|--------|---------|----------|
| QUICK-START.md | ~120 lines | Fast deployment & reference | Everyone |
| README.md | ~770 lines | Comprehensive overview | New users |
| DEPLOYMENT-NOTES.md | ~200 lines | Testing & troubleshooting | Admins |
| INSTALL.md | ~610 lines | Manual installation | Advanced |
| README-OXIDIZED.md | ~800 lines | Oxidized usage | Operators |
| Other docs/ | Varies | Specific topics | As needed |

## 🚀 Recommended Reading Order

### For First-Time Deployment:

1. QUICK-START.md (deployment)
2. README.md (understanding)
3. README-OXIDIZED.md (configuration)
4. DEPLOYMENT-NOTES.md (troubleshooting if needed)

### For Day-to-Day Use:

- QUICK-START.md (quick reference)
- README-OXIDIZED.md (device configuration)

### For Troubleshooting:

1. DEPLOYMENT-NOTES.md (common issues)
2. README-OXIDIZED.md (Oxidized-specific)
3. QUICK-START.md (diagnostic commands)

## 💡 Why Multiple Documents?

Each document serves a specific purpose:

- **QUICK-START**: Minimizes time to deployment
- **README**: Comprehensive reference for all features
- **INSTALL**: Educational for understanding the system
- **DEPLOYMENT-NOTES**: Documents real-world testing and improvements
- **README-OXIDIZED**: Oxidized-specific usage (not deployment)

This structure allows users to:

- Get started quickly (QUICK-START)
- Understand the system deeply (README)
- Learn by doing manually (INSTALL)
- Troubleshoot effectively (DEPLOYMENT-NOTES)
- Configure Oxidized properly (README-OXIDIZED)

## 📝 Summary

**Most users should:**

1. Start with QUICK-START.md
2. Reference README.md for understanding
3. Use DEPLOYMENT-NOTES.md if issues arise

**The scripts/ directory automates everything in INSTALL.md**, making manual installation unnecessary for most users.

---

Last Updated: January 17, 2026
