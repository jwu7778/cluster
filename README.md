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
    └── check_gpu_wsl.sh      # WSL GPU 檢查腳本
```

## 前置需求

*   **Master 節點 (Ubuntu Desktop)**: 必須先手動安裝好 NVIDIA 驅動 (建議 535+)，並確認 `nvidia-smi` 運作正常。
*   **Worker 節點 (Windows WSL2)**: 必須先在 Windows 端安裝 NVIDIA 驅動，並確認 WSL 內可看到 `/dev/dxg`。

## 安裝步驟

### 1. Master 節點 (Ubuntu)

在 Ubuntu Desktop 上執行：

```bash
sudo chmod +x scripts/*.sh
./scripts/install_master.sh
```

此腳本會自動：
1.  **檢查** NVIDIA 驅動狀態 (不會重新安裝驅動)。
2.  安裝 NVIDIA Container Toolkit (如果尚未安裝)。
3.  配置 K3s Master (使用 Containerd Runtime)。
4.  **輸出** 連線所需的 Token 與 URL。

### 2. Worker 節點 (WSL)

在 WSL 終端機中，執行安裝腳本：

```bash
sudo chmod +x scripts/*.sh
./scripts/install_worker_wsl.sh
```

此腳本會互動式詢問 `K3S_URL` 與 `K3S_TOKEN`，並自動：
1.  檢查並修復 WSL GPU 環境 (`/dev/dxg` 與 `ld.so.conf`)。
2.  安裝 NVIDIA Container Toolkit。
3.  加入 K3s 集群 (Agent Mode)。

### 3. 部署監控服務 (K8s)

回到 Master 節點執行 (確保 K3s 已啟動)：

```bash
# 部署後端 Service 與 DaemonSet
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/gpu-monitor-daemonset.yaml
```

### 4. 啟動應用程式 (開發模式)

啟動後端 API：
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

啟動前端 Dashboard：
```bash
cd frontend
npm install
npm start
```
