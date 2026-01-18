# Oxidized Credentials Guide

## Overview

Your Oxidized deployment uses **TWO completely separate sets of credentials** for different purposes. Understanding this distinction is critical.

---

## 🔑 Credential Set #1: Web UI Login (nginx Authentication)

### Purpose
Protects access to the Oxidized web interface and API.

### Used By
- You (the administrator)
- Anyone accessing the Web UI
- API clients

### Used For
- Logging into http://10.1.10.55:8888
- Accessing the Oxidized dashboard
- Using the REST API

### Where Configured
- **Source**: `.env` file variables: `NGINX_USERNAME` and `NGINX_PASSWORD`
- **Password file**: `/var/lib/oxidized/nginx/.htpasswd` (auto-generated)
- **nginx config**: `/etc/nginx/conf.d/oxidized.conf` (auto-deployed)

### Default Credentials (from .env)
```
Username: oxidized
Password: oxidized2026!
```

### How to Change (Method 1: via .env - Recommended)
```bash
# Edit .env file BEFORE deployment
vim /root/deploy-containerized-oxidized/.env

# Update these lines:
NGINX_USERNAME="your-username"
NGINX_PASSWORD="your-secure-password"

# Remove existing htpasswd file (if redeploying)
sudo rm /var/lib/oxidized/nginx/.htpasswd

# Redeploy
cd /root/deploy-containerized-oxidized
sudo ./scripts/deploy.sh
```

### How to Change (Method 2: Manual)
```bash
# Change password for existing user
sudo htpasswd /var/lib/oxidized/nginx/.htpasswd oxidized

# Add another user
sudo htpasswd /var/lib/oxidized/nginx/.htpasswd newuser

# Restart nginx (optional, changes apply immediately)
sudo systemctl restart nginx
```

### Security Notes
- These credentials are hashed in `/etc/nginx/.htpasswd`
- HTTP Basic Authentication (consider HTTPS for production)
- Controls who can VIEW device configurations
- Does NOT access network devices

---

## 🔑 Credential Set #2: Network Device Credentials (.env file)

### Purpose
**Credentials that Oxidized uses to SSH into your network devices (routers, switches, firewalls) to pull their configurations.**

### Used By
- Oxidized service (automated backups)
- When connecting to network equipment via SSH/Telnet

### Used For
- Logging into routers (e.g., Cisco IOS devices)
- Logging into switches (e.g., HP ProCurve, Arista)
- Logging into firewalls (e.g., FortiGate, Palo Alto)
- Pulling device configurations
- Any network device in your inventory

### Where Configured
- **File**: `/root/deploy-containerized-oxidized/.env`
- **Variables**: `OXIDIZED_USERNAME` and `OXIDIZED_PASSWORD`

### Current Values (from your .env)
```bash
OXIDIZED_USERNAME="admin"
OXIDIZED_PASSWORD="thunder123"
```

### ⚠️ IMPORTANT: These Must Match Your Network Devices!

These credentials must be:
1. **Valid** on all your network devices
2. **Consistent** across devices (or use per-device credentials)
3. **Read-only** access level (recommended for security)
4. **Changed** from example values to your actual credentials

### How to Change
```bash
# Edit the .env file
sudo vim /root/deploy-containerized-oxidized/.env

# Update these lines:
OXIDIZED_USERNAME="your-actual-username"
OXIDIZED_PASSWORD="your-actual-password"

# Save and redeploy
cd /root/deploy-containerized-oxidized
sudo ./scripts/deploy.sh
```

### Security Notes
- File has 600 permissions (owner read/write only)
- Used by Oxidized to SSH into devices
- Stored in plaintext in .env (keep secure!)
- Consider per-device credentials for heterogeneous environments

---

## 📋 Comparison Table

| Aspect | Web UI Login | Device Credentials |
|--------|-------------|-------------------|
| **Purpose** | Access Oxidized interface | Log into network devices |
| **Used by** | Administrators | Oxidized service |
| **Source** | `.env`: NGINX_USERNAME/PASSWORD | `.env`: OXIDIZED_USERNAME/PASSWORD |
| **Deployed to** | `/var/lib/oxidized/nginx/.htpasswd` | `/var/lib/oxidized/config/config` |
| **Format** | Hashed (APR1-MD5) | Plaintext in config |
| **Default User** | `oxidized` | `admin` |
| **Default Pass** | `oxidized2026!` | `thunder123` |
| **Controls** | Who views configs | How configs are collected |
| **Change method** | Edit `.env` + redeploy OR `htpasswd` | Edit `.env` + redeploy |
| **Auto-created** | ✅ Yes (from .env) | ✅ Yes (from .env) |

---

## 🎯 Common Scenarios

### Scenario 1: Adding a Router to Inventory

**Question**: What credentials do I need?

**Answer**: Device credentials (from .env)

**Example**:
```bash
# In router.db:
core-router:10.1.1.1:ios:core::

# The :: at the end means "use global credentials from .env"
# Oxidized will SSH to 10.1.1.1 using:
# Username: admin (from OXIDIZED_USERNAME)
# Password: thunder123 (from OXIDIZED_PASSWORD)
```

### Scenario 2: Viewing Backed-Up Configs

**Question**: What credentials do I need?

**Answer**: Web UI login credentials

**Example**:
```
1. Open http://10.1.10.55:8888
2. Login prompt appears
3. Enter: oxidized / oxidized2026!
4. View your device configurations
```

### Scenario 3: Different Device Credentials

**Question**: My devices have different usernames/passwords

**Answer**: Use per-device credentials in router.db

**Example**:
```bash
# Instead of using global credentials (::)
# Specify per-device credentials:

router1:10.1.1.1:ios:core:netadmin:router1pass
switch1:10.1.2.1:procurve:access:switchadmin:switch1pass
firewall1:10.1.3.1:fortios:security:fwadmin:fwpass
```

---

## 🔒 Security Best Practices

### For Web UI Login
1. ✅ Change default password immediately
2. ✅ Use strong passwords (12+ characters)
3. ✅ Add HTTPS/SSL for production
4. ✅ Create separate users for different admins
5. ✅ Monitor access logs: `/var/log/nginx/oxidized_access.log`

### For Device Credentials
1. ✅ Use dedicated "backup" account on devices
2. ✅ Use read-only privilege level when possible
   - Cisco: `privilege level 1` or `privilege level 7`
   - Use `username oxidized-backup privilege 7 password ...`
3. ✅ Never use enable/admin level credentials if possible
4. ✅ Rotate passwords regularly
5. ✅ Consider SSH keys instead of passwords
6. ✅ Audit `.env` file permissions: `ls -la .env` (should be 600)

---

## 📝 Setting Up Device Credentials

### Option A: Global Credentials (Simplest)

**Best for**: Homogeneous environments where all devices use the same credentials

1. Edit `.env`:
```bash
OXIDIZED_USERNAME="network-backup"
OXIDIZED_PASSWORD="SecureBackupPass123!"
```

2. Create backup account on ALL devices with same credentials

3. Add devices to `router.db` with empty username/password:
```
router1:10.1.1.1:ios:core::
router2:10.1.1.2:ios:core::
router3:10.1.1.3:ios:core::
```

### Option B: Per-Device Credentials

**Best for**: Heterogeneous environments with different device credentials

1. Keep `.env` with fallback credentials

2. Specify credentials per device in `router.db`:
```
router1:10.1.1.1:ios:core:admin:router1pass
switch1:10.1.2.1:procurve:access:switchuser:switch1pass
firewall1:10.1.3.1:fortios:security:fwadmin:fwpass
```

### Option C: Mixed Approach

1. Set common credentials in `.env`
2. Override only for devices that differ

Example:
```bash
# .env has admin/commonpass

# router.db:
router1:10.1.1.1:ios:core::                    # Uses global admin/commonpass
router2:10.1.1.2:ios:core::                    # Uses global admin/commonpass
special-router:10.1.1.10:ios:core:root:special # Uses root/special
```

---

## 🔧 Troubleshooting

### "Cannot login to Web UI"

**Issue**: Web UI login credentials

**Check**:
```bash
# Verify password file exists
sudo cat /etc/nginx/.htpasswd

# Test authentication
curl -u oxidized:oxidized2026! http://10.1.10.55:8888/nodes.json
```

**Fix**:
```bash
# Reset password
sudo htpasswd /etc/nginx/.htpasswd oxidized
sudo systemctl restart nginx
```

### "Oxidized cannot connect to devices"

**Issue**: Device credentials in .env or router.db

**Check**:
```bash
# View current credentials
grep OXIDIZED_USERNAME /root/deploy-containerized-oxidized/.env
grep OXIDIZED_PASSWORD /root/deploy-containerized-oxidized/.env

# Test SSH manually
ssh admin@10.1.1.1
# (use password from .env)
```

**Check Oxidized logs**:
```bash
podman logs oxidized | grep -i "auth\|login\|password"
```

**Common errors**:
- `Authentication failed` - Wrong username/password
- `Connection refused` - Device not reachable
- `Connection timeout` - Firewall blocking
- `Permission denied` - Insufficient privileges

### "Some devices work, others don't"

**Likely**: Different credentials on different devices

**Solution**: Use per-device credentials in `router.db`:
```
# Working device (using global creds)
router1:10.1.1.1:ios:core::

# Non-working device (needs specific creds)
router2:10.1.1.2:ios:core:differentuser:differentpass
```

---

## 📚 Configuration File Examples

### Example .env (Network Device Credentials)
```bash
# Network Device Credentials
# These are used by Oxidized to SSH into your devices
OXIDIZED_USERNAME="network-backup"
OXIDIZED_PASSWORD="YourDevicePassword123!"

# NOT the Web UI login credentials!
```

### Example router.db (Device Inventory)
```
# Using global credentials from .env:
core-router01:10.1.1.1:ios:core::
core-router02:10.1.1.2:ios:core::

# Using per-device credentials:
edge-router01:10.2.1.1:ios:edge:edgeuser:edgepass

# FQDN instead of IP:
dc-switch01:switch1.datacenter.local:nxos:datacenter::
```

### Example nginx .htpasswd (Web UI Users)
```
# Web UI login credentials (hashed)
oxidized:$apr1$VchWyeAT$fwyJYURzQTux0CUTtxvFx.
admin:$apr1$ABC123XY$anotherhashedpasswordhere
john:$apr1$DEF456ZW$yetanotherhashedpassword
```

---

## ✅ Quick Checklist

Before going live, verify:

- [ ] Changed Web UI password from `oxidized2026!`
- [ ] Updated `.env` with real device credentials
- [ ] Verified device credentials work (test SSH manually)
- [ ] Created read-only account on devices (if possible)
- [ ] Tested backup of at least one device
- [ ] Checked Oxidized logs for authentication errors
- [ ] Documented credentials securely (password manager)
- [ ] Set up credential rotation schedule
- [ ] Reviewed `.env` file permissions (600)
- [ ] Backed up `.env` file securely

---

## 🎓 Summary

**Remember**:

1. **Two separate credential sets** with different purposes
2. **Web UI login** (`oxidized/oxidized2026!`) - for YOU to access the interface
3. **Device credentials** (`.env`: `admin/thunder123`) - for OXIDIZED to access network devices
4. **Change both** from default values
5. **Document and secure** both sets appropriately

**The .env credentials (`OXIDIZED_USERNAME` and `OXIDIZED_PASSWORD`) are your network device credentials - they must match what you use to log into your routers and switches!**

---

## 📞 Need Help?

- Web UI authentication issues: See `AUTHENTICATION-SETUP.md`
- Device connection issues: Check Oxidized logs: `podman logs oxidized`
- General security: See `SECURITY-AUTHENTICATION.md`
- Deployment issues: See `DEPLOYMENT-NOTES.md`
