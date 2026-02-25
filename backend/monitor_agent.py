import subprocess
import csv
import io
import time
import os
import requests
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

BACKEND_URL = os.getenv("BACKEND_URL", "http://gpu-monitor-backend-service.default.svc.cluster.local:80/report")
NODE_NAME = os.getenv("NODE_NAME", os.uname().nodename)
REPORT_INTERVAL = int(os.getenv("REPORT_INTERVAL", 5))

def get_nvidia_smi():
    try:
        # Query nvidia-smi for local GPU stats
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
        logger.error(f"nvidia-smi error: {e.stderr}")
        return []
    except FileNotFoundError:
        logger.warning("nvidia-smi not found (mock mode?)")
        if os.getenv("MOCK_GPU", "false").lower() == "true":
             return [
                {"index": "0", "name": f"Mock GPU on {NODE_NAME}", "utilization": 45, "memory_used": 1024, "temperature": 65}
            ]
        return []

def report_status():
    while True:
        try:
            gpus = get_nvidia_smi()
            payload = {
                "node": NODE_NAME,
                "gpus": gpus,
                "gpu_count": len(gpus)
            }
            logger.info(f"Reporting status for node {NODE_NAME} with {len(gpus)} GPUs")
            requests.post(BACKEND_URL, json=payload, timeout=2)
        except Exception as e:
            logger.error(f"Failed to report status: {e}")

        time.sleep(REPORT_INTERVAL)

if __name__ == "__main__":
    logger.info("Starting GPU Monitor Agent...")
    report_status()
