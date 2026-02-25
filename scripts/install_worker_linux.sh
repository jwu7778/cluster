#!/bin/bash
set -e

# Configuration
MASTER_IP="10.8.22.147"
K3S_TOKEN="K101ee6610015501a3574c871583594892543314407887373070499298379415712::server:75037d6e409c95d82008630072702737"

echo "=== Installing K3s Worker Node (Standard Linux) ==="

# 1. Connectivity Check
echo "Checking connection to Master ($MASTER_IP)..."
if ! curl -k https://$MASTER_IP:6443/cacerts > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to K3s API at https://$MASTER_IP:6443"
    echo "Please check:"
    echo "1. Is the Master Node running?"
    echo "2. Is the firewall on the Master blocking port 6443? (Try: sudo ufw allow 6443/tcp)"
    echo "3. Can you ping the Master IP?"
    exit 1
fi
echo "Connection OK."

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
curl -sfL https://get.k3s.io | K3S_URL="https://${MASTER_IP}:6443" K3S_TOKEN="${K3S_TOKEN}" sh -s - agent --node-name $(hostname)

# 5. Patch K3s Config for NVIDIA Runtime (Worker)
# This is crucial for GPU support on workers too!
echo "Patching K3s containerd config for NVIDIA runtime..."
SCRIPT_DIR=$(dirname "$0")
if [ -f "$SCRIPT_DIR/fix_master_config.sh" ]; then
    # We reuse the master config fix script as the logic is identical for containerd config
    bash "$SCRIPT_DIR/fix_master_config.sh"
else
    echo "WARNING: fix_master_config.sh not found. You must run it manually to enable GPU support."
fi

echo "=== Installation Complete ==="
echo "Run 'kubectl get nodes' on the Master node to verify connection."
