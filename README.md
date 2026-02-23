# Distributed GPU Computing Platform (Simple Shell Setup)

這是一個分散式 GPU 算力平台的輕量化版本，移除了 Ansible 依賴，改用簡單的 Shell Script 進行安裝。

## 專案架構

```
.
├── backend/          # FastAPI 後端服務 (接收 GPU 狀態、派發 K8s Job)
├── frontend/         # React 前端介面 (監控儀表板)
├── k8s/              # Kubernetes 部署清單 (DaemonSet 監控程式)
└── scripts/          # 安裝與輔助腳本
    ├── install_master.sh     # Ubuntu Desktop 安裝腳本
    ├── install_worker_wsl.sh # WSL Worker 安裝腳本
    └── check_gpu_wsl.sh      # WSL GPU 修復邏輯
```

## 前置需求

*   **Master 節點 (Ubuntu Desktop)**
*   **Worker 節點 (Windows WSL2)**：已啟用 systemd (推薦)。

## 安裝步驟

### 1. Master 節點 (Ubuntu)

在 Ubuntu Desktop 上執行：

```bash
sudo chmod +x scripts/*.sh
./scripts/install_master.sh
```

此腳本會自動：
1.  **移除** 不穩定的 NVIDIA 575 驅動。
2.  **安裝** 穩定的 NVIDIA 535 驅動。
3.  安裝 NVIDIA Container Toolkit。
4.  安裝 K3s Master。
5.  **輸出** 連線所需的 Token 與 URL。

### 2. Worker 節點 (WSL)

在 WSL 終端機中，使用 Master 輸出的資訊設定環境變數，然後執行安裝：

```bash
export K3S_URL=https://<MASTER_IP>:6443
export K3S_TOKEN=<TOKEN_FROM_MASTER>

sudo chmod +x scripts/*.sh
./scripts/install_worker_wsl.sh
```

此腳本會自動：
1.  執行 `check_gpu_wsl.sh` 修復 `/dev/dxg` 與 `LD_LIBRARY_PATH`。
2.  安裝 NVIDIA Container Toolkit。
3.  加入 K3s 集群。

### 3. 部署監控服務 (K8s)

回到 Master 節點執行：

```bash
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/gpu-monitor-daemonset.yaml
```

### 4. 啟動應用程式

啟動後端：
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

啟動前端：
```bash
cd frontend
npm install
npm start
```
