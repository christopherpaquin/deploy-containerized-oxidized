# Oxidized Authentication Setup

## ✅ Status: AUTOMATED AUTHENTICATION

Authentication is **automatically configured** during deployment using credentials from the `.env` file.

### How It Works

1. **Before deployment**: Set `NGINX_USERNAME` and `NGINX_PASSWORD` in `.env`
2. **During deployment**: `deploy.sh` automatically:
   - Installs nginx (if not present)
   - Creates htpasswd file from .env credentials
   - Deploys nginx configuration from template
   - Configures SELinux for nginx
   - Starts nginx service
3. **Result**: Web UI protected with login credentials

### Persistence

- **htpasswd file**: `/var/lib/oxidized/nginx/.htpasswd` (persistent, not overwritten on redeploy)
- **nginx config**: `/etc/nginx/conf.d/oxidized.conf` (regenerated from template on each deploy)
- **Uninstall**: Optional removal with `--remove-data` flag

## Login Credentials

```
URL:      http://10.1.10.55:8888
Username: (configured in .env: NGINX_USERNAME)
Password: (configured in .env: NGINX_PASSWORD)
```

**Default values** (if using the example):

- Username: `oxidized`
- Password: `oxidized2026!`

**⚠️ IMPORTANT**: These credentials are now configured in the `.env` file and automatically created during deployment!

## What Was Implemented

### 1. Automated Deployment via .env

- **Configuration**: Nginx credentials in `.env` file
- **Variables**: `NGINX_USERNAME` and `NGINX_PASSWORD`
- **Automated**: htpasswd file created automatically during deployment
- **Persistent**: Stored in `/var/lib/oxidized/nginx/.htpasswd`

### 2. Nginx Reverse Proxy

- **Installed**: nginx 1.26.3 (automatically)
- **Configuration**: `/etc/nginx/conf.d/oxidized.conf` (from template)
- **Template**: `config/nginx/oxidized.conf.template`
- **Function**: Acts as authentication gateway in front of Oxidized

### 3. HTTP Basic Authentication

- **Method**: HTTP Basic Auth (RFC 7617)
- **Password File**: `/var/lib/oxidized/nginx/.htpasswd`
- **User**: Created from .env during deployment (password hashed with APR1-MD5)
- **Persistent**: Survives redeployment (not overwritten if exists)

### 4. Security Configuration

- **Oxidized Binding**: Changed from `10.1.10.55:8888` to `127.0.0.1:8889`
- **Result**: Oxidized only accessible via nginx (not directly)
- **Firewall**: Port 8888 open for nginx (Oxidized port 8889 not exposed)
- **SELinux**: Configured to allow nginx network connections

### 5. Components

```
Internet/Network
       ↓
Port 8888 (firewall allows)
       ↓
nginx (with HTTP Basic Auth)
       ↓
localhost:8889
       ↓
Oxidized Container (Puma web server)
```

## How It Works

1. User accesses `http://10.1.10.55:8888`
2. nginx intercepts the request
3. nginx prompts for username/password (HTTP Basic Auth)
4. If credentials correct: nginx proxies request to Oxidized at `localhost:8889`
5. If credentials wrong: nginx returns `401 Unauthorized`

## Testing

### Browser Test

1. Open: `http://10.1.10.55:8888`
2. Login prompt will appear
3. Enter:
   - Username: `oxidized`
   - Password: `oxidized2026!`
4. You should see the Oxidized Web UI

### Command Line Test

```bash

# Without credentials (will fail)

curl http://10.1.10.55:8888/

# Returns: 401 Unauthorized

# With credentials (will work)

curl -u oxidized:oxidized2026! http://10.1.10.55:8888/nodes.json

# Returns: JSON device list

```

## Managing Users

### Configure Initial User (via .env) ⭐ RECOMMENDED

**Before deployment**, edit the `.env` file:

```bash
vim /root/deploy-containerized-oxidized/.env
```

Update these lines:
```bash
NGINX_USERNAME="your-username"
NGINX_PASSWORD="your-secure-password"
```

Then deploy:
```bash
cd /root/deploy-containerized-oxidized
sudo ./scripts/deploy.sh
```

The htpasswd file will be created automatically with your credentials.

**⚠️ Note**: If the htpasswd file already exists, it won't be overwritten. Delete it first if you want to recreate it:
```bash
sudo rm /var/lib/oxidized/nginx/.htpasswd
sudo ./scripts/deploy.sh
```

### Add Additional Users (Manual)

After deployment, you can add more users to the htpasswd file:

```bash

# Add another user to the password file

sudo htpasswd /var/lib/oxidized/nginx/.htpasswd newusername

# Enter password when prompted

# Restart nginx to apply changes (optional, should work immediately)

sudo systemctl restart nginx
```

### Change Password

```bash

# Update existing user's password

sudo htpasswd /var/lib/oxidized/nginx/.htpasswd oxidized

# Enter new password when prompted

```

### Delete a User

```bash

# Remove user from password file

sudo htpasswd -D /var/lib/oxidized/nginx/.htpasswd username
```

### List Users

```bash

# View all users (passwords are hashed)

sudo cat /var/lib/oxidized/nginx/.htpasswd
```

## Service Management

### Restart nginx

```bash
sudo systemctl restart nginx
```

### Restart Oxidized

```bash
sudo systemctl restart oxidized.service
```

### Check nginx Status

```bash
sudo systemctl status nginx
```

### View nginx Logs

```bash

# Access log (shows login attempts)

sudo tail -f /var/log/nginx/oxidized_access.log

# Error log

sudo tail -f /var/log/nginx/oxidized_error.log
```

### Check nginx Configuration

```bash
sudo nginx -t
```

## Configuration Files

### nginx Reverse Proxy Config

**Location**: `/etc/nginx/conf.d/oxidized.conf` (deployed from template)
**Template**: `/root/deploy-containerized-oxidized/config/nginx/oxidized.conf.template`

**Automatically configured from** `.env` variables:

- `{{OXIDIZED_API_PORT}}` → from `OXIDIZED_API_PORT` (default: 8888)
- `{{OXIDIZED_API_HOST}}` → from `OXIDIZED_API_HOST` (e.g., 10.1.10.55)

```nginx
server {
    listen 8888;  # From OXIDIZED_API_PORT
    server_name 10.1.10.55;  # From OXIDIZED_API_HOST

    # HTTP Basic Authentication
    auth_basic "Oxidized Access - Login Required";
    auth_basic_user_file /var/lib/oxidized/nginx/.htpasswd;  # Persistent location

    # Proxy to Oxidized
    location / {
        proxy_pass http://127.0.0.1:8889;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Note**: This file is automatically generated during deployment. Manual changes will be overwritten on redeployment.

### Password File

**Location**: `/var/lib/oxidized/nginx/.htpasswd`
```
oxidized:$apr1$VchWyeAT$fwyJYURzQTux0CUTtxvFx.
```

**Note**: This file is now stored in `/var/lib/oxidized/nginx/` for persistence alongside other Oxidized data.

### Oxidized Quadlet (Modified)

**Location**: `/etc/containers/systemd/oxidized.container`
```ini
PublishPort=127.0.0.1:8889:8888
```

## Security Features

### ✅ Implemented

- HTTP Basic Authentication
- Password hashing (APR1-MD5)
- Localhost-only backend binding
- SELinux enforcing mode maintained
- Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- Access logging for audit trail

### ⚠️ Considerations

- HTTP Basic Auth sends credentials in Base64 (not encrypted)
- Consider adding HTTPS/SSL for production use
- Passwords stored in htpasswd file (server-side, hashed)
- No account lockout mechanism (consider fail2ban)
- No multi-factor authentication (MFA)

## Upgrading to HTTPS (Recommended for Production)

To add SSL/TLS encryption:

1. **Obtain SSL Certificate**
   - Self-signed: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/oxidized.key -out /etc/nginx/ssl/oxidized.crt`
   - Let's Encrypt: Use certbot
   - Enterprise: Use your CA

2. **Update nginx Config**

   ```nginx
   server {
       listen 443 ssl http2;
       server_name 10.1.10.55;

       ssl_certificate /etc/nginx/ssl/oxidized.crt;
       ssl_certificate_key /etc/nginx/ssl/oxidized.key;

       # ... rest of config
   }
   ```

3. **Update Firewall**

   ```bash
   sudo firewall-cmd --permanent --add-service=https
   sudo firewall-cmd --reload
   ```

## Troubleshooting

### Cannot Access Web UI

```bash

# Check nginx is running

sudo systemctl status nginx

# Check Oxidized is running

sudo systemctl status oxidized.service

# Check ports

sudo ss -tlnp | grep -E "8888|8889"

# Check nginx error log

sudo tail -50 /var/log/nginx/error.log
```

### Authentication Not Working

```bash

# Verify password file exists

sudo cat /var/lib/oxidized/nginx/.htpasswd

# Test password manually

echo -n "oxidized2026!" | openssl passwd -apr1 -stdin

# Check nginx config

sudo nginx -t
```

### 502 Bad Gateway

```bash

# Check if Oxidized is responding

curl -I http://127.0.0.1:8889/

# Check SELinux boolean

getsebool httpd_can_network_connect

# If off, enable it

sudo setsebool -P httpd_can_network_connect 1

# Check for stale PID file

sudo rm -f /var/lib/oxidized/data/oxidized.pid
sudo systemctl restart oxidized.service
```

### SELinux Issues

```bash

# Check for denials

sudo ausearch -m avc -ts recent | grep nginx

# Allow nginx network connections

sudo setsebool -P httpd_can_network_connect 1

# Allow nginx to bind to port 8888

sudo semanage port -a -t http_port_t -p tcp 8888
```

## Firewall Configuration

Current firewall rules:
```bash

# Port 8888 is open for nginx

sudo firewall-cmd --list-ports

# Should show: 8888/tcp

# Port 8889 is NOT exposed (localhost only)

```

To restrict access to specific IPs (additional security):
```bash

# Remove open port

sudo firewall-cmd --permanent --remove-port=8888/tcp

# Add rich rule for specific IP

sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="YOUR_IP" port protocol="tcp" port="8888" accept'

# Reload

sudo firewall-cmd --reload
```

## Backup and Recovery

### Backup Password File

```bash
sudo cp /var/lib/oxidized/nginx/.htpasswd /root/oxidized-htpasswd.backup
```

### Backup nginx Config

```bash
sudo cp /etc/nginx/conf.d/oxidized.conf /root/oxidized-nginx.conf.backup
```

### Restore

```bash
sudo cp /root/oxidized-htpasswd.backup /var/lib/oxidized/nginx/.htpasswd
sudo chown root:nginx /var/lib/oxidized/nginx/.htpasswd
sudo chmod 640 /var/lib/oxidized/nginx/.htpasswd
sudo cp /root/oxidized-nginx.conf.backup /etc/nginx/conf.d/oxidized.conf
sudo systemctl restart nginx
```

## Summary

✅ **Authentication**: ENABLED
✅ **Method**: HTTP Basic Auth
✅ **Username**: oxidized
✅ **Password**: oxidized2026!
✅ **URL**: http://10.1.10.55:8888
✅ **Security**: Oxidized accessible only through authenticated nginx proxy
✅ **SELinux**: Enforcing (configured for nginx)
✅ **Firewall**: Port 8888 open for nginx

**The Oxidized Web UI now requires login credentials!** 🔒

## Next Steps

1. **Test the login** in your browser
2. **Change the default password** (recommended)
3. **Consider adding HTTPS** for production
4. **Add your real devices** to `/var/lib/oxidized/config/router.db`
5. **Monitor access logs** for security

---

For more information, see:

- Main documentation: `README.md`
- Security guide: `SECURITY-AUTHENTICATION.md`
- Deployment notes: `DEPLOYMENT-NOTES.md`
