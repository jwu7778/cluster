# Troubleshooting Master Node NotReady

If your Master Node shows `NotReady` after changing the network cable (e.g., WSL -> Linux), it likely means its IP address changed, or the network interface is down.

## Step 1: Check Master Status
Run this script on the Master Node (Ubuntu Desktop):
```bash
bash scripts/check_master_status.sh
```
- Verify the **K3s Service** is active.
- Compare the **Current IP** with the configured IP in the service file.

## Step 2: Recover Master IP (If Changed)
If the IP address changed (e.g., from `10.8.22.147` to `192.168.1.50`), run:
```bash
bash scripts/recover_master_ip.sh
```
Enter the **new** IP address when prompted. This will update the K3s configuration and restart the service.

## Step 3: Verify Cluster Status
```bash
kubectl get nodes
```
The Master Node should become `Ready`.

## Step 4: Re-register Workers
If the Master IP changed, you must reinstall the agents on all worker nodes using the NEW Master IP:
```bash
# On Worker (Linux/WSL)
bash scripts/install_worker_linux.sh  # or install_worker_wsl.sh
```
(Update the `MASTER_IP` variable in the script first!)
