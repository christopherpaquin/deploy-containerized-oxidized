#!/usr/bin/env bash
set -euo pipefail

# SX3008F Command Discovery Script
# Interactively discovers what CLI commands this switch supports

DEVICE_IP="10.1.10.48"
USERNAME="admin"
PASSWORD="thunder123"

echo "========================================="
echo "SX3008F CLI Command Discovery"
echo "========================================="
echo ""
echo "Connecting to ${DEVICE_IP}..."
echo ""

# Use sshpass for non-interactive SSH
if ! command -v sshpass &> /dev/null; then
  echo "Installing sshpass..."
  dnf install -y sshpass > /dev/null 2>&1 || yum install -y sshpass > /dev/null 2>&1
fi

echo "Testing basic help/discovery commands..."
echo ""

# Try to get help
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=10 "${USERNAME}@${DEVICE_IP}" 2>&1 << 'COMMANDS' | tee /tmp/sx3008f-discovery.log
?
help
show ?
enable
enable
?
show ?
config
configure
display ?
dir
ls
menu
exit
COMMANDS

echo ""
echo "========================================="
echo "Log saved to: /tmp/sx3008f-discovery.log"
echo "========================================="
echo ""
echo "Analyzing output..."
grep -E "^[a-z-]+" /tmp/sx3008f-discovery.log | grep -v "Warning:" | sort -u || true
