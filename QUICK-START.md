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

> **📝 Note:** A test device (`test-device:192.0.2.1`) is included by default to enable the Web UI. Replace it with your real devices in `/var/lib/oxidized/config/router.db` before production use.

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

# Device Management

# Add device interactively (recommended)
/var/lib/oxidized/scripts/add-device.sh

# Validate router.db syntax
/var/lib/oxidized/scripts/validate-router-db.sh

# Test specific device
/var/lib/oxidized/scripts/test-device.sh <device-name>

# Monitoring

watch -n 5 'curl -s http://localhost:8888/nodes.json | jq ".[].status"'
```

## Uninstall

```bash

# Keep data (default - preserves /var/lib/oxidized)

sudo ./scripts/uninstall.sh

# Remove everything (prompts to backup router.db)

sudo ./scripts/uninstall.sh --remove-data

# Remove everything without prompts (NO BACKUP!)

sudo ./scripts/uninstall.sh --force --remove-data
```

**Note:** When using `--remove-data`, you'll be prompted to backup `router.db` to your home directory with a timestamp before deletion.

## Automatic Backups

**Every deployment automatically backs up `router.db`!**

```bash

# List backups

ls -lht /var/lib/oxidized/config/*.backup.*

# Restore from backup

sudo cp /var/lib/oxidized/config/router.db.backup.20260117_203749 \
        /var/lib/oxidized/config/router.db
sudo systemctl restart oxidized.service

# Cleanup old backups (keep last 10)

cd /var/lib/oxidized/config
ls -t router.db.backup.* | tail -n +11 | xargs -r sudo rm
```

See `DEVICE-MANAGEMENT.md` for full backup documentation.

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

grep -A 2 "oxidized-web:" /var/lib/oxidized/config/config

# Should show:
# extensions:
#   oxidized-web:
#     host: 0.0.0.0
#     port: 8888

```

### Permission errors

```bash
ls -laZ /var/lib/oxidized

# Fix container-accessed directories (must be UID 30000)

chown -R 30000:30000 /var/lib/oxidized/config
chown -R 30000:30000 /var/lib/oxidized/data
chown -R 30000:30000 /var/lib/oxidized/repo
chown -R 30000:30000 /var/lib/oxidized/ssh
chown -R 30000:30000 /var/lib/oxidized/output

# Or re-run deploy.sh to fix all ownership automatically

./scripts/deploy.sh
```

**Note:** See [DIRECTORY-STRUCTURE.md](/var/lib/oxidized/docs/DIRECTORY-STRUCTURE.md) for ownership details.

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
