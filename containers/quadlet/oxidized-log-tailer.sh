#!/usr/bin/env bash
# Oxidized Log Tailer
# This script tails the Oxidized container logs and writes them to the log file
# Run by systemd as a companion service to oxidized.service

set -euo pipefail

LOG_FILE="/var/lib/oxidized/data/oxidized.log"
CONTAINER_NAME="oxidized"

# Ensure log file exists and is writable
touch "${LOG_FILE}"
chown 30000:30000 "${LOG_FILE}"
chmod 644 "${LOG_FILE}"

# First, capture last 100 lines of existing logs (only if log file is empty)
if [[ ! -s "${LOG_FILE}" ]]; then
  podman logs --tail=100 "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1
fi

# Then tail new logs continuously
exec podman logs -f --since=5s "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1
