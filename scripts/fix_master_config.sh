#!/bin/bash
set -e

echo "=== Fixing Master Node K3s GPU Configuration ==="

CONFIG_PATH="/var/lib/rancher/k3s/agent/etc/containerd/config.toml"
TEMPLATE_PATH="/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl"

echo "Waiting for K3s to generate default config.toml..."
# Wait up to 30s
MAX_RETRIES=15
COUNT=0
# Use sudo test -f to check root-owned file existence
while ! sudo test -f "$CONFIG_PATH"; do
  sleep 2
  COUNT=$((COUNT+1))
  if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
    echo "ERROR: Timeout waiting for K3s config.toml. Ensure K3s is running."
    exit 1
  fi
done

echo "Copying generated config.toml to config.toml.tmpl as base..."
sudo cp "$CONFIG_PATH" "$TEMPLATE_PATH"

echo "Appending NVIDIA runtime configuration..."

# Determine if we are using new containerd config format (1.5+) or old
# Use sudo grep to read the root-owned file
if sudo grep -q "io.containerd.grpc.v1.cri" "$TEMPLATE_PATH"; then
  echo "Detected containerd 1.5+ configuration format."
  cat <<EOF | sudo tee -a "$TEMPLATE_PATH"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes."nvidia"]
  runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes."nvidia".options]
  BinaryName = "/usr/bin/nvidia-container-runtime"
  SystemdCgroup = true
EOF
else
  echo "Detected legacy containerd configuration format."
  cat <<EOF | sudo tee -a "$TEMPLATE_PATH"

[plugins.cri.containerd.runtimes.nvidia]
  runtime_type = "io.containerd.runc.v2"
[plugins.cri.containerd.runtimes.nvidia.options]
  BinaryName = "/usr/bin/nvidia-container-runtime"
  SystemdCgroup = true
EOF
fi

echo "Restarting K3s Master to apply runtime changes..."
sudo systemctl restart k3s

echo "---------------------------------------------------"
echo "Master GPU Configuration Updated!"
echo "Run 'kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu' to verify capacity."
echo "---------------------------------------------------"
