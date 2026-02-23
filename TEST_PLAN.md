# Test Plan & Verification Instructions

## 1. Master Node (Ubuntu Desktop) Fix Validation

**Goal:** Verify that the "Conflicting values set for option Signed-By" error is resolved and NVIDIA drivers install correctly.

**Steps:**
1.  On your Ubuntu Desktop (Master Node), navigate to the project directory.
2.  Ensure you have the latest version of `scripts/install_master.sh`.
3.  Run the installation script:
    ```bash
    sudo ./scripts/install_master.sh
    ```
4.  **Expected Output:**
    - The script should proceed past the "Purging old NVIDIA drivers..." and "Installing NVIDIA Driver 535..." steps without error.
    - Specifically, no "Conflicting values set for option Signed-By" errors should appear.
    - The script should complete with "Master Installation Complete!".

**Verification:**
- Run `nvidia-smi` to confirm drivers are loaded.
- Run `kubectl get nodes` to confirm K3s master is running.

## 2. WSL Worker Node Configuration Check

**Goal:** Verify that the WSL environment is correctly configured for GPU passthrough.

**Steps:**
1.  On your Windows machine, open a WSL terminal (Ubuntu distribution).
2.  Navigate to the project directory.
3.  Run the check script:
    ```bash
    ./scripts/check_gpu_wsl.sh
    ```
4.  **Expected Output:**
    - `SUCCESS: /dev/dxg found.` (Indicates GPU passthrough is active).
    - `SUCCESS: Appended /usr/lib/wsl/lib to /etc/ld.so.conf.d/wsl.conf...` (or similar success message).
    - `WARNING: LD_LIBRARY_PATH environment variable does not contain...` (This is normal if you haven't set it in `.bashrc` yet; follow the instructions if needed).
    - `SUCCESS: Created /etc/nvidia-container-runtime/config.toml` (or similar).

**Verification:**
- Run `nvidia-smi` inside WSL. It should display GPU information.
- Run `ldconfig -p | grep libcuda` to confirm CUDA libraries are reachable.
