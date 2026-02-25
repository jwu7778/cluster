#!/bin/bash
set -e

echo "=== Verifying Master Node Status ==="

# 1. Check K3s Service Status
echo "--- K3s Service Status ---"
if systemctl is-active k3s; then
    echo "SUCCESS: K3s service is running."
else
    echo "ERROR: K3s service is NOT running."
    echo "Try starting it: sudo systemctl start k3s"
    sudo systemctl status k3s --no-pager
    exit 1
fi

# 2. Check Node Status
echo "--- Kubernetes Node Status ---"
kubectl get nodes -o wide

# 3. Check Current IP
echo "--- Current IP Address ---"
CURRENT_IP=$(hostname -I | awk '{print $1}')
echo "Current IP: $CURRENT_IP"

# 4. Check Configured IP
echo "--- Checking Configured K3s IP ---"
# K3s often uses --advertise-address or --tls-san.
# If installed via script, it might be in the service file.
if [ -f /etc/systemd/system/k3s.service ]; then
    grep "ExecStart" /etc/systemd/system/k3s.service
else
    echo "Service file /etc/systemd/system/k3s.service not found."
fi

# 5. Check Logs for Errors
echo "--- Recent K3s Logs ---"
sudo journalctl -u k3s -n 50 --no-pager | grep -i "error"

echo "=== Diagnosis Complete ==="
echo "If the Current IP differs from the Configured IP in ExecStart, K3s will be broken."
echo "If so, you must update the service file or restore the original IP."
