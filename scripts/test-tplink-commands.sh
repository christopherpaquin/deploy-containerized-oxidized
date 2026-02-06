#!/usr/bin/env bash
set -euo pipefail

# TP-Link Command Discovery Script
# Tests various commands to determine what this TP-Link switch supports

# Colors for output
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_RESET=$'\033[0m'

# Configuration
readonly DEVICE_IP="${1:-10.1.10.48}"
readonly USERNAME="${2:-admin}"
readonly PASSWORD="${3:-thunder123}"
readonly TIMEOUT=10

echo "${COLOR_BLUE}========================================${COLOR_RESET}"
echo "${COLOR_BLUE}TP-Link Command Discovery${COLOR_RESET}"
echo "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""
echo "Device: ${DEVICE_IP}"
echo "User:   ${USERNAME}"
echo ""

# Test connectivity
echo "${COLOR_BLUE}Testing connectivity...${COLOR_RESET}"
if ! ping -c 1 -W 2 "${DEVICE_IP}" > /dev/null 2>&1; then
  echo "${COLOR_RED}ERROR: Device not reachable${COLOR_RESET}"
  exit 1
fi
echo "${COLOR_GREEN}✓ Device is reachable${COLOR_RESET}"
echo ""

# Test interactive session with help and command discovery
echo "${COLOR_BLUE}Attempting interactive session...${COLOR_RESET}"
echo ""

(
  sleep 1
  echo "$USERNAME"
  sleep 1.5
  echo "$PASSWORD"
  sleep 2
  echo "?"
  sleep 3
  echo "show ?"
  sleep 3
  echo "display ?"
  sleep 3
  echo "show running-config"
  sleep 2
  echo "exit"
  sleep 1
) | timeout 25 telnet "$DEVICE_IP" 2>&1 | tee /tmp/tplink-test.log

echo ""
echo "${COLOR_BLUE}========================================${COLOR_RESET}"
echo "${COLOR_BLUE}Session log saved to: /tmp/tplink-test.log${COLOR_RESET}"
echo "${COLOR_BLUE}========================================${COLOR_RESET}"
