# 📊 Zabbix Monitoring Guide

This document provides guidance for monitoring Oxidized using Zabbix, including API examples, metrics, and alert suggestions.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Monitoring Strategy](#-monitoring-strategy)
- [Oxidized API](#-oxidized-api)
- [Zabbix Configuration](#-zabbix-configuration)
- [Metrics to Monitor](#-metrics-to-monitor)
- [Alert Definitions](#-alert-definitions)
- [Example Queries](#-example-queries)

---

## 🎯 Overview

Oxidized exposes a **REST API** that provides real-time status information about:
- Service availability
- Device backup status
- Last successful backup timestamps
- Failure counts

This data can be consumed by Zabbix using **HTTP Agent** items.

### Monitoring Endpoints

| Endpoint | Description | Use Case |
|----------|-------------|----------|
| `http://host:8888/` | Service health | Check if Oxidized is running |
| `http://host:8888/nodes.json` | All node status | Per-device monitoring |
| `http://host:8888/node/show/{name}` | Individual node detail | Troubleshooting |
| `http://host:8888/reload` | Reload inventory (POST) | Manual refresh |

---

## 📈 Monitoring Strategy

### What to Monitor

1. Service Availability
   - Is Oxidized responding?
   - Is port 8888 reachable?

2. Backup Freshness
   - When was the last successful backup per device?
   - Are any devices stale (not backed up in > 2 hours)?

3. Backup Success Rate
   - How many devices are failing?
   - What's the overall success rate?

4. System Resources
   - Container CPU usage
   - Container memory usage
   - Disk space in `/srv/oxidized`

5. Git Repository Health
   - Is the Git repository growing?
   - Are commits being made?

### Monitoring Frequency

- **Service health**: Every 1 minute
- **Node status**: Every 5 minutes
- **Resource usage**: Every 5 minutes
- **Disk space**: Every 10 minutes

---

## 🔌 Oxidized API

### API Overview

Oxidized provides a REST API on port 8888 by default. The API returns JSON data that can be parsed by Zabbix.

### Authentication

The default Oxidized configuration does **not** require authentication for API access. For production environments, consider:
- Firewall rules restricting access to monitoring server
- Reverse proxy with authentication
- Network isolation

### API Response Format

#### `/nodes.json` Response Structure

```json
[
  {
    "name": "switch-01",
    "full_name": "switch-01",
    "ip": "192.168.1.1",
    "group": "core",
    "model": "ios",
    "last": {
      "start": "2026-01-17 10:30:15 UTC",
      "end": "2026-01-17 10:30:22 UTC",
      "status": "success",
      "time": 7.234
    },
    "vars": {},
    "mtime": "2026-01-17 10:30:22 UTC",
    "status": "success",
    "time": 7.234
  },
  {
    "name": "router-01",
    "full_name": "router-01",
    "ip": "192.168.2.1",
    "group": "wan",
    "model": "ios",
    "last": {
      "start": "2026-01-17 10:31:05 UTC",
      "end": "2026-01-17 10:31:08 UTC",
      "status": "no_connection",
      "time": 3.156
    },
    "vars": {},
    "mtime": "2026-01-17 10:31:08 UTC",
    "status": "no_connection",
    "time": 3.156
  }
]
```

### Key Fields

- `name`: Device identifier
- `ip`: Device IP address
- `group`: Device group
- `model`: Device model type
- `status`: Current status (`success`, `no_connection`, `auth_fail`, etc.)
- `last.end`: Timestamp of last backup attempt
- `last.status`: Result of last backup
- `time`: Backup duration in seconds

---

## ⚙️ Zabbix Configuration

### Zabbix HTTP Agent Setup

Zabbix can poll the Oxidized API using **HTTP Agent** items.

### Host Configuration

1. **Create Zabbix Host**:
   - Host name: `Oxidized Server`
   - Host groups: `Network Management`
   - Interfaces: Agent interface (optional), can use HTTP checks only

2. **Define Macros**:
   - `{$OXIDIZED.URL}` = `http://oxidized-host:8888`
   - `{$OXIDIZED.STALE_THRESHOLD}` = `7200` (2 hours in seconds)

### Item Configuration Examples

#### 1. Service Health Check

```ini
Name: Oxidized: Service Status
Type: HTTP Agent
Key: oxidized.service.status
URL: {$OXIDIZED.URL}/
Request type: GET
Timeout: 5s
Update interval: 1m
History: 7d
Trends: 90d

Value mapping:
  200 = Service UP
  Others = Service DOWN

Preprocessing:
  1. Check for HTTP 200 status code
```

#### 2. All Nodes Status (JSON Data)

```ini
Name: Oxidized: All Nodes Status (JSON)
Type: HTTP Agent
Key: oxidized.nodes.json
URL: {$OXIDIZED.URL}/nodes.json
Request type: GET
Timeout: 10s
Update interval: 5m
History: 1d
Type of information: Text

Preprocessing:
  1. JSONPath: $[*]
```

#### 3. LLD Rule: Discover Devices

```ini
Name: Oxidized: Device Discovery
Type: HTTP Agent
Key: oxidized.devices.discovery
URL: {$OXIDIZED.URL}/nodes.json
Request type: GET
Timeout: 10s
Update interval: 1h

LLD Preprocessing:
  1. JSONPath: $[*]
  2. JavaScript to format for Zabbix LLD

LLD Macros:
  {#DEVICE_NAME}
  {#DEVICE_IP}
  {#DEVICE_GROUP}
  {#DEVICE_MODEL}
```

---

## 📊 Metrics to Monitor

### 1. Service-Level Metrics

| Metric | Description | Zabbix Item Key | Alert Threshold |
|--------|-------------|-----------------|-----------------|
| Service Reachable | HTTP 200 response | `oxidized.service.up` | < 1 (DOWN) |
| Total Devices | Count of all devices | `oxidized.devices.total` | N/A |
| Successful Devices | Count with status=success | `oxidized.devices.success` | N/A |
| Failed Devices | Count with status≠success | `oxidized.devices.failed` | > 5 |
| Success Rate | (success/total)*100 | `oxidized.devices.success_rate` | < 90% |

### 2. Per-Device Metrics (via LLD)

| Metric | Description | Zabbix Item Key | Alert Threshold |
|--------|-------------|-----------------|-----------------|
| Device Status | Current backup status | `oxidized.device[{#DEVICE_NAME},status]` | ≠ "success" |
| Last Backup Time | Timestamp of last backup | `oxidized.device[{#DEVICE_NAME},last_backup]` | > 2 hours ago |
| Backup Duration | Time to complete backup | `oxidized.device[{#DEVICE_NAME},duration]` | > 60s |
| Backup Age | Time since last success | `oxidized.device[{#DEVICE_NAME},age]` | > 7200s |

### 3. System Resource Metrics

| Metric | Description | Command/Check |
|--------|-------------|---------------|
| CPU Usage | Container CPU % | `podman stats oxidized --no-stream` |
| Memory Usage | Container RAM | `podman stats oxidized --no-stream` |
| Disk Space | `/srv/oxidized` free space | `df -h /srv/oxidized` |
| Git Repo Size | Size of configs.git | `du -sh /srv/oxidized/git` |

---

## 🚨 Alert Definitions

### Critical Alerts

#### 1. Oxidized Service Down

```ini
Name: Oxidized: Service is Down
Expression: {Oxidized Server:oxidized.service.up.last()}=0
Severity: Disaster
Duration: 2 minutes

Message:
Oxidized service is not responding on {$OXIDIZED.URL}

Action:
- Send notification to network team
- Attempt automatic restart: systemctl restart oxidized
```

#### 2. Device Backup Stale

```ini
Name: Oxidized: Device {#DEVICE_NAME} backup is stale
Expression: {Oxidized Server:oxidized.device[{#DEVICE_NAME},age].last()}>7200
Severity: High
Duration: 5 minutes

Message:
Device {#DEVICE_NAME} ({#DEVICE_IP}) has not been backed up in over 2 hours.
Last backup: {ITEM.LASTVALUE}

Action:
- Send notification
- Check device connectivity
- Review Oxidized logs
```

### Warning Alerts

#### 3. Device Backup Failed

```ini
Name: Oxidized: Device {#DEVICE_NAME} backup failed
Expression: {Oxidized Server:oxidized.device[{#DEVICE_NAME},status].str("success")}=0
Severity: Warning
Duration: 15 minutes

Message:
Device {#DEVICE_NAME} backup status: {ITEM.LASTVALUE}

Action:
- Send notification
- Log for review
```

#### 4. Low Success Rate

```ini
Name: Oxidized: Low success rate
Expression: {Oxidized Server:oxidized.devices.success_rate.last()}<90
Severity: Warning
Duration: 30 minutes

Message:
Oxidized success rate is {ITEM.LASTVALUE}%.
Check failed devices.

Action:
- Send notification
- Review failed devices list
```

### Informational Alerts

#### 5. Disk Space Low

```ini
Name: Oxidized: Low disk space
Expression: {Oxidized Server:vfs.fs.size[/srv/oxidized,pfree].last()}<20
Severity: Warning
Duration: 10 minutes

Message:
Oxidized disk space is at {ITEM.LASTVALUE}% free.

Action:
- Send notification
- Review and rotate logs
- Check Git repository size
```

---

## 🔍 Example Queries

### Manual API Queries with curl

#### Check Service Health

```bash
# Simple health check
curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/

# Expected output: 200
```

#### Get All Nodes

```bash
# Fetch all nodes
curl -s http://localhost:8888/nodes.json | jq '.'

# Count total devices
curl -s http://localhost:8888/nodes.json | jq '. | length'

# Count successful devices
curl -s http://localhost:8888/nodes.json | \
  jq '[.[] | select(.status == "success")] | length'

# Count failed devices
curl -s http://localhost:8888/nodes.json | \
  jq '[.[] | select(.status != "success")] | length'
```

#### Get Specific Device Status

```bash
# Get single device
curl -s http://localhost:8888/node/show/switch-01 | jq '.'

# Get last backup time for device
curl -s http://localhost:8888/nodes.json | \
  jq '.[] | select(.name == "switch-01") | .last.end'

# Get all failed devices
curl -s http://localhost:8888/nodes.json | \
  jq '[.[] | select(.status != "success") | {name, ip, status}]'
```

#### Calculate Backup Age

```bash
# Get devices with stale backups (>2 hours)
curl -s http://localhost:8888/nodes.json | jq '
  .[] |
  select(.last.end) |
  {
    name,
    last_backup: .last.end,
    status
  }
'
```

### Zabbix Item Scripts

#### JSONPath for Device Discovery

```javascript
// Zabbix LLD JSON format
var nodes = JSON.parse(value);
var lld = [];

nodes.forEach(function(node) {
  lld.push({
    "{#DEVICE_NAME}": node.name,
    "{#DEVICE_IP}": node.ip,
    "{#DEVICE_GROUP}": node.group,
    "{#DEVICE_MODEL}": node.model
  });
});

return JSON.stringify(lld);
```

#### JavaScript for Success Rate

```javascript
// Calculate success rate
var nodes = JSON.parse(value);
var total = nodes.length;
var success = nodes.filter(function(n) {
  return n.status === "success";
}).length;

return total > 0 ? (success / total * 100).toFixed(2) : 0;
```

---

## 📝 Monitoring Checklist

### Initial Setup

- [ ] Oxidized API is accessible from Zabbix server
- [ ] HTTP Agent items configured
- [ ] Device discovery LLD rule created
- [ ] Triggers defined for critical alerts
- [ ] Notification actions configured

### Regular Checks

- [ ] Verify all devices are discovered
- [ ] Check alert noise (too many false positives?)
- [ ] Review failed device trends
- [ ] Validate backup freshness
- [ ] Monitor disk space trends

---

## 🛠️ Troubleshooting Monitoring

### Issue: API Not Reachable from Zabbix

**Diagnosis**:

```bash
# From Zabbix server
curl -v http://oxidized-host:8888/nodes.json

# Check firewall
sudo firewall-cmd --list-ports

# Check service status
systemctl status oxidized
```

**Solution**: Open port 8888 in firewall, verify service is running

### Issue: Stale Data in Zabbix

**Diagnosis**:
- Check Zabbix item update interval
- Verify Oxidized is polling devices

**Solution**: Adjust update intervals, check Oxidized logs

### Issue: Too Many False Positive Alerts

**Diagnosis**: Review trigger thresholds and durations

**Solution**:
- Increase alert duration
- Adjust thresholds
- Add maintenance windows for known issues

---

## 📚 Additional Resources

### Oxidized API Documentation

- **GitHub**: <https://github.com/yggdrasil-network/oxidized>
- **REST API**: <https://github.com/yggdrasil-network/oxidized/blob/master/docs/API.md>

### Zabbix HTTP Agent

- **Documentation**: <https://www.zabbix.com/documentation/current/en/manual/config/items/itemtypes/http>
- **JSONPath**: <https://www.zabbix.com/documentation/current/en/manual/config/macros/usermacros_functions>

---

## 🎯 Quick Start Example

### Minimal Monitoring Setup

For a quick start, monitor these essentials:

1. Service Health (every 1 min):

   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://oxidized:8888/
   ```

2. Total Devices (every 5 min):

   ```bash
   curl -s http://oxidized:8888/nodes.json | jq 'length'
   ```

3. Failed Devices Count (every 5 min):

   ```bash
   curl -s http://oxidized:8888/nodes.json | \
     jq '[.[] | select(.status != "success")] | length'
   ```

4. Success Rate (every 5 min):

   ```bash
   curl -s http://oxidized:8888/nodes.json | jq '
     (([.[] | select(.status == "success")] | length) / length * 100)
   '
   ```

---

## 📊 Sample Zabbix Dashboard

### Recommended Dashboard Widgets

1. **Service Status** - Simple indicator (UP/DOWN)
2. **Success Rate Gauge** - Percentage gauge
3. **Device Status Pie Chart** - Success vs Failed
4. **Failed Devices Table** - List of currently failed devices
5. **Backup Freshness Graph** - Time since last backup per device
6. **Historical Success Rate** - Graph over time

---

**Monitoring Best Practices**:
- Start simple, add complexity as needed
- Focus on actionable alerts
- Review and tune thresholds regularly
- Document your alert response procedures

🎉 **Happy Monitoring!**
