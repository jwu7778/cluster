#!/bin/bash
set -e

echo "=== Applying NVIDIA Device Plugin Fix ==="
echo "Updating DaemonSet configuration..."
kubectl apply -f k8s/nvidia-device-plugin.yaml

echo "Waiting for rollout to complete..."
kubectl rollout status daemonset -n kube-system nvidia-device-plugin-daemonset

echo "=== Fix Applied Successfully! ==="
echo "You can now proceed with deploying the backend and frontend."
