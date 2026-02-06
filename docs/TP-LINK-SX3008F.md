# TP-Link SX3008F Configuration Backup

## Status: COMMANDS DISCOVERED ✅

The TP-Link SX3008F requires **enable mode** to access the `show running-config` command.

## Working Commands

```
User mode (SX3008F>):
  - ? (shows available commands)
  - enable (enters privileged mode)

Enable mode (SX3008F#):
  - show running-config (displays full configuration)
  - show startup-config (NOT WORKING - returns error)
```

## Manual Backup via Telnet

```bash
telnet 10.1.10.48
# Login: admin
# Password: thunder123

enable
show running-config
# Press SPACE to page through output
# Copy output to save configuration
```

## Custom Oxidized Model Created

A custom model has been created at:
- `/var/lib/oxidized/config/models/sx3008f.rb`

### Model Features:
- Automatically enters enable mode after login
- Handles paging prompts ("Press any key to continue")
- Removes secrets (passwords, SNMP communities)
- Captures running configuration

### Configuration Contents

The SX3008F stores:
- VLAN configuration
- Interface descriptions
- Port-channel (LAG) configuration
- IP addresses
- Spanning tree settings
- Physical interface settings (10GbE ports)

### Example Output

```
vlan 1
 name "System-VLAN"
#
vlan 10
 name "DEFAULT"
#
interface port-channel 1
  description "columbia bond0"
  switchport general allowed vlan 10 untagged
  switchport pvid 10
#
interface ten-gigabitEthernet 1/0/1
  description "viper bond member"
  switchport general allowed vlan 10 untagged
  switchport pvid 10
  channel-group 3 mode active
#
interface vlan 10
  ip address 10.1.10.48 255.255.255.0
#
end
```

## Integration Challenges

### Issue: Ephemeral Container Filesystem

The Oxidized container resets its filesystem on restart, causing custom models placed in `/var/lib/gems/.../model/` to disappear.

### Attempted Solutions:
1. ✅ Placed model in persisted location: `/var/lib/oxidized/config/models/`
2. ❌ Symlink to Oxidized's model directory - doesn't persist across restarts
3. ❌ Direct copy to model directory - doesn't persist across restarts

### Working Solution (To Implement):

**Option A: Build Custom Container Image**
```dockerfile
FROM docker.io/oxidized/oxidized:0.35.0
COPY sx3008f.rb /var/lib/gems/3.3.0/gems/oxidized-0.35.0/lib/oxidized/model/
```

**Option B: Use Init Script**
Add to container startup script to copy model on boot:
```bash
cp /home/oxidized/.config/oxidized/models/sx3008f.rb \
   /var/lib/gems/3.3.0/gems/oxidized-0.35.0/lib/oxidized/model/
```

**Option C: Workaround with TP-Link Model**
Use the existing `tplink` model with group-level enable configuration.

## Current Device Entry

```
# router.db
SX3008F:10.1.10.48:sx3008f:lab-switches:admin:thunder123
```

## Next Steps

1. Implement one of the working solutions above
2. Test backup manually to verify
3. Commit the working configuration

## Testing Commands

### Force Manual Backup Test
```bash
/root/deploy-containerized-oxidized/scripts/test-tplink-real.exp
```

### Check If Device Appears in Oxidized
```bash
curl -s http://127.0.0.1:8889/nodes.json | jq -r '.[] | .name'
```

### View Backed Up Configuration
```bash
cat /var/lib/oxidized/repo/lab-switches/SX3008F
```

## Files Created

- `/var/lib/oxidized/config/models/sx3008f.rb` - Custom Oxidized model
- `/root/deploy-containerized-oxidized/scripts/test-sx3008f-real.exp` - Test script
- `/root/deploy-containerized-oxidized/scripts/discover-sx3008f.py` - Command discovery
- This documentation file

## References

- [TP-Link JetStream CLI Reference](https://static.tp-link.com/2020/202011/20201103/1910012904_T16_T26_CLI.pdf)
- [Oxidized Model Documentation](https://github.com/ytti/oxidized/blob/master/docs/Creating-Models.md)
