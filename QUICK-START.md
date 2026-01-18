# Oxidized Deployment Quick Start

## Prerequisites
```bash
sudo dnf install -y podman git logrotate curl jq
```

## Deploy in 3 Steps

### 1. Configure
```bash
cd /root/deploy-containerized-oxidized
cp env.example .env
chmod 600 .env
vim .env  # Edit OXIDIZED_PASSWORD at minimum
```

### 2. Deploy
```bash
sudo ./scripts/deploy.sh --skip-credentials
```

### 3. Verify
```bash
sudo ./scripts/health-check.sh
curl http://localhost:8888/nodes.json | jq
```

## Common Commands

```bash
# Service Management
systemctl status oxidized.service
systemctl restart oxidized.service
journalctl -u oxidized.service -f

# Container Management
podman ps
podman logs oxidized
podman restart oxidized

# API Testing
curl http://localhost:8888/nodes.json | jq
curl http://localhost:8888/nodes.json | jq 'length'

# Configuration
vim /var/lib/oxidized/config/router.db
systemctl restart oxidized.service

# Monitoring
watch -n 5 'curl -s http://localhost:8888/nodes.json | jq ".[].status"'
```

## Uninstall

```bash
# Keep data
sudo ./scripts/uninstall.sh

# Remove everything
sudo ./scripts/uninstall.sh --force --remove-data
```

## File Locations

| Purpose | Location |
|---------|----------|
| Main config | `/var/lib/oxidized/config/config` |
| Device inventory | `/var/lib/oxidized/config/router.db` |
| Git backups | `/var/lib/oxidized/repo/` |
| SSH keys | `/var/lib/oxidized/ssh/` |
| Logs | `/var/lib/oxidized/data/oxidized.log` |
| Quadlet | `/etc/containers/systemd/oxidized.container` |

## Troubleshooting

### Service won't start
```bash
journalctl -u oxidized.service -n 50
systemctl status oxidized.service
```

### API not responding
```bash
# Check if listening
ss -tlnp | grep 8888

# Check config
grep "rest:" /var/lib/oxidized/config/config

# Should show: rest: 0.0.0.0:8888
```

### Permission errors
```bash
ls -laZ /var/lib/oxidized
chown -R 2000:2000 /var/lib/oxidized
```

## Documentation

- **DEPLOYMENT-NOTES.md** - Testing results, improvements, detailed troubleshooting
- **README.md** - Complete documentation
- **README-OXIDIZED.md** - Oxidized usage guide
- **docs/** - Detailed guides

## Support

For issues, see DEPLOYMENT-NOTES.md or open an issue on GitHub.

---

**Last Updated**: January 17, 2026
**Version**: Tested on RHEL 10.1
