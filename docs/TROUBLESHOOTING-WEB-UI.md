# Web UI Troubleshooting Guide

## Issue: Web UI Not Starting / Backend Not Responding

### Symptoms

- **502 Bad Gateway** error when accessing the web UI
- Health check shows: `[⚠] Backend not responding (may be expected if no devices configured)`
- REST API returns connection refused: `curl: (7) Failed to connect`
- nginx can't connect to oxidized backend on port 8889

### Root Cause

**Oxidized 0.35.0 with oxidized-web 0.18.0** has a compatibility issue where the web extension requires **both** configuration formats to initialize:

1. **New format** (for future compatibility): `extensions.oxidized-web`
2. **Legacy format** (required for initialization): `rest:`

Using only the new `extensions.oxidized-web` format will cause oxidized to start, but the web server will **not** start, resulting in a non-responsive backend.

### Diagnosis

#### Check if Web Server is Running

```bash
# Check oxidized logs for web server startup message
sudo podman logs oxidized | grep "Oxidized-web server listening"

# If you see this message, web server is running:
# Oxidized-web server listening on 0.0.0.0:8888

# If you DON'T see this message, web server didn't start
```

#### Check Configuration Format

```bash
# View the deployed config
sudo cat /var/lib/oxidized/config/config | grep -A 6 "extensions:"

# Should show BOTH formats:
# extensions:
#   oxidized-web:
#     host: 0.0.0.0
#     port: 8888
# rest: 0.0.0.0:8888
```

#### Test Backend Connectivity

```bash
# Test if backend is responding
curl http://127.0.0.1:8889/nodes.json

# If you get JSON response: ✅ Backend is working
# If you get "Connection refused": ❌ Backend is not running
```

### Solution

#### Step 1: Verify Config Template Has Both Formats

```bash
# Check the config template
cat /root/deploy-containerized-oxidized/config/oxidized/config.template | grep -A 8 "extensions:"

# Should show:
# extensions:
#   oxidized-web:
#     host: 0.0.0.0
#     port: 8888
# # Legacy format (required for oxidized-web initialization in 0.35.0)
# rest: 0.0.0.0:8888
```

#### Step 2: Redeploy Configuration

```bash
cd /root/deploy-containerized-oxidized
sudo ./scripts/deploy.sh
```

This will regenerate the config file with both formats.

#### Step 3: Restart Oxidized Service

```bash
sudo systemctl restart oxidized.service
```

#### Step 4: Verify Web Server Started

```bash
# Wait a few seconds for oxidized to start
sleep 5

# Check logs for web server startup
sudo podman logs oxidized --tail 20 | grep -i "web\|listen"

# Should see:
# Oxidized-web server listening on 0.0.0.0:8888

# Test backend
curl http://127.0.0.1:8889/nodes.json

# Should return JSON array of devices
```

#### Step 5: Verify Health Check

```bash
cd /root/deploy-containerized-oxidized
sudo ./scripts/health-check.sh

# Should show:
# Status: HEALTHY
# All checks passed successfully! 🎉
```

### Expected Behavior

After applying the fix:

1. **Oxidized starts successfully** - Check with `sudo systemctl status oxidized.service`
2. **Web server initializes** - Logs show "Oxidized-web server listening on 0.0.0.0:8888"
3. **Backend responds** - `curl http://127.0.0.1:8889/nodes.json` returns JSON
4. **nginx can connect** - No more 502 errors
5. **Web UI accessible** - Can access at `http://your-server:8888`

### Deprecation Warning

You may see this warning in the logs:

```
W [pid:1140] Oxidized::Core -- configuration: "rest" is deprecated. Migrate to "extensions.oxidized-web" and remove "rest" from the configuration
```

**This warning is expected and harmless.** Both formats are required for oxidized 0.35.0 compatibility. Do **not** remove the `rest:` line, as the web server will not start without it.

### Version Information

- **Oxidized Version**: 0.35.0
- **oxidized-web Version**: 0.18.0
- **Issue**: Web extension requires both old and new config formats
- **Workaround**: Include both `extensions.oxidized-web` and `rest:` in config

### Related Files

- **Config Template**: `/root/deploy-containerized-oxidized/config/oxidized/config.template`
- **Deployed Config**: `/var/lib/oxidized/config/config`
- **Container Logs**: `sudo podman logs oxidized`
- **Service Logs**: `sudo journalctl -u oxidized.service`

### Additional Troubleshooting

If the web server still doesn't start after applying the fix:

1. **Check for stale PID file**:
   ```bash
   sudo podman exec oxidized rm -f /home/oxidized/.config/oxidized/data/oxidized.pid
   sudo systemctl restart oxidized.service
   ```

2. **Check oxidized-web gem is installed**:
   ```bash
   sudo podman exec oxidized gem list | grep oxidized-web
   # Should show: oxidized-web (0.18.0)
   ```

3. **Check port binding**:
   ```bash
   sudo podman exec oxidized netstat -tlnp | grep 8888
   # Should show oxidized listening on port 8888
   ```

4. **Check nginx configuration**:
   ```bash
   sudo cat /etc/nginx/conf.d/oxidized.conf | grep proxy_pass
   # Should show: proxy_pass http://127.0.0.1:8889;
   ```

### References

- [Oxidized Configuration Documentation](https://github.com/ytti/oxidized/blob/master/docs/Configuration.md)
- [oxidized-web Extension](https://github.com/ytti/oxidized-web)
