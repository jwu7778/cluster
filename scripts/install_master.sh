#!/bin/bash
set -e

echo "Starting K3s Master (Ubuntu Desktop) Installation..."

# 1. Purge problematic drivers and libs
echo "Purging old NVIDIA drivers..."
sudo apt-get update

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

# 2. Install Stable NVIDIA Driver (535)
echo "Installing NVIDIA Driver 535..."
# Clean up potential PPA conflicts more aggressively
sudo add-apt-repository --remove -y ppa:graphics-drivers/ppa || true
sudo rm -f /etc/apt/sources.list.d/graphics-drivers-ppa-*.list
sudo rm -f /etc/apt/sources.list.d/graphics-drivers-ubuntu-ppa-*.list
sudo rm -f /etc/apt/sources.list.d/graphics-drivers-ubuntu-ppa-*.sources

# Remove any manual entries in /etc/apt/sources.list matching the PPA
if grep -q "graphics-drivers/ppa" /etc/apt/sources.list; then
    echo "Removing conflicting PPA entry from /etc/apt/sources.list..."
    sudo sed -i '/graphics-drivers\/ppa/d' /etc/apt/sources.list
fi

# Add the PPA again cleanly
sudo add-apt-repository -y ppa:graphics-drivers/ppa
sudo apt-get update
sudo apt-get install -y nvidia-driver-535 nvidia-utils-535

# 3. Install NVIDIA Container Toolkit
echo "Installing NVIDIA Container Toolkit..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure for K3s (containerd)
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart containerd || true

# 4. Install K3s Master
echo "Installing K3s Master..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable traefik" sh -

# 5. Extract Token for Worker
TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
IP=$(hostname -I | awk '{print $1}')

echo "---------------------------------------------------"
echo "Master Installation Complete!"
echo "Use the following command on your WSL Worker node:"
echo "export K3S_URL=https://$IP:6443"
echo "export K3S_TOKEN=$TOKEN"
echo "./scripts/install_worker_wsl.sh"
echo "---------------------------------------------------"
