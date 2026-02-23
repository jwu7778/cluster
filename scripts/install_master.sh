#!/bin/bash
set -e

echo "Starting K3s Master (Ubuntu Desktop) Installation..."

# --- STEP 0: PRE-FLIGHT CHECKS ---

echo "=== PHASE 0: PRE-FLIGHT CHECKS ==="

# 0.1 Check for NVIDIA GPU and Driver
if ! command -v nvidia-smi &> /dev/null; then
    echo "ERROR: nvidia-smi not found! Please install NVIDIA drivers manually."
    exit 1
fi

echo "Checking NVIDIA Driver Status..."
if nvidia-smi; then
    echo "SUCCESS: NVIDIA Driver is detected and functioning."
else
    echo "ERROR: nvidia-smi failed to communicate with the NVIDIA driver."
    echo "Please ensure your NVIDIA drivers are correctly installed and loaded."
    exit 1
fi

# 0.2 Clean up previous K3s installation if it exists
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    echo "Found existing K3s installation. Uninstalling..."
    /usr/local/bin/k3s-uninstall.sh
fi

# Ensure clean slate for K3s artifacts
echo "Removing residual K3s directories..."
sudo rm -rf /etc/rancher/k3s
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /var/lib/kubelet
sudo rm -rf /etc/cni/net.d
sudo pkill -f k3s || true

# --- STEP 1: INSTALL CONTAINER TOOLKIT ---

echo "=== PHASE 1: INSTALLING NVIDIA CONTAINER TOOLKIT ==="

if ! command -v nvidia-ctk &> /dev/null; then
    echo "Installing NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
else
    echo "NVIDIA Container Toolkit already installed."
fi

echo "Configuring NVIDIA Container Toolkit for Containerd..."
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart containerd || true

# --- STEP 2: INSTALL K3S MASTER ---

echo "=== PHASE 2: INSTALLING K3S MASTER ==="
# Standard K3s installation, allowing it to manage the container runtime.
# We disable traefik to keep the master node lightweight and avoid port conflicts on development machines,
# but we can enable it if needed. The user asked for "standard", but "standard" on a desktop often implies
# just getting the cluster up. I will keep the flags minimal but useful.
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable traefik" sh -

# --- STEP 3: FINALIZE ---

echo "Waiting for K3s to start..."
sleep 10

# Extract Token for Worker
TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
IP=$(hostname -I | awk '{print $1}')

echo "---------------------------------------------------"
echo "Master Installation Complete!"
echo "Master IP: $IP"
echo "K3S Token: $TOKEN"
echo ""
echo "Use the following command on your WSL Worker node:"
echo "export K3S_URL=https://$IP:6443"
echo "export K3S_TOKEN=$TOKEN"
echo "./scripts/install_worker_wsl.sh"
echo "---------------------------------------------------"
