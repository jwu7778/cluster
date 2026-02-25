#!/bin/bash
set -e

echo "=== Diagnosing Master Node NotReady State ==="

echo "1. System Information:"
hostname
uptime

echo -e "\n2. Disk Usage (df -h):"
df -h
echo -e "\n   Focus on / and /var/lib/rancher:"
df -h / /var/lib/rancher/k3s 2>/dev/null || echo "/var/lib/rancher/k3s not explicitly mounted"

echo -e "\n3. Inode Usage (df -i):"
df -i /

echo -e "\n4. K3s Service Status:"
systemctl status k3s --no-pager | head -n 20

echo -e "\n5. Recent Kubelet Disk Errors (Last 50 lines):"
# Grep for specific disk pressure errors in logs
journalctl -u k3s --no-pager | grep -E "DiskPressure|FreeDiskSpaceFailed|InvalidDiskCapacity" | tail -n 20

echo -e "\n6. Heavy Directories in /var (Top 5):"
# Only look if we have permissions, might need sudo
if [ "$EUID" -ne 0 ]; then
  echo "   (Run with sudo to see directory sizes)"
else
  du -h /var/lib 2>/dev/null | sort -rh | head -n 5
fi

echo -e "\n=== Diagnosis Complete ==="
echo "If 'Use%' is 100% or Inodes are full, run scripts/fix_master_disk_pressure.sh"
