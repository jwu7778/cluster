#!/bin/bash
# check_gpu_wsl.sh - Diagnostics for WSL GPU Setup

echo "=== WSL GPU Diagnostic Tool ==="

FAIL=0

# Check 1: /dev/dxg (DirectX GPU device for WSL2)
if [ -e "/dev/dxg" ]; then
    echo "[PASS] /dev/dxg found."
else
    echo "[FAIL] /dev/dxg NOT found. Ensure you are running on WSL2 with NVIDIA Drivers installed on Windows."
    FAIL=1
fi

# Check 2: WSL Libraries (/usr/lib/wsl/lib)
WSL_LIB="/usr/lib/wsl/lib"
if [ -d "$WSL_LIB" ]; then
    echo "[PASS] $WSL_LIB directory found."
else
    echo "[FAIL] $WSL_LIB NOT found. Verify NVIDIA Driver installation on Windows."
    FAIL=1
fi

# Check 3: LD Configuration (ld.so.conf)
LD_CONF="/etc/ld.so.conf.d/wsl.conf"
if [ -f "$LD_CONF" ] && grep -q "$WSL_LIB" "$LD_CONF"; then
    echo "[PASS] ld.so.conf configured correctly for WSL libraries."
else
    echo "[WARN] ld.so.conf might be missing $WSL_LIB. Run 'sudo ldconfig' after adding it."
    # Not a critical fail if libraries are in standard path, but usually required for WSL
fi

# Check 4: NVIDIA Container Toolkit
if command -v nvidia-ctk &> /dev/null; then
    echo "[PASS] NVIDIA Container Toolkit installed."
else
    echo "[FAIL] NVIDIA Container Toolkit NOT installed."
    FAIL=1
fi

# Check 5: K3s Agent Configuration
CONFIG_TMPL="/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl"
if [ -f "$CONFIG_TMPL" ]; then
    if grep -q "plugins.*nvidia" "$CONFIG_TMPL"; then
        echo "[PASS] K3s Agent config.toml.tmpl contains NVIDIA runtime configuration."
    else
        echo "[WARN] K3s Agent config.toml.tmpl exists but might be missing NVIDIA configuration."
    fi
else
    echo "[INFO] K3s Agent config.toml.tmpl not found (K3s might not be installed or configured yet)."
fi

echo "=== Diagnostic Complete ==="
if [ $FAIL -eq 1 ]; then
    echo "Summary: Issues detected. Please run 'scripts/install_worker_wsl.sh' to fix them."
    exit 1
else
    echo "Summary: System looks ready for GPU workloads."
    exit 0
fi
