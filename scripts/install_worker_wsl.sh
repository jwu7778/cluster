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

# --- STEP 3: CONFIGURE RUNTIME FOR WSL ---

echo "=== PHASE 3: CONFIGURING RUNTIME ==="

# Generate default config for system containerd (optional but good practice)
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart containerd || true

# --- STEP 4: CLEANUP & INSTALL K3S AGENT ---

echo "=== PHASE 4: CLEANUP & INSTALL K3S AGENT ==="

# 4.1 Cleanup previous installation
echo "Checking for previous K3s agent installation..."

if systemctl is-active --quiet k3s-agent; then
    echo "Stopping running k3s-agent service..."
    sudo systemctl stop k3s-agent
fi

if [ -f "/usr/local/bin/k3s-agent-uninstall.sh" ]; then
    echo "Running K3s agent uninstaller..."
    sudo /usr/local/bin/k3s-agent-uninstall.sh
else
    echo "Uninstaller not found. Manually cleaning up..."
    sudo systemctl disable k3s-agent 2>/dev/null || true
    sudo rm -f /etc/systemd/system/k3s-agent.service
    sudo systemctl daemon-reload
fi

echo "Removing K3s data directories to ensure fresh registration..."
# Remove state data (including old certificates causing 401 errors)
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /etc/rancher/k3s
# Remove runtime data
sudo rm -rf /run/k3s
sudo rm -rf /run/flannel

echo "Cleanup complete."

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
  if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
    echo "ERROR: Timeout waiting for K3s to generate config.toml"
    exit 1
  fi
done

echo "Copying generated config.toml to config.toml.tmpl as base..."
sudo cp "$CONFIG_PATH" "$TEMPLATE_PATH"

echo "Appending NVIDIA runtime configuration..."

# Determine if we are using new containerd config format (1.5+) or old
if grep -q "io.containerd.grpc.v1.cri" "$TEMPLATE_PATH"; then
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

echo "Restarting K3s Agent to apply runtime changes..."
sudo systemctl restart k3s-agent

echo "---------------------------------------------------"
echo "Worker Installation Complete!"
echo "Run 'kubectl get nodes' on the master to verify."
echo "---------------------------------------------------"
