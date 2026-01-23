# 🔧 Adding Custom Oxidized Models

This guide explains how to add custom device models to your containerized Oxidized deployment.

---

## 📋 Table of Contents

- [Understanding Models](#understanding-models)
- [Check if Model Already Exists](#check-if-model-already-exists)
- [Adding Custom Models](#adding-custom-models)
- [Example: Adding TP-Link Model](#example-adding-tp-link-model)
- [Verifying Models](#verifying-models)
- [Troubleshooting](#troubleshooting)

---

## 🤖 Understanding Models

Oxidized models are Ruby classes that define how to interact with specific network device types. They handle:
- Login prompts and authentication
- Command execution
- Configuration retrieval
- Output formatting

**Model Location:**
- **Container Path:** `/home/oxidized/.config/oxidized/model/`
- **Standard Models:** Included in the oxidized container image (130+ models)
- **Custom Models:** Can be added via bind mount

**Model File Format:**
- Ruby class extending `Oxidized::Model`
- File extension: `.rb`
- Class name must match filename (e.g., `tplink.rb` → `class TPLink`)

---

## ✅ Check if Model Already Exists

Most standard models (including `tplink`) are already included in the oxidized container.

### Check Available Models

```bash
# If service is running
podman exec oxidized ls /home/oxidized/.config/oxidized/model/ | grep -i tplink

# List all models
podman exec oxidized ls /home/oxidized/.config/oxidized/model/ | sort

# Check specific model
podman exec oxidized test -f /home/oxidized/.config/oxidized/model/tplink.rb && echo "TP-Link model exists" || echo "TP-Link model not found"
```

### Standard Models Included

The oxidized container includes models from the official repository:
- https://github.com/ytti/oxidized/tree/master/lib/oxidized/model

Common models already included:
- `ios`, `iosxr`, `nxos`, `asa` (Cisco)
- `junos` (Juniper)
- `eos` (Arista)
- `procurve`, `comware` (HP)
- `fortios` (Fortinet)
- `panos` (Palo Alto)
- `tplink` (TP-Link) - **likely already included**
- And 120+ more...

---

## 🔨 Adding Custom Models

If you need to add a custom model or ensure a specific model is available:

### Step 1: Create Models Directory

```bash
# Create directory for custom models
sudo mkdir -p /var/lib/oxidized/models

# Set ownership (container uses UID 30000)
sudo chown -R 30000:30000 /var/lib/oxidized/models
sudo chmod 755 /var/lib/oxidized/models
```

### Step 2: Add Your Custom Model File

```bash
# Download or create your model file
sudo vim /var/lib/oxidized/models/custom_model.rb

# Example: Download TP-Link model (if not already in container)
sudo curl -o /var/lib/oxidized/models/tplink.rb \
  https://raw.githubusercontent.com/ytti/oxidized/master/lib/oxidized/model/tplink.rb

# Set permissions
sudo chown 30000:30000 /var/lib/oxidized/models/*.rb
sudo chmod 644 /var/lib/oxidized/models/*.rb
```

### Step 3: Mount Models Directory in Container

You have two options:

#### Option A: Manual Quadlet Edit (Quick)

Edit the Quadlet file directly:

```bash
# Edit Quadlet file
sudo vim /etc/containers/systemd/oxidized.container

# Add this line in the [Container] section (after other Volume lines):
Volume=/var/lib/oxidized/models:/home/oxidized/.config/oxidized/model:Z

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart oxidized.service
```

#### Option B: Update Deployment Script (Permanent)

To make this persistent across redeployments, you would need to:
1. Add `MOUNT_MODELS` variable to `.env`
2. Update the Quadlet template to include models mount
3. Update `deploy.sh` to handle models directory

**Note:** This requires modifying the deployment scripts (not covered in this guide).

### Step 4: Verify Model is Loaded

```bash
# Check if model file is accessible in container
podman exec oxidized ls -la /home/oxidized/.config/oxidized/model/ | grep tplink

# Check oxidized logs for model loading
podman logs oxidized | grep -i model

# Test with a device
# Add device to router.db with model: tplink
```

---

## 📝 Example: Adding TP-Link Model

The TP-Link model is likely already included, but here's how to add it if needed:

### Download TP-Link Model

```bash
# Create models directory
sudo mkdir -p /var/lib/oxidized/models
sudo chown 30000:30000 /var/lib/oxidized/models

# Download TP-Link model
sudo curl -o /var/lib/oxidized/models/tplink.rb \
  https://raw.githubusercontent.com/ytti/oxidized/master/lib/oxidized/model/tplink.rb

# Set permissions
sudo chown 30000:30000 /var/lib/oxidized/models/tplink.rb
sudo chmod 644 /var/lib/oxidized/models/tplink.rb
```

### Mount Models Directory

```bash
# Edit Quadlet file
sudo vim /etc/containers/systemd/oxidized.container

# Add this Volume line in [Container] section:
Volume=/var/lib/oxidized/models:/home/oxidized/.config/oxidized/model:Z

# Save and reload
sudo systemctl daemon-reload
sudo systemctl restart oxidized.service
```

### Add TP-Link Device to Inventory

```bash
# Edit router.db
sudo vim /var/lib/oxidized/config/router.db

# Add device with tplink model:
# Format: name:ip:model:group:username:password
tplink-switch01:192.168.1.1:tplink:switches:admin:password

# Restart service
sudo systemctl restart oxidized.service
```

---

## ✅ Verifying Models

### Check Model File Exists

```bash
# In container
podman exec oxidized test -f /home/oxidized/.config/oxidized/model/tplink.rb && echo "✓ Model exists"

# List all models
podman exec oxidized ls /home/oxidized/.config/oxidized/model/ | wc -l
```

### Test Model with Device

```bash
# Add test device to router.db
echo "test-tplink:192.168.1.1:tplink:test::" | sudo tee -a /var/lib/oxidized/config/router.db

# Trigger manual backup
curl -X POST http://localhost:8888/node/fetch/test-tplink

# Check logs
podman logs oxidized | tail -50
```

### Check Model Loading in Logs

```bash
# Watch for model-related errors
podman logs oxidized | grep -i "model\|tplink\|error"

# Check if model class is loaded
podman exec oxidized ruby -e "require '/home/oxidized/.config/oxidized/model/tplink.rb'; puts 'Model loaded'"
```

---

## 🔍 Troubleshooting

### Issue: Model Not Found

**Symptoms:**
```
Error: unknown model: tplink
```

**Solutions:**

1. **Verify model file exists:**
   ```bash
   podman exec oxidized ls -la /home/oxidized/.config/oxidized/model/tplink.rb
   ```

2. **Check file permissions:**
   ```bash
   # Should be readable by UID 30000
   podman exec oxidized ls -la /home/oxidized/.config/oxidized/model/ | grep tplink
   ```

3. **Verify mount point:**
   ```bash
   # Check if models directory is mounted
   podman exec oxidized mount | grep model
   ```

4. **Check model file syntax:**
   ```bash
   # Validate Ruby syntax
   podman exec oxidized ruby -c /home/oxidized/.config/oxidized/model/tplink.rb
   ```

### Issue: Model Loads But Device Fails

**Symptoms:**
- Model is recognized but device backup fails

**Solutions:**

1. **Check device connectivity:**
   ```bash
   # Test SSH/Telnet from container
   podman exec oxidized telnet <device-ip> 23
   podman exec oxidized ssh <device-ip>
   ```

2. **Enable debug mode:**
   ```bash
   # Edit config
   sudo vim /var/lib/oxidized/config/config
   # Set: debug: true

   # Restart and check logs
   sudo systemctl restart oxidized.service
   podman logs oxidized | tail -100
   ```

3. **Verify model prompts match device:**
   - Check model file for prompt regex
   - Compare with actual device prompt
   - May need to customize model file

### Issue: Permission Denied

**Symptoms:**
```
Permission denied: /home/oxidized/.config/oxidized/model/tplink.rb
```

**Solutions:**

1. **Fix ownership:**
   ```bash
   sudo chown 30000:30000 /var/lib/oxidized/models/*.rb
   sudo chmod 644 /var/lib/oxidized/models/*.rb
   ```

2. **Check SELinux context:**
   ```bash
   ls -Z /var/lib/oxidized/models/
   # Should show container_file_t or similar
   ```

---

## 📚 Additional Resources

- **Oxidized Models Repository:** https://github.com/ytti/oxidized/tree/master/lib/oxidized/model
- **TP-Link Model Source:** https://raw.githubusercontent.com/ytti/oxidized/master/lib/oxidized/model/tplink.rb
- **Creating Custom Models:** https://github.com/ytti/oxidized/wiki/Creating-and-Extending-Models
- **Model Documentation:** https://github.com/ytti/oxidized/wiki/Models

---

## 💡 Best Practices

1. **Check First:** Always verify if a model is already included before adding it
2. **Backup:** Backup your models directory before making changes
3. **Test:** Test custom models in a non-production environment first
4. **Version Control:** Keep custom models in version control
5. **Documentation:** Document any customizations made to models

---

**Remember:** Most standard models (including `tplink`) are already included in the oxidized container image. Only add custom models if you need device-specific customizations or models not in the official repository.
