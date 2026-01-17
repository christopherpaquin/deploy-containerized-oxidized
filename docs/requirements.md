Oxidized Deployment -- Requirements & Design Specification
=========================================================

1\. Purpose
-----------

This project defines a **production-grade, containerized deployment of Oxidized** for network configuration backup and auditing.

The goals are:

-   Reliable configuration backups

-   Git-based versioning from day one

-   Fully containerized (Podman)

-   Idempotent deployment

-   Easy recovery and upgrades

-   Observable and monitorable

-   Designed for long-term maintenance

This document serves as the **source of truth** for implementation and automation.

* * * * *

2\. Scope
---------

### In Scope

-   Oxidized deployment via Podman

-   Persistent storage for:

    -   configs

    -   git repository

    -   logs

-   CSV-based inventory

-   Web UI enabled

-   Git output (local repository)

-   Log rotation

-   SELinux-safe configuration

-   Monitoring readiness (Zabbix-compatible)

-   Version-pinned container image

-   RHEL 10 compatible

### Out of Scope (for now)

-   GitLab/GitHub integration

-   NetBox integration

-   Multi-instance clustering

-   High availability

-   UI customization

-   Device provisioning

* * * * *

3\. Target Platform
-------------------

| Component | Requirement |
| --- | --- |
| OS | RHEL 10 |
| Container runtime | Podman (rootful) |
| Init system | systemd |
| SELinux | Enforcing |
| Network | Internal LAN |
| Expected scale | ~100 devices |
| Polling frequency | Hourly |

* * * * *

4\. Functional Requirements
---------------------------

### 4.1 Oxidized Service

-   Must run as a container

-   Must survive restart/redeployment

-   Must expose Web UI

-   Must expose REST API

-   Must store device configs in Git

### 4.2 Inventory

-   Inventory source: CSV

-   CSV fields:

    -   name

    -   ip

    -   model

    -   group

-   CSV must be editable outside the container

-   Oxidized must reload inventory without rebuild

### 4.3 Git Integration

-   Local Git repository

-   One repo for all devices

-   Automatic commits

-   Human-readable diffs

-   No remote required initially

### 4.4 Logging

-   Logs written to disk (not journald)

-   Log path:

    `/var/lib/oxidized/logs`

-   Log rotation:

    -   Daily

    -   14-day retention

    -   Compressed

-   No logs written to `/var/log`

### 4.5 Persistence

All state must persist across container recreation.

Persisted paths:

| Path | Purpose |
| --- | --- |
| /etc/oxidized | Config |
| /var/lib/oxidized | State |
| /var/lib/oxidized/configs.git | Git repo |
| /var/lib/oxidized/logs | Logs |

* * * * *

5\. Non-Functional Requirements
-------------------------------

### Stability

-   Use pinned container image version

-   No `latest` tags

-   Manual upgrade process

### Security

-   No plaintext secrets in repo

-   SELinux enforced

-   No privileged container

-   Minimal exposed ports

### Maintainability

-   Idempotent deployment

-   Declarative configuration

-   Minimal manual steps

-   Clear directory structure

### Observability

-   Web UI accessible

-   API available for monitoring

-   Compatible with Zabbix polling

-   Detect:

    -   service down

    -   stale backups

    -   repeated failures

* * * * *

6\. Container Requirements
--------------------------

### Image

`docker.io/oxidized/oxidized:<version>`

### Runtime

-   Podman

-   Systemd-managed (Quadlet or unit file)


### **6.1 Container Lifecycle Management**

Oxidized **must be deployed using Podman Quadlets** and managed by **systemd**.

Manual `podman run` commands are **not permitted** for production deployment.

#### Requirements:

-   A `.container` file must be used

-   The service must:

    -   start automatically on boot

    -   restart on failure

    -   be manageable via `systemctl`

-   No manual container lifecycle management

#### Expected behavior:

`systemctl enable oxidized
systemctl start oxidized
systemctl status oxidized`

* * * * *

### **6.2 Quadlet Requirements**

The Quadlet configuration must:

-   Use a pinned Oxidized image version

-   Define all required bind mounts

-   Apply SELinux labeling (`:Z`)

-   Expose port 8888

-   Restart automatically

-   Not use `latest` tags

* * * * *

What This Means Practically
---------------------------

Instead of:

`podman run ...`

You will have:

`/etc/containers/systemd/oxidized.container`

Which generates:

`oxidized.service`

And is controlled via:

`systemctl enable --now oxidized`

* * * * *

Why This Matters (and You're Right to Ask)
------------------------------------------

Without Quadlets:

-   Containers won't reliably start after reboot

-   Changes aren't tracked declaratively

-   Automation becomes brittle

-   Troubleshooting becomes harder

-   You lose the benefit of systemd integration

With Quadlets:

-   Fully declarative

-   Reproducible

-   Version-controllable

-   Safe upgrades

-   Clean rollback

* * * * *

### Ports

| Port | Purpose |
| --- | --- |
| 8888 | Web UI / API |

* * * * *

7\. Directory Layout (Host)
---------------------------

`/srv/oxidized/
├── config/
│   └── config
├── inventory/
│   └── devices.csv
├── data/
│   └── nodes/
├── git/
│   └── configs.git/
└── logs/
    └── oxidized.log`

* * * * *

8\. Configuration Requirements
------------------------------

### Oxidized Config Must:

-   Use CSV source

-   Use Git output

-   Log to `/var/lib/oxidized/logs`

-   Bind REST API to `0.0.0.0`

* * * * *

9\. Logging & Rotation
----------------------

### Log location

`/var/lib/oxidized/logs/oxidized.log`

### Rotation

-   Managed by host

-   logrotate

-   No container-based rotation

* * * * *

10\. Monitoring & Alerting
--------------------------

### Required Signals

-   Service running

-   API reachable

-   Last backup time per device

-   Failed backup detection

-   Disk usage

### Monitoring Method

-   Zabbix HTTP agent

-   JSON API polling

-   Threshold-based alerts

* * * * *

11\. Upgrade Policy
-------------------

-   Image version pinned

-   Manual upgrade only

-   Rollback supported

-   No auto-updates

* * * * *

12\. Future Enhancements (Not Implemented Yet)
----------------------------------------------

-   NetBox inventory

-   Git remote push

-   Slack notifications

-   Secrets manager

-   Dashboard UI

-   Multi-instance support

* * * * *

13\. Success Criteria
---------------------

The deployment is considered successful when:

-   Oxidized runs continuously

-   Devices are backed up hourly

-   Git history is populated

-   Logs rotate cleanly

-   No data loss occurs during restart

-   Zabbix can monitor health



