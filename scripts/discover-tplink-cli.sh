#!/usr/bin/env bash
# Direct SSH test to discover TP-Link CLI commands

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@10.1.10.48 << 'EOF'
?
help
show ?
enable
configure
EOF
