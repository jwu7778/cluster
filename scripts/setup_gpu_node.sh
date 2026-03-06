#!/bin/bash
set -e

echo "=== Setup Physical Ubuntu Node for GPU ==="
echo "This script installs the NVIDIA Container Toolkit and configures K3s to use it."

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "[1/4] Installing NVIDIA Container Toolkit..."
# Add repository and GPG key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Update package lists
sudo apt-get update

# Install toolkit
sudo apt-get install -y nvidia-container-toolkit

echo "[2/4] Configuring NVIDIA Container Runtime..."
sudo nvidia-ctk runtime configure --runtime=docker

echo "[3/4] Configuring containerd (used by K3s)..."
# K3s uses its own containerd configuration. We need to tell K3s about the nvidia runtime.
K3S_CONTAINERD_CONFIG="/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl"

# Check if the K3s agent directory exists
if [ -d "/var/lib/rancher/k3s/agent/etc/containerd" ]; then
    echo "Creating custom containerd config for K3s..."
    cat <<EOF | sudo tee $K3S_CONTAINERD_CONFIG
[plugins.opt]
  path = "/var/lib/rancher/k3s/agent/containerd"

[plugins.cri]
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"

[plugins.cri.containerd]
  snapshotter = "overlayfs"
  disable_snapshot_annotations = true

[plugins.cri.containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins.cri.containerd.runtimes.runc.options]
  SystemdCgroup = true

# ADD NVIDIA RUNTIME
[plugins.cri.containerd.runtimes.nvidia]
  runtime_type = "io.containerd.runc.v2"
[plugins.cri.containerd.runtimes.nvidia.options]
  BinaryName = "/usr/bin/nvidia-container-runtime"
EOF
else
    echo "Warning: K3s containerd directory not found. Is K3s installed?"
fi


echo "[4/4] Restarting K3s service..."
# Restart either K3s server or agent depending on the node type
if systemctl is-active --quiet k3s; then
    sudo systemctl restart k3s
elif systemctl is-active --quiet k3s-agent; then
    sudo systemctl restart k3s-agent
else
    echo "Neither k3s nor k3s-agent is running. Please start the service."
fi

echo "=== Setup Complete ==="
echo "Please deploy the NVIDIA Device Plugin in Kubernetes next."
