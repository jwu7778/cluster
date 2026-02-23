#!/bin/bash
set -e

echo "Starting K3s Worker (WSL) Installation..."

if [ -z "$K3S_URL" ] || [ -z "$K3S_TOKEN" ]; then
    echo "ERROR: Please export K3S_URL and K3S_TOKEN environment variables first."
    echo "Example: export K3S_URL=https://192.168.1.100:6443"
    echo "Example: export K3S_TOKEN=..."
    exit 1
fi

# 1. WSL Specific GPU Fix (from existing script)
# We assume the check_gpu_wsl.sh is in the same directory as this script.
SCRIPT_DIR="$(dirname "$0")"
FIX_SCRIPT="$SCRIPT_DIR/check_gpu_wsl.sh"

if [ -f "$FIX_SCRIPT" ]; then
    echo "Executing WSL GPU Fix Script..."
    bash "$FIX_SCRIPT"
else
    echo "WARNING: check_gpu_wsl.sh not found in $SCRIPT_DIR!"
fi

# 2. Install NVIDIA Container Toolkit
echo "Installing NVIDIA Container Toolkit..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure for K3s (containerd)
sudo nvidia-ctk runtime configure --runtime=containerd
# containerd might not be running as a service in WSL if systemd isn't enabled, but K3s will start it
sudo systemctl restart containerd || true

# 3. Install K3s Worker
echo "Installing K3s Worker..."
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -

echo "---------------------------------------------------"
echo "Worker Installation Complete!"
echo "Check nodes status on master: kubectl get nodes"
echo "---------------------------------------------------"
