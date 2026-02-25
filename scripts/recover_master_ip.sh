#!/bin/bash
set -e

echo "=== Recovering Master Node Configuration ==="

# 1. Ask for current CORRECT IP
echo "This script will update the K3s service to listen on the current IP."
echo "If your IP changed, this will fix the cluster connectivity."
echo "WARNING: This will restart K3s."
read -p "Enter current Master Node IP (from check_master_status.sh): " NEW_IP
if [ -z "$NEW_IP" ]; then
    echo "ERROR: IP is required."
    exit 1
fi

echo "Updating K3s Service Configuration..."
SERVICE_FILE="/etc/systemd/system/k3s.service"

if [ ! -f "$SERVICE_FILE" ]; then
    echo "ERROR: Service file not found at $SERVICE_FILE"
    exit 1
fi

# Backup the original service file
sudo cp "$SERVICE_FILE" "$SERVICE_FILE.bak"

# 2. Update Bind Address and Advertise Address
# Assuming the file has --bind-address and --advertise-address arguments
# If not, we append them or update them.
# The user's original script installed with these flags.

echo "Backing up service file to $SERVICE_FILE.bak"

# Replace the IP in the ExecStart line (using sed with a unique delimiter)
# This assumes the old IP was 10.8.22.147 or similar format.
# We'll just look for the --bind-address/--advertise-address lines if they exist, or append.
# But wait, the user's install script put them in the curl command, which modifies the systemd unit file on install.

# A safer way is to check the file content and modify it.
if grep -q "\-\-bind-address" "$SERVICE_FILE"; then
    echo "Found --bind-address argument. Updating..."
    sudo sed -i "s/--bind-address [0-9.]\+/--bind-address $NEW_IP/g" "$SERVICE_FILE"
else
    echo "Appending --bind-address..."
    sudo sed -i "/server \\\\/a \ \ --bind-address $NEW_IP \\\\" "$SERVICE_FILE"
fi

if grep -q "\-\-advertise-address" "$SERVICE_FILE"; then
    echo "Found --advertise-address argument. Updating..."
    sudo sed -i "s/--advertise-address [0-9.]\+/--advertise-address $NEW_IP/g" "$SERVICE_FILE"
else
    echo "Appending --advertise-address..."
    sudo sed -i "/server \\\\/a \ \ --advertise-address $NEW_IP \\\\" "$SERVICE_FILE"
fi

# 3. Reload Daemon and Restart K3s
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Restarting K3s Service..."
sudo systemctl restart k3s

echo "Waiting for K3s to start..."
sleep 10
sudo systemctl status k3s --no-pager

echo "=== Recovery Complete ==="
echo "Run 'kubectl get nodes' to verify."
