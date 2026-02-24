#!/bin/bash
set -e

echo "=== Debugging GPU Cluster Status ==="

echo -e "\n1. Checking Nodes Status:"
kubectl get nodes -o wide

echo -e "\n2. Describing Worker Node 'ailab' Capacity (Look for nvidia.com/gpu):"
kubectl describe node ailab | grep -A 10 "Allocatable"

echo -e "\n3. Checking Device Plugin Pods:"
kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset -o wide

echo -e "\n4. Fetching Logs from Device Plugin Pods:"
PODS=$(kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset -o jsonpath='{.items[*].metadata.name}')

for pod in $PODS; do
    echo -e "\n--- Logs for Pod: $pod ---"
    kubectl logs -n kube-system "$pod" --tail=50
done

echo -e "\n=== End of Debug Report ==="
echo "If the logs show 'Error: no devices found' or similar, check if /dev/dxg (WSL) or NVIDIA drivers (Master) are working."
