#!/bin/bash
set -e

echo "=== Verifying GPU Runtime on K3s Agent ==="

CONFIG_PATH="/var/lib/rancher/k3s/agent/etc/containerd/config.toml"
TEMPLATE_PATH="/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl"

echo "Checking config.toml..."
if sudo test -f "$CONFIG_PATH"; then
    echo "Found $CONFIG_PATH"
    if sudo grep -q "nvidia" "$CONFIG_PATH"; then
        echo "SUCCESS: 'nvidia' runtime found in config.toml."
    else
        echo "WARNING: 'nvidia' runtime NOT found in config.toml. Did the injection happen?"
    fi
else
    echo "ERROR: $CONFIG_PATH does not exist."
fi

echo "Checking config.toml.tmpl..."
if sudo test -f "$TEMPLATE_PATH"; then
    echo "Found $TEMPLATE_PATH"
    if sudo grep -q "nvidia" "$TEMPLATE_PATH"; then
        echo "SUCCESS: 'nvidia' runtime found in config.toml.tmpl."
    else
        echo "WARNING: 'nvidia' runtime NOT found in config.toml.tmpl. The startup script may have failed to inject it."
    fi
else
    echo "WARNING: $TEMPLATE_PATH does not exist. (If this is the first run, it might not have been created yet)"
fi

echo "Checking crictl info..."
# Try running crictl from PATH or k3s crictl
if command -v crictl &> /dev/null; then
    sudo crictl info | grep -A 5 "runtimes"
elif command -v k3s &> /dev/null; then
    sudo k3s crictl info | grep -A 5 "runtimes"
else
    echo "ERROR: crictl not found."
fi

echo "=== Verification Complete ==="
echo "If the runtime is listed above, try submitting the test job:"
echo "kubectl apply -f infrastructure/test-gpu-job.yaml"
