#!/bin/bash
set -e

echo "=== Cleaning Up NotReady Nodes ==="

NOT_READY_NODES=$(kubectl get nodes --no-headers | grep "NotReady" | awk '{print $1}')

if [ -z "$NOT_READY_NODES" ]; then
    echo "No NotReady nodes found. Cluster looks healthy."
    exit 0
fi

echo "Found the following NotReady nodes:"
echo "$NOT_READY_NODES"
echo ""
echo "These nodes are preventing DaemonSet rollouts from completing."
echo "If these nodes are offline (e.g., WSL IP changed), you should delete them."
echo "They will re-register automatically when the agent restarts on the worker."
echo ""
read -p "Do you want to delete these nodes now? (y/N) " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    for node in $NOT_READY_NODES; do
        echo "Deleting node: $node"
        kubectl delete node "$node"
    done
    echo "Cleanup complete. Run 'kubectl get nodes' to verify."
else
    echo "Aborted."
fi
