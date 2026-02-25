#!/bin/bash

# Script to deploy the GPU stack correctly (using local patched files)

echo "Deploying GPU Stack..."

# Check if kubectl is working
if ! kubectl get nodes > /dev/null 2>&1; then
    echo "Error: kubectl is not working. Please check your KUBECONFIG."
    echo "Try running: export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
    exit 1
fi

# 1. Apply the patched NVIDIA Device Plugin (Crucial for WSL support)
if [ -f "k8s/nvidia-device-plugin.yaml" ]; then
    echo "Cleaning up old NVIDIA Device Plugin..."
    kubectl delete -f k8s/nvidia-device-plugin.yaml 2>/dev/null || true
    kubectl delete ds nvidia-device-plugin-daemonset -n kube-system 2>/dev/null || true

    echo "Waiting for cleanup..."
    sleep 5

    echo "Applying patched NVIDIA Device Plugin..."
    kubectl apply -f k8s/nvidia-device-plugin.yaml
else
    echo "Error: k8s/nvidia-device-plugin.yaml not found!"
    exit 1
fi

# 2. Deploy the Backend
if [ -f "k8s/backend-deployment.yaml" ]; then
    echo "Deploying Backend..."
    kubectl apply -f k8s/backend-deployment.yaml
else
    echo "Warning: k8s/backend-deployment.yaml not found."
fi

# 3. Deploy the Frontend
if [ -f "k8s/frontend-deployment.yaml" ]; then
    echo "Deploying Frontend..."
    kubectl apply -f k8s/frontend-deployment.yaml
else
    echo "Warning: k8s/frontend-deployment.yaml not found."
fi

# 4. Deploy the Monitor
if [ -f "k8s/gpu-monitor-daemonset.yaml" ]; then
    echo "Deploying GPU Monitor..."
    kubectl apply -f k8s/gpu-monitor-daemonset.yaml
else
    echo "Warning: k8s/gpu-monitor-daemonset.yaml not found."
fi

echo "Deployment commands sent. Checking status..."
sleep 5
kubectl get pods -A | grep nvidia
echo "If the pod crashes, please run: ./scripts/fetch_crash_logs.sh"
