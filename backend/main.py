import time
import uuid
from typing import Dict, List, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from kubernetes import client, config

app = FastAPI()

# In-memory storage for node status
node_statuses: Dict[str, dict] = {}

# Try to load Kubernetes configuration
try:
    config.load_incluster_config()
    print("Loaded in-cluster configuration.")
except config.ConfigException:
    try:
        config.load_kube_config()
        print("Loaded kube-config.")
    except config.ConfigException:
        print("Warning: Could not load Kubernetes configuration. Job submission will fail.")

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
    Submits a K8s Job requesting GPU resources.
    """
    job_name = f"gpu-job-{uuid.uuid4().hex[:8]}"

    # Define the container with GPU limits
    container = client.V1Container(
        name="gpu-container",
        image=job.image,
        command=job.command,
        resources=client.V1ResourceRequirements(
            limits={"nvidia.com/gpu": str(job.gpu_count)}
        )
    )

    # Define the Job spec
    template = client.V1PodTemplateSpec(
        metadata=client.V1ObjectMeta(labels={"app": "gpu-job"}),
        spec=client.V1PodSpec(
            restart_policy="Never",
            containers=[container]
        )
    )

    spec = client.V1JobSpec(
        template=template,
        backoff_limit=2,
        ttl_seconds_after_finished=600  # Clean up after 10 mins
    )

    job_obj = client.V1Job(
        api_version="batch/v1",
        kind="Job",
        metadata=client.V1ObjectMeta(name=job_name),
        spec=spec
    )

    try:
        batch_v1 = client.BatchV1Api()
        api_response = batch_v1.create_namespaced_job(
            body=job_obj,
            namespace="default"
        )
        print(f"Job created: {job_name}")
        return {"job_id": job_name, "status": "submitted"}
    except Exception as e:
        print(f"Exception when calling BatchV1Api->create_namespaced_job: {e}")
        # Return mock response if K8s is not available (for testing UI without cluster)
        # return {"job_id": job_name, "status": "mock-submitted", "error": str(e)}
        raise HTTPException(status_code=500, detail=str(e))
