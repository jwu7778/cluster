#!/bin/bash
set -e

echo "=== K3s Master Node Repair Script ==="
echo "This script attempts to fix K3s startup failures caused by previous disk pressure."

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "[1/4] Stopping K3s service..."
systemctl stop k3s || echo "K3s was already stopped."

echo "[2/4] Cleaning up potentially corrupted K3s data binaries..."
# When K3s extracts binaries to /var/lib/rancher/k3s/data and the disk is full,
# the binaries can be corrupted. Deleting this folder forces a clean re-extraction.
DATA_DIR="/var/lib/rancher/k3s/data"
if [ -d "$DATA_DIR" ]; then
    echo "Removing $DATA_DIR..."
    rm -rf "$DATA_DIR"
else
    echo "$DATA_DIR not found, skipping."
fi

echo "[3/4] Restarting K3s service..."
systemctl start k3s

echo "[4/4] Verifying K3s status..."
sleep 3
systemctl status k3s --no-pager | grep Active

echo ""
echo "=== Repair Process Complete ==="
echo "If the status above does not show 'active (running)', please run:"
echo "  sudo journalctl -xeu k3s -n 50"
echo "to check for further database/etcd corruption errors."
