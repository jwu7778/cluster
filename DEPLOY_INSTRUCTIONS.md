# GPU Cluster Deployment Guide

This document outlines the steps to deploy the GPU monitoring platform on your K3s cluster.

## 1. Prerequisites (Build Docker Images)
You need to build the Docker images for the Backend, Frontend, and Agent. Run these commands from the root of the project:

### Backend
```bash
docker build -t gpu-monitor-backend:latest -f backend/Dockerfile .
# If using local K3s registry (optional):
# docker save gpu-monitor-backend:latest | sudo k3s ctr images import -
```

### Frontend
```bash
docker build -t gpu-monitor-frontend:latest -f frontend/Dockerfile frontend/
# If using local K3s registry (optional):
# docker save gpu-monitor-frontend:latest | sudo k3s ctr images import -
```

### Monitoring Agent
```bash
docker build -t gpu-monitor-agent:latest -f backend/Dockerfile.monitor backend/
# If using local K3s registry (optional):
# docker save gpu-monitor-agent:latest | sudo k3s ctr images import -
```

---

## 2. Deployment Order (kubectl apply)

Follow this strict order to ensure dependencies are met.

### Step 1: Infrastructure & Device Plugin (CRITICAL)
This fixes the GPU driver paths on both Ubuntu Master and WSL Worker nodes.
```bash
kubectl apply -f k8s/nvidia-device-plugin.yaml
```
*Wait for the daemonset to be ready:*
```bash
kubectl rollout status daemonset -n kube-system nvidia-device-plugin-daemonset
```

### Step 2: Backend Service
The backend aggregates data. It must be running before agents start reporting.
```bash
kubectl apply -f k8s/backend-deployment.yaml
```

### Step 3: Frontend Dashboard
Deploys the React UI.
```bash
kubectl apply -f k8s/frontend-deployment.yaml
```

### Step 4: Monitoring Agent (DaemonSet)
Deploys the agent on every GPU node to push data to the backend.
```bash
kubectl apply -f k8s/gpu-monitor-daemonset.yaml
```

---

## 3. Verification

### Verify GPU Detection (Infrastructure)
Check if nodes report GPU capacity:
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu
# Expected: All nodes should show '1' or more (not <none>).
```

### Verify Monitoring Agent
Check if the agents are running and successfully pushing data:
1.  **Check Pod Status:**
    ```bash
    kubectl get pods -l app=gpu-monitor-agent
    ```
2.  **Check Agent Logs:**
    ```bash
    kubectl logs -l app=gpu-monitor-agent --tail=20
    # Look for: "Reporting status for node <hostname> with X GPUs"
    ```
3.  **Check Backend API:**
    Access the backend status endpoint (port-forward if needed):
    ```bash
    kubectl port-forward svc/gpu-monitor-backend-service 8000:80
    curl http://localhost:8000/status
    # Expected Output: JSON array with node data [{"node": "...", "gpus": [...]}]
    ```

### Access Dashboard
Get the LoadBalancer IP (or use NodePort/Port-Forward):
```bash
kubectl get svc gpu-monitor-frontend-service
# Access http://<EXTERNAL-IP>:80
```
