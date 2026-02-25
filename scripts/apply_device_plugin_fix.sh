#!/bin/bash
set -e

echo "=== Applying NVIDIA Device Plugin Fix ==="

# 0. Pre-flight Check: Are all nodes Ready?
NOT_READY_NODES=$(kubectl get nodes --no-headers | grep "NotReady" | awk '{print $1}')
if [ ! -z "$NOT_READY_NODES" ]; then
    echo "WARNING: The following nodes are NotReady:"
    echo "$NOT_READY_NODES"
    echo "The DaemonSet rollout will HANG until these nodes recover or are deleted."
    echo "To delete a dead node: kubectl delete node <node-name>"
    read -p "Press Enter to continue anyway (Ctrl+C to abort)..."
fi

echo "Updating DaemonSet configuration..."
kubectl apply -f k8s/nvidia-device-plugin.yaml

echo "Waiting for rollout to complete..."
kubectl rollout status daemonset -n kube-system nvidia-device-plugin-daemonset

echo "=== Fix Applied Successfully! ==="
echo "You can now proceed with deploying the backend and frontend."
