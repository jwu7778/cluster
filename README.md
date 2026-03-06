# Distributed GPU Computing Platform (Simple Shell Setup)

這是一個分散式 GPU 算力平台的輕量化版本，移除了 Ansible 依賴，改用簡單的 Shell Script 與 Kubernetes Manifests 進行安裝與部署。

## 專案架構

```
.
├── backend/          # FastAPI 後端服務 (提供 API 並 Serve React 靜態檔)
├── frontend/         # React 前端介面 (監控儀表板)
├── infrastructure/   # Kubernetes 部署清單 (NVIDIA Device Plugin, Backend 等)
└── scripts/          # 安裝與輔助腳本
    ├── fix_k3s_startup.sh # 修復 Master 節點磁碟滿載導致的 K3s 啟動失敗
    └── setup_gpu_node.sh  # 配置物理 Ubuntu 節點的 GPU 與 Containerd 環境
```

## 快速啟動 (Quick Start) - 物理 Ubuntu 節點

請按照以下順序操作，以確保環境正確設置並啟動監控。目前優先目標為串聯兩台物理 Ubuntu 主機 (暫緩 WSL)。

### 1. 修復與配置 Master Node
如果在 Master 節點遇到磁碟空間滿載導致的 K3s `connection refused` 或服務 `dead` 問題：

```bash
# 1. 給予腳本執行權限
chmod +x scripts/*.sh

# 2. 執行修復腳本 (清理損壞的資料庫/二進制檔並重啟服務)
sudo ./scripts/fix_k3s_startup.sh
```

### 2. 配置物理節點 GPU (Master & Worker)
在 **每一台** 具備 GPU 的 Ubuntu 物理機上執行以下腳本，以安裝 NVIDIA Container Toolkit 並配置 K3s 的 Containerd：

```bash
sudo ./scripts/setup_gpu_node.sh
```

### 3. 部署基礎設施與應用程式 (於 Master 執行)

請依序執行以下 `kubectl` 指令：

```bash
# 1. 部署 NVIDIA Device Plugin (修復 GPU 偵測)
kubectl apply -f infrastructure/nvidia-device-plugin.yaml

# 檢查 Plugin 是否就緒
kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset

# 2. 部署後端與前端聚合服務 (單一 Backend Pod Serve UI)
kubectl apply -f infrastructure/backend-deployment.yaml

# 3. 部署監控代理 (DaemonSet)
# 收集各節點 nvidia-smi 數據回報給 Backend
kubectl apply -f infrastructure/gpu-monitor-daemonset.yaml
```

### 4. 啟動應用程式 (本地開發測試)

若不透過 K8s 部署，可直接在本地啟動整合了前端與後端的服務：

```bash
# 1. 建置前端
cd frontend
npm install
npm run build
cd ..

# 2. 啟動後端 (會自動讀取 frontend/build)
cd backend
pip install -r requirements.txt
python main.py
```
打開瀏覽器訪問 `http://localhost:8000` 即可看到 Dashboard。
