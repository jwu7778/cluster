from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import subprocess
import csv
import io
import uvicorn
import os

app = FastAPI()

# Add CORS middleware to allow requests from frontend (React usually on port 3000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For dev only, restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_nvidia_smi():
    try:
        # Run nvidia-smi with CSV output for easier parsing
        # Querying utilization.gpu and memory.used as requested
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=index,name,utilization.gpu,memory.used,temperature.gpu', '--format=csv,noheader,nounits'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        output = result.stdout.strip()

        gpus = []
        if output:
            reader = csv.reader(io.StringIO(output))
            for row in reader:
                if len(row) >= 5:
                    gpus.append({
                        "index": row[0].strip(),
                        "name": row[1].strip(),
                        "utilization": int(row[2].strip()),
                        "memory_used": int(row[3].strip()),
                        "temperature": int(row[4].strip())
                    })
        return gpus
    except subprocess.CalledProcessError as e:
        print(f"nvidia-smi error: {e.stderr}")
        return []
    except FileNotFoundError:
        print("nvidia-smi not found (running in mock mode?)")
        # Return mock data for testing if no GPU present
        return [
            {"index": "0", "name": "Mock GPU 1", "utilization": 45, "memory_used": 1024, "temperature": 65},
            {"index": "1", "name": "Mock GPU 2", "utilization": 12, "memory_used": 512, "temperature": 55}
        ] if os.getenv("MOCK_GPU", "false").lower() == "true" else []

@app.get("/")
def read_root():
    return {"status": "ok", "service": "gpu-monitor-backend"}

from pydantic import BaseModel
from typing import List, Dict

# In-memory store for GPU status from all nodes
# Format: { "node_name": { "gpus": [...], "last_updated": timestamp } }
cluster_status: Dict[str, dict] = {}

class GPUStatus(BaseModel):
    index: str
    name: str
    utilization: int
    memory_used: int
    temperature: int

class NodeReport(BaseModel):
    node: str
    gpus: List[GPUStatus]
    gpu_count: int

@app.post("/report")
def report_status(report: NodeReport):
    """
    Receives GPU status reports from worker nodes via the DaemonSet agent.
    """
    cluster_status[report.node] = report.dict()
    return {"status": "received", "node": report.node}

@app.get("/status")
def get_status():
    """
    Returns the aggregated status of all nodes in the cluster.
    """
    # If no agents have reported yet, return local status as fallback
    if not cluster_status:
        local_gpus = get_nvidia_smi()
        hostname = os.uname().nodename
        return [{
            "node": hostname,
            "gpus": local_gpus,
            "gpu_count": len(local_gpus)
        }]

    # Return list of all node statuses
    return list(cluster_status.values())

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
