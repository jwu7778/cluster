# GPU Worker Verification Guide

Great news! Your WSL node `ailab` is now `Ready` in the cluster. This means the K3s agent is successfully talking to the master.

To confirm that the **GPU** is actually usable by Kubernetes (and not just visible to the OS), follow these steps:

## Step 1: Deploy the NVIDIA Device Plugin
Kubernetes needs a "Device Plugin" to advertise GPU resources to the scheduler. Without this, your node has a GPU, but Kubernetes doesn't know it can schedule pods on it.

Run this on your **Master Node**:
```bash
kubectl apply -f k8s/nvidia-device-plugin.yaml
```

Wait about 30 seconds, then check if the plugin pods are running:
```bash
kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset
```
You should see one pod for each node (master and worker).

## Step 2: Verify Node Capacity
Once the plugin is running, check if the node is advertising `nvidia.com/gpu` resources:

```bash
kubectl describe node ailab | grep "Allocatable" -A 5
```
You should see a line like:
```
  nvidia.com/gpu:  1
```

If you do NOT see `nvidia.com/gpu`, run the debug script:
```bash
bash scripts/debug_gpu_cluster.sh
```
Look for error messages in the logs like "no devices found" or configuration errors.

## Step 3: Run a Test Job
Now, let's run a real workload that requests a GPU and runs `nvidia-smi`.

Run this on your **Master Node**:
```bash
kubectl apply -f k8s/test-gpu-job.yaml
```

## Step 4: Check Results
Wait a few seconds for the job to complete.

1. **Check the Pod Status:**
   ```bash
   kubectl get pods
   ```
   You should see a pod named `gpu-test-job-xxxxx` with status `Completed`.

2. **View the Logs:**
   Replace `gpu-test-job-xxxxx` with the actual pod name from above:
   ```bash
   kubectl logs gpu-test-job-xxxxx
   ```

   **Success Criteria:**
   If everything is working, you will see the standard `nvidia-smi` table output showing your GPU (e.g., GeForce RTX 4090 or similar) inside the container.

---

## Troubleshooting

- **If the pod stays in `Pending` state:**
  - This usually means no node has available GPU capacity.
  - Re-check **Step 2**. If `nvidia.com/gpu` is 0 or missing, the Device Plugin isn't working or the Runtime config on the worker is still incorrect.
  - On the WSL worker, run `scripts/verify_gpu_runtime.sh` to double-check the local config.
  - Run `bash scripts/debug_gpu_cluster.sh` to capture logs from the cluster.

- **If the pod fails with `Error` or `CrashLoopBackOff`:**
  - Check `kubectl describe pod gpu-test-job-xxxxx`.
  - Check `kubectl logs gpu-test-job-xxxxx`.
