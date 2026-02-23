import time
from typing import Dict, List, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

# In-memory storage for node status
node_statuses: Dict[str, dict] = {}

class GPUStatus(BaseModel):
    utilization_gpu: int
    memory_used: int
    temperature: Optional[int] = None
    node_name: str
    timestamp: float

class JobRequest(BaseModel):
    image: str
    command: List[str]
    gpu_count: int = 1

@app.get("/")
def read_root():
    return {"status": "ok", "service": "GPU Dispatcher"}

@app.post("/report")
def report_status(status: GPUStatus):
    """
    Receives GPU status updates from nodes.
    """
    # Simply store the latest status from each node in memory
    node_statuses[status.node_name] = status.dict()
    return {"received": True}

@app.get("/status")
def get_status():
    """
    Returns the aggregated status of all nodes.
    """
    return node_statuses

@app.post("/submit")
def submit_job(job: JobRequest):
    """
    Submits a K8s Job.
    """
    # Stub for K8s Job creation
    print(f"Submitting job for image {job.image}: {job.command}")
    return {"job_id": "mock-job-id", "status": "submitted"}
