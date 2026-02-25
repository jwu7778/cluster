#!/bin/bash
set -e

echo "=== Attempting to Fix Disk Pressure on Master Node ==="

# Check if run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

echo "1. Pruning unused container images (crictl)..."
# K3s uses containerd by default. crictl is the tool.
if command -v crictl &> /dev/null; then
    crictl rmi --prune
else
    # try full path if not in PATH
    if [ -f /usr/local/bin/crictl ]; then
        /usr/local/bin/crictl rmi --prune
    else
        echo "crictl not found. Skipping image prune."

    fi
fi

echo -e "\n2. Cleaning apt cache..."
apt-get clean
apt-get autoremove -y

echo -e "\n3. Vacuuming systemd journals (older than 2 days)..."
journalctl --vacuum-time=2d

echo -e "\n4. Removing unused docker images (if docker is installed)..."
if command -v docker &> /dev/null; then
    docker system prune -af --volumes
else
    echo "Docker not found (using containerd/k3s). Skipping docker prune."
fi

echo -e "\n=== Cleanup Complete. Checking Disk Usage ==="
df -h /
echo "If usage is still high (>85%), consider expanding disk or deleting large files manually."
