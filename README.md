# Distributed GPU Computing Platform (Simple Shell Setup)

這是一個分散式 GPU 算力平台的輕量化版本，移除了 Ansible 依賴，改用簡單的 Shell Script 進行安裝。

## 快速啟動 (Quick Start)

請按照以下順序操作，以確保環境正確設置並啟動監控。

### 1. Master Node (Desktop) - 啟動 Backend 和 Monitoring
在 Ubuntu Desktop 上執行以下指令：

**A. 安裝基礎設施 (如果尚未安裝)**
```bash
# 1. 給予腳本執行權限
chmod +x scripts/*.sh

# 2. 安裝 Master 節點 (會自動配置 NVIDIA Runtime)
bash scripts/install_master.sh
```

**B. 部署應用程式與監控 (關鍵步驟)**
請依序執行以下 `kubectl` 指令，順序很重要：

```bash
# 1. 部署 NVIDIA Device Plugin (修復 GPU 偵測)
# 這是讓 K8s 看到 GPU 的關鍵，同時支援 WSL 與 Linux 路徑
kubectl apply -f k8s/nvidia-device-plugin.yaml

# 等待 Plugin 啟動完成
kubectl rollout status daemonset -n kube-system nvidia-device-plugin-daemonset

# 2. 部署後端服務 (Backend Service)
# 負責接收節點回報的數據
kubectl apply -f k8s/backend-deployment.yaml

# 3. 部署前端儀表板 (Frontend Dashboard)
# 提供視覺化介面 (Port 80)
kubectl apply -f k8s/frontend-deployment.yaml

# 4. 啟動監控代理 (Monitoring Agent)
# 在每個 GPU 節點上運行，回報 nvidia-smi 數據
kubectl apply -f k8s/gpu-monitor-daemonset.yaml
```

---

### 2. Worker Node (Laptop) - 加入 Cluster 並啟動 GPU Agent
在 Windows WSL 終端機中執行：

```bash
# 1. 給予腳本執行權限
chmod +x scripts/*.sh

# 2. 執行安裝腳本 (會詢問 Master URL 和 Token)
# 此腳本會自動修復 WSL GPU 環境並加入 K3s 集群
bash scripts/install_worker_wsl.sh
```

*(注意：Agent 會透過 DaemonSet 自動在加入的節點上啟動，無需額外手動執行)*

---

### 3. 驗證指令
如何確認 GPU 算力已經被正確分配到各個節點？

**A. 檢查節點 GPU 容量**
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu,STATUS:.status.conditions[-1].type
```
*預期輸出：每個節點的 GPU 欄位應顯示數字 (如 `1`)，而非 `<none>`。*

**B. 檢查監控數據流**
```bash
# 查看 Agent 是否成功回報數據
kubectl logs -l app=gpu-monitor-agent --tail=10
```
*預期輸出：`Reporting status for node <hostname> with X GPUs`*

**C. 訪問儀表板**
獲取 Frontend Service 的 IP：
```bash
kubectl get svc gpu-monitor-frontend-service
```
然後在瀏覽器開啟該 IP (或 localhost:80)。

---

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
