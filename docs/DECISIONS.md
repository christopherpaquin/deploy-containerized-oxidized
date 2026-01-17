# 📝 Implementation Decisions

This document records key implementation decisions made during the design and development of this containerized Oxidized deployment.

---

## 🎯 Purpose

This document serves as a **decision log** to:
- Explain why specific approaches were chosen
- Document alternatives considered
- Provide context for future maintainers
- Justify deviations from common practices

---

## 📋 Decision Log

### Decision 1: Podman Quadlets vs Traditional systemd Unit

**Date**: 2026-01-17

**Decision**: Use Podman Quadlets (`.container` files) instead of traditional systemd unit files

**Context**:
- Need systemd integration for automatic startup on boot
- Want declarative container configuration
- Require reliable restart policies

**Alternatives Considered**:

1. **Manual `podman run` commands**
   - ❌ Not persistent across reboots
   - ❌ Configuration not tracked
   - ❌ Difficult to manage

2. **Traditional systemd unit file with ExecStart**
   - ✅ Works reliably
   - ❌ Verbose and error-prone
   - ❌ Hard to maintain long container configurations

3. **Podman Quadlets** (CHOSEN)
   - ✅ Declarative configuration
   - ✅ Automatic systemd integration
   - ✅ Clean, readable syntax
   - ✅ Version-controllable
   - ✅ Systemd native (247+)

**Rationale**:
Quadlets provide the best balance of simplicity, maintainability, and systemd integration. They generate proper systemd units automatically and are the recommended approach for RHEL 9/10.

**References**:
- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- RHEL 10 systemd version: 252+ (supports Quadlets)

---

### Decision 2: Regular Git Repository vs Bare Repository

**Date**: 2026-01-17

**Decision**: Use **regular Git repository** at `/srv/oxidized/git/configs.git`

**Context**:
- Need to store device configurations in Git
- Want to inspect files easily
- Single-server deployment (no push/pull initially)

**Alternatives Considered**:

1. **Bare Git repository** (`.git` only, no working tree)
   - ✅ Traditional for Git output
   - ✅ Required for remote push
   - ❌ Can't easily view files on disk
   - ❌ Requires Git commands to inspect content

2. **Regular Git repository** (CHOSEN)
   - ✅ Working directory with actual files
   - ✅ Easy to inspect: `ls /srv/oxidized/git/configs.git/`
   - ✅ Simpler for beginners
   - ✅ No loss of functionality for single-server
   - ⚠️ Requires conversion if adding remote push later

**Rationale**:
For a single-server deployment without remote Git integration, a regular repository is more user-friendly. Files can be directly inspected, compared, and accessed without Git commands. If remote push is needed later, the repository can be converted to bare.

**Migration Path** (if needed in future):
```bash
cd /srv/oxidized/git
git clone --bare configs.git configs-bare.git
mv configs.git configs.git.old
mv configs-bare.git configs.git
```

---

### Decision 3: Host Path `/srv/oxidized` vs `/var/lib/oxidized`

**Date**: 2026-01-17

**Decision**: Use `/srv/oxidized` for host persistent storage

**Context**:
- Need persistent storage on host
- SELinux enforcing
- Standard filesystem hierarchy

**Alternatives Considered**:

1. **`/var/lib/oxidized`**
   - ✅ Standard for application state
   - ❌ Mixed with other `/var/lib` content
   - ⚠️ May conflict with native package

2. **`/opt/oxidized`**
   - ✅ For third-party software
   - ❌ Historically for pre-compiled software
   - ❌ Less standard for data

3. **`/srv/oxidized`** (CHOSEN)
   - ✅ Designed for site-specific data
   - ✅ Clear separation from system paths
   - ✅ Easier to backup (isolated)
   - ✅ No conflicts with potential native packages
   - ✅ Commonly used for containerized services

**Rationale**:
`/srv` is specifically intended for "data for services provided by the system" per FHS. This makes it ideal for containerized service data. It's also easier to manage, backup, and doesn't conflict with system paths.

**References**:
- [Filesystem Hierarchy Standard (FHS)](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch03s17.html)

---

### Decision 4: SELinux `:Z` vs `:z` for Volume Labels

**Date**: 2026-01-17

**Decision**: Use `:Z` (exclusive) for all volume mounts

**Context**:
- SELinux enforcing mode required
- Container needs read/write access
- Single container accessing these volumes

**Alternatives Considered**:

1. **`:z` (shared)**
   - ✅ Allows multiple containers to share volume
   - ❌ Unnecessary for single-container deployment
   - ❌ Less restrictive security

2. **`:Z` (exclusive)** (CHOSEN)
   - ✅ Exclusive access to container
   - ✅ More restrictive (better security)
   - ✅ Appropriate for single-container use case
   - ✅ Automatic SELinux relabeling

3. **Manual `chcon` or `semanage`**
   - ❌ Not idempotent
   - ❌ More complex
   - ❌ Violates "boring solutions" principle
   - ❌ `chcon` changes are not persistent across relabeling

**Rationale**:
Since only one container (Oxidized) accesses these volumes, `:Z` provides appropriate isolation and automatic SELinux context management without requiring manual commands.

**References**:
- [Podman SELinux Documentation](https://docs.podman.io/en/latest/markdown/podman-run.1.html#security-opt)
- CONTEXT.md: "Adhere to SELinux best practices (semanage over chcon)"

---

### Decision 5: Log Location `/var/lib/oxidized/logs` vs `/var/log`

**Date**: 2026-01-17

**Decision**: Logs written to `/var/lib/oxidized/logs` (container path)

**Context**:
- Container environment
- Persistent log storage needed
- Logrotate on host

**Alternatives Considered**:

1. **Container `/var/log`**
   - ❌ Lost when container recreated
   - ❌ Not accessible on host

2. **Host `/var/log/oxidized`**
   - ✅ Standard location
   - ❌ Requires additional volume mount
   - ❌ Conflicts with container's internal logging
   - ⚠️ Requirements explicitly state: "No logs written to `/var/log`"

3. **`/var/lib/oxidized/logs`** (CHOSEN)
   - ✅ Persistent across container recreations
   - ✅ Part of application state
   - ✅ Accessible on host at `/srv/oxidized/logs`
   - ✅ Complies with requirements
   - ✅ Logrotate handles via copytruncate

**Rationale**:
Keeping logs within the application state directory (`/var/lib/oxidized`) ensures persistence and aligns with containerized application best practices. The host-side logrotate uses `copytruncate` to handle the open file.

**References**:
- docs/requirements.md: "No logs written to `/var/log`"

---

### Decision 6: Image Version Pinning - `0.30.1`

**Date**: 2026-01-17

**Decision**: Pin to `oxidized/oxidized:0.30.1` (stable release)

**Context**:
- Production deployment
- Need stability and predictability
- Must avoid breaking changes

**Alternatives Considered**:

1. **`latest` tag**
   - ❌ Unpredictable changes
   - ❌ Can break production
   - ❌ Violates requirements
   - ❌ No rollback path

2. **`nightly` or `master` tags**
   - ❌ Development/unstable
   - ❌ Not for production

3. **Specific version tag `0.30.1`** (CHOSEN)
   - ✅ Stable, tested release
   - ✅ Predictable behavior
   - ✅ Controlled upgrades
   - ✅ Easy rollback
   - ✅ Documented upgrade path

**Rationale**:
Version pinning is essential for production stability. `0.30.1` is a recent stable release. Upgrades are manual and deliberate, following the process in `UPGRADE.md`.

**Note**: When implementing this, verify the latest stable version on Docker Hub and update accordingly.

---

### Decision 7: Rootful vs Rootless Podman

**Date**: 2026-01-17

**Decision**: Use **rootful Podman** (run as root)

**Context**:
- Need to bind to port 8888
- Systemd integration required
- File permissions management

**Alternatives Considered**:

1. **Rootless Podman**
   - ✅ Better security isolation
   - ❌ Complications with port binding < 1024 (not applicable here)
   - ❌ User-level systemd units more complex
   - ❌ File permission complexity with host mounts
   - ⚠️ More difficult to manage in multi-admin environment

2. **Rootful Podman** (CHOSEN)
   - ✅ Simple systemd integration
   - ✅ Straightforward file permissions
   - ✅ System-wide service
   - ✅ Standard for production services
   - ✅ Container still runs as non-root inside (UID 30000)

**Rationale**:
Rootful Podman provides simpler management for a system-wide production service. The container itself runs as non-root (UID 30000), providing defense-in-depth. This is the standard approach for production services on RHEL.

**Security Note**:
The container process runs as UID 30000 inside the container (User=30000:30000 in Quadlet), providing process isolation even though Podman runs as root.

---

### Decision 8: Container User UID 30000

**Date**: 2026-01-17

**Decision**: Run container process as UID 30000

**Context**:
- Oxidized default user UID
- Security best practice
- SELinux compatibility

**Alternatives Considered**:

1. **Run as root inside container**
   - ❌ Security risk
   - ❌ Not necessary
   - ❌ Violates least privilege

2. **Run as UID 30000** (CHOSEN, Oxidized default)
   - ✅ Oxidized image default
   - ✅ Non-root process
   - ✅ Works with SELinux `:Z`
   - ✅ Least privilege

**Rationale**:
The official Oxidized image is designed to run as UID 30000. Using this default ensures compatibility and security. SELinux handles access control via context, making the specific UID less critical.

---

### Decision 9: Hourly Polling Interval

**Date**: 2026-01-17

**Decision**: Set default polling interval to 3600 seconds (1 hour)

**Context**:
- Network device configuration backup
- ~100 devices expected
- Balance between freshness and load

**Alternatives Considered**:

| Interval | Pros | Cons | Use Case |
|----------|------|------|----------|
| 15 min | Faster detection of changes | High load, more Git commits | Critical infrastructure |
| **1 hour** | **Balanced** | **Good freshness** | **General production** ✅ |
| 4 hours | Lower load | Slower change detection | Stable networks |
| Daily | Minimal load | Stale data risk | Non-critical devices |

**Rationale**:
Hourly polling provides a good balance:
- Changes detected within reasonable time
- Manageable load on network devices
- Reasonable Git commit frequency
- Aligns with typical change windows

**Note**: Interval is configurable in `/srv/oxidized/config/config`. Adjust based on change frequency and device count.

---

### Decision 10: Logrotate `copytruncate` Strategy

**Date**: 2026-01-17

**Decision**: Use `copytruncate` in logrotate configuration

**Context**:
- Container keeps log file handle open
- Can't signal container to reopen logs
- Need reliable rotation

**Alternatives Considered**:

1. **Traditional rotate (move and recreate)**
   - ❌ Requires signaling application
   - ❌ Complex with containers
   - ❌ May lose log entries

2. **`copytruncate`** (CHOSEN)
   - ✅ Works with open file handles
   - ✅ No signaling required
   - ✅ Container-friendly
   - ⚠️ Brief potential for log loss during copy (acceptable risk)

**Rationale**:
`copytruncate` is the standard approach for containerized applications where you cannot easily signal the process to reopen log files. The tiny window of potential log loss is acceptable for configuration backup logs.

---

### Decision 11: Credentials in Config File

**Date**: 2026-01-17

**Decision**: Default to plaintext credentials in config file with documentation for alternatives

**Context**:
- Need device authentication
- Balance simplicity vs security
- Different org requirements

**Alternatives Considered**:

1. **Plaintext in config** (CHOSEN as default)
   - ✅ Simple to implement
   - ✅ Works out of box
   - ⚠️ File must be protected (permissions)
   - ⚠️ Not suitable for high-security environments

2. **Environment variables**
   - ✅ Better security
   - ❌ Requires Quadlet modification
   - ❌ More complex for users

3. **Secrets manager integration**
   - ✅ Best security
   - ❌ Complex setup
   - ❌ External dependencies
   - ❌ Out of scope

**Rationale**:
Start with the simplest working solution (plaintext in protected file) with clear documentation about security implications and alternatives. Users can upgrade to environment variables or secrets managers as needed.

**Security Notes**:
- Config file permissions: 644 (readable by container)
- Located in `/srv/oxidized/config` (root-owned)
- NOT committed to Git (if users fork this repo)
- Document environment variable option in config file

---

### Decision 12: No GitLab/GitHub Integration (Initially)

**Date**: 2026-01-17

**Decision**: Use local Git repository only, no remote integration

**Context**:
- Simplify initial deployment
- Avoid external dependencies
- Requirements explicitly state "local Git only"

**Alternatives Considered**:

1. **Include GitLab/GitHub push**
   - ❌ Requires additional setup
   - ❌ Credentials management
   - ❌ Network dependencies
   - ❌ Out of scope per requirements

2. **Local Git only** (CHOSEN)
   - ✅ Simple, reliable
   - ✅ No external dependencies
   - ✅ Works offline
   - ✅ Can be added later if needed

**Rationale**:
Local Git provides version control and diff capabilities without external dependencies. Remote push can be added later as an enhancement if needed.

**Future Enhancement**:
If remote push is needed, Oxidized supports Git hooks and remote configuration. See [Oxidized Git Hooks Documentation](https://github.com/yggdrasil-network/oxidized/blob/master/docs/Hooks.md).

---

## 🔍 Decision Review Schedule

These decisions should be reviewed:
- **Annually**: Check if Oxidized best practices have changed
- **On major version upgrade**: Validate decisions still apply
- **When requirements change**: Re-evaluate if decisions still meet needs

---

## 📚 References

- [CONTEXT.md](ai/CONTEXT.md) - AI Engineering Standards
- [requirements.md](requirements.md) - Project Requirements
- [Podman Documentation](https://docs.podman.io/)
- [Oxidized Documentation](https://github.com/yggdrasil-network/oxidized)
- [RHEL 10 Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10)

---

## 📝 Adding New Decisions

When adding new decisions, use this format:

```markdown
### Decision N: [Title]

**Date**: YYYY-MM-DD

**Decision**: [What was decided]

**Context**: [Why this decision was needed]

**Alternatives Considered**:
1. Option A
   - ✅ Pro
   - ❌ Con
2. Option B (CHOSEN)
   - ✅ Pros
   - ❌ Cons

**Rationale**: [Why this option was chosen]

**References**: [Links to relevant docs]
```

---

**Last Updated**: 2026-01-17
