# Distributed GPU Computing Platform (Ubuntu + WSL)

這是一個分散式 GPU 算力平台的專案模板，旨在串接 Ubuntu 桌機（Master 節點）與 Windows WSL 筆電（Worker 節點），利用 K3s 建立 Kubernetes 集群，並提供簡單的算力監控與任務派發介面。

## 專案架構

```
.
├── ansible/          # 自動化部署腳本 (K3s 安裝、NVIDIA 驅動設定)
├── backend/          # FastAPI 後端服務 (接收 GPU 狀態、派發 K8s Job)
├── frontend/         # React 前端介面 (監控儀表板)
├── k8s/              # Kubernetes 部署清單 (DaemonSet 監控程式)
└── scripts/          # 輔助腳本 (WSL GPU 修復工具)
```

## 功能亮點

1.  **混合架構支援**：同時支援標準 Linux (Ubuntu) 與 Windows Subsystem for Linux (WSL2)。
2.  **WSL GPU 自動修復**：包含針對 WSL 環境的自動化修復腳本，解決 `/dev/dxg` 識別與 `libcuda.so` 載入問題。
3.  **即時監控**：透過 Kubernetes DaemonSet 在每個節點執行監控代理 (Agent)，即時回報 GPU 使用率與溫度。
4.  **任務派發**：後端 API 支援將運算任務封裝為 Kubernetes Job 派發至集群。

## 前置需求

*   **Master 節點 (Ubuntu)**：需安裝 Ansible。
*   **Worker 節點 (Windows)**：
    *   已安裝 WSL2 (Ubuntu 22.04+)。
    *   Windows 主機已安裝 NVIDIA 驅動程式 (WSL 會自動掛載)。
    *   確保 Master 節點可以 SSH 連線至 WSL (建議設定 SSH Key)。

## 安裝與部署步驟

### 1. 配置 Ansible

編輯 `ansible/inventory.ini`，填入你的節點 IP 與 SSH 使用者：

```ini
[master]
ubuntu-desktop ansible_host=192.168.1.100 ansible_user=user

[worker]
wsl-laptop ansible_host=192.168.1.101 ansible_user=user
```

### 2. 執行自動化部署

在專案根目錄執行 Ansible Playbook，這會安裝 K3s 並配置 NVIDIA Container Toolkit：

```bash
cd ansible
ansible-playbook -i inventory.ini site.yml
```

**此步驟會自動執行 `scripts/check_gpu_wsl.sh`，該腳本負責：**
*   檢查 `/dev/dxg` 是否存在 (確認 GPU Passthrough)。
*   將 `/usr/lib/wsl/lib` 加入 `LD_LIBRARY_PATH` (修復 `libcuda.so` 找不到的問題)。
*   配置 `nvidia-container-runtime` 以支援 K3s (Containerd)。

### 3. 部署監控服務 (K8s)

當 K3s 集群啟動後，將監控 Agent 部署到所有節點：

```bash
# 在 Master 節點執行
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/gpu-monitor-daemonset.yaml
```

*注意：`gpu-monitor-daemonset.yaml` 已配置 Volume Mount，將 WSL 的驅動路徑掛載至容器內，確保容器能存取 GPU。*

### 4. 啟動後端服務 (Backend)

你可以選擇在本地開發或將其部署到 K8s。以下為本地啟動方式：

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 5. 啟動前端介面 (Frontend)

```bash
cd frontend
npm install
npm start
```

開啟瀏覽器訪問 `http://localhost:3000`，即可看到 GPU 算力監控儀表板。

## API 說明

*   `GET /status`: 獲取所有節點的 GPU 狀態。
*   `POST /report`: 節點回報自身狀態 (由 Agent 呼叫)。
*   `POST /submit`: 提交運算任務 (範例)。

## 常見問題 (Troubleshooting)

*   **WSL 節點抓不到 GPU**：
    *   確認 Windows 主機的 NVIDIA 驅動是最新的。
    *   在 WSL 內執行 `nvidia-smi` 確認驅動是否正常掛載。
    *   檢查 `/etc/ld.so.conf.d/wsl.conf` 是否包含 `/usr/lib/wsl/lib`。

*   **K3s Pod 無法啟動**：
    *   檢查 `kubectl describe pod <pod-name>`。
    *   確認 `RuntimeClass` 是否正確配置 (K3s 預設使用 containerd，Ansible 腳本已針對此進行配置)。
