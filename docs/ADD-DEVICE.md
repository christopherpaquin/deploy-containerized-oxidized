# Add Device Script

## Overview

The `add-device.sh` script provides an interactive, user-friendly way to add network devices to Oxidized's router.db inventory file. It includes comprehensive validation, automatic backups, and step-by-step guidance through the device addition process.

## Location

- **Repository:** `scripts/add-device.sh`
- **Installed:** `/var/lib/oxidized/scripts/add-device.sh` (after deployment)

## Features

✅ **Interactive prompts** - Guided step-by-step device addition
✅ **Input validation** - Validates hostname, IP, model, and format at each step
✅ **Smart suggestions** - Shows available OS types and existing groups
✅ **Duplicate detection** - Prevents adding devices with existing names
✅ **Credential management** - Shows default credentials, allows override
✅ **Automatic backups** - Creates timestamped backup before any changes
✅ **Append-only** - Never overwrites router.db, only appends
✅ **Full validation** - Runs syntax check on all entries after addition
✅ **Comprehensive OS list** - 20+ common device models with descriptions
✅ **Password security** - Passwords never displayed in plain text

## Usage

```bash
# Run the interactive script
sudo /var/lib/oxidized/scripts/add-device.sh

# Or from the repository
sudo ./scripts/add-device.sh
```

## What It Prompts For

### 1. Device Hostname
- Validates format (alphanumeric, hyphens, underscores, dots)
- Checks for duplicates in router.db
- Examples: `core-router01`, `switch-dc1`, `fw01.example.com`

### 2. IP Address or FQDN
- Validates IPv4 format or hostname format
- Accepts both IP addresses and fully qualified domain names
- Examples: `10.1.1.1`, `192.168.1.254`, `router.example.com`

### 3. Device Model (OS Type)
Displays a comprehensive list of supported models:
- Cisco: ios, iosxr, iosxe, nxos, asa
- Juniper: junos, screenos
- Arista: eos
- HP: procurve, comware
- Aruba: aoscx, arubaos
- Fortinet: fortios
- Palo Alto: panos
- Others: mikrotik, vyos, edgeos, tplink, and more

### 4. Group Assignment
- Shows existing groups from router.db
- Allows creating new groups
- Groups are optional but recommended for organization
- Examples: `core`, `datacenter`, `branch`, `firewalls`

### 5. Credentials
- Shows default username from config (password hidden)
- Asks if you want to override defaults
- If yes, prompts for:
  - Device-specific username
  - Device-specific password (with confirmation)
- Passwords never displayed in output

## Example Session

```
╔══════════════════════════════════════════════════════════════════════════╗
║              Oxidized Device Management Tool                         ║
║                  Add Device to router.db                             ║
╚══════════════════════════════════════════════════════════════════════════╝

[INFO] This tool will help you add a new device to the Oxidized inventory
[INFO] Router database: /var/lib/oxidized/config/router.db

[INFO] Step 1: Device Hostname
[?] Enter device hostname (e.g., switch01, core-router-01):
datacenter-sw01
[✓] Hostname: datacenter-sw01

[INFO] Step 2: IP Address or FQDN
[?] Enter IP address or FQDN (e.g., 10.1.1.1 or router.example.com):
10.10.1.100
[✓] IP/Hostname: 10.10.1.100

[INFO] Step 3: Device Model/OS Type

Available Device Models:

  1   aoscx           - Aruba AOS-CX
  2   arubaos         - Aruba ArubaOS
  3   asa             - Cisco ASA
  4   comware         - HP Comware
  5   eos             - Arista EOS
  6   fortios         - FortiGate FortiOS
  7   ios             - Cisco IOS
  8   iosxe           - Cisco IOS XE
  9   iosxr           - Cisco IOS XR
  10  junos           - Juniper JunOS
  11  nxos            - Cisco Nexus
  12  procurve        - HP ProCurve
  ... (and more)

[INFO] For a complete list, visit: https://github.com/yggdrasil-network/oxidized/tree/master/lib/oxidized/model

[?] Enter device model (e.g., ios, nxos, junos, fortios):
procurve
[✓] Device model: procurve (HP ProCurve)

[INFO] Step 4: Group Assignment

Existing groups in router.db:
  - core
  - datacenter
  - branch

[INFO] You can use an existing group or create a new one

[?] Enter group name (e.g., datacenter, branch, core, firewalls):
datacenter
[✓] Using existing group: datacenter

[INFO] Step 5: Device Credentials

[INFO] Default credentials from config:
  Username: netadmin
  Password: ********** (hidden)

Do you want to use the default credentials for this device? (Y/n): y

[✓] Using credentials from config

╔══════════════════════════════════════════════════════════════════════════╗
║                      Entry to be Added                               ║
╚══════════════════════════════════════════════════════════════════════════╝

Entry Details:
  Hostname: datacenter-sw01
  IP/FQDN:  10.10.1.100
  Model:    procurve
  Group:    datacenter
  Credentials: Using credentials from config

Router.db format:
  datacenter-sw01:10.10.1.100:procurve:datacenter:netadmin:password123

[✓] Entry format is valid

Add this device to router.db? (y/N): y

[INFO] Creating backup...
[✓] Backup created: /var/lib/oxidized/config/backup/router.db.20260122_154530

[INFO] Adding entry to router.db...
[✓] Entry added to router.db

[INFO] Validating router.db...

╔══════════════════════════════════════════════════════════════════════════╗
║           Oxidized Router Database Syntax Validator                  ║
╚══════════════════════════════════════════════════════════════════════════╝

[INFO] Validating: /var/lib/oxidized/config/router.db
[OK] Line 96: test-device (192.0.2.1, ios) [using global credentials]
[OK] Line 97: datacenter-sw01 (10.10.1.100, procurve) [using global credentials]

╔══════════════════════════════════════════════════════════════════════════╗
║                         Validation Summary                           ║
╚══════════════════════════════════════════════════════════════════════════╝

Total Lines: 97
Valid Devices: 2
Warnings: 0
Errors: 0

✓ Validation PASSED

╔══════════════════════════════════════════════════════════════════════════╗
║                    Device Added Successfully!                        ║
╚══════════════════════════════════════════════════════════════════════════╝

[✓] Device 'datacenter-sw01' has been added to router.db
[INFO] Oxidized will pick up this device on the next poll cycle

Next steps:
  1. Test the device: test-device.sh datacenter-sw01
  2. Check Oxidized logs: tail -f /var/lib/oxidized/data/oxidized.log
  3. Restart Oxidized (if needed): systemctl restart oxidized.service
```

## Workflow

1. **Pre-validation**
   - Checks write permissions
   - Verifies router.db accessibility

2. **Data Collection**
   - Prompts for each field with validation
   - Shows available options and existing values
   - Validates format at each step

3. **Entry Preview**
   - Shows complete entry details
   - Displays router.db format
   - Masks password for security

4. **Confirmation**
   - User confirms before any changes
   - Can cancel at this point

5. **Backup Creation**
   - Creates timestamped backup in `/var/lib/oxidized/config/backup/`
   - Format: `router.db.YYYYMMDD_HHMMSS`
   - Never overwrites existing backups

6. **Entry Addition**
   - Appends to router.db (never overwrites)
   - Maintains proper format

7. **Validation**
   - Runs full syntax validation on entire router.db
   - Reports any issues found
   - Warns about pre-existing invalid entries

## Safety Features

### Never Overwrites
- Only appends to router.db
- Original file is preserved
- All entries remain intact

### Automatic Backups
- Created before any changes
- Timestamped uniquely
- Stored in dedicated backup directory
- Easy to restore if needed

### Input Validation
- Hostname format validation
- IP address / FQDN validation
- Duplicate name detection
- Model name verification (warning for unknown)
- Entry format validation (5 colons, 6 fields)

### Error Handling
- Clear error messages
- Option to retry on validation failure
- Graceful exit on user cancellation
- No partial writes to router.db

## Files and Directories

### Created/Modified
- `/var/lib/oxidized/config/router.db` - Device inventory (appended)
- `/var/lib/oxidized/config/backup/router.db.YYYYMMDD_HHMMSS` - Backup

### Used for Reference
- `/var/lib/oxidized/config/config` - For default credentials
- `/var/lib/oxidized/scripts/validate-router-db.sh` - For validation

## Supported Device Models

The script includes a built-in list of 20+ common device models:

| Model | Description |
|-------|-------------|
| ios | Cisco IOS |
| iosxr | Cisco IOS XR |
| iosxe | Cisco IOS XE |
| nxos | Cisco Nexus |
| asa | Cisco ASA |
| junos | Juniper JunOS |
| screenos | Juniper ScreenOS |
| eos | Arista EOS |
| procurve | HP ProCurve |
| comware | HP Comware |
| aoscx | Aruba AOS-CX |
| arubaos | Aruba ArubaOS |
| fortios | FortiGate FortiOS |
| panos | Palo Alto PAN-OS |
| powerconnect | Dell PowerConnect |
| vyos | VyOS |
| edgeos | EdgeOS |
| mikrotik | MikroTik RouterOS |
| routeros | MikroTik RouterOS (alt) |
| tplink | TP-Link |
| opengear | Opengear |
| ironware | Brocade IronWare |

**Note:** Custom or less common models can still be used - the script will warn but allow them.

For complete model list, see: https://github.com/yggdrasil-network/oxidized/tree/master/lib/oxidized/model

## Permissions

The script requires:
- Write access to `/var/lib/oxidized/config/router.db`
- Write access to `/var/lib/oxidized/config/backup/`
- Typically needs to be run with `sudo`

## Integration with Deploy Script

The script is automatically copied to `/var/lib/oxidized/scripts/` when you run:

```bash
sudo ./scripts/deploy.sh
```

It's included in the list of helper scripts that are deployed alongside validate-router-db.sh, test-device.sh, and health-check.sh.

## Troubleshooting

### Permission Denied
```bash
# Run with sudo
sudo /var/lib/oxidized/scripts/add-device.sh
```

### Validation Script Not Found
The script looks for validate-router-db.sh in multiple locations:
- Same directory as router.db
- `/var/lib/oxidized/scripts/`
- Script's own directory

If validation is skipped, run manually:
```bash
/var/lib/oxidized/scripts/validate-router-db.sh
```

### Entry Not Showing in Web UI
After adding a device:
1. Wait for next poll cycle (check `interval` in config)
2. Or restart Oxidized: `systemctl restart oxidized.service`
3. Check logs: `tail -f /var/lib/oxidized/data/oxidized.log`

### Duplicate Name Error
Device names must be unique. Either:
- Use a different name
- Remove/comment out the existing entry first

## Related Scripts

- **validate-router-db.sh** - Validates router.db syntax
- **test-device.sh** - Tests device connectivity and triggers backup
- **health-check.sh** - Checks overall Oxidized health

## Best Practices

1. ✅ Use this script instead of manual editing when possible
2. ✅ Test devices immediately after adding: `test-device.sh <device-name>`
3. ✅ Use global credentials unless device-specific is required
4. ✅ Use consistent group naming scheme
5. ✅ Check validation output for warnings
6. ✅ Keep backups directory clean (remove old backups periodically)
7. ✅ Document any custom/unusual device models in comments

## Exit Codes

- `0` - Success
- `1` - Error (validation failed, permission denied, user cancelled, etc.)

## Version History

- **v1.0** (2026-01-22) - Initial release
  - Interactive device addition
  - Comprehensive validation
  - Automatic backups
  - Support for 20+ device models

## See Also

- [DEVICE-MANAGEMENT.md](../DEVICE-MANAGEMENT.md) - Complete device management guide
- [router.db.template](../inventory/router.db.template) - Router.db format documentation
- [validate-router-db.sh](validate-router-db.sh) - Syntax validation script
- [test-device.sh](test-device.sh) - Device testing script

---

**Last Updated:** 2026-01-22
**Script Version:** 1.0
