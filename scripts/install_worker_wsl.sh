#!/bin/bash
set -e

echo "Starting K3s Worker (WSL) Installation..."

# --- STEP 0: CREDENTIALS CHECK ---

# Prompt for URL if not set
if [ -z "$K3S_URL" ]; then
    read -p "Enter K3S_URL (e.g., https://192.168.1.100:6443): " K3S_URL
fi

# Prompt for Token if not set
if [ -z "$K3S_TOKEN" ]; then
    read -p "Enter K3S_TOKEN: " K3S_TOKEN
fi

# Final validation
if [ -z "$K3S_URL" ] || [ -z "$K3S_TOKEN" ]; then
    echo "ERROR: K3S_URL and K3S_TOKEN are required."
    exit 1
fi

echo "Using K3S_URL=$K3S_URL"
# masking token in output
echo "Using K3S_TOKEN=***"

# --- STEP 1: WSL GPU ENVIRONMENT CHECK & FIX ---

echo "=== PHASE 1: WSL GPU CHECK ==="

# 1.1 Check for /dev/dxg
if [ ! -e "/dev/dxg" ]; then
    echo "WARNING: /dev/dxg not found. This implies the WSL2 instance may not have GPU passthrough enabled or drivers are missing on the Windows host."
    echo "Please ensure you have NVIDIA Drivers installed on Windows and are running WSL 2."
else
    echo "SUCCESS: /dev/dxg found."
fi

# 1.2 Check and Configure Library Path for WSL
WSL_LIB="/usr/lib/wsl/lib"

if [ ! -d "$WSL_LIB" ]; then
    echo "ERROR: $WSL_LIB directory not found. Ensure you are running on WSL2 with NVIDIA drivers installed on Windows."
    # Proceeding might fail, but we try.
else
    echo "SUCCESS: $WSL_LIB found."

    # Configure ld.so.conf
    LD_CONF="/etc/ld.so.conf.d/wsl.conf"
    if [ ! -f "$LD_CONF" ] || ! grep -q "$WSL_LIB" "$LD_CONF"; then
        echo "Configuring ld.so.conf for WSL libraries..."
        echo "$WSL_LIB" | sudo tee "$LD_CONF"
        sudo ldconfig
        echo "SUCCESS: Added $WSL_LIB to ldconfig."
    else
        echo "SUCCESS: ld.so.conf already configured."
    fi
fi

# --- STEP 2: INSTALL NVIDIA CONTAINER TOOLKIT ---

echo "=== PHASE 2: INSTALLING NVIDIA CONTAINER TOOLKIT ==="

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

# --- STEP 3: CONFIGURE RUNTIME (SKIPPED FOR K3S EMBEDDED) ---
# Previous versions configured system containerd here.
# Since K3s uses its own embedded containerd, we skip system-wide configuration
# to avoid confusion and conflicts. The K3s config is handled in Phase 4.

# --- STEP 4: CLEANUP & INSTALL K3S AGENT ---

echo "=== PHASE 4: CLEANUP & INSTALL K3S AGENT ==="

# Function for aggressive cleanup
force_cleanup_k3s() {
    echo "Starting aggressive K3s cleanup..."

    # Stop the service if running
    if systemctl is-active --quiet k3s-agent; then
        echo "Stopping running k3s-agent service..."
        sudo systemctl stop k3s-agent || echo "Warning: Failed to stop k3s-agent"
    fi

    # Run official cleanup scripts first
    if [ -f "/usr/local/bin/k3s-killall.sh" ]; then
        echo "Running k3s-killall.sh..."
        sudo /usr/local/bin/k3s-killall.sh || echo "Warning: k3s-killall.sh failed"
    fi

    if [ -f "/usr/local/bin/k3s-agent-uninstall.sh" ]; then
        echo "Running k3s-agent-uninstall.sh..."
        sudo /usr/local/bin/k3s-agent-uninstall.sh || echo "Warning: k3s-agent-uninstall.sh failed"
    else
        echo "Uninstaller not found. Manually cleaning up service files..."
        sudo systemctl disable k3s-agent 2>/dev/null || true
        sudo rm -f /etc/systemd/system/k3s-agent.service
        sudo systemctl daemon-reload
    fi

    # Aggressive unmount loop
    echo "Checking for remaining mounts in K3s directories..."
    # List mounts, filter for k3s-related paths, sort by length (longest first) to unmount nested mounts properly
    mount | grep -E '/var/lib/kubelet|/var/lib/rancher/k3s|/run/k3s|/run/flannel' | awk '{print $3}' | sort -r | while read -r mnt; do
        echo "Unmounting $mnt..."
        sudo umount -f "$mnt" || echo "Warning: Failed to force unmount $mnt"
    done

    echo "Removing K3s data directories..."
    # Remove state data
    sudo rm -rf /var/lib/rancher/k3s || echo "Warning: Failed to remove /var/lib/rancher/k3s"
    sudo rm -rf /etc/rancher/k3s || echo "Warning: Failed to remove /etc/rancher/k3s"
    # Remove runtime data
    sudo rm -rf /run/k3s || echo "Warning: Failed to remove /run/k3s"
    sudo rm -rf /run/flannel || echo "Warning: Failed to remove /run/flannel"
    # Remove kubelet data (often busy)
    sudo rm -rf /var/lib/kubelet || echo "Warning: Failed to remove /var/lib/kubelet"

    echo "Cleanup phase finished."
}

# Execute cleanup
force_cleanup_k3s

# 4.2 Install K3s Agent
echo "Installing K3s Agent..."

# Install K3s Agent
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -

echo "Waiting for K3s to generate default config.toml..."
CONFIG_PATH="/var/lib/rancher/k3s/agent/etc/containerd/config.toml"
TEMPLATE_PATH="/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl"

# Loop until config.toml is created by K3s start
MAX_RETRIES=30
COUNT=0
while [ ! -f "$CONFIG_PATH" ]; do
  sleep 2
  COUNT=$((COUNT+1))

  # Check if service died
  if ! systemctl is-active --quiet k3s-agent; then
      echo "ERROR: k3s-agent service is not running! Check logs below:"
      echo "--- journalctl output ---"
      sudo journalctl -u k3s-agent -n 50 --no-pager
      echo "-------------------------"
      exit 1
  fi

  if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
    echo "ERROR: Timeout waiting for K3s to generate config.toml"
    echo "Dumping recent logs:"
    sudo journalctl -u k3s-agent -n 50 --no-pager
    exit 1
  fi
done

echo "Copying generated config.toml to config.toml.tmpl as base..."
sudo cp "$CONFIG_PATH" "$TEMPLATE_PATH"

echo "Appending NVIDIA runtime configuration..."
# Using the standard format strictly as requested.

# Determine if we are using new containerd config format (1.5+) or old
if grep -q "io.containerd.grpc.v1.cri" "$TEMPLATE_PATH"; then
  echo "Detected containerd 1.5+ configuration format."
  cat <<EOF | sudo tee -a "$TEMPLATE_PATH"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
  runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
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

echo "Restarting K3s Agent to apply runtime changes..."
sudo systemctl restart k3s-agent

echo "---------------------------------------------------"
echo "Worker Installation Complete!"
echo "Run 'kubectl get nodes' on the master to verify."
echo "---------------------------------------------------"
