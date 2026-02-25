#!/bin/bash
set -e

# Configuration
MASTER_IP="10.8.22.147"
K3S_TOKEN="K101ee6610015501a3574c871583594892543314407887373070499298379415712::server:75037d6e409c95d82008630072702737"

echo "=== Installing K3s Master Node (Ubuntu Desktop) ==="

# 1. Check for NVIDIA Container Toolkit (System)
# We need this installed on the host for device plugin to work correctly, even if K3s uses embedded containerd.
if ! command -v nvidia-ctk &> /dev/null; then
    echo "WARNING: nvidia-ctk not found. Please install NVIDIA Container Toolkit."
    echo "Ref: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"
    read -p "Press Enter to continue anyway..."
fi

# 2. Clean up previous K3s (optional, for idempotency)
if command -v k3s-uninstall.sh &> /dev/null; then
    echo "Removing existing K3s installation..."
    k3s-uninstall.sh
fi

# 3. Install K3s Master
# Note: We do NOT use --docker. We use containerd.
# We will patch the config later to use nvidia-container-runtime.
echo "Installing K3s Server..."
curl -sfL https://get.k3s.io | sh -s - server \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --token "${K3S_TOKEN}" \
    --bind-address "${MASTER_IP}" \
    --advertise-address "${MASTER_IP}"

echo "Waiting for K3s to start..."
sleep 15

# 4. Patch K3s Config for NVIDIA Runtime
# This is crucial because K3s uses its own containerd config template.
echo "Patching K3s containerd config for NVIDIA runtime..."
SCRIPT_DIR=$(dirname "$0")
if [ -f "$SCRIPT_DIR/fix_master_config.sh" ]; then
    bash "$SCRIPT_DIR/fix_master_config.sh"
else
    echo "WARNING: fix_master_config.sh not found. You must run it manually to enable GPU support."
fi

echo "=== Master Installation Complete ==="
echo "Copy ~/.kube/config to your local machine if needed."
kubectl get nodes
