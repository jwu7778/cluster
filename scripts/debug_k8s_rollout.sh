#!/bin/bash
set -e

echo "=== Debugging DaemonSet Rollout (v1.0) ==="

# 1. Check if the DaemonSet exists and its status
echo "--- Checking DaemonSet Status ---"
kubectl get daemonset -n kube-system nvidia-device-plugin-daemonset -o wide

# 2. Check if pods are running
echo "--- Checking DaemonSet Pods ---"
PODS=$(kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset -o name)
if [ -z "$PODS" ]; then
    echo "ERROR: No pods found for DaemonSet 'nvidia-device-plugin-daemonset'."
else
    echo "Found pods: $PODS"
    kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset -o wide
fi

# 3. Describe pending/failed pods
echo "--- Describing Pending/Failed Pods ---"
PENDING_PODS=$(kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset --field-selector=status.phase!=Running -o name)
if [ -z "$PENDING_PODS" ]; then
    echo "No pending or failed pods found."
else
    for pod in $PENDING_PODS; do
        echo "Describing Pod: $pod"
        kubectl describe $pod -n kube-system
        echo "-----------------------------------"
    done
fi

# 4. Check Node Status
echo "--- Checking Node Status ---"
kubectl get nodes -o wide
kubectl describe nodes | grep -E "Taint|Allocatable|Capacity" -A 5

# 5. Check logs of running/completed/crashed pods
echo "--- Fetching Logs ---"
for pod in $PODS; do
    echo "Logs for Pod: $pod"
    kubectl logs $pod -n kube-system --tail=50 || echo "Cannot fetch logs for $pod"
    echo "-----------------------------------"
done

echo "=== End of Debug Report ==="
echo "If pods are pending, check Taints on nodes or Resource limits."
echo "If pods are crashing, check logs for runtime errors."
