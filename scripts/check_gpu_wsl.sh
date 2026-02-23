#!/bin/bash
set -e

echo "Starting WSL GPU Configuration Check..."

# 1. Check for /dev/dxg (DirectX Graphics Kernel)
if [ ! -e "/dev/dxg" ]; then
    echo "WARNING: /dev/dxg not found. This implies the WSL2 instance may not have GPU passthrough enabled or drivers are missing on the Windows host."
else
    echo "SUCCESS: /dev/dxg found."
fi

# 2. Check and Configure Library Path for WSL
WSL_LIB="/usr/lib/wsl/lib"

# Check if the directory actually exists (it should be mounted from Windows)
if [ ! -d "$WSL_LIB" ]; then
    echo "ERROR: $WSL_LIB directory not found. Ensure you are running on WSL2 with NVIDIA drivers installed on Windows."
    # We proceed, but this is critical.
fi

# We use ldconfig to manage library paths persistently
LD_CONF="/etc/ld.so.conf.d/wsl.conf"
if [ ! -f "$LD_CONF" ]; then
    echo "Configuring ld.so.conf for WSL libraries..."
    echo "$WSL_LIB" | sudo tee "$LD_CONF"
    sudo ldconfig
    echo "SUCCESS: Added $WSL_LIB to ldconfig."
else
    if grep -q "$WSL_LIB" "$LD_CONF"; then
        echo "SUCCESS: $WSL_LIB is already configured in $LD_CONF."
    else
        echo "Updating $LD_CONF..."
        echo "$WSL_LIB" | sudo tee -a "$LD_CONF"
        sudo ldconfig
        echo "SUCCESS: Appended $WSL_LIB to $LD_CONF and refreshed ldconfig."
    fi
fi

# 3. Configure nvidia-container-runtime for WSL compatibility
# This is often needed to ensure the runtime hook picks up the WSL libraries correctly.
CONFIG_FILE="/etc/nvidia-container-runtime/config.toml"
CONFIG_DIR=$(dirname "$CONFIG_FILE")

if [ ! -d "$CONFIG_DIR" ]; then
    sudo mkdir -p "$CONFIG_DIR"
fi

# We will create a basic config if it doesn't exist, or ensure specific flags if it does.
# For WSL, we usually want to ensure we accept the mounted devices.
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating default nvidia-container-runtime config for WSL..."
    sudo tee "$CONFIG_FILE" > /dev/null <<EOF
disable-require = false
# sw-name = "Unknown"
# docker-runtimes = ["runc"]

[nvidia-container-cli]
# root = "/run/nvidia/driver"
# path = "/usr/bin/nvidia-container-cli"
environment = []
# debug = "/var/log/nvidia-container-toolkit.log"
# load-kmods = true
# no-cgroups = false
# user = "root:video"
ldconfig = "@/sbin/ldconfig"

[nvidia-container-runtime]
# debug = "/var/log/nvidia-container-runtime.log"
log-level = "info"

# specific for WSL usage if needed
mode = "auto"
EOF
    echo "SUCCESS: Created $CONFIG_FILE"
else
    echo "SUCCESS: $CONFIG_FILE exists."
fi

echo "WSL GPU Check & Configuration Complete."
