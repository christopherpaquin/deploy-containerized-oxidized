# Oxidized Web UI Security and Authentication

## ⚠️ Critical Security Information

**Oxidized's Web UI does NOT have built-in user authentication.**

By default, anyone who can access port 8888 can:
- View all device configurations
- See device inventory
- Access historical configuration backups
- Use the REST API

This is a significant security consideration since device configurations often contain:
- Network topology information
- IP addressing schemes
- VLAN configurations
- Management interfaces
- Potentially sensitive comments

## Current Deployment Status

```
Web UI:     http://10.1.10.55:8888
Auth:       ❌ NONE (open access)
Firewall:   ✅ Port 8888/tcp allowed from all IPs
Access:     Anyone on network can access
```

## Security Options

### Option 1: Firewall IP Restriction ⭐ RECOMMENDED FOR QUICK SETUP

**Use Case**: Quick security, small team, known IP addresses

**Implementation**:
```bash
# Remove open port rule
sudo firewall-cmd --permanent --remove-port=8888/tcp

# Allow specific IP
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.1.10.50" port protocol="tcp" port="8888" accept'

# Or allow subnet
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.1.10.0/24" port protocol="tcp" port="8888" accept'

# Apply changes
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-all
```

**Pros**:
- ✅ Easy to implement
- ✅ No additional software
- ✅ Works immediately
- ✅ Can allow multiple IPs/subnets

**Cons**:
- ❌ No user-level authentication
- ❌ Bypassed if attacker on allowed network
- ❌ Difficult with dynamic IPs
- ❌ Requires firewall rule updates for new users

---

### Option 2: SSH Tunnel Access 🔒 MOST SECURE

**Use Case**: Maximum security, remote access, single/few users

**Implementation**:

**1. Bind Oxidized to localhost only:**
```bash
sudo vim /etc/containers/systemd/oxidized.container
```

Change:
```ini
PublishPort=10.1.10.55:8888:8888
```

To:
```ini
PublishPort=127.0.0.1:8888:8888
```

**2. Remove firewall rule:**
```bash
sudo firewall-cmd --permanent --remove-port=8888/tcp
sudo firewall-cmd --reload
```

**3. Restart service:**
```bash
sudo systemctl daemon-reload
sudo systemctl restart oxidized.service
```

**4. Access from workstation:**
```bash
# Create SSH tunnel
ssh -L 8888:localhost:8888 root@10.1.10.55

# In another terminal or browser:
http://localhost:8888
```

**For permanent tunnel (Linux/Mac):**
```bash
# Add to ~/.ssh/config
Host oxidized
    HostName 10.1.10.55
    User root
    LocalForward 8888 localhost:8888

# Connect
ssh oxidized

# Access
http://localhost:8888
```

**For Windows:**
Use PuTTY with local port forwarding:
- Connection → SSH → Tunnels
- Source port: 8888
- Destination: localhost:8888
- Click "Add"

**Pros**:
- ✅ Very secure (requires SSH authentication)
- ✅ Encrypted tunnel
- ✅ Multi-factor auth possible (SSH keys)
- ✅ Audit trail (SSH logs)
- ✅ No additional software on server

**Cons**:
- ❌ Requires SSH tunnel each session
- ❌ Slightly more complex for users
- ❌ Can be forgotten (tunnel drops)

---

### Option 3: Nginx Reverse Proxy with HTTP Basic Auth 🏢 PRODUCTION

**Use Case**: Production, multiple users, web-based auth

**Implementation**:

**1. Install nginx:**
```bash
sudo dnf install -y nginx httpd-tools
```

**2. Create htpasswd file:**
```bash
sudo htpasswd -c /etc/nginx/.htpasswd oxidized
# Enter password when prompted

# Add more users
sudo htpasswd /etc/nginx/.htpasswd user2
```

**3. Configure nginx:**
```bash
sudo vim /etc/nginx/conf.d/oxidized.conf
```

```nginx
server {
    listen 80;
    server_name oxidized.example.com;

    # Redirect to HTTPS (recommended)
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name oxidized.example.com;

    # SSL certificates
    ssl_certificate /etc/pki/tls/certs/oxidized.crt;
    ssl_certificate_key /etc/pki/tls/private/oxidized.key;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Authentication
    auth_basic "Oxidized Access";
    auth_basic_user_file /etc/nginx/.htpasswd;

    # Proxy to Oxidized
    location / {
        proxy_pass http://localhost:8888;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Access logs
    access_log /var/log/nginx/oxidized_access.log;
    error_log /var/log/nginx/oxidized_error.log;
}
```

**4. Bind Oxidized to localhost:**
```bash
sudo vim /etc/containers/systemd/oxidized.container
# Change to: PublishPort=127.0.0.1:8888:8888

sudo systemctl daemon-reload
sudo systemctl restart oxidized.service
```

**5. Configure firewall:**
```bash
# Remove direct Oxidized access
sudo firewall-cmd --permanent --remove-port=8888/tcp

# Allow HTTP/HTTPS
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

**6. Enable and start nginx:**
```bash
sudo systemctl enable --now nginx
```

**Pros**:
- ✅ User-level authentication
- ✅ Multiple users easily managed
- ✅ SSL/TLS encryption
- ✅ Standard web access (no tunnels)
- ✅ Can integrate with LDAP/AD
- ✅ Audit logging
- ✅ Can add rate limiting

**Cons**:
- ❌ More complex setup
- ❌ Additional software to maintain
- ❌ Requires SSL certificates
- ❌ Need to manage nginx configuration

---

### Option 4: VPN or Bastion Host 🌐 ENTERPRISE

**Use Case**: Enterprise environments, existing VPN infrastructure

**Implementation**:
Oxidized server accessible only via:
- Corporate VPN
- Bastion/jump host
- Zero-trust network

This is handled at the network layer and doesn't require changes to Oxidized.

**Pros**:
- ✅ Centralized access control
- ✅ Works with existing infrastructure
- ✅ Network-level security
- ✅ Compliance-friendly

**Cons**:
- ❌ Requires existing VPN/bastion infrastructure
- ❌ More complex to set up if not already in place

---

## Recommendations by Environment

### Lab/Development
```
✓ Current open setup (if isolated network)
✓ OR firewall IP restriction
✓ Focus on functionality over security
```

### Small Production
```
✓ SSH Tunnel (Option 2)
✓ OR Firewall IP restriction (Option 1)
✓ Simple, secure, easy to maintain
```

### Medium Production
```
✓ Nginx reverse proxy (Option 3)
✓ SSL/TLS required
✓ Multiple user support
✓ Audit logging
```

### Enterprise
```
✓ VPN requirement (Option 4)
✓ PLUS nginx reverse proxy (Option 3)
✓ PLUS firewall IP restriction (Option 1)
✓ SSL/TLS with valid certificates
✓ Integration with SSO/LDAP
✓ SIEM integration
```

---

## Quick Security Checklist

- [ ] Understand Oxidized has no built-in auth
- [ ] Device configs contain sensitive data
- [ ] Choose appropriate security option
- [ ] Implement firewall restrictions at minimum
- [ ] Consider SSH tunnel for remote access
- [ ] Use reverse proxy for production
- [ ] Enable SSL/TLS for external access
- [ ] Audit access logs regularly
- [ ] Restrict network access at firewall
- [ ] Document who has access
- [ ] Review security quarterly

---

## Current Firewall Configuration

Check current status:
```bash
sudo firewall-cmd --list-all
```

View specific port:
```bash
sudo firewall-cmd --list-ports | grep 8888
```

---

## Testing Access

**Without restrictions:**
```bash
curl http://10.1.10.55:8888/nodes.json
```

**With HTTP Basic Auth (nginx):**
```bash
curl -u username:password http://10.1.10.55:8888/nodes.json
```

**Via SSH tunnel:**
```bash
ssh -L 8888:localhost:8888 root@10.1.10.55
curl http://localhost:8888/nodes.json
```

---

## Audit Logging

**SSH tunnel access:**
```bash
# SSH logs show who connected
sudo tail -f /var/log/secure | grep sshd
```

**Nginx logs:**
```bash
# Access logs with authentication
sudo tail -f /var/log/nginx/oxidized_access.log
```

**Oxidized logs:**
```bash
# Application logs
podman logs -f oxidized
```

---

## Emergency Access Lockdown

If you need to immediately restrict access:

```bash
# Close firewall port
sudo firewall-cmd --permanent --remove-port=8888/tcp
sudo firewall-cmd --reload

# Stop service
sudo systemctl stop oxidized.service

# View who might be connected
sudo ss -tnp | grep :8888
```

---

## Additional Security Measures

1. **Change default credentials** in `.env`:
   ```bash
   OXIDIZED_USERNAME=your-username
   OXIDIZED_PASSWORD=strong-password-here
   ```

2. **Restrict router.db permissions**:
   ```bash
   sudo chmod 600 /var/lib/oxidized/config/router.db
   sudo chown oxidized:oxidized /var/lib/oxidized/config/router.db
   ```

3. **Monitor access**:
   ```bash
   # Watch for connections
   watch -n 1 'ss -tnp | grep :8888'
   ```

4. **Regular Git backups**:
   ```bash
   # Backup the Git repo regularly
   tar -czf oxidized-backup-$(date +%Y%m%d).tar.gz /var/lib/oxidized/repo/
   ```

---

## Support and Questions

For security concerns or questions about implementing these options, please refer to:
- Main documentation: `README.md`
- Deployment notes: `DEPLOYMENT-NOTES.md`
- Firewall configuration: `FIREWALL-IMPLEMENTATION.md`

---

## Summary

**Default State**: ❌ NO AUTHENTICATION
**Minimum Security**: ✅ Firewall IP restriction
**Recommended**: ✅ SSH tunnel OR reverse proxy with auth
**Enterprise**: ✅ VPN + reverse proxy + SSL/TLS

**Choose the option that fits your environment and implement it before adding real device data!**
