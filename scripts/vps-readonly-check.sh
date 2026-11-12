#!/usr/bin/env bash
# Read-only VPS checks. Does not change system configuration. No credentials are read.
# WARNING: output may contain private and public network addresses. Redact before sharing.
set -u
printf '=== VPS read-only network check ===\n'
date -Is || date
printf '\n=== OS ===\n'
cat /etc/os-release 2>/dev/null | head -n 6 || true
printf '\n=== Interfaces ===\n'
ip -br addr || true
printf '\n=== Routes ===\n'
ip route || true
printf '\n=== Route to public test IP ===\n'
ip route get 1.1.1.1 || true
printf '\n=== IPv4 forwarding ===\n'
sysctl net.ipv4.ip_forward || true
printf '\n=== WireGuard status (without root may show limited information) ===\n'
wg show 2>/dev/null || echo 'WireGuard status unavailable; run sudo wg show manually if authorized.'
printf '\n=== UFW ===\n'
ufw status 2>/dev/null || echo 'UFW status unavailable.'
printf '\nDone: redact before sharing.\n'
