#!/bin/bash
set -e

echo "Starting K3s Master (Ubuntu Desktop) Installation..."

# --- STEP 0: PRE-FLIGHT CLEANUP (Must happen before apt-get update) ---

echo "=== PHASE 0: CLEANUP & PREPARATION ==="

# 0.1 Clean up previous K3s installation if it exists
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
# Kill any lingering k3s processes just in case
sudo pkill -f k3s || true

# 0.2 Aggressively clean up Broken PPA Configs to fix "Conflicting values set for option Signed-By"
echo "Cleaning up conflicting PPA configurations..."
# Remove all PPA files related to graphics-drivers in sources.list.d
# We use wildcards to catch all variations (.list, .sources, .save, etc)
sudo rm -f /etc/apt/sources.list.d/graphics-drivers-ppa-*.list
sudo rm -f /etc/apt/sources.list.d/graphics-drivers-ubuntu-ppa-*.list
sudo rm -f /etc/apt/sources.list.d/graphics-drivers-ubuntu-ppa-*.sources
sudo rm -f /etc/apt/sources.list.d/*graphics-drivers*.list
sudo rm -f /etc/apt/sources.list.d/*graphics-drivers*.sources

# Remove manual entries in /etc/apt/sources.list
if grep -q "graphics-drivers/ppa" /etc/apt/sources.list; then
    echo "Removing conflicting PPA entry from /etc/apt/sources.list..."
    # Create backup
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
    # Remove lines containing graphics-drivers/ppa
    sudo sed -i '/graphics-drivers\/ppa/d' /etc/apt/sources.list
fi

# 0.3 Clean up NVIDIA Container Toolkit sources if they exist (to avoid conflicts there too)
sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list

# --- STEP 1: SYSTEM UPDATE & DRIVER PURGE ---

echo "=== PHASE 1: SYSTEM UPDATE & DRIVER PURGE ==="
echo "Updating package lists..."
# Now we can safely update because the conflicting PPA config is gone
sudo apt-get update

echo "Purging old NVIDIA drivers..."
# Force remove the specific conflicting package causing dpkg errors
sudo dpkg --remove --force-all libnvidia-egl-gbm1 || true
# Also force remove potential broken driver installs
sudo dpkg --remove --force-all nvidia-driver-535 libnvidia-gl-535 || true

# General purge
sudo apt-get remove --purge -y '^nvidia-.*' '^libnvidia-.*' || true
sudo apt-get autoremove -y
sudo apt-get autoclean

# Fix any broken dependencies from partial installs
sudo apt-get install --fix-broken -y

# --- STEP 2: INSTALL DRIVERS ---

echo "=== PHASE 2: INSTALLING NVIDIA DRIVERS ==="
echo "Installing NVIDIA Driver 535 from Standard Ubuntu Repositories..."

# Ensure we have the standard repositories enabled (Restricted/Multiverse)
# This is safer than the PPA which might push broken bleeding-edge drivers (like 575).
sudo add-apt-repository -y restricted
sudo add-apt-repository -y multiverse
sudo add-apt-repository -y universe
sudo apt-get update

# Install driver from standard repos instead of PPA
sudo apt-get install -y nvidia-driver-535 nvidia-utils-535

# --- STEP 3: INSTALL CONTAINER TOOLKIT ---

echo "=== PHASE 3: INSTALLING NVIDIA CONTAINER TOOLKIT ==="
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure for K3s (containerd)
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart containerd || true

# --- STEP 4: INSTALL K3S MASTER ---

echo "=== PHASE 4: INSTALLING K3S MASTER ==="
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable traefik" sh -

# --- STEP 5: FINALIZE ---

# Extract Token for Worker
TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
IP=$(hostname -I | awk '{print $1}')

echo "---------------------------------------------------"
echo "Master Installation Complete!"
echo "Use the following command on your WSL Worker node:"
echo "export K3S_URL=https://$IP:6443"
echo "export K3S_TOKEN=$TOKEN"
echo "./scripts/install_worker_wsl.sh"
echo "---------------------------------------------------"
