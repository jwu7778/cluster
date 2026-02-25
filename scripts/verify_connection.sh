#!/bin/bash
set -e

echo "=== Verifying Master Node Connectivity ==="

# 1. Ask for Master IP
read -p "Enter Master Node IP (e.g., 10.8.22.147): " MASTER_IP
if [ -z "$MASTER_IP" ]; then
    echo "ERROR: IP is required."
    exit 1
fi

echo "Checking connectivity to $MASTER_IP..."

# 2. Ping Check
echo "--- Ping Test ---"
if ping -c 3 "$MASTER_IP" &> /dev/null; then
    echo "SUCCESS: Master node is reachable via Ping."
else
    echo "WARNING: Master node is NOT responding to Ping. (This might be firewall blocking ICMP)"
fi

# 3. Port Check (6443)
echo "--- K3s Port (6443) Check ---"
if command -v nc &> /dev/null; then
    if nc -z -v -w 5 "$MASTER_IP" 6443 &> /dev/null; then
        echo "SUCCESS: Port 6443 is OPEN."
    else
        echo "ERROR: Port 6443 is CLOSED or BLOCKED."
        echo "Please run this on the Master Node: sudo ufw allow 6443/tcp"
    fi
else
    # Fallback to curl
    if curl -k --connect-timeout 5 "https://$MASTER_IP:6443" &> /dev/null; then
        echo "SUCCESS: K3s API is reachable (Port 6443)."
    else
        echo "ERROR: Cannot connect to K3s API on port 6443."
        echo "Please check firewall on Master Node."
    fi
fi

echo "=== Verification Complete ==="
