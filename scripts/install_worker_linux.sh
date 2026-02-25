#!/bin/bash
set -e

# Configuration
MASTER_IP="10.8.22.147"   # Replace with your Master Node IP
K3S_TOKEN="K101ee6610015501a3574c871583594892543314407887373070499298379415712::server:75037d6e409c95d82008630072702737" # Replace with your K3s Token

echo "=== Installing K3s Worker Node (Standard Linux) ==="

# 1. Install prerequisites
echo "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y curl

# 2. Check for NVIDIA Container Toolkit
if ! command -v nvidia-ctk &> /dev/null; then
    echo "WARNING: NVIDIA Container Toolkit not found. GPU workloads may fail."
    echo "Please ensure NVIDIA drivers and nvidia-container-toolkit are installed."
    echo "Refer to: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"
    read -p "Press Enter to continue anyway, or Ctrl+C to abort..."
fi

# 3. Clean up previous K3s installation (optional)
if command -v k3s-agent-uninstall.sh &> /dev/null; then
    echo "Removing existing K3s agent..."
    /usr/local/bin/k3s-agent-uninstall.sh
fi

# 4. Install K3s Agent
echo "Installing K3s Agent..."
curl -sfL https://get.k3s.io | K3S_URL="https://${MASTER_IP}:6443" K3S_TOKEN="${K3S_TOKEN}" sh -

echo "=== Installation Complete ==="
echo "Run 'kubectl get nodes' on the Master node to verify connection."
