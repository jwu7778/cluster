# Test Plan: Distributed GPU Computing Platform

## 1. Master Node Installation (Ubuntu 24.04 Desktop)

This script has been updated to aggressively handle the "Conflicting values set for option Signed-By" error caused by duplicate PPA definitions.

### Steps:
1.  **Pull Latest Changes:**
    ```bash
    cd ~/cluster
    git pull
    ```
2.  **Make Scripts Executable:**
    ```bash
    chmod +x scripts/*.sh
    ```
3.  **Run Master Installation:**
    ```bash
    # This script will now:
    # 1. Detect and uninstall any previous K3s installation.
    # 2. Aggressively remove all 'graphics-drivers' PPA files to fix APT errors.
    # 3. Purge old drivers and conflicting packages (libnvidia-egl-gbm1).
    # 4. Re-add PPA, install drivers (v535), and install K3s.
    ./scripts/install_master.sh
    ```
4.  **Verification:**
    *   Check if K3s is running: `sudo systemctl status k3s`
    *   Check NVIDIA driver: `nvidia-smi`
    *   Check if node is ready: `sudo kubectl get nodes`

## 2. Worker Node Installation (WSL2)

### Steps:
1.  **Prepare Environment:**
    Ensure you are inside your WSL2 instance (Ubuntu).
2.  **Run Worker Installation:**
    Using the Token and URL provided by the Master installation output:
    ```bash
    export K3S_URL=https://<MASTER_IP>:6443
    export K3S_TOKEN=<TOKEN>

    # This script will:
    # 1. Run check_gpu_wsl.sh to verify /dev/dxg and configure ld.so.conf
    # 2. Install NVIDIA Container Toolkit
    # 3. Join the cluster
    ./scripts/install_worker_wsl.sh
    ```
3.  **Verification (on Master):**
    *   Run `sudo kubectl get nodes` and ensure the WSL node appears as `Ready`.

## 3. GPU Passthrough Verification

### On Worker Node (WSL):
1.  **Check Hardware Access:**
    ```bash
    ls -l /dev/dxg
    # Should show the device file
    ```
2.  **Check Library Path:**
    ```bash
    ldconfig -p | grep wsl
    # Should show libraries in /usr/lib/wsl/lib
    ```

### On Master Node (Cluster Check):
1.  **Deploy a Test Pod:**
    Create a file `gpu-test.yaml`:
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: gpu-test
    spec:
      containers:
      - name: cuda-container
        image: nvidia/cuda:11.8.0-base-ubuntu22.04
        command: ["nvidia-smi"]
        resources:
          limits:
            nvidia.com/gpu: 1
    ```
2.  **Run Test:**
    ```bash
    sudo kubectl apply -f gpu-test.yaml
    sudo kubectl logs gpu-test
    # Output should show the GPU table
    ```
