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

# Generate default config
sudo nvidia-ctk runtime configure --runtime=containerd

# Apply WSL-specific fixes to config.toml if needed
# Typically, nvidia-ctk handles this, but explicitly ensuring ldconfig path is safe.
CONFIG_FILE="/etc/nvidia-container-runtime/config.toml"

# Ensure specific WSL settings if they are not default
# We can use a simple sed to ensure 'ldconfig' points to the right place if needed,
# but usually standard config works if ld.so.conf is set (Phase 1).
# We just restart containerd to pick up changes.
sudo systemctl restart containerd || true

# --- STEP 4: INSTALL K3S AGENT ---

echo "=== PHASE 4: INSTALLING K3S AGENT ==="

# We use the standard install script, pointing to the master
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -

echo "---------------------------------------------------"
echo "Worker Installation Complete!"
echo "Run 'kubectl get nodes' on the master to verify."
echo "---------------------------------------------------"
