# Oxidized Service Management

This document explains how to manage the Oxidized systemd service with proper PID file handling.

## Problem

When the Oxidized container stops or restarts, it sometimes fails to remove its PID file (`/home/oxidized/.config/oxidized/data/oxidized.pid`). This causes startup failures on the next service start with errors like:

```
Another process is already running the oxidized server (PID file exists)
```

## Solution

We've created wrapper scripts that handle PID file cleanup automatically:

### Available Scripts

All scripts are located in `${OXIDIZED_ROOT}/scripts/` (typically `/var/lib/oxidized/scripts/`):

- **`oxidized-start.sh`** - Start the service with PID cleanup
- **`oxidized-stop.sh`** - Stop the service and remove PID file
- **`oxidized-restart.sh`** - Restart the service with full cleanup

## Usage

### Starting the Service

```bash
# Using the wrapper script (recommended)
sudo /var/lib/oxidized/scripts/oxidized-start.sh

# OR using systemctl directly
sudo systemctl start oxidized.service
```

The start script will:
1. Check for existing PID file
2. Verify if the process is actually running
3. Remove stale PID file if needed
4. Start the service
5. Verify successful startup

### Stopping the Service

```bash
# Using the wrapper script (recommended)
sudo /var/lib/oxidized/scripts/oxidized-stop.sh

# OR using systemctl directly
sudo systemctl stop oxidized.service
```

The stop script will:
1. Stop the systemd service
2. Verify the container has stopped
3. Remove the PID file
4. Confirm clean shutdown

### Restarting the Service

```bash
# Using the wrapper script (recommended)
sudo /var/lib/oxidized/scripts/oxidized-restart.sh

# OR using systemctl directly (may fail if PID file exists)
sudo systemctl restart oxidized.service
```

The restart script will:
1. Stop the service gracefully
2. Verify container shutdown
3. Remove stale PID file
4. Start the service fresh
5. Verify successful restart

## Systemctl vs Wrapper Scripts

| Command | When to Use | Notes |
|---------|-------------|-------|
| `systemctl start` | Quick start if no issues | May fail if PID file exists |
| `oxidized-start.sh` | **Recommended for start** | Handles stale PID cleanup |
| `systemctl stop` | Quick stop | May leave PID file behind |
| `oxidized-stop.sh` | **Recommended for stop** | Ensures clean shutdown |
| `systemctl restart` | Quick restart | May fail if PID file exists |
| `oxidized-restart.sh` | **Recommended for restart** | Full cleanup and restart |

## Troubleshooting

### Service Won't Start

If you get PID file errors:

```bash
# Manual cleanup
sudo rm -f /var/lib/oxidized/data/oxidized.pid

# Then start normally
sudo systemctl start oxidized.service

# OR use the wrapper script
sudo /var/lib/oxidized/scripts/oxidized-start.sh
```

### Verify Service Status

```bash
# Check systemd service status
sudo systemctl status oxidized.service

# Check container status
sudo podman ps | grep oxidized

# View service logs
sudo journalctl -u oxidized.service -n 50

# View container logs
sudo podman logs oxidized
```

### Check PID File

```bash
# Check if PID file exists
ls -la /var/lib/oxidized/data/oxidized.pid

# Check the PID inside
cat /var/lib/oxidized/data/oxidized.pid

# Check if process is running
ps -p $(cat /var/lib/oxidized/data/oxidized.pid)
```

## Configuration

The scripts automatically load configuration from `.env` in the repository root:

```bash
# Example .env configuration
OXIDIZED_ROOT=/var/lib/oxidized
OXIDIZED_USER=oxidized
OXIDIZED_GROUP=oxidized
```

## Integration with Systemd

You can create systemd service overrides to use these scripts:

```bash
# Create override directory
sudo mkdir -p /etc/systemd/system/oxidized.service.d/

# Create override file
sudo tee /etc/systemd/system/oxidized.service.d/pidfile-cleanup.conf <<'EOF'
[Service]
# Remove stale PID file before starting
ExecStartPre=-/bin/bash -c 'rm -f /var/lib/oxidized/data/oxidized.pid'

# Remove PID file after stopping
ExecStopPost=-/bin/bash -c 'rm -f /var/lib/oxidized/data/oxidized.pid'
EOF

# Reload systemd
sudo systemctl daemon-reload

# Now systemctl commands will handle PID cleanup automatically
sudo systemctl restart oxidized.service
```

## Automation

### Cron Job for Auto-Restart

If you want to automatically restart on failure with PID cleanup:

```bash
# Edit crontab
sudo crontab -e

# Add periodic health check and restart
*/5 * * * * /var/lib/oxidized/scripts/health-check.sh || /var/lib/oxidized/scripts/oxidized-restart.sh
```

### Systemd Timer

Create a systemd timer for periodic restarts:

```bash
# Create timer unit
sudo tee /etc/systemd/system/oxidized-restart.timer <<'EOF'
[Unit]
Description=Periodic Oxidized Service Restart
Requires=oxidized-restart.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Create service unit
sudo tee /etc/systemd/system/oxidized-restart.service <<'EOF'
[Unit]
Description=Restart Oxidized Service
After=network.target

[Service]
Type=oneshot
ExecStart=/var/lib/oxidized/scripts/oxidized-restart.sh
EOF

# Enable and start timer
sudo systemctl enable oxidized-restart.timer
sudo systemctl start oxidized-restart.timer
```

## Best Practices

1. **Always use wrapper scripts** for manual operations
2. **Add systemd overrides** for automatic PID cleanup
3. **Monitor logs** after restart to ensure clean startup
4. **Use health-check.sh** to verify service health
5. **Document any custom modifications** to the scripts

## Related Documentation

- [TROUBLESHOOTING-WEB-UI.md](TROUBLESHOOTING-WEB-UI.md) - Web UI troubleshooting
- [INSTALL.md](INSTALL.md) - Installation guide
- [UPGRADE.md](UPGRADE.md) - Upgrade procedures

## Support

If you continue to experience PID file issues after using these scripts:

1. Check container logs: `podman logs oxidized`
2. Check systemd logs: `journalctl -u oxidized.service -n 100`
3. Verify file permissions: `ls -la /var/lib/oxidized/data/`
4. Check SELinux context: `ls -laZ /var/lib/oxidized/data/`
5. Report issue with full logs
